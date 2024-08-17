#!/bin/bash

#     ____                  __        ____
#    / __ \____ ___________/ /_____ _/ / /
#   / /_/ / __ `/ ___/ ___/ __/ __ `/ / /
#  / ____/ /_/ / /__(__  ) /_/ /_/ / / /
# /_/    \__,_/\___/____/\__/\__,_/_/_/
#
# Copyright (C) 2020-present
#
# This file is part of Pacstall
#
# Pacstall is free software: you can redistribute it and/or modify
# it under the terms of the GNU General Public License as published by
# the Free Software Foundation, version 3 of the License
#
# Pacstall is distributed in the hope that it will be useful,
# but WITHOUT ANY WARRANTY; without even the implied warranty of
# MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE. See the
# GNU General Public License for more details.
#
# You should have received a copy of the GNU General Public License
# along with Pacstall. If not, see <https://www.gnu.org/licenses/>.

{ ignore_stack=false; set -o pipefail; trap stacktrace ERR RETURN; }

# shellcheck source=./misc/scripts/version-constraints.sh
source "${SCRIPTDIR}/scripts/version-constraints.sh" || {
    fancy_message error $"Could not find version-constraints"
    { ignore_stack=true; return 1; }
}

# shellcheck source=./misc/scripts/srcinfo.sh
source "${SCRIPTDIR}/scripts/srcinfo.sh" || {
    fancy_message error $"Could not find srcinfo.sh"
    { ignore_stack=true; return 1; }
}

# shellcheck source=./misc/scripts/manage-repo.sh
source "${SCRIPTDIR}/scripts/manage-repo.sh" || {
    fancy_message error $"Could not find manage-repo.sh"
    { ignore_stack=true; return 1; }
}

function deblog() {
    { ignore_stack=false; set -o pipefail; trap stacktrace ERR RETURN; }
    local key="$1"
    shift
    local content=("$@")
    echo "$key: ${content[*]}" | sudo tee -a "$STAGEDIR/$pacname/DEBIAN/control" > /dev/null
}

function clean_builddir() {
    { ignore_stack=false; set -o pipefail; trap stacktrace ERR RETURN; }
    sudo rm -rf "${STAGEDIR:?}/${pacname:?}"
    sudo rm -f "${STAGEDIR:?}/${pacname}.deb"
}

function check_apt_dep() {
    { ignore_stack=false; set -o pipefail; trap stacktrace ERR RETURN; }
    local dep="${1}" just_name just_arch real_dep
    real_dep="${dep}"
    # Firstly, check if this is an alt dep list
    if dep_const.is_pipe "${dep}"; then
        dep="$(dep_const.get_pipe "${dep}")"
    fi
    # Let's get just the name
    dep_const.split_name_and_version "${dep}" just_name
    just_arch="$(dep_const.get_arch "${just_name[0]}")"
    # Check if package exists in the repos, and if not, go to the next program
    if [[ ${just_name[0]} == *":${just_arch}" ]]; then
        if [[ -z "$(aptitude search --quiet --disable-columns "?exact-name(${just_name[0]%:*})?architecture(${just_arch})" -F "%p")" ]]; then
            if [[ -z "$(aptitude search --quiet --disable-columns "?provides(^${just_name[0]%:*}$)?architecture(${just_arch})" -F "%p")" ]]; then
                echo "${real_dep}" >> "${PACDIR}-missing-deps-${pacname}"
                fancy_message sub $"${BLUE}${real_dep}${NC} ${RED}✗${NC} [required]"
                return 0
            fi
        fi
    else
        if [[ -z "$(apt-cache search --no-generate --names-only "^${just_name[0]}\$" 2> /dev/null || apt-cache search --names-only "^${just_name[0]}\$")" ]]; then
            if [[ -z "$(aptitude search --quiet --disable-columns "?exact-name(${just_name[0]})?architecture(${just_arch})" -F "%p")" ]]; then
                if [[ -z "$(aptitude search --quiet --disable-columns "?provides(^${just_name[0]}$)?architecture(${just_arch})" -F "%p")" ]]; then
                    echo "${real_dep}" >> "${PACDIR}-missing-deps-${pacname}"
                    fancy_message sub $"${BLUE}${real_dep}${NC} ${RED}✗${NC} [required]"
                    return 0
                fi
            fi
        fi
    fi
    # Next let's check if the version (if available) is in the repos
    dep_const.apt_compare_to_constraints "${dep}" || { echo "${real_dep}" >> "${PACDIR}-not-satisfied-deps-${pacname}"; return 0; }
    # Add to the dependency list if already installed so it doesn't get autoremoved on upgrade
    echo "${real_dep}" >> "${PACDIR}-deps-${pacname}"
    if ! is_apt_package_installed "${just_name[0]}"; then
        fancy_message sub $"${BLUE}${just_name[0]} ${GREEN}↑${YELLOW}↓${NC} [remote]"
    else
        fancy_message sub $"${BLUE}${just_name[0]} ${GREEN}✓${NC} [installed]"
    fi
}

function check_opt_dep() {
    { ignore_stack=false; set -o pipefail; trap stacktrace ERR RETURN; }
    local optdep="${1}" just_name just_arch realopt optdesc opt
    dep_const.extract_description "${optdep}" optdesc
    dep_const.strip_description "${optdep}" realopt
    # Firstly, check if this is an alt dep list
    if dep_const.is_pipe "${optdep}"; then
        # Ok, we need to select *one* of those deps to be our sacrificial lamb Ψ(•̀ᴗ•́ )⤴
        optdep="$(dep_const.get_pipe "${optdep}")"
    fi
    if ! [[ ${optdep} =~ ${optdesc} ]]; then
        optdep="${optdep}: ${optdesc}"
    fi
    # Strip the description, `opt` is now the canonical optdep name
    dep_const.strip_description "${optdep}" opt
    # Let's get just the name
    dep_const.split_name_and_version "${opt}" just_name
    just_arch="$(dep_const.get_arch "${just_name[0]}")"
    # Check if package exists in the repos, and if not, go to the next program
    if [[ ${just_name[0]} == *":${just_arch}" ]]; then
        if [[ -z "$(aptitude search --quiet --disable-columns "?exact-name(${just_name[0]%:*})?architecture(${just_arch})" -F "%p")" ]]; then
            if [[ -z "$(aptitude search --quiet --disable-columns "?provides(^${just_name[0]%:*}$)?architecture(${just_arch})" -F "%p")" ]]; then
                echo "${realopt}" >> "${PACDIR}-missing-optdeps-${pacname}"
                return 0
            fi
        fi
    else
        if [[ -z "$(apt-cache search --no-generate --names-only "^${just_name[0]}\$" 2> /dev/null || apt-cache search --names-only "^${just_name[0]}\$")" ]]; then
            if [[ -z "$(aptitude search --quiet --disable-columns "?exact-name(${just_name[0]})?architecture(${just_arch})" -F "%p")" ]]; then
                if [[ -z "$(aptitude search --quiet --disable-columns "?provides(^${just_name[0]}$)?architecture(${just_arch})" -F "%p")" ]]; then
                    echo "${realopt}" >> "${PACDIR}-missing-optdeps-${pacname}"
                    return 0
                fi
            fi
        fi
    fi
    # Next let's check if the version (if available) is in the repos
    dep_const.apt_compare_to_constraints "${opt}" || { echo "${realopt}" >> "${PACDIR}-not-satisfied-optdeps-${pacname}"; return 0; }

    # Add to the dependency list if already installed so it doesn't get autoremoved on upgrade
    # If the package is not installed already, add it to the list. It's much easier for a user to choose from a list of uninstalled packages than every single one regardless of it's status
    if ! is_apt_package_installed "${just_name[0]}"; then
        echo "${realopt}: ${optdesc}" >> "${PACDIR}-suggested-optdeps-${pacname}"
    else
        echo "${realopt}" >> "${PACDIR}-already-installed-optdeps-${pacname}"
    fi
}

function prompt_aptdepends() {
    { ignore_stack=false; set -o pipefail; trap stacktrace ERR RETURN; }
    # So basically, we're gonna now check if the `depends` elements can be installed on this system based on the
    # version constraints (if available), because I'd be very pissed if I tried building wine only to figure out
    # 8 hours later the versions specified in `depends` aren't available.
    if [[ -n ${missing_deps[*]} ]]; then
        echo -ne "\t"
        fancy_message error $"${BLUE}$(printf "${BLUE}%s${NC}, " "${missing_deps[@]}" | sed 's/, $/\n/')${NC} does not exist in apt repositories"
    fi
    if [[ -n ${not_satisfied_deps[*]} ]]; then
        echo -ne "\t"
        fancy_message error $"${BLUE}$(printf "${BLUE}%s${NC}, " "${not_satisfied_deps[@]}" | sed 's/, $/\n/')${NC} version(s) cannot be satisfied"
    fi
    if [[ -n ${missing_deps[*]} || -n ${not_satisfied_deps[*]} ]]; then
        fancy_message info $"Cleaning up"
        cleanup
        exit 1
    fi
}

function prompt_optdepends() {
    { ignore_stack=false; set -o pipefail; trap stacktrace ERR RETURN; }
    if [[ -n ${missing_optdeps[*]} || -n ${not_satisfied_optdeps[*]} ]] || ((${#suggested_optdeps[@]} != 0)); then
        fancy_message info $"Optional dependencies"
    fi
    if [[ -n ${missing_optdeps[*]} ]]; then
        echo -ne "\t"
        fancy_message warn $"${BLUE}$(printf "${BLUE}%s${NC}, " "${missing_optdeps[@]}" | sed 's/, $/\n/')${NC} does not exist in apt repositories"
    fi
    if [[ -n ${not_satisfied_optdeps[*]} ]]; then
        echo -ne "\t"
        fancy_message warn $"${BLUE}$(printf "${BLUE}%s${NC}, " "${not_satisfied_optdeps[@]}" | sed 's/, $/\n/')${NC} version(s) cannot be satisfied"
    fi
    if ((${#suggested_optdeps[@]} != 0)); then
        if ((PACSTALL_INSTALL != 0)); then
            # We do this so that arrays 'start at' 1 to the user
            z=1
            echo -e "\t\t[${BIRed}0${NC}] Select none"
            for i in "${suggested_optdeps[@]}"; do
                # print optdepends with bold package name
                echo -e "\t\t[${BICyan}$z${NC}] ${BOLD}${i%%:\ *}${NC}: ${i#*:\ }"
                { ignore_stack=true; ((z++)); }
            done
            unset z
            # tab over the next line
            echo -ne "\t"
            select_options "Select optional dependencies to install" "${#suggested_optdeps[@]}" "optdeps"
            read -ra choices < "${PACDIR}-selectopts-optdeps-${pacname}"
            local choice_inc=0
            for i in "${choices[@]}"; do
                # have we gone over the maximum number in choices[@]?
                if [[ $i != "n" && $i != "y" ]] && ((i > ${#suggested_optdeps[@]})); then
                    local skip_opt+=("$i")
                    unset 'choices[$choice_inc]'
                fi
                { ignore_stack=true; ((choice_inc++)); }
            done
            if [[ -n ${skip_opt[*]} ]]; then
                fancy_message warn $"${BGreen}${skip_opt[*]}${NC} has exceeded the maximum number of optional dependencies. Skipping"
            fi

            # Did we get actual answers?
            if [[ ${choices[0]} != "n" && ${choices[0]} != "0" ]]; then
                for i in "${choices[@]}"; do
                    # Set our user array that started at 1 down to 0 based
                    not_installed_yet_optdeps+=("${suggested_optdeps[$((i - 1))]}")
                done
                if [[ -n ${not_installed_yet_optdeps[*]} ]]; then
                    fancy_message info $"Selecting packages ${BCyan}${not_installed_yet_optdeps[*]%%:\ *}${NC}"
                fi
            fi
        fi
    fi
}

function deblog_depends() {
    { ignore_stack=false; set -o pipefail; trap stacktrace ERR RETURN; }
    # shellcheck disable=SC2034
    local log_depends log_depends_str input_depends="${1}" todeblog="${2}"
    dep_const.format_control "${input_depends}" log_depends
    dep_const.comma_array log_depends log_depends_str
    deblog "${todeblog}" "${log_depends_str}"
}

function prompt_depends() {
    { ignore_stack=false; set -o pipefail; trap stacktrace ERR RETURN; }
    local d o deps missing_optdeps not_satisfied_optdeps missing_deps not_satisfied_deps suggested_optdeps not_installed_yet_optdeps already_installed_optdeps
    fancy_message info $"Checking apt dependencies"
    for i in "deps" "missing_deps" "not_satisfied_deps" "suggested_optdeps" "missing_optdeps" "not_satisfied_optdeps" "already_installed_optdeps"; do
        sudo rm -rf "${PACDIR}-${i//_/-}-${pacname}"
        touch "${PACDIR}-${i//_/-}-${pacname}"
    done
    for d in "${depends[@]}"; do
        check_apt_dep "${d}" &
    done
    wait
    for i in "deps" "missing_deps" "not_satisfied_deps"; do
        if [[ -f "${PACDIR}-${i//_/-}-${pacname}" ]]; then
            mapfile -t "${i}" <"${PACDIR}-${i//_/-}-${pacname}"
            rm -rf "${PACDIR}-${i//_/-}-${pacname}"
        fi
    done
    prompt_aptdepends
    if ((${#optdepends[@]} != 0)); then
        for o in "${optdepends[@]}"; do
            check_opt_dep "${o}" &
        done
        wait
        for i in "suggested_optdeps" "missing_optdeps" "not_satisfied_optdeps" "already_installed_optdeps"; do
            if [[ -f "${PACDIR}-${i//_/-}-${pacname}" ]]; then
                mapfile -t "${i}" <"${PACDIR}-${i//_/-}-${pacname}"
                rm -rf "${PACDIR}-${i//_/-}-${pacname}"
            fi
        done
        prompt_optdepends
    fi
    if [[ -n ${pacdeps[*]} ]]; then
        for i in "${pacdeps[@]}"; do
            awk -F'=' '/^_gives=/{gives=$2} /^_name=/{name=$2} END{val=(gives ? gives : name); gsub(/"/, "", val); print val}' "${METADIR}/${i}" >> "${PACDIR}-gives-${pacname}"
        done
        # shellcheck disable=SC2031
        while IFS= read -r line; do
            if ! array.contains deps "${line}"; then
                deps+=("${line}")
            fi
        done < "${PACDIR}-gives-${pacname}"
    fi
    # Do we have any deps or optdeps scheduled for installation?
    if [[ -n ${deps[*]} || -n ${not_installed_yet_optdeps[*]} || -n ${already_installed_optdeps[*]} ]]; then
        # shellcheck disable=SC2034
        local all_deps_to_install=("${not_installed_yet_optdeps[@]}" "${already_installed_optdeps[@]}" "${deps[@]}")
        deblog_depends all_deps_to_install "Depends"
    fi
    for i in "gives" "deps" "missing-deps" "not-satisfied-deps" "suggested-optdeps" "missing-optdeps" "not-satisfied-optdeps" "already-installed-optdeps"; do
        sudo rm -rf "${PACDIR}-${i}-${pacname}"
    done
}

function generate_changelog() {
    { ignore_stack=false; set -o pipefail; trap stacktrace ERR RETURN; }
    printf "%s (%s) %s; urgency=medium\n\n  * Version now at %s.\n\n -- %s %(%a, %d %b %Y %T %z)T\n" \
        "${pacname}" "${full_version}" "${CDISTRO#*:}" "${full_version}" "${maintainer[0]}"
}

function clean_logdir() {
    { ignore_stack=false; set -o pipefail; trap stacktrace ERR RETURN; }
    if [[ ! -d ${LOGDIR} ]]; then
        sudo mkdir -p "${LOGDIR}"
    fi
    sudo find -H "${LOGDIR:-/var/log/pacstall/error_log/}" -maxdepth 1 -mtime +30 -delete
}

function createdeb() {
    { ignore_stack=false; set -o pipefail; trap stacktrace ERR RETURN; }
    local debname="${1}_${2}_${3}"
    if ((PACSTALL_INSTALL == 0)); then
        # We are not going to immediately install, meaning the user might want to share their deb with someone else, so create the highest compression.
        local flags=("-19" "-T0" "-q")
        local compression="zst"
        local command="zstd"
    else
        # Immediate install (gzip), so we want fast build times over everything else
        local flags=("-1n")
        local compression="gz"
        local command="gzip"
    fi
    cd "$STAGEDIR/$pacname" || { ignore_stack=true; return 1; }
    # https://tldp.org/HOWTO/html_single/Debian-Binary-Package-Building-HOWTO/#AEN66
    echo "2.0" | sudo tee debian-binary > /dev/null
    sudo tar -cf "$PWD/control.tar" -T /dev/null
    local CONTROL_LOCATION="$PWD/control.tar"
    # avoid having to cd back
    pushd DEBIAN > /dev/null || { ignore_stack=true; return 1; }
    for i in *; do
        if [[ -f $i ]]; then
            local files_for_control+=("$i")
        fi
    done
    fancy_message sub $"Packing control.tar"
    sudo tar -rf "$CONTROL_LOCATION" "${files_for_control[@]}"
    popd > /dev/null || { ignore_stack=true; return 1; }
    sudo tar -cf "$PWD/data.tar" -T /dev/null
    local DATA_LOCATION="$PWD/data.tar"
    # collect every top level file/dir except for deb stuff
    for i in *; do
        [[ $i =~ ^(DEBIAN|control.tar|data.tar|debian-binary)$ ]] && continue
        local files_for_data+=("$i")
    done
    fancy_message sub $"Packing data.tar"
    sudo tar -rf "$DATA_LOCATION" "${files_for_data[@]}"

    fancy_message sub $"Compressing"
    sudo "$command" "${flags[@]}" "$DATA_LOCATION" "$CONTROL_LOCATION"
    sudo ar -rU "$debname.deb" debian-binary control.tar."$compression" data.tar."$compression" > /dev/null 2>&1
    sudo mv "$debname.deb" ..
    sudo rm -f debian-binary control.tar."$compression" data.tar."$compression"
}

function is_builddep_arch() {
    { ignore_stack=false; set -o pipefail; trap stacktrace ERR RETURN; }
    local buildar="${1}_${TARCH}[*]" buildar_distb="${1}_${DISTRO%:*}_${TARCH}[*]" buildar_distv="${1}_${DISTRO#*:}_${TARCH}[*]"
    local -n appendar="${2}"
    [[ -n ${!buildar} ]] && appendar+=("${!buildar}")
    [[ -n ${!buildar_distb} ]] && appendar+=("${!buildar_distb}")
    [[ -n ${!buildar_distv} ]] && appendar+=("${!buildar_distv}")
    if [[ -n ${appendar[*]} ]]; then
        return 0
    else
        { ignore_stack=true; return 1; }
    fi
}

function makedeb() {
    { ignore_stack=false; set -o pipefail; trap stacktrace ERR RETURN; }
    # It looks weird for it to say: `Packaging foo as foo`
    if [[ -n $gives && $pacname != "$gives" ]]; then
        fancy_message info $"Packaging ${BGreen}$pacname${NC} as ${BBlue}$gives${NC}"
    else
        fancy_message info $"Packaging ${BGreen}$pacname${NC}"
    fi
    deblog "Package" "${gives:-$pacname}"

    if [[ $pkgver =~ ^[0-9] ]]; then
        deblog "Version" "${full_version}"
        export version="${full_version}"
    else
        deblog "Version" "0${full_version}"
        export version="0${full_version}"
    fi

    if [[ -n ${arch[*]} ]]; then
        # If we have any or all in the arch, then the package works everywhere
        if array.contains arch "any" || array.contains arch "all"; then
            deblog "Architecture" "all"
        else # If it doesn't but arch[@] exists we should log the current arch as the build arch
            deblog "Architecture" "$(dpkg --print-architecture)"
        fi
    else # If arch[@] does not exist, we log it as all according to
        # https://github.com/pacstall/pacstall/wiki/Pacscript-101#arch
        deblog "Architecture" "all"
    fi
    deblog "Section" "Pacstall"

    if [[ ${priority} == "essential" ]]; then
        deblog "Priority" "required"
        deblog "Essential" "yes"
    else
        deblog "Priority" "${priority:-optional}"
    fi

    if [[ -n ${bugs} ]]; then
        deblog "Bugs" "${bugs}"
    elif [[ ${local} == "no" ]]; then
        repo.unraw "$REPO"
        if [[ -n ${pISSUES} ]]; then
            deblog "Bugs" "${pISSUES}"
        fi
        unset pURL pBRANCH pISSUES pTYPE pREPO pOWNER
    fi

    if [[ $pacname == *-git ]]; then
        parse_source_entry "${source[0]}"
        # shellcheck disable=SC2031
        local vcsurl="${source_url#file://}"
        vcsurl="${vcsurl#git+}"
        if [[ -n ${git_branch} ]]; then
            deblog "Vcs-Git" "${vcsurl} -b ${git_branch}"
        elif [[ -n ${git_tag} ]]; then
            deblog "Vcs-Git" "${vcsurl} -b ${git_tag}"
        else
            deblog "Vcs-Git" "${vcsurl}"
        fi
    fi

    if [[ -n ${makedepends[*]} ]]; then
        local builddependsarch
        is_function "check" && [[ -n ${checkdepends[*]} ]] && makedepends+=("${checkdepends[@]}")
        deblog_depends makedepends "Build-Depends"
        if is_builddep_arch makedepends builddependsarch; then
            if is_function "check"; then
                is_builddep_arch checkdepends builddependsarch \
                    || builddependsarch=("${builddependsarch[@]}")
            fi
            deblog_depends builddependsarch "Build-Depends-Arch"
        fi
    fi

    if [[ -n ${makeconflicts[*]} ]]; then
        local buildconflictsarch
        is_function "check" && [[ -n ${checkconflicts[*]} ]] && makeconflicts+=("${checkconflicts[@]}")
        deblog_depends makeconflicts "Build-Conflicts"
        if is_builddep_arch makeconflicts buildconflictsarch; then
            if is_function "check"; then
                is_builddep_arch checkconflicts buildconflictsarch \
                    || buildconflictsarch=("${buildconflictsarch[@]}")
            fi
            deblog_depends buildconflictsarch "Build-Conflicts-Arch"
        fi
    fi

    if ! array.contains provides "${gives:-${pacname}}"; then
        provides+=("${gives:-${pacname}}")
    fi
    deblog_depends provides "Provides"

    if [[ -n ${conflicts[*]} ]]; then
        deblog_depends conflicts "Conflicts"
    fi

    if [[ -n ${breaks[*]} ]]; then
        deblog_depends breaks "Breaks"
    fi

    if [[ -n ${enhances[*]} ]]; then
        deblog_depends enhances "Enhances"
    fi

    if [[ -n ${recommends[*]} ]]; then
        deblog_depends recommends "Recommends"
    fi

    if [[ -n ${suggests[*]} || ${optdepends[*]} ]]; then
        # shellcheck disable=SC2034
        local all_suggests=("${suggests[@]}" "${optdepends[@]}")
        deblog_depends all_suggests "Suggests"
    fi

    if [[ -n ${replaces[*]} ]]; then
        deblog_depends replaces "Replaces"
    fi

    if [[ -n ${url} ]]; then
        deblog "Homepage" "${url}"
    fi

    if [[ -n ${license[*]} ]]; then
        # shellcheck disable=SC2001
        deblog "License" "$(sed 's/ /, /g' <<< "${license[@]/custom\:/}")"
    fi

    if [[ -n ${custom_fields[*]} ]]; then
        local field logvar logstr
        for field in "${custom_fields[@]}"; do
            logvar="${field%:*}"
            logstr="${field#*: }"
            deblog "${logvar}" "${logstr}"
        done
    fi

    if [[ -n ${maintainer[*]} ]]; then
        deblog "Maintainer" "${maintainer[0]}"
        if ((${#maintainer[@]} > 1)); then
            # Since https://www.debian.org/doc/debian-policy/ch-controlfields.html#uploaders says that Maintainer can only have one field, shove the rest in Uploaders
            local uploaders
            printf -v uploaders '%s, ' "${maintainer[@]:1}"
            printf -v uploaders '%s' "${uploaders%, }"
            deblog "Uploaders" "${uploaders}"
            unset uploaders
        fi
    else
        deblog "Maintainer" "Pacstall <pacstall@pm.me>"
    fi

    # Do we have a long description? (longer than 2 lines)
    while IFS=$'\n' read -r line; do
        if [[ -z ${line} ]]; then
            # Description states that empty lines must contain a single period after the period.
            local description_arr+=(".")
        else
            local description_arr+=("$line")
        fi
    done <<< "${pkgdesc}"
    if ((${#description_arr[@]} > 1)); then
        deblog "Description" "$(
            echo "${description_arr[0]}"
            for ((i = 1; i < "${#description_arr[@]}"; i++)); do
                echo -e " ${description_arr[i]}"
            done
        )"
    else
        deblog "Description" "${pkgdesc}"
    fi
    local pre_inst_upg post_inst_upg
    if is_package_installed "${pacname}"; then
        if type -t pre_upgrade &> /dev/null; then
            pre_inst_upg="pre_upgrade"
        else
            pre_inst_upg="pre_install"
        fi
        if type -t post_upgrade &> /dev/null; then
            post_inst_upg="post_upgrade"
        else
            post_inst_upg="post_install"
        fi
    else
        pre_inst_upg="pre_install"
        post_inst_upg="post_install"
    fi

    for i in {"${pre_inst_upg}",pre_remove,"${post_inst_upg}",post_remove}; do
        case "$i" in
            "${pre_inst_upg}") export deb_post_file="preinst" ;;
            pre_remove) export deb_post_file="prerm" ;;
            "${post_inst_upg}") export deb_post_file="postinst" ;;
            post_remove) export deb_post_file="postrm" ;;
        esac
        if is_function "$i"; then
            local pac_min_functions pacmf_out
            # shellcheck disable=SC2016
            pac_min_functions=(
                'set -e' 'function ask(){' 'local default reply' 'if [[ ${2-} == "Y" ]];then'
                'echo -ne "$1 [Y/n] "' 'default="Y"' 'elif [[ ${2-} == "N" ]];then' 'echo -ne "$1 [y/N] "'
                'fi' 'default=${2-}' 'read -r reply <&0' '[[ -z $reply ]] && reply=$default' 'case "$reply" in'
                'Y*|y*)export answer=1' 'return 0' ';;' 'N*|n*)export answer=0' 'return 1' 'esac' '}'
                'function fancy_message(){' 'local MESSAGE_TYPE="$1"' 'local MESSAGE="$2"' 'local BOLD="\033[1m"'
                'local NC="\033[0m"' 'case $MESSAGE_TYPE in' 'info)echo -e "[$BOLD+$NC] INFO: $MESSAGE";;'
                'warn)echo -e "[$BOLD*$NC] WARNING: $MESSAGE";;' 'error)echo -e "[$BOLD!$NC] ERROR: $MESSAGE";;'
                'sub)echo -e "  [$BOLD>$NC] $MESSAGE";;' '*)echo -e "[$BOLD?$NC] UNKNOWN: $MESSAGE"' 'esac' '}'
                'function get_homedir(){' 'local PACSTALL_USER=$(logname 2>/dev/null||echo "${SUDO_USER:-$USER}")'
                'eval echo ~"$PACSTALL_USER"' '}' 'export homedir="$(get_homedir)"' 'if [[ -n $PACSTALL_BUILD_CORES ]];then'
                'declare -g NCPU="${PACSTALL_BUILD_CORES:-1}"' 'else' 'declare -g NCPU="$(nproc)"' 'fi'
            )
            echo '#!/bin/bash' | sudo tee "$STAGEDIR/$pacname/DEBIAN/$deb_post_file" > /dev/null
            for pacmf_out in "${pac_min_functions[@]}"; do
                echo "${pacmf_out}" | sudo tee -a "$STAGEDIR/$pacname/DEBIAN/$deb_post_file" > /dev/null
            done
            {
                cat "${pacfile}"
                echo -e "\n$i"
            } | sudo tee -a "$STAGEDIR/$pacname/DEBIAN/$deb_post_file" > /dev/null
        fi
    done
    unset pre_inst_upg post_inst_upg
    echo -e "sudo rm -f ${METADIR:?}/$pacname\nsudo rm -f /etc/apt/preferences.d/${pacname//./-}-pin" | sudo tee -a "$STAGEDIR/$pacname/DEBIAN/postrm" > /dev/null
    local postfile
    for postfile in {postrm,postinst,preinst,prerm}; do
        if [[ -f "$STAGEDIR/$pacname/DEBIAN/${postfile}" ]]; then
            sudo chmod -x "$STAGEDIR/$pacname/DEBIAN/${postfile}" &> /dev/null
            sudo chmod 755 "$STAGEDIR/$pacname/DEBIAN/${postfile}" &> /dev/null
        fi
    done

    # Handle `backup` key
    if [[ -n ${backup[*]} ]]; then
        local file
        for file in "${backup[@]}"; do
            if [[ -z ${file} ]]; then
                fancy_message warn $"Empty key... Skipping" && continue
            fi
            # `r:usr/share/pac.conf`
            if [[ ${file:0:2} == "r:" ]]; then
                # `r:`
                if [[ -z ${file:2} ]]; then
                    fancy_message warn $"'${file}' cannot contain empty path... Skipping" && continue
                fi
                # `r:/usr/share/pac.conf`
                if [[ ${file:2:1} == "/" ]]; then
                    fancy_message warn $"'${file}' cannot contain path starting with '/'... Skipping" && continue
                fi
                if [[ -f "$STAGEDIR/$pacname/${file:2}" ]]; then
                    fancy_message warn $"'${file}' is inside the package... Skipping" && continue
                fi
                echo "remove-on-upgrade /${file:2}" | sudo tee -a "$STAGEDIR/$pacname/DEBIAN/conffiles" > /dev/null
            else
                if [[ ${file:0:1} == "/" ]]; then
                    fancy_message warn $"'${file}' cannot contain path starting with '/'... Skipping" && continue
                fi
                echo "/${file}" | sudo tee -a "$STAGEDIR/$pacname/DEBIAN/conffiles" > /dev/null
            fi
        done
    fi

    local estsize
    estsize="$(sudo du -s --apparent-size --exclude=DEBIAN -- "$STAGEDIR/$pacname" | cut -d$'\t' -f1)"
    deblog "Installed-Size" "${estsize}"
    if ((estsize < 10)); then
        install_size="$((estsize * 1024)) B"
    else
        local duargs="b" numargs rawsize
        ((estsize < 1024)) && {
            duargs+="h"
            numargs="--from=iec --to=si"
        } || numargs="--to=si"
        rawsize="$(sudo du -s${duargs} --exclude=DEBIAN -- "$STAGEDIR/$pacname" | cut -d$'\t' -f1)"
        # shellcheck disable=SC2086
        install_size="$(
            numfmt ${numargs} --format="%3.2f" "${rawsize}" \
                | awk '{
                if (match($0, /[A-Za-z]+$/)) {
                    num = sprintf("%.3g", $1);
                    if (num == int(num)) {
                        if (int(num) < 10) {
                            num = sprintf("%.2f", num);
                        } else if (int(num) < 100) {
                            num = sprintf("%.1f", num);
                        } else {
                            num = sprintf("%.0f", num);
                        }
                    }
                    unit = substr($0, RSTART, RLENGTH);
                    if (unit == "K") unit = "k";
                    printf "%s %sB\n", num, unit;
                } else {
                    num = sprintf("%3.2f", $1);
                    printf "%s B\n", num;
                }
            }'
        )"
    fi
    export install_size

    generate_changelog | sudo tee -a "$STAGEDIR/$pacname/DEBIAN/changelog" > /dev/null

    cd "$STAGEDIR" || { ignore_stack=true; return 1; }
    if array.contains arch "${CARCH}" || array.contains arch "${AARCH}"; then
        local deb_arch="${CARCH}"
    else
        local deb_arch="all"
    fi
    createdeb "${pacname}" "${full_version}" "${deb_arch}"
    install_deb "${pacname}" "${full_version}" "${deb_arch}"
}

function install_deb() {
    { ignore_stack=false; set -o pipefail; trap stacktrace ERR RETURN; }
    local debname="${1}_${2}_${3}"
    if ((PACSTALL_INSTALL != 0)); then
        for pkg in "${replaces[@]}"; do
            if is_apt_package_installed "${pkg}"; then
                if [[ ${priority} == "essential" ]]; then
                    sudo apt-get remove -y "${pkg}" --allow-remove-essential
                else
                    sudo apt-get remove -y "${pkg}"
                fi
            fi
        done
        # --allow-downgrades is to allow git packages to "downgrade", because the commits aren't necessarily a higher number than the last version
        if ! sudo -E apt-get install --reinstall "$STAGEDIR/$debname.deb" -y --allow-downgrades 2> /dev/null; then
            echo -ne "\t"
            fancy_message error $"Failed to install $pacname deb"
            error_log 8 "install $pacname"
            sudo dpkg -r --force-all "${gives:-$pacname}" 2> /dev/null
            fancy_message info $"Cleaning up"
            cleanup
            exit 1
        fi
        if [[ -f "${PACDIR}-pacdeps-$pacname" ]]; then
            sudo apt-mark auto "${gives:-$pacname}" 2> /dev/null
        fi
        sudo rm -rf "${STAGEDIR:?}/${pacname}"
        sudo rm -rf "${PACDIR:?}/${debname}.deb"

        if ! [[ -d /etc/apt/preferences.d/ ]]; then
            sudo mkdir -p /etc/apt/preferences.d
        fi
        local combined_pinning=("${provides[@]}" "${gives:-${pacname}}")
        echo "Package: ${combined_pinning[*]}" | sudo tee "/etc/apt/preferences.d/${pacname//./-}-pin" > /dev/null
        echo "Pin: version *" | sudo tee -a "/etc/apt/preferences.d/${pacname//./-}-pin" > /dev/null
        echo "Pin-Priority: -1" | sudo tee -a "/etc/apt/preferences.d/${pacname//./-}-pin" > /dev/null
        return 0
    else
        sudo mv "$STAGEDIR/$debname.deb" "$PACDEB_DIR"
        sudo chown "$PACSTALL_USER":"$PACSTALL_USER" "$PACDEB_DIR/$debname.deb"
        fancy_message info $"Package built at ${BGreen}$PACDEB_DIR/$debname.deb${NC}"
        if [[ $KEEP ]]; then
            fancy_message info $"Moving ${BGreen}$STAGEDIR/$pacname${NC} to ${BGreen}${PACDIR}-no-build/$pacname${NC}"
            sudo rm -rf "${PACDIR}-no-build/${pacname:?}"
            mkdir -p "${PACDIR}-no-build/$pacname"
            sudo mv "$STAGEDIR/$pacname" "${PACDIR}-no-build/$pacname"
        fi
        return 0
    fi
}

function repacstall() {
    { ignore_stack=false; set -o pipefail; trap stacktrace ERR RETURN; }
    # shellcheck disable=SC2034
    local depends_array unpackdir depends_line deper pacgives meper ceper pacdep depends_array_form repac_depends_str upcontrol input_dest="${1}"
    unpackdir="${STAGEDIR}/${pacname}"
    upcontrol="${unpackdir}/DEBIAN/control"
    sudo mkdir -p "${unpackdir}"
    sudo rm -rf "${unpackdir:?}"/*
    fancy_message sub $"Repacking ${CYAN}${pacname/\-deb/}.deb${NC}"
    sudo dpkg-deb -R "${input_dest}" "${unpackdir}"
    depends_line=$(awk '/^Depends:/ {print; exit}' "${upcontrol}")
    if [[ -n ${depends_line} ]]; then
        readarray -t depends_array <<< "$(echo "${depends_line#Depends: }" | tr ',' '\n')"
        depends_array=("${depends_array[@]/# /}")
        depends_array=("${depends_array[@]/% /}")
    fi
    if [[ -n ${makedepends[*]} ]]; then
        # shellcheck disable=SC2076
        for meper in "${makedepends[@]}"; do
            if ! array.contains depends_array "${meper}"; then
                depends_array+=("${meper}")
            fi
        done
    fi
    if [[ -n ${checkdepends[*]} ]] && is_function "check"; then
        # shellcheck disable=SC2076
        for ceper in "${checkdepends[@]}"; do
            if ! array.contains depends_array "${ceper}"; then
                depends_array+=("${ceper}")
            fi
        done
    fi
    if [[ -n ${depends[*]} ]]; then
        # shellcheck disable=SC2076
        for deper in "${depends[@]}"; do
            if ! array.contains depends_array "${deper}"; then
                depends_array+=("${deper}")
            fi
        done
    fi
    if [[ -n ${pacdeps[*]} ]]; then
        for pacdep in "${pacdeps[@]}"; do
            pacgives=$(awk '/_gives/ {print; exit}' "${METADIR}/${pacdep}")
            if [[ -z ${pacgives} ]]; then
                pacgives=$(awk '/_name/ {print; exit}' "${METADIR}/${pacdep}")
            fi
            eval "pacgives=${pacgives#*=}"
            if ! array.contains depends_array "${pacgives}"; then
                local pacdeps_array repac_depends
                # shellcheck disable=SC2034
                pacdeps_array=("${pacgives}")
                dep_const.format_control pacdeps_array repac_depends
                depends_array+=("${repac_depends[@]}")
            fi
        done
    fi
    dep_const.format_control depends_array depends_array_form
    dep_const.comma_array depends_array_form repac_depends_str
    sudo sed -i '/^Depends:/d' "${upcontrol}"
    sudo sed -i "/Installed-Size:/a Depends: ${repac_depends_str}" "${upcontrol}"
    sudo sed -i "/Description:/i Modified-By-Pacstall: yes" "${upcontrol}"
    if array.contains arch "${CARCH}" || array.contains arch "${AARCH}"; then
        local deb_arch="${CARCH}"
    else
        local deb_arch="all"
    fi
    createdeb "${pacname}" "${full_version}" "${deb_arch}"
    install_deb "${pacname}" "${full_version}" "${deb_arch}"
}

function check_if_pacdep() {
    { ignore_stack=false; set -o pipefail; trap stacktrace ERR RETURN; }
    local package="${1}" finddir="${2}" found
    found="$(find "${finddir}" -type f -exec awk -v pkg="${package}" '
        $0 ~ "_pacdeps=\\(\\[" "[0-9]+" "\\]=\"" pkg "\"" {
                found = 1
        } END {
                if (!found) {exit 1}
        }' {} \; -print)"
    if [[ ${found} ]]; then
        return 0
    else
        # shellcheck disable=SC2034
        { ignore_stack=true; return 1; }
    fi
}

function write_meta() {
    { ignore_stack=false; set -o pipefail; trap stacktrace ERR RETURN; }
    echo "_name=\"$pacname\""
    if [[ -n $pkgbase ]]; then
        echo "_pkgbase=\"$pkgbase\""
    fi
    echo "_version=\"${full_version}\""
    [[ -z ${install_size} ]] && install_size="$(aptitude search ~i --display-format '%p %I' --sort installsize | awk -v pkg="${gives:-${pacname}}" '$0 ~ "^" pkg " " {print $2 " " $3}')"
    echo "_install_size=\"${install_size}\""
    printf '_date=\"%(%a %b %_d %r %Z %Y)T\"\n'
    if [[ -n ${maintainer[*]} ]]; then
        _maintainer=("${maintainer[@]}")
        declare -p _maintainer
        unset _maintainer
    fi
    if [[ -n $ppa ]]; then
        echo "_ppa=(${ppa[*]})"
    fi
    if [[ -n $url ]]; then
        echo "_homepage=\"${url}\""
    fi
    if [[ -n $gives ]]; then
        echo "_gives=\"$gives\""
    fi
    if [[ -f "${PACDIR}-pacdeps-$pacname" ]] || check_if_pacdep "${pacname}" "${METADIR}"; then
        echo '_pacstall_depends="true"'
    fi
    if [[ $local == 'no' ]]; then
        echo "_remoterepo=\"$pURL\""
        if [[ -n ${pBRANCH} ]]; then
            echo "_remotebranch=\"$pBRANCH\""
        fi
    fi
    if [[ -n ${pacdeps[*]} ]]; then
        _pacdeps=("${pacdeps[@]}")
        declare -p _pacdeps
        unset _pacdeps
    fi
    if [[ -n ${mask[*]} ]]; then
        _mask=("${mask[@]}")
        declare -p _mask
        unset _mask
    fi
}

function meta_log() {
    # shellcheck disable=SC2034
    { ignore_stack=false; set -o pipefail; trap stacktrace ERR RETURN; }
    # Origin repo info parsing
    if [[ ${local} == "no" ]]; then
        repo.unraw "$REPO"
    fi

    # Metadata writing
    write_meta | sudo tee "$METADIR/$pacname" > /dev/null
    unset pURL pBRANCH pISSUES pTYPE pREPO pOWNER
}

# vim:set ft=sh ts=4 sw=4 et:
