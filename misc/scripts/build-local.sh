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
                        # shellcheck disable=SC2001
                        deblog "Suggests" "$(sed 's/ /, /g' <<< "${final_merged_deps[@]//: */}")"
                        fancy_message info "Installing selected optional dependencies"
                        sudo -E apt-get install "${not_installed_yet_optdeps[@]}" -y 2> /dev/null
                    fi
                else # Did we get 0 or n?
                    # Add everything to Suggests
                    local final_merged_deps=("${not_installed_yet_optdeps[@]}" "${already_installed_optdeps[@]}" "${suggested_optdeps[@]}")
                    # shellcheck disable=SC2001
                    deblog "Suggests" "$(sed 's/ /, /g' <<< "${final_merged_deps[@]//: */}")"
                fi
            else # If `-B` is being used
                # We can log everything from optdepends to Suggests
                for pkg in "${optdepends[@]}"; do
                    local B_suggests+=("${pkg%%: *}")
                done
                # shellcheck disable=SC2001
                deblog "Suggests" "$(sed 's/ /, /g' <<< "${B_suggests[@]//: */}")"
                unset pkg
            fi
        fi
    fi

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
        # Merge Depends and Pacdeps
        while IFS= read -r line; do
            deps+=("$line")
        done < /tmp/pacstall-gives
    fi
    # Do we have any deps or optdeps scheduled for installation?
    if [[ -n ${deps[*]} || -n ${not_installed_yet_optdeps[*]} ]]; then
        local all_deps_to_install=("${not_installed_yet_optdeps[@]}" "${deps[@]}")
        # shellcheck disable=SC2001
        deblog "Depends" "$(sed 's/ /, /g' <<< "${all_deps_to_install[@]}")"
    fi
}

function generate_changelog() {
    printf "%s (%s) %s; urgency=medium\n\n  * Version now at %s.\n\n -- %s %(%a, %d %b %Y %T %z)T\n" \
        "${name}" "${full_version}" "$(lsb_release -sc)" "${full_version}" "${maintainer[0]}"
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
        # shellcheck disable=SC2001
        deblog "Build-Depends" "$(sed 's/ /, /g' <<< "${makedepends[@]}")"
    fi

    if [[ -n ${provides[*]} ]]; then
        # shellcheck disable=SC2001
        deblog "Provides" "$(sed 's/ /, /g' <<< "${provides[@]}")"
    fi

    if [[ -n $replace ]]; then
        # shellcheck disable=SC2001
        deblog "Conflicts" "$(sed 's/ /, /g' <<< "${replace[@]}")"
        # shellcheck disable=SC2001
        deblog "Replace" "$(sed 's/ /, /g' <<< "${replace[@]}")"
    fi

    if [[ -n ${homepage} ]]; then
        deblog "Homepage" "${homepage}"
    fi

    if [[ -n ${maintainer[*]} ]]; then
        deblog "Maintainer" "${maintainer[0]}"
        if ((${#maintainer[@]} > 0)); then
            # Since https://www.debian.org/doc/debian-policy/ch-controlfields.html#uploaders says that Maintainer can only have one field, shove the rest in Uploaders
            printf -v uploader '%s, ' "${maintainer[@]:1}"
            printf -v uploader '%s\n' "${uploader%, }"
            deblog "Uploader" "${uploader}"
            unset uploader
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
    install_size="$(sudo du -s --apparent-size --exclude=DEBIAN -- "$STOWDIR/$name" | cut -d$'\t' -f1 | numfmt --to=iec)"
    export install_size

    generate_changelog | sudo tee -a "$STOWDIR/$name/DEBIAN/changelog" > /dev/null

    cd "$STOWDIR" || return 1
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

function write_meta() {
    echo "_name=\"$name\""
    echo "_version=\"${full_version}\""
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

# vim:set ft=sh ts=4 sw=4 noet:
