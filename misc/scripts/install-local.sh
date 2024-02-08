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

# shellcheck source=./misc/scripts/checks.sh
source "${STGDIR}/scripts/checks.sh" || {
    fancy_message error "Could not find checks.sh"
    return 1
}

function cleanup() {
    if [[ -n $KEEP ]]; then
        rm -rf "/tmp/pacstall-keep/$name"
        mkdir -p "/tmp/pacstall-keep/$name"
        if [[ -f /tmp/pacstall-pacdeps-"$PACKAGE" ]]; then
            sudo mv /tmp/pacstall-pacdep/* "/tmp/pacstall-keep/$name"
        else
            sudo mv "${SRCDIR:?}"/* "/tmp/pacstall-keep/$name"
        fi
    fi
    if [[ -f "/tmp/pacstall-pacdeps-$PACKAGE" ]]; then
        sudo rm -rf "/tmp/pacstall-pacdeps-$PACKAGE"
        sudo rm -rf /tmp/pacstall-pacdep
    else
        sudo rm -rf "${SRCDIR:?}"/*
        # just in case we quit before $name is declared, we should be able to remove a fake directory so it doesn't exit out the script
        sudo rm -rf "${STOWDIR:-/usr/src/pacstall}/${name:-raaaaaaaandom}"
        rm -rf /tmp/pacstall-gives
    fi
    sudo rm -rf "${STOWDIR}/${name:-$PACKAGE}.deb"
    rm -f /tmp/pacstall-select-options
    unset name repology pkgver git_pkgver epoch url source depends makedepends breaks replace gives pkgdesc hash optdepends ppa arch maintainer pacdeps patch PACPATCH NOBUILDDEP provides incompatible optinstall pkgbase homepage backup pkgrel mask pac_functions repo priority noextract 2> /dev/null
    unset -f post_install post_remove pre_install prepare build package 2> /dev/null
    sudo rm -f "${pacfile}"
}

function trap_ctrlc() {
    fancy_message warn "\nInterrupted, cleaning up"
    if is_apt_package_installed "${name}"; then
        sudo apt-get purge "${gives:-$name}" -y > /dev/null
    fi
    sudo rm -f "/etc/apt/preferences.d/${name:-$PACKAGE}-pin"
    cleanup
    exit 1
}

function write_meta() {
    echo "_name=\"$name\""
    echo "_version=\"${full_version}\""
    echo "_install_size=\"${install_size}\""
    printf '_date=\"%(%a %b %_d %r %Z %Y)T\"\n'
    if [[ -n $maintainer ]]; then
        echo "_maintainer=\"${maintainer}\""
    fi
    if [[ -n $ppa ]]; then
        echo "_ppa=(${ppa[*]})"
    fi
    if [[ -n $homepage ]]; then
        echo "_homepage=\"${homepage}\""
    fi
    if [[ -n $gives ]]; then
        echo "_gives=\"$gives\""
    fi
    if [[ -f /tmp/pacstall-pacdeps-"$name" ]]; then
        echo '_pacstall_depends="true"'
    fi
    if [[ $local == 'no' ]]; then
        echo "_remoterepo=\"$pURL\""
        if [[ $branch == 'yes' ]]; then
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
    # Origin repo info parsing
    if [[ ${local} == "no" ]]; then
        # shellcheck disable=SC2153
        case $REPO in
            *"github"*)
                pURL="${REPO/'raw.githubusercontent.com'/'github.com'}"
                pURL="${pURL%/*}"
                pBRANCH="${REPO##*/}"
                branch="yes"
                ;;
            *"gitlab"*)
                pURL="${REPO%/-/raw/*}"
                pBRANCH="${REPO##*/-/raw/}"
                branch="yes"
                ;;
            *)
                pURL="$REPO"
                branch="no"
                ;;
        esac
    fi

    # Metadata writing
    write_meta | sudo tee "$METADIR/$name" > /dev/null
}

function parse_source_entry() {
    unset url dest git_branch git_tag git_commit
    local entry="$1"
    url="${entry#*::}"
    dest="${entry%%::*}"
    if [[ $entry != *::* && $entry == *#*=* ]]; then
        dest="${url%%#*}"
        dest="${dest##*/}"
    fi
    case $url in
        *#branch=*)
            git_branch="${url##*#branch=}"
            url="${url%%#branch=*}"
            ;;
        *#tag=*)
            git_tag="${url##*#tag=}"
            url="${url%%#tag=*}"
            ;;
        *#commit=*)
            git_commit="${url##*#commit=}"
            url="${url%%#commit=*}"
            ;;
    esac
    url="${url%%#*}"
    if [[ $entry == *::* ]]; then
        dest="${entry%%::*}"
    elif [[ $entry != *#*=* ]]; then
        url="$entry"
        dest="${url##*/}"
    fi
    if [[ ${dest} == *"?"* ]]; then
        dest="${dest%%\?*}"
    fi
}

function calc_git_pkgver() {
    unset comp_git_pkgver
    local calc_commit
    if [[ $url == git+* ]]; then
        url="${url#git+}"
    fi
    if [[ -n ${git_branch} ]]; then
        calc_commit="$(git ls-remote "${url}" "${git_branch}")"
    elif [[ -n ${git_tag} ]]; then
        calc_commit="$(git ls-remote "${url}" "${git_tag}")"
    elif [[ -n ${git_commit} ]]; then
        calc_commit="${git_commit}"
    else
        calc_commit="$(git ls-remote "${url}" HEAD)"
    fi
    comp_git_pkgver="${calc_commit:0:8}"
}

function compare_remote_version() {
    local input="${1}"
    unset -f pkgver 2> /dev/null
    source "$METADIR/$input" || return 1
    if [[ -z ${_remoterepo} ]]; then
        return 0
    elif [[ ${_remoterepo} == *"github.com"* ]]; then
        local remoterepo="${_remoterepo/'github.com'/'raw.githubusercontent.com'}/${_remotebranch}"
    elif [[ ${_remoterepo} == *"gitlab.com"* ]]; then
        local remoterepo="${_remoterepo}/-/raw/${_remotebranch}"
    else
        local remoterepo="${_remoterepo}"
    fi
    local remotever="$(
        source <(curl -s -- "$remoterepo/packages/$input/$input.pacscript") && if [[ ${name} == *-git ]]; then
            parse_source_entry "${source[0]}"
            calc_git_pkgver
            echo "${epoch+$epoch:}${pkgver}-pacstall${pkgrel:-1}~git${comp_git_pkgver}"
        elif [[ ${name} == *-deb ]]; then
            echo "${epoch+$epoch:}${pkgver}"
        else
            echo "${epoch+$epoch:}${pkgver}-pacstall${pkgrel:-1}"
        fi
    )" > /dev/null
    if [[ $input == *"-git" ]]; then
        if [[ $(pacstall -Qi "$input" version) != "$remotever" ]]; then
            echo "update"
        else
            echo "no"
        fi
    elif dpkg --compare-versions "$(pacstall -Qi "$input" version)" lt "$remotever" > /dev/null 2>&1; then
        echo "update"
    else
        echo "no"
    fi
}

function set_distro() {
    local distro_name="$(lsb_release -si 2> /dev/null)"
    distro_name="${distro_name,,}"
    if [[ "$(lsb_release -ds 2> /dev/null | tail -c 4)" == "sid" ]]; then
        local distro_version_name="sid"
        local distro_version_number="sid"
    else
        local distro_version_name="$(lsb_release -sc 2> /dev/null)"
    fi
    echo "${distro_name}:${distro_version_name}"
}

function get_compatible_releases() {
    # example for this function is "ubuntu:jammy"
    local distro_name="$(lsb_release -si 2> /dev/null)"
    distro_name="${distro_name,,}"
    if [[ "$(lsb_release -ds 2> /dev/null | tail -c 4)" == "sid" ]]; then
        local distro_version_name="sid"
        local distro_version_number="sid"
    else
        local distro_version_name="$(lsb_release -sc 2> /dev/null)"
        local distro_version_number="$(lsb_release -sr 2> /dev/null)"
    fi
    # lowercase
    local input=("${@,,}")
    local is_compat=false
    for key in "${input[@]}"; do
        # check for `*:jammy`
        if [[ $key == "*:"* ]]; then
            # check for `22.04` or `jammy`
            if [[ ${key#*:} == "${distro_version_number}" || ${key#*:} == "${distro_version_name}" ]]; then
                is_compat=true
                return 0
            fi
        # check for `ubuntu:*`
        elif [[ $key == *":*" ]]; then
            # check for `ubuntu`
            if [[ ${key%%:*} == "${distro_name}" ]]; then
                is_compat=true
                return 0
            fi
        elif [[ $key == "${distro_name}:${distro_version_name}" || $key == "${distro_name}:${distro_version_number}" ]]; then
            # check for `ubuntu:jammy` or `ubuntu:22.04`
            is_compat=true
            return 0
        fi
    done
    if [[ ${is_compat} == "false" || ${is_compat} != "true" ]]; then
        fancy_message error "This Pacscript does not work on ${BBlue}${distro_name}:${distro_version_name}${NC}/${BBlue}${distro_name}:${distro_version_number}${NC}"
        return 1
    fi
}

function get_incompatible_releases() {
    # example for this function is "ubuntu:jammy"
    local distro_name="$(lsb_release -si 2> /dev/null)"
    distro_name="${distro_name,,}"
    if [[ "$(lsb_release -ds 2> /dev/null | tail -c 4)" == "sid" ]]; then
        local distro_version_name="sid"
        local distro_version_number="sid"
    else
        local distro_version_name="$(lsb_release -sc 2> /dev/null)"
        local distro_version_number="$(lsb_release -sr 2> /dev/null)"
    fi
    # lowercase
    local input=("${@,,}")
    for key in "${input[@]}"; do
        # check for `*:jammy`
        if [[ $key == "*:"* ]]; then
            # check for `22.04` or `jammy`
            if [[ ${key#*:} == "${distro_version_number}" || ${key#*:} == "${distro_version_name}" ]]; then
                fancy_message error "This Pacscript does not work on ${BBlue}${distro_version_name}${NC}/${BBlue}${distro_version_number}${NC}"
                return 1
            fi
        # check for `ubuntu:*`
        elif [[ $key == *":*" ]]; then
            # check for `ubuntu`
            if [[ ${key%%:*} == "${distro_name}" ]]; then
                fancy_message error "This Pacscript does not work on ${BBlue}${distro_name}${NC}"
                return 1
            fi
        else
            # check for `ubuntu:jammy` or `ubuntu:22.04`
            if [[ $key == "${distro_name}:${distro_version_name}" || $key == "${distro_name}:${distro_version_number}" ]]; then
                fancy_message error "This Pacscript does not work on ${BBlue}${distro_name}:${distro_version_name}${NC}/${BBlue}${distro_name}:${distro_version_number}${NC}"
                return 1
            fi
        fi
    done
}

function is_compatible_arch() {
    local input=("${@}") ret=1 pacarch farch
    if [[ " ${input[*]} " =~ " any " ]]; then
        ret=0
    elif [[ " ${input[*]} " =~ " ${CARCH} " ]]; then
        ret=0
    elif [[ -n ${FARCH[*]} ]]; then
        for pacarch in "${input[@]}"; do
            for farch in "${FARCH[@]}"; do
                if [[ ${pacarch} == "${farch}" ]]; then
                    fancy_message warn "This package is for ${BBlue}${farch}${NC}, which is a foreign architecture"
                    ret=0
                    break
                fi
            done
            if ((ret == 0)); then
                break
            fi
        done
    fi
    if ((ret == 1)); then
        fancy_message error "This Pacscript does not work on ${BBlue}${CARCH}${NC}"
    fi
    return "${ret}"
}

function deblog() {
    local key="$1"
    shift
    local content=("$@")
    echo "$key: ${content[*]}" | sudo tee -a "$STOWDIR/$name/DEBIAN/control" > /dev/null
}

function clean_builddir() {
    sudo rm -rf "${STOWDIR}/${name:?}"
    sudo rm -f "${STOWDIR}/${name}.deb"
}

function prompt_optdepends() {
    local deps optdep
    deps=("${depends[@]}")
    if ((${#optdepends[@]} != 0)); then
        local suggested_optdeps=()
        for optdep in "${optdepends[@]}"; do
            # Strip the description, `opt` is now the canonical optdep name
            local opt="${optdep%%: *}"
            # Check if package exists in the repos, and if not, go to the next program
            if [[ -z "$(apt-cache search --no-generate --names-only "^$opt\$" 2> /dev/null || apt-cache search --names-only "^$opt\$")" ]]; then
                local missing_optdeps+=("${opt}")
                continue
            fi
            # Add to the dependency list if already installed so it doesn't get autoremoved on upgrade
            # If the package is not installed already, add it to the list. It's much easier for a user to choose from a list of uninstalled packages than every single one regardless of it's status
            if ! is_apt_package_installed "${opt}"; then
                suggested_optdeps+=("${optdep}")
            else
                already_installed_optdeps+=("${opt}")
            fi
        done

        if [[ -n ${missing_optdeps[*]} ]] || ((${#suggested_optdeps[@]} != 0)); then
            fancy_message sub "Optional dependencies"
        fi
        if [[ -n ${missing_optdeps[*]} ]]; then
            echo -ne "\t"
            fancy_message warn "${BLUE}${missing_optdeps[*]}${NC} does not exist in apt repositories"
        fi
        if ((${#suggested_optdeps[@]} != 0)); then
            if ((PACSTALL_INSTALL != 0)); then
                # We do this so that arrays 'start at' 1 to the user
                z=1
                echo -e "\t\t[${BIRed}0${NC}] Select none"
                for i in "${suggested_optdeps[@]}"; do
                    # print optdepends with bold package name
                    echo -e "\t\t[${BICyan}$z${NC}] ${BOLD}${i%%:*}${NC}:${i#*:}"
                    ((z++))
                done
                unset z
                # tab over the next line
                echo -ne "\t"
                select_options "Select optional dependencies to install" "${#suggested_optdeps[@]}"
                read -ra choices < /tmp/pacstall-select-options
                local choice_inc=0
                for i in "${choices[@]}"; do
                    # have we gone over the maximum number in choices[@]?
                    if [[ $i != "n" && $i != "y" ]] && ((i > ${#suggested_optdeps[@]})); then
                        local skip_opt+=("$i")
                        unset 'choices[$choice_inc]'
                    fi
                    ((choice_inc++))
                done
                if [[ -n ${skip_opt[*]} ]]; then
                    fancy_message warn "${BGreen}${skip_opt[*]}${NC} has exceeded the maximum number of optional dependencies. Skipping"
                fi

                # Did we get actual answers?
                if [[ ${choices[0]} != "n" && ${choices[0]} != "0" ]]; then
                    for i in "${choices[@]}"; do
                        # Set our user array that started at 1 down to 0 based
                        ((i--))
                        local s="${suggested_optdeps[$i]}"
                        local not_installed_yet_optdeps+=("${s%%: *}")
                        unset s
                    done
                    if [[ -n ${not_installed_yet_optdeps[*]} ]]; then
                        fancy_message info "Selecting packages ${BCyan}${not_installed_yet_optdeps[*]}${NC}"
                        # final_merged_deps is a dep list of *every* type of dep we want to be logged into Suggests. This includes
                        # already installed optdeps, not yet installed ones (selected by user) and the rest
                        local final_merged_deps=("${not_installed_yet_optdeps[@]}" "${already_installed_optdeps[@]}" "${suggested_optdeps[@]}")
                        deblog "Suggests" "$(sed 's/ /, /g' <<< "${final_merged_deps[@]//: */}")"
                        fancy_message info "Installing selected optional dependencies"
                        sudo -E apt-get install "${not_installed_yet_optdeps[@]}" -y 2> /dev/null
                    fi
                else # Did we get 0 or n?
                    # Add everything to Suggests
                    local final_merged_deps=("${not_installed_yet_optdeps[@]}" "${already_installed_optdeps[@]}" "${suggested_optdeps[@]}")
                    deblog "Suggests" "$(sed 's/ /, /g' <<< "${final_merged_deps[@]//: */}")"
                fi
            else # If `-B` is being used
                # We can log everything from optdepends to Suggests
                for pkg in "${optdepends[@]}"; do
                    local B_suggests+=("${pkg%%: *}")
                done
                deblog "Suggests" "$(sed 's/ /, /g' <<< "${B_suggests[@]//: */}")"
                unset pkg
            fi
        fi
    fi

    if [[ -n ${pacdeps[*]} ]]; then
        for i in "${pacdeps[@]}"; do
            (
                source "$METADIR/$i"
                if [[ -n $_gives ]]; then
                    echo "$_gives" | tee -a /tmp/pacstall-gives > /dev/null
                else
                    echo "$_name" | tee -a /tmp/pacstall-gives > /dev/null
                fi
            )
        done
        # Merge Depends and Pacdeps
        while IFS= read -r line; do
            deps+=("$line")
        done < /tmp/pacstall-gives
    fi
    # Do we have any deps or optdeps scheduled for installation?
    if [[ -n ${deps[*]} || -n ${not_installed_yet_optdeps[*]} ]]; then
        local all_deps_to_install=("${not_installed_yet_optdeps[@]}" "${deps[@]}")
        deblog "Depends" "$(sed 's/ /, /g' <<< "${all_deps_to_install[@]}")"
    fi
}

function generate_changelog() {
    printf "%s (%s) %s; urgency=medium\n\n  * Version now at %s.\n\n -- %s %(%a, %d %b %Y %T %z)T\n" \
        "${name}" "${full_version}" "$(lsb_release -sc)" "${full_version}" "${maintainer}"
}

function clean_logdir() {
    if [[ ! -d ${LOGDIR} ]]; then
        sudo mkdir -p "${LOGDIR}"
    fi
    sudo find -H "${LOGDIR:-/var/log/pacstall/error_log/}" -maxdepth 1 -mtime +30 -delete
}

function createdeb() {
    local name="$1"
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
    cd "$STOWDIR/$name" || return 1
    # https://tldp.org/HOWTO/html_single/Debian-Binary-Package-Building-HOWTO/#AEN66
    echo "2.0" | sudo tee debian-binary > /dev/null
    sudo tar -cf "$PWD/control.tar" -T /dev/null
    local CONTROL_LOCATION="$PWD/control.tar"
    # avoid having to cd back
    pushd DEBIAN > /dev/null || return 1
    for i in *; do
        if [[ -f $i ]]; then
            local files_for_control+=("$i")
        fi
    done
    fancy_message sub "Packing control.tar"
    sudo tar -rf "$CONTROL_LOCATION" "${files_for_control[@]}"
    popd > /dev/null || return 1
    sudo tar -cf "$PWD/data.tar" -T /dev/null
    local DATA_LOCATION="$PWD/data.tar"
    # collect every top level file/dir except for deb stuff
    for i in *; do
        [[ $i =~ ^(DEBIAN|control.tar|data.tar|debian-binary)$ ]] && continue
        local files_for_data+=("$i")
    done
    fancy_message sub "Packing data.tar"
    sudo tar -rf "$DATA_LOCATION" "${files_for_data[@]}"

    fancy_message sub "Compressing"
    sudo "$command" "${flags[@]}" "$DATA_LOCATION" "$CONTROL_LOCATION"
    sudo ar -rU "$name.deb" debian-binary control.tar."$compression" data.tar."$compression" > /dev/null 2>&1
    sudo mv "$name.deb" ..
    sudo rm -f debian-binary control.tar."$compression" data.tar."$compression"
}

function makedeb() {
    # It looks weird for it to say: `Packaging foo as foo`
    if [[ -n $gives && $name != "$gives" ]]; then
        fancy_message info "Packaging ${BGreen}$name${NC} as ${BBlue}$gives${NC}"
    else
        fancy_message info "Packaging ${BGreen}$name${NC}"
    fi
    deblog "Package" "${gives:-$name}"

    if [[ $pkgver =~ ^[0-9] ]]; then
        deblog "Version" "${full_version}"
        export version="${full_version}"
    else
        deblog "Version" "0${full_version}"
        export version="0${full_version}"
    fi

    if [[ -n ${arch[*]} ]]; then
        # If we have any or all in the arch, then the package works everywhere
        if array.contains arch "any"; then
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

    if [[ $name == *-git ]]; then
        parse_source_entry "${source[0]}"
        # shellcheck disable=SC2031
        local vcsurl="${url#file://}"
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
        deblog "Build-Depends" "$(sed 's/ /, /g' <<< "${makedepends[@]}")"
    fi

    if [[ -n ${provides[*]} ]]; then
        deblog "Provides" "$(sed 's/ /, /g' <<< "${provides[@]}")"
    fi

    if [[ -n $replace ]]; then
        deblog "Conflicts" "$(sed 's/ /, /g' <<< "${replace[@]}")"
        deblog "Replace" "$(sed 's/ /, /g' <<< "${replace[@]}")"
    fi

    if [[ -n ${homepage} ]]; then
        deblog "Homepage" "${homepage}"
    fi

    if [[ -n ${maintainer} ]]; then
        deblog "Maintainer" "${maintainer}"
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

    for i in {post_remove,post_install,pre_install}; do
        case "$i" in
            post_remove) export deb_post_file="postrm" ;;
            post_install) export deb_post_file="postinst" ;;
            pre_install) export deb_post_file="preinst" ;;
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
            echo '#!/bin/bash' | sudo tee "$STOWDIR/$name/DEBIAN/$deb_post_file" > /dev/null
            for pacmf_out in "${pac_min_functions[@]}"; do
                echo "${pacmf_out}" | sudo tee -a "$STOWDIR/$name/DEBIAN/$deb_post_file" > /dev/null
            done
            {
                cat "${pacfile}"
                echo -e "\n$i"
            } | sudo tee -a "$STOWDIR/$name/DEBIAN/$deb_post_file" > /dev/null
        fi
    done
    echo -e "sudo rm -f $METADIR/$name\nsudo rm -f /etc/apt/preferences.d/$name-pin" | sudo tee -a "$STOWDIR/$name/DEBIAN/postrm" > /dev/null
    local postfile
    for postfile in {postrm,postinst,preinst}; do
        sudo chmod -x "$STOWDIR/$name/DEBIAN/${postfile}" &> /dev/null
        sudo chmod 755 "$STOWDIR/$name/DEBIAN/${postfile}" &> /dev/null
    done

    # Handle `backup` key
    if [[ -n ${backup[*]} ]]; then
        local file
        for file in "${backup[@]}"; do
            if [[ -z ${file} ]]; then
                fancy_message warn "Empty key... Skipping" && continue
            fi
            # `r:usr/share/pac.conf`
            if [[ ${file:0:2} == "r:" ]]; then
                # `r:`
                if [[ -z ${file:2} ]]; then
                    fancy_message warn "'${file}' cannot contain empty path... Skipping" && continue
                fi
                # `r:/usr/share/pac.conf`
                if [[ ${file:2:1} == "/" ]]; then
                    fancy_message warn "'${file}' cannot contain path starting with '/'... Skipping" && continue
                fi
                if [[ -f "$STOWDIR/$name/${file:2}" ]]; then
                    fancy_message warn "'${file}' is inside the package... Skipping" && continue
                fi
                echo "remove-on-upgrade /${file:2}" | sudo tee -a "$STOWDIR/$name/DEBIAN/conffiles" > /dev/null
            else
                if [[ ${file:0:1} == "/" ]]; then
                    fancy_message warn "'${file}' cannot contain path starting with '/'... Skipping" && continue
                fi
                echo "/${file}" | sudo tee -a "$STOWDIR/$name/DEBIAN/conffiles" > /dev/null
            fi
        done
    fi

    deblog "Installed-Size" "$(sudo du -s --apparent-size --exclude=DEBIAN -- "$STOWDIR/$name" | cut -d$'\t' -f1)"
    export install_size="$(sudo du -s --apparent-size --exclude=DEBIAN -- "$STOWDIR/$name" | cut -d$'\t' -f1 | numfmt --to=iec)"

    generate_changelog | sudo tee -a "$STOWDIR/$name/DEBIAN/changelog" > /dev/null

    cd "$STOWDIR"
    if ! createdeb "$name"; then
        fancy_message error "Could not create package"
        error_log 5 "install $PACKAGE"
        fancy_message info "Cleaning up"
        cleanup
        return 1
    fi

    if ((PACSTALL_INSTALL != 0)); then
        # --allow-downgrades is to allow git packages to "downgrade", because the commits aren't necessarily a higher number than the last version
        if ! sudo -E apt-get install --reinstall "$STOWDIR/$name.deb" -y --allow-downgrades 2> /dev/null; then
            echo -ne "\t"
            fancy_message error "Failed to install $name deb"
            error_log 8 "install $PACKAGE"
            sudo dpkg -r --force-all "$name" > /dev/null
            fancy_message info "Cleaning up"
            cleanup
            exit 1
        fi
        if [[ -f /tmp/pacstall-pacdeps-"$name" ]]; then
            sudo apt-mark auto "${gives:-$name}" 2> /dev/null
        fi
        sudo rm -rf "$STOWDIR/$name"
        sudo rm -rf "$SRCDIR/$name.deb"

        if ! [[ -d /etc/apt/preferences.d/ ]]; then
            sudo mkdir -p /etc/apt/preferences.d
        fi
        local combined_pinning=("${provides[@]}" "${gives:-${name}}")
        echo "Package: ${combined_pinning[*]}" | sudo tee "/etc/apt/preferences.d/${name}-pin" > /dev/null
        echo "Pin: version *" | sudo tee -a "/etc/apt/preferences.d/${name}-pin" > /dev/null
        echo "Pin-Priority: -1" | sudo tee -a "/etc/apt/preferences.d/${name}-pin" > /dev/null
        return 0
    else
        sudo mv "$STOWDIR/$name.deb" "$PACDEB_DIR"
        sudo chown "$PACSTALL_USER":"$PACSTALL_USER" "$PACDEB_DIR/$name.deb"
        fancy_message info "Package built at ${BGreen}$PACDEB_DIR/$name.deb${NC}"
        fancy_message info "Moving ${BGreen}$STOWDIR/$name${NC} to ${BGreen}/tmp/pacstall-no-build/$name${NC}"
        sudo rm -rf "/tmp/pacstall-no-build/$name"
        mkdir -p "/tmp/pacstall-no-build/$name"
        sudo mv "$STOWDIR/$name" "/tmp/pacstall-no-build/$name"
        cleanup
        exit 0
    fi
}

function install_builddepends() {
    if [[ -n ${makedepends[*]} ]]; then
        for build_dep in "${makedepends[@]}"; do
            if ! is_apt_package_installed "${build_dep}"; then
                # If not installed yet, we can mark it as possibly removable
                not_installed_yet_builddepends+=("${build_dep}")
            fi
        done

        if ((${#not_installed_yet_builddepends[@]} != 0)); then
            fancy_message info "${BLUE}$name${NC} requires ${CYAN}${not_installed_yet_builddepends[*]}${NC} to install"
            if ! sudo apt-get install -y "${not_installed_yet_builddepends[@]}"; then
                fancy_message error "Failed to install build dependencies"
                error_log 8 "install $PACKAGE"
                fancy_message info "Cleaning up"
                cleanup
                return 1
            fi
        fi
    fi
}

function genextr_declare() {
    unset ext_method ext_deps
    # shellcheck disable=SC2031
    case "${url,,}" in
        *.zip)
            ext_method="unzip -qo"
            ext_deps=("unzip")
            ;;
        *.tar.gz | *.tgz)
            ext_method="tar -xzf"
            ext_deps=("tar" "gzip")
            ;;
        *.tar.bz2 | *.tbz2)
            ext_method="tar -xjf"
            ext_deps=("tar" "bzip2")
            ;;
        *.tar.xz | *.txz)
            ext_method="tar -xJf"
            ext_deps=("tar" "xz-utils")
            ;;
        *.tar.zst | *.tzst)
            ext_method="tar -xf"
            ext_deps=("tar" "zstd")
            ;;
        *.gz)
            ext_method="gunzip"
            ext_deps=("gzip")
            ;;
        *.bz2)
            ext_method="bunzip2"
            ext_deps=("bzip2")
            ;;
        *.xz)
            ext_method="unxz"
            ext_deps=("xz-utils")
            ;;
        *.lz)
            ext_method="lzip -d"
            ext_deps=("lzip")
            ;;
        *.lzma)
            ext_method="unlzma"
            ext_deps=("xz-utils")
            ;;
        *.zst)
            ext_method="unzstd -q"
            ext_deps=("zstd")
            ;;
        *.7z)
            ext_method="7za x"
            ext_deps=("p7zip-full")
            ;;
        *.rar)
            ext_method="unrar x -inul"
            ext_deps=("unrar")
            ;;
        *.lz4)
            ext_method="lz4 -d"
            ext_deps=("liblz4-tool")
            ;;
        *.tar)
            ext_method="tar -xf"
            ext_deps=("tar")
            ;;
    esac
}

function clean_fail_down() {
    fancy_message info "Cleaning up"
    cleanup
    exit 1
}

function hashcheck() {
    local inputFile="${1}" inputHash="${2}" fileHash
    # Get hash of file
    fileHash="$(sha256sum "${inputFile}")"
    fileHash="${fileHash%% *}"

    # Check if the input hash is the same as of the downloaded file.
    # Skip this test if the hash variable doesn't exist in the pacscript.
    if [[ -n ${inputHash} && ${inputHash} != "${fileHash}" ]]; then
        fancy_message error "Hashes do not match"
        fancy_message sub "Got:      ${BRed}${fileHash}${NC}"
        fancy_message sub "Expected: ${BGreen}${inputHash}${NC}"
        error_log 16 "install $PACKAGE"
        clean_fail_down
    fi
}

function fail_down() {
    error_log 1 "download $PACKAGE"
    fancy_message error "Failed to download package"
    clean_fail_down
}

function gather_down() {
    if [[ -z ${pkgbase} ]]; then
        if [[ -n $PACSTALL_PAYLOAD ]]; then
            export pkgbase="/tmp/pacstall-pacdep"
        else
            export pkgbase="${SRCDIR}/${PACKAGE}~${pkgver}"
        fi
    fi
    mkdir -p "${pkgbase}"
    if ! [[ ${PWD} == "${pkgbase}" ]]; then
        find "${PWD}" -mindepth 1 -maxdepth 1 ! -wholename "${pkgbase}" \
            ! -wholename "${SRCDIR}" \
            ! -wholename "/tmp/pacstall-pacdep" \
            ! -wholename "/tmp/pacstall-pacdeps-$PACKAGE" \
            -exec mv {} "${pkgbase}/" \;
        cd "${pkgbase}" || {
            error_log 1 "gather-main $PACKAGE"
            fancy_message error "Could not enter into the main directory ${YELLOW}${pkgbase}${NC}"
            clean_fail_down
        }
    fi
}

function git_down() {
    local revision gitopts
    dest="${dest%.git}"
    if [[ -n ${git_branch} || -n ${git_tag} ]]; then
        if [[ -n ${git_branch} ]]; then
            revision="${git_branch}"
            fancy_message info "Cloning ${BPurple}${dest}${NC} from branch ${CYAN}${git_branch}${NC}"
        elif [[ -n ${git_tag} ]]; then
            revision="${git_tag}"
            fancy_message info "Cloning ${BPurple}${dest}${NC} from tag ${CYAN}${git_tag}${NC}"
        fi
        gitopts="--recurse-submodules -b ${revision}"
    elif [[ -n ${git_commit} ]]; then
        gitopts="--no-checkout --filter=blob:none"
        fancy_message info "Cloning ${BPurple}${dest}${NC} with no blobs"
    else
        gitopts="--recurse-submodules"
        fancy_message info "Cloning ${BPurple}${dest}${NC} from ${CYAN}HEAD${NC}"
    fi
    # git clone quietly, with no history, and if submodules are there, download with 10 jobs
    # shellcheck disable=SC2086,SC2031
    git clone --quiet --depth=1 --jobs=10 "${url}" "${dest}" ${gitopts} &> /dev/null || fail_down
    # cd into the directory
    cd "./${dest}" 2> /dev/null || {
        error_log 1 "install $PACKAGE"
        fancy_message error "Could not enter into the cloned git repository"
        clean_fail_down
    }
    if [[ -n ${git_commit} ]]; then
        fancy_message sub "Fetching commit ${CYAN}${git_commit:0:8}${NC}"
        git fetch --quiet origin "${git_commit}" &> /dev/null || fail_down
        git checkout --quiet --force "${git_commit}" &> /dev/null || fail_down
        git submodule update --init --recursive
    fi
    # Check the integrity
    calc_git_pkgver
    local cloned_git_hash
    cloned_git_hash="$(git rev-parse HEAD)"
    fancy_message sub "Checking integrity of ${YELLOW}${cloned_git_hash:0:8}${NC}"
    git fsck --full --no-progress --no-verbose || fancy_message warn "Could not check integrity of cloned git repository"
    if [[ ${cloned_git_hash:0:8} != "${comp_git_pkgver}" ]]; then
        fancy_message error "Cloned git repository does not match upstream hash"
        clean_fail_down
    fi
    if [[ ${source[i]} != "${source[0]}" ]]; then
        cd ..
        gather_down
    else
        export pkgbase="${PWD}"
    fi
}

function net_down() {
    fancy_message info "Downloading ${BPurple}${dest}${NC}"
    # shellcheck disable=SC2031
    download "$url" "$dest" || fail_down
}

function hashcheck_down() {
    if [[ -n ${expectedHash} && ${expectedHash} != "SKIP" ]]; then
        fancy_message sub "Checking hash ${YELLOW}${expectedHash:0:8}${NC}[${YELLOW}...${NC}]"
        hashcheck "${dest}" "${expectedHash}" || return 1
    fi
}

function genextr_down() {
    hashcheck_down
    local extract=true keep_archive
    for keep_archive in "${noextract[@]}"; do
        if [[ ${keep_archive} == "${dest}" ]]; then
            extract=false
            break
        fi
    done
    if ${extract}; then
        fancy_message sub "Extracting ${CYAN}${dest}${NC}"
        ${ext_method} "${dest}" 1>&1 2> /dev/null
        if [[ -f ${dest} ]]; then
            rm -f "${dest}"
        fi
    fi
    if [[ ${source[i]} == "${source[0]}" && ${extract} == "true" ]]; then
        cd ./*/ 2> /dev/null || {
            error_log 1 "install $PACKAGE"
            fancy_message warn "Could not enter into the extracted archive"
            gather_down
        }
        export pkgbase="${PWD}"
    else
        gather_down
    fi
}

function deb_down() {
    hashcheck_down
    if type -t pre_install &> /dev/null; then
        if ! pre_install; then
            error_log 5 "pre_install hook"
            fancy_message error "Could not run preinst hook successfully"
            exit 1
        fi
    fi
    if sudo apt install -y -f ./"${dest}" 2> /dev/null; then
        meta_log
        if [[ -f /tmp/pacstall-pacdeps-"$name" ]]; then
            sudo apt-mark auto "${gives:-$name}" 2> /dev/null
        fi
        if type -t post_install &> /dev/null; then
            if ! post_install; then
                error_log 5 "post_install hook"
                fancy_message error "Could not run post_install hook successfully"
                exit 1
            fi
        fi
        fancy_message info "Storing pacscript"
        sudo mkdir -p "/var/cache/pacstall/$PACKAGE/${full_version}"
        if ! cd "$DIR" 2> /dev/null; then
            error_log 1 "install $PACKAGE"
            fancy_message error "Could not enter into ${DIR}"
            exit 1
        fi
        sudo cp -r "${pacfile}" "/var/cache/pacstall/$PACKAGE/${full_version}"
        sudo chmod o+r "/var/cache/pacstall/$PACKAGE/${full_version}/$PACKAGE.pacscript"
        fancy_message info "Cleaning up"
        cleanup
        exit 0
    else
        fancy_message error "Failed to install the package"
        error_log 14 "install $PACKAGE"
        sudo apt purge "${gives:-$name}" -y > /dev/null
        clean_fail_down
    fi
}

function file_down() {
    fancy_message info "Copying local archive ${BPurple}${dest}${NC}"
    # shellcheck disable=SC2031
    cp -r "${url}" "${dest}" || fail_down
    genextr_declare
    if [[ -n ${ext_method} ]]; then
        genextr_down
    elif [[ ${source[i]} == "${source[0]}" && -d ${dest} ]]; then
        cd "./${dest}" 2> /dev/null || {
            error_log 1 "install $PACKAGE"
            fancy_message warn "Could not enter into the copied archive"
            gather_down
        }
        export pkgbase="${PWD}"
    else
        gather_down
    fi
}

function append_arch_entry() {
    local source_arch hash_arch
    source_arch="source_${CARCH}[*]"
    hash_arch="hash_${CARCH}[*]"
    if [[ -n ${!source_arch} ]]; then
        # shellcheck disable=SC2206
        source+=(${!source_arch})
    fi
    if [[ -n ${!hash_arch} ]]; then
        # shellcheck disable=SC2206
        hash+=(${!hash_arch})
    fi
}

# NCPU is the core count
if [[ -n $PACSTALL_BUILD_CORES ]]; then
    if [[ $PACSTALL_BUILD_CORES =~ ^[0-9]+$ ]]; then
        function nproc() { echo "${PACSTALL_BUILD_CORES:-1}"; }
        declare -g NCPU="${PACSTALL_BUILD_CORES:-1}"
    else
        fancy_message error "${UCyan}PACSTALL_BUILD_CORES${NC} is not an integer. Falling back to 1"
        function nproc() { echo "1"; }
        declare -g NCPU="1"
    fi
else
    declare -g NCPU="$(nproc)"
fi

ask "(${BPurple}$PACKAGE${NC}) Do you want to view/edit the pacscript?" N
if ((answer == 1)); then
    (
        if [[ -n $PACSTALL_EDITOR ]]; then
            $PACSTALL_EDITOR "$PACKAGE".pacscript
        elif [[ -n $EDITOR ]]; then
            $EDITOR "$PACKAGE".pacscript
        elif [[ -n $VISUAL ]]; then
            $VISUAL "$PACKAGE".pacscript
        else
            sensible-editor "$PACKAGE".pacscript
        fi
    ) || {
        fancy_message warn "Editor not found, falling back to 'sensible-editor'"
        sensible-editor "$PACKAGE".pacscript
    }
fi

fancy_message info "Sourcing pacscript"
DIR="$PWD"
homedir="$(eval echo ~"$PACSTALL_USER")"
export homedir

sudo cp "${PACKAGE}.pacscript" /tmp
sudo chmod a+r "/tmp/${PACKAGE}.pacscript"
pacfile="$(readlink -f "/tmp/${PACKAGE}.pacscript")"
export pacfile
mapfile -t FARCH < <(dpkg --print-foreign-architectures)
export FARCH
export CARCH="$(dpkg --print-architecture)"
export DISTRO="$(set_distro)"
if ! source "${pacfile}"; then
    fancy_message error "Could not source pacscript"
    error_log 12 "install $PACKAGE"
    fancy_message info "Cleaning up"
    cleanup
    return 1
fi

# Running `-B` on a deb package doesn't make sense, so let's download instead
if ((PACSTALL_INSTALL == 0)) && [[ ${name} == *-deb ]]; then
    if ! download "${source[0]}"; then
        fancy_message error "Failed to download '${source[0]}'"
        return 1
    fi
    return 0
fi

masked_packages=()
getMasks masked_packages
if ((${#masked_packages[@]} != 0)); then
    if array.contains masked_packages "${name:-${PACKAGE}}"; then
        offending_pkg="$(getMasks_offending_pkg "${name:-${PACKAGE}}")"
        # shellcheck disable=SC2181
        if (($? == 0)); then
            fancy_message error "The package ${BBlue}${offending_pkg}${NC} is masking ${BBlue}${name:-${PACKAGE}}${NC}. By installing the masked package, you may cause damage to your operating system"
            exit 1
        else
            fancy_message error "Somehow, 'getMasks' found masked packages that match the package you want to install, but 'getMasks_offending_pkg' could not find it. Report this upstream"
            exit 1
        fi
    fi
fi

if [[ -n ${arch[*]} ]]; then
    if ! is_compatible_arch "${arch[@]}"; then
        cleanup
        exit 1
    fi
fi

if [[ -n ${compatible[*]} ]]; then
    if ! get_compatible_releases "${compatible[@]}"; then
        cleanup
        exit 1
    fi
elif [[ -n ${incompatible[*]} ]]; then
    if ! get_incompatible_releases "${incompatible[@]}"; then
        cleanup
        exit 1
    fi
fi

clean_builddir
sudo mkdir -p "$STOWDIR/$name/DEBIAN"
sudo chmod a+rx "$STOWDIR" "$STOWDIR/$name" "$STOWDIR/$name/DEBIAN"

# Run checks function
if ! checks; then
    error_log 6 "install $PACKAGE"
    fancy_message info "Cleaning up"
    cleanup
    return 1
fi

# If priority exists and is required, and also that this package has not been installed before (first time)
if [[ -n ${priority} && ${priority} == 'essential' ]] && ! is_package_installed "${name}"; then
    ask "This package has 'priority=essential', meaning once this is installed, it should be assumed to be uninstallable. Do you want to continue?" Y
    if ((answer == 0)); then
        cleanup
        exit 1
    fi
fi

if [[ ${name} == *-git ]]; then
    parse_source_entry "${source[0]}"
    calc_git_pkgver
    full_version="${epoch+$epoch:}${pkgver}-pacstall${pkgrel:-1}~git${comp_git_pkgver}"
    git_pkgver="${comp_git_pkgver}"
    export git_pkgver
elif [[ ${name} == *-deb ]]; then
    full_version="${epoch+$epoch:}${pkgver}"
else
    full_version="${epoch+$epoch:}${pkgver}-pacstall${pkgrel:-1}"
fi

# Trap Crtl+C just before the point cleanup is first needed
trap "trap_ctrlc" 2

if [[ -n $ppa ]]; then
    for i in "${ppa[@]}"; do
        # Add ppa, but ppa bad I guess
        sudo add-apt-repository ppa:"$i"
    done
fi

if [[ -n $pacdeps ]]; then
    for i in "${pacdeps[@]}"; do
        # If /tmp/pacstall-pacdeps-"$i" is available, it will trigger the logger to log it as a dependency
        touch "/tmp/pacstall-pacdeps-$i"

        [[ $KEEP ]] && cmd="-KPI" || cmd="-PI"
        if pacstall -S "${i}@${REPO}" &> /dev/null; then
            repo="@${REPO}"
        fi
        if is_package_installed "${i}"; then
            pacstall_pacdep_status="$(compare_remote_version "$i")"
            if [[ $pacstall_pacdep_status == "update" ]]; then
                fancy_message info "Found newer version for $i pacdep"
                if ! pacstall "$cmd" "${i}${repo}"; then
                    fancy_message error "Failed to install dependency"
                    error_log 8 "install $PACKAGE"
                    cleanup
                    return 1
                fi
            else
                fancy_message info "The pacstall dependency ${i} is already installed and at latest version"

            fi
        elif fancy_message info "Installing $i" && ! pacstall "$cmd" "${i}${repo}"; then
            fancy_message error "Failed to install dependency"
            error_log 8 "install $PACKAGE"
            cleanup
            return 1
        fi
        unset repo
        rm -f "/tmp/pacstall-pacdeps-$i"
    done
fi

if ! is_package_installed "${name}"; then
    if [[ -n $breaks ]]; then
        for pkg in "${breaks[@]}"; do
            # Do we have an apt package installed (but not pacstall)?
            if is_apt_package_installed "${pkg}" && ! is_package_installed "${pkg}"; then
                # Check if anything in breaks variable is installed already
                fancy_message error "${RED}$name${NC} breaks $pkg, which is currently installed by apt"
                suggested_solution "Remove the apt package by running '${UCyan}sudo apt purge $pkg${NC}'"
                error_log 13 "install $PACKAGE"
                fancy_message info "Cleaning up"
                cleanup
                return 1
            fi
            if [[ ${pkg} != "${name}" ]] && is_package_installed "${pkg}"; then
                # Same thing, but check if anything is installed with pacstall
                fancy_message error "${RED}$name${NC} breaks $pkg, which is currently installed by pacstall"
                suggested_solution "Remove the pacstall package by running '${UCyan}pacstall -R $pkg${NC}'"
                error_log 13 "install $PACKAGE"
                fancy_message info "Cleaning up"
                cleanup
                return 1
            fi
        done
    fi

    if [[ -n ${replace[*]} ]]; then
        # Ask user if they want to replace the program
        for pkg in "${replace[@]}"; do
            if is_apt_package_installed "${pkg}"; then
                ask "This script replaces ${pkg}. Do you want to proceed?" Y
                if ((answer == 0)); then
                    fancy_message info "Cleaning up"
                    cleanup
                    return 1
                fi
                if [[ ${priority} == "essential" ]]; then
                    sudo apt-get remove -y "${pkg}" --allow-remove-essential
                else
                    sudo apt-get remove -y "${pkg}"
                fi
            fi
        done
    fi
fi

unset dest_list
declare -A dest_list
append_arch_entry
for i in "${!source[@]}"; do
    parse_source_entry "${source[$i]}"
    dest="${dest%.git}"
    if [[ -n ${dest_list[$dest]} && ${dest_list[$dest]} != "${url}" ]]; then
        fancy_message error "${dest} is associated with multiple source entries"
        clean_fail_down
    else
        dest_list["${dest}"]="${url}"
    fi
    genextr_declare
    unset ext_dep make_dep in_make_deps
    for ext_dep in "${ext_deps[@]}"; do
        in_make_deps=false
        for make_dep in "${makedepends[@]}"; do
            if [[ ${ext_dep} == "${make_dep}" ]]; then
                in_make_deps=true
                break
            fi
        done
        if ! ${in_make_deps}; then
            makedepends+=("${ext_dep}")
        fi
    done
    unset ext_dep make_dep in_make_deps
done
unset dest_list
install_builddepends

fancy_message info "Retrieving packages"
if [[ -f /tmp/pacstall-pacdeps-"$PACKAGE" ]]; then
    mkdir -p "/tmp/pacstall-pacdep"
    if ! cd "/tmp/pacstall-pacdep" 2> /dev/null; then
        error_log 1 "install $PACKAGE"
        fancy_message error "Could not enter /tmp/pacstall-pacdep"
        exit 1
    fi
else
    mkdir -p "$SRCDIR"
    if ! cd "$SRCDIR" 2> /dev/null; then
        error_log 1 "install $PACKAGE"
        fancy_message error "Could not enter ${SRCDIR}"
        exit 1
    fi
fi

mkdir -p "${SRCDIR}"

for i in "${!source[@]}"; do
    parse_source_entry "${source[$i]}"
    expectedHash="${hash[$i]}"
    if [[ -n $PACSTALL_PAYLOAD && ! -f "/tmp/pacstall-pacdeps-$PACKAGE" ]]; then
        dest="${PACSTALL_PAYLOAD##*/}"
    fi
    case "${url,,}" in
        *file://*)
            url="${url#file://}"
            url="${url#git+}"
            file_down
            ;;
        *.git | git+*)
            if [[ $url == git+* ]]; then
                url="${url#git+}"
            fi
            git_down
            ;;
        *.deb)
            net_down
            deb_down
            ;;
        *.zip | *.tar.gz | *.tgz | *.tar.bz2 | *.tbz2 | *.tar.xz | *.txz | *.tar.zst | *.tzst | *.gz | *.bz2 | *.xz | *.lz | *.lzma | *.zst | *.7z | *.rar | *.lz4 | *.tar)
            net_down
            genextr_declare
            genextr_down
            ;;
        *)
            net_down
            hashcheck_down
            if [[ ${source[i]} != "${source[0]}" ]]; then
                gather_down
            fi
            ;;
    esac
    unset expectedHash dest url git_branch git_tag git_commit ext_deps ext_method
done

export srcdir="$PWD"
sudo chown -R "$PACSTALL_USER":"$PACSTALL_USER" . 2> /dev/null

export pkgdir="$STOWDIR/$name"
export -f ask fancy_message select_options

# Trap so that we can clean up (hopefully without messing up anything)
trap cleanup ERR
trap - SIGINT

prompt_optdepends || return 1
clean_logdir

function fail_out_functions() {
    local func="$1"
    trap - ERR
    eval "$restoreshopt"
    error_log 5 "$func $PACKAGE"
    echo -ne "\t"
    fancy_message error "Could not $func $PACKAGE properly"
    sudo dpkg -r "${gives:-$name}" > /dev/null
    fancy_message info "Cleaning up"
    cleanup
    exit 1
}

function run_function() {
    local func="$1"
    fancy_message sub "Running $func"
    if [[ ! -d ${LOGDIR} ]]; then
        sudo mkdir -p "${LOGDIR}"
    fi
    # NOTE: https://stackoverflow.com/a/29163890 (shorthand for 2>&1 |)
    $func |& sudo tee "${LOGDIR}/$(printf '%(%Y-%m-%d_%T)T')-$name-$func.log" && return "${PIPESTATUS[0]}"
}

function safe_run() {
    local func="$1"
    export restoreshopt="$(shopt -p)
$(shopt -p -o)"
    local -
    shopt -o -s errexit errtrace pipefail

    local restoretrap="$(trap -p ERR)"
    trap "fail_out_functions '$func'" ERR

    run_function "$func"

    trap - ERR
    eval "$restoreshopt"
    eval "$restoretrap"
}

for i in {prepare,build,package}; do
    if is_function "$i"; then
        pac_functions+=("$i")
    fi
done
if [[ -n ${pac_functions[*]} ]]; then
    fancy_message info "Running functions"
    for function in "${pac_functions[@]}"; do
        safe_run "$function"
    done
fi

trap - ERR

cd "$HOME" 2> /dev/null || (
    error_log 1 "install $PACKAGE"
    fancy_message warn "Could not enter into ${HOME}"
)

makedeb

# Metadata writing
meta_log

fancy_message info "Performing post install operations"
fancy_message sub "Storing pacscript"
sudo mkdir -p "/var/cache/pacstall/$PACKAGE/${full_version}"
if ! cd "$DIR" 2> /dev/null; then
    error_log 1 "install $PACKAGE"
    fancy_message error "Could not enter into ${DIR}"
    sudo dpkg -r "${gives:-$name}" > /dev/null
    fancy_message info "Cleaning up"
    cleanup
    exit 1
fi

sudo cp -r "${pacfile}" "/var/cache/pacstall/$PACKAGE/${full_version}"
sudo chmod o+r "/var/cache/pacstall/$PACKAGE/${full_version}/$PACKAGE.pacscript"

fancy_message sub "Cleaning up"
cleanup

fancy_message info "Done installing ${BPurple}$PACKAGE${NC}"
return 0

# vim:set ft=sh ts=4 sw=4 noet:
