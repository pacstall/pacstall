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

# shellcheck source=./misc/scripts/version-constraints.sh
source "${SCRIPTDIR}/scripts/version-constraints.sh" || {
    fancy_message error "Could not find version-constraints"
    return 1
}

function cleanup() {
    if [[ -n $KEEP ]]; then
        sudo rm -rf "/tmp/pacstall-keep/$pkgname"
        mkdir -p "/tmp/pacstall-keep/$pkgname"
        sudo mv "${PACDIR:?}/${pkgname}.pacscript" "/tmp/pacstall-keep/$pkgname"
        sudo mv "${PACDIR:?}/${pkgname}~${pkgver}" "/tmp/pacstall-keep/$pkgname"
    fi
    if [[ -f "/tmp/pacstall-pacdeps-$PACKAGE" ]]; then
        sudo rm -rf "/tmp/pacstall-pacdeps-$PACKAGE"
        sudo rm -rf /tmp/pacstall-pacdep
    else
        sudo rm -rf "${PACDIR:?}"/*
        if [[ -n $pkgname ]]; then
            sudo rm -rf "${STAGEDIR:-/usr/src/pacstall}/${pkgname}"
        fi
        sudo rm -rf /tmp/pacstall-gives
    fi
    sudo rm -rf "${STAGEDIR}/${pkgname:-$PACKAGE}.deb"
    sudo rm -f /tmp/pacstall-select-options
    sudo rm -f "${PACDIR}/bwrapenv.*"
    local clsrc clsum cla_sum arch_vars \
        known_hashsums_clean=("b2" "sha512" "sha384" "sha256" "sha224" "sha1" "md5") \
        known_archs_clean=("amd64" "arm64" "armel" "armhf" "i386" "mips64el" "ppc64el" "riscv64" "s390x")
    for clsrc in "${known_archs_clean[@]}"; do
        for clvars in {source,depends,makedepends,optdepends,pacdeps,checkdepends,provides,conflicts,breaks,replaces,gives}; do
            arch_vars+=("${clvars}_${clsrc}")
        done
    done
    for clsum in "${known_hashsums_clean[@]}"; do
        arch_vars+=("${clsum}sums")
        for cla_sum in "${known_archs_clean[@]}"; do
            arch_vars+=("${clsum}sums_${cla_sum}")
        done
    done
    unset pkgname repology pkgver git_pkgver epoch source_url source depends makedepends checkdepends conflicts breaks replaces \
        gives pkgdesc hash optdepends ppa arch maintainer pacdeps patch PACPATCH NOBUILDDEP provides incompatible compatible optinstall \
        srcdir url backup pkgrel mask pac_functions repo priority noextract nosubmodules _archive license bwrapenv safeenv external_connection "${arch_vars[@]}" 2> /dev/null
    unset -f pre_install pre_upgrade pre_remove post_install post_upgrade post_remove prepare build check package 2> /dev/null
    sudo rm -f "${pacfile}"
}

function deblog() {
    local key="$1"
    shift
    local content=("$@")
    echo "$key: ${content[*]}" | sudo tee -a "$STAGEDIR/$pkgname/DEBIAN/control" > /dev/null
}

function clean_builddir() {
    sudo rm -rf "${STAGEDIR}/${pkgname:?}"
    sudo rm -f "${STAGEDIR}/${pkgname}.deb"
}

function prompt_optdepends() {
    local deps optdep opt optdesc just_name=() missing_optdeps=() not_satisfied_optdeps=()
    deps=("${depends[@]}")
    if ((${#optdepends[@]} != 0)); then
        local suggested_optdeps=()
        for optdep in "${optdepends[@]}"; do
            # Firstly, check if this is an alt dep list
            if dep_const.is_pipe "${optdep}"; then
                # Ok, we need to select *one* of those deps to be our sacrificial lamb Ψ(•̀ᴗ•́ )⤴
                dep_const.extract_description "${optdep}" optdesc
                optdep="$(dep_const.get_pipe "${optdep}")"
            fi
            if ! [[ ${optdep} =~ ${optdesc} ]]; then
                optdep="${optdep}: ${optdesc}"
            fi
            # Strip the description, `opt` is now the canonical optdep name
            dep_const.strip_description "${optdep}" opt
            # Let's get just the name
            dep_const.split_name_and_version "${opt}" just_name
            # Check if package exists in the repos, and if not, go to the next program
            if [[ -z "$(apt-cache search --no-generate --names-only "^${just_name[0]}\$" 2> /dev/null || apt-cache search --names-only "^${just_name[0]}\$")" ]]; then
                missing_optdeps+=("${just_name[0]}")
                continue
            fi
            # Next let's check if the version (if available) is in the repos
            if ! dep_const.apt_compare_to_constraints "${opt}"; then
                # Just put the name in
                not_satisfied_optdeps+=("${just_name[0]}")
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

        if [[ -n ${missing_optdeps[*]} || -n ${not_satisfied_optdeps[*]} ]] || ((${#suggested_optdeps[@]} != 0)); then
            fancy_message sub "Optional dependencies"
        fi
        if [[ -n ${missing_optdeps[*]} ]]; then
            echo -ne "\t"
            fancy_message warn "${BLUE}${missing_optdeps[*]}${NC} does not exist in apt repositories"
        fi
        if [[ -n ${not_satisfied_optdeps[*]} ]]; then
            echo -ne "\t"
            fancy_message warn "${BLUE}${not_satisfied_optdeps[*]}${NC} versions cannot be satisfied"

        fi
        if ((${#suggested_optdeps[@]} != 0)); then
            if ((PACSTALL_INSTALL != 0)); then
                # We do this so that arrays 'start at' 1 to the user
                z=1
                echo -e "\t\t[${BIRed}0${NC}] Select none"
                for i in "${suggested_optdeps[@]}"; do
                    # print optdepends with bold package name
                    echo -e "\t\t[${BICyan}$z${NC}] ${BOLD}${i%%:\ *}${NC}: ${i#*:\ }"
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
                        local not_installed_yet_optdeps+=("${suggested_optdeps[$((i - 1))]}")
                    done
                    if [[ -n ${not_installed_yet_optdeps[*]} ]]; then
                        fancy_message info "Selecting packages ${BCyan}${not_installed_yet_optdeps[*]%%:\ *}${NC}"
                        # final_merged_deps is a dep list of *every* type of dep we want to be logged into Suggests. This includes
                        # already installed optdeps, not yet installed ones (selected by user) and the rest
                        local final_merged_deps=("${not_installed_yet_optdeps[@]}" "${already_installed_optdeps[@]}" "${suggested_optdeps[@]}")
                        local log_depends log_depends_str
                        dep_const.format_control optdepends log_depends
                        dep_const.comma_array log_depends log_depends_str
                        deblog "Suggests" "${log_depends_str}"
                        fancy_message info "Installing selected optional dependencies"
                        sudo -E apt-get install "${not_installed_yet_optdeps[@]}" -y 2> /dev/null
                    fi
                else # Did we get 0 or n?
                    # Add everything to Suggests
                    local log_depends log_depends_str
                    dep_const.format_control optdepends log_depends
                    dep_const.comma_array log_depends log_depends_str
                    deblog "Suggests" "${log_depends_str}"
                fi
            else # If `-B` is being used
                # We can log everything from optdepends to Suggests
                # shellcheck disable=SC2034
                local log_depends log_depends_str
                dep_const.format_control optdepends log_depends
                dep_const.comma_array log_depends log_depends_str
                deblog "Suggests" "${log_depends_str}"
            fi
        fi
    fi

    # shellcheck disable=SC2034
    local depends_for_logging out_str
    if [[ -n ${pacdeps[*]} ]]; then
        for i in "${pacdeps[@]}"; do
            (
                #shellcheck disable=SC1090
                source "$METADIR/$i"
                if [[ -n $_gives ]]; then
                    echo "$_gives" | tee -a /tmp/pacstall-gives > /dev/null
                else
                    echo "$_name" | tee -a /tmp/pacstall-gives > /dev/null
                fi
            )
        done
        # shellcheck disable=SC2031
        while IFS= read -r line; do
            if ! array.contains deps "${line}"; then
                deps+=("${line}")
            fi
        done < /tmp/pacstall-gives
    fi
    # Do we have any deps or optdeps scheduled for installation?
    if [[ -n ${deps[*]} || -n ${not_installed_yet_optdeps[*]} ]]; then
        # shellcheck disable=SC2034
        local all_deps_to_install=("${not_installed_yet_optdeps[@]}" "${deps[@]}") ze_dep ze_dep_splits ze_dep_split
        # So basically, we're gonna now check if the `depends` elements can be installed on this system based on the
        # version constraints (if available), because I'd be very pissed if I tried building wine only to figure out
        # 8 hours later the versions specified in `depends` aren't available.
        for ze_dep in "${deps[@]}"; do
            dep_const.pipe_split "${ze_dep}" ze_dep_splits
            local pipe_nomatch=0
            for ze_dep_split in "${ze_dep_splits[@]}"; do
                if ! dep_const.apt_compare_to_constraints "${ze_dep_split}"; then
                    ((pipe_nomatch++))
                fi
            done
            if ((pipe_nomatch == ${#ze_dep_splits[@]})); then
                fancy_message error "'${BBlue}${ze_dep}${NC}' version(s) cannot be satisfied"
                fancy_message info "Cleaning up"
                cleanup
                exit 1
            fi
        done

        dep_const.format_control all_deps_to_install depends_for_logging
        dep_const.comma_array depends_for_logging out_str
        deblog "Depends" "${out_str}"
    fi
}

function generate_changelog() {
    printf "%s (%s) %s; urgency=medium\n\n  * Version now at %s.\n\n -- %s %(%a, %d %b %Y %T %z)T\n" \
        "${pkgname}" "${full_version}" "$(lsb_release -sc)" "${full_version}" "${maintainer[0]}"
}

function clean_logdir() {
    if [[ ! -d ${LOGDIR} ]]; then
        sudo mkdir -p "${LOGDIR}"
    fi
    sudo find -H "${LOGDIR:-/var/log/pacstall/error_log/}" -maxdepth 1 -mtime +30 -delete
}

function createdeb() {
    local pkgname="$1"
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
    cd "$STAGEDIR/$pkgname" || return 1
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
    sudo ar -rU "$pkgname.deb" debian-binary control.tar."$compression" data.tar."$compression" > /dev/null 2>&1
    sudo mv "$pkgname.deb" ..
    sudo rm -f debian-binary control.tar."$compression" data.tar."$compression"
}

function makedeb() {
    # It looks weird for it to say: `Packaging foo as foo`
    if [[ -n $gives && $pkgname != "$gives" ]]; then
        fancy_message info "Packaging ${BGreen}$pkgname${NC} as ${BBlue}$gives${NC}"
    else
        fancy_message info "Packaging ${BGreen}$pkgname${NC}"
    fi
    deblog "Package" "${gives:-$pkgname}"

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

    if [[ $pkgname == *-git ]]; then
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
        # shellcheck disable=SC2034
        local builddepends builddepends_str
        is_function "check" && [[ -n ${checkdepends[*]} ]] && makedepends+=("${checkdepends[@]}")
        dep_const.format_control makedepends builddepends
        dep_const.comma_array builddepends builddepends_str
        # shellcheck disable=SC2001
        deblog "Build-Depends" "${builddepends_str}"
    fi

    if [[ -n ${provides[*]} ]]; then
        # shellcheck disable=SC2001
        deblog "Provides" "$(sed 's/ /, /g' <<< "${provides[@]}")"
    fi

    if [[ -n ${conflicts[*]} ]]; then
        # shellcheck disable=SC2001
        deblog "Conflicts" "$(sed 's/ /, /g' <<< "${conflicts[@]}")"
    fi

    if [[ -n ${breaks[*]} ]]; then
        # shellcheck disable=SC2001
        deblog "Breaks" "$(sed 's/ /, /g' <<< "${breaks[@]}")"
    fi

    if [[ -n ${replaces[*]} ]]; then
        # shellcheck disable=SC2001
        deblog "Conflicts" "$(sed 's/ /, /g' <<< "${replaces[@]}")"
        # shellcheck disable=SC2001
        deblog "Replaces" "$(sed 's/ /, /g' <<< "${replaces[@]}")"
    fi

    if [[ -n ${url} ]]; then
        deblog "Homepage" "${url}"
    fi

    if [[ -n ${license[*]} ]]; then
        # shellcheck disable=SC2001
        deblog "License" "$(sed 's/ /, /g' <<< "${license[@]/custom\:/}")"
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
    if is_package_installed "${pkgname}"; then
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
            echo '#!/bin/bash' | sudo tee "$STAGEDIR/$pkgname/DEBIAN/$deb_post_file" > /dev/null
            for pacmf_out in "${pac_min_functions[@]}"; do
                echo "${pacmf_out}" | sudo tee -a "$STAGEDIR/$pkgname/DEBIAN/$deb_post_file" > /dev/null
            done
            {
                cat "${pacfile}"
                echo -e "\n$i"
            } | sudo tee -a "$STAGEDIR/$pkgname/DEBIAN/$deb_post_file" > /dev/null
        fi
    done
    unset pre_inst_upg post_inst_upg
    echo -e "sudo rm -f $METADIR/$pkgname\nsudo rm -f /etc/apt/preferences.d/$pkgname-pin" | sudo tee -a "$STAGEDIR/$pkgname/DEBIAN/postrm" > /dev/null
    local postfile
    for postfile in {postrm,postinst,preinst}; do
        sudo chmod -x "$STAGEDIR/$pkgname/DEBIAN/${postfile}" &> /dev/null
        sudo chmod 755 "$STAGEDIR/$pkgname/DEBIAN/${postfile}" &> /dev/null
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
                if [[ -f "$STAGEDIR/$pkgname/${file:2}" ]]; then
                    fancy_message warn "'${file}' is inside the package... Skipping" && continue
                fi
                echo "remove-on-upgrade /${file:2}" | sudo tee -a "$STAGEDIR/$pkgname/DEBIAN/conffiles" > /dev/null
            else
                if [[ ${file:0:1} == "/" ]]; then
                    fancy_message warn "'${file}' cannot contain path starting with '/'... Skipping" && continue
                fi
                echo "/${file}" | sudo tee -a "$STAGEDIR/$pkgname/DEBIAN/conffiles" > /dev/null
            fi
        done
    fi

    local estsize
    estsize="$(sudo du -s --apparent-size --exclude=DEBIAN -- "$STAGEDIR/$pkgname" | cut -d$'\t' -f1)"
    deblog "Installed-Size" "${estsize}"
    if ((estsize < 10)); then
        install_size="$((estsize * 1024)) B"
    else
        local duargs="b" numargs rawsize
        ((estsize < 1024)) && {
            duargs+="h"
            numargs="--from=iec --to=si"
        } || numargs="--to=si"
        rawsize="$(sudo du -s${duargs} --exclude=DEBIAN -- "$STAGEDIR/$pkgname" | cut -d$'\t' -f1)"
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

    generate_changelog | sudo tee -a "$STAGEDIR/$pkgname/DEBIAN/changelog" > /dev/null

    cd "$STAGEDIR" || return 1
    if ! createdeb "$pkgname"; then
        fancy_message error "Could not create package"
        error_log 5 "install $PACKAGE"
        fancy_message info "Cleaning up"
        cleanup
        return 1
    fi
    install_deb
}

function install_deb() {
    if ((PACSTALL_INSTALL != 0)); then
        # --allow-downgrades is to allow git packages to "downgrade", because the commits aren't necessarily a higher number than the last version
        if ! sudo -E apt-get install --reinstall "$STAGEDIR/$pkgname.deb" -y --allow-downgrades 2> /dev/null; then
            echo -ne "\t"
            fancy_message error "Failed to install $pkgname deb"
            error_log 8 "install $PACKAGE"
            sudo dpkg -r --force-all "$pkgname" > /dev/null
            fancy_message info "Cleaning up"
            cleanup
            exit 1
        fi
        if [[ -f /tmp/pacstall-pacdeps-"$pkgname" ]]; then
            sudo apt-mark auto "${gives:-$pkgname}" 2> /dev/null
        fi
        sudo rm -rf "$STAGEDIR/$pkgname"
        sudo rm -rf "$PACDIR/$pkgname.deb"

        if ! [[ -d /etc/apt/preferences.d/ ]]; then
            sudo mkdir -p /etc/apt/preferences.d
        fi
        local combined_pinning=("${provides[@]}" "${gives:-${pkgname}}")
        echo "Package: ${combined_pinning[*]}" | sudo tee "/etc/apt/preferences.d/${pkgname}-pin" > /dev/null
        echo "Pin: version *" | sudo tee -a "/etc/apt/preferences.d/${pkgname}-pin" > /dev/null
        echo "Pin-Priority: -1" | sudo tee -a "/etc/apt/preferences.d/${pkgname}-pin" > /dev/null
        return 0
    else
        sudo mv "$STAGEDIR/$pkgname.deb" "$PACDEB_DIR"
        sudo chown "$PACSTALL_USER":"$PACSTALL_USER" "$PACDEB_DIR/$pkgname.deb"
        fancy_message info "Package built at ${BGreen}$PACDEB_DIR/$pkgname.deb${NC}"
        fancy_message info "Moving ${BGreen}$STAGEDIR/$pkgname${NC} to ${BGreen}/tmp/pacstall-no-build/$pkgname${NC}"
        sudo rm -rf "/tmp/pacstall-no-build/$pkgname"
        mkdir -p "/tmp/pacstall-no-build/$pkgname"
        sudo mv "$STAGEDIR/$pkgname" "/tmp/pacstall-no-build/$pkgname"
        cleanup
        exit 0
    fi
}

function repacstall() {
    # shellcheck disable=SC2034
    local depends_array unpackdir depends_line deper pacgives meper ceper pacdep depends_array_form repac_depends_str upcontrol input_dest="${1}"
    unpackdir="${STAGEDIR}/${pkgname}"
    upcontrol="${unpackdir}/DEBIAN/control"
    sudo mkdir -p "${unpackdir}"
    sudo rm -rf "${unpackdir}"/*
    fancy_message sub "Repacking ${CYAN}${pkgname/\-deb/}.deb${NC}"
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
    if ! createdeb "${pkgname}"; then
        fancy_message error "Could not create package"
        error_log 5 "install $PACKAGE"
        fancy_message info "Cleaning up"
        cleanup
        return 1
    fi
    install_deb
}

function write_meta() {
    echo "_name=\"$pkgname\""
    echo "_version=\"${full_version}\""
    [[ -z ${install_size} ]] && install_size="$(aptitude search ~i --display-format '%p %I' --sort installsize | awk -v pkg="${gives:-${pkgname}}" '$0 ~ "^" pkg " " {print $2 " " $3}')"
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
    if [[ -f /tmp/pacstall-pacdeps-"$pkgname" ]]; then
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
    write_meta | sudo tee "$METADIR/$pkgname" > /dev/null
}

# vim:set ft=sh ts=4 sw=4 noet:
