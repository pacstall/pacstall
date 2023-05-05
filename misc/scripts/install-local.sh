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
    unset name pkgname repology epoch url depends build_depends breaks replace gives description hash optdepends ppa arch maintainer pacdeps patch PACPATCH NOBUILDDEP provides incompatible optinstall epoch homepage backup pac_functions 2> /dev/null
    unset -f pkgver postinst removescript preinst prepare build install 2> /dev/null
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

# run checks to verify script works
function checks() {
    if [[ -z $name ]]; then
        fancy_message error "Package does not contain name"
        return 1
    fi
    if [[ -z $gives && $name == *-deb ]]; then
        fancy_message warn "Deb package does not contain gives"
    fi
    if [[ -z $hash && $name != *-git ]]; then
        fancy_message warn "Package does not contain a hash"
    fi
    if [[ -z $version ]]; then
        fancy_message error "Package does not contain version"
        return 1
    fi
    if [[ -z $url ]]; then
        fancy_message error "Package does not contain URL"
        return 1
    fi
    if [[ -z $description ]]; then
        fancy_message error "Package must contain a description"
        return 1
    fi
    if [[ -z $maintainer ]]; then
        fancy_message warn "Package does not have a maintainer. Please be advised"
    fi
}

# Logging metadata
function log() {
    # Origin repo info parsing
    if [[ $local == 'no' ]]; then
        if [[ $REPO == *"github"* ]]; then
            pURL="${REPO/'raw.githubusercontent.com'/'github.com'}"
            pURL="${pURL%/*}"
            pBRANCH="${REPO##*/}"
            branch="yes"
        elif [[ $REPO == *"gitlab"* ]]; then
            pURL="${REPO%/-/raw/*}"
            pBRANCH="${REPO##*/-/raw/}"
            branch="yes"
        else
            pURL="$REPO"
            branch="no"
        fi
    fi

    # Metadata writing
    {
        echo "_name=\"$name"\"
        if [[ -n $pkgname ]]; then
            echo "_pkgname=\"$pkgname"\"
        fi
        echo "_version=\"${full_version}"\"
        echo "_install_size=\"${install_size}"\"
        echo "_date=\"$(date)"\"
        if [[ -n $ppa ]]; then
            echo "_ppa=(${ppa[*]})"
        fi
        if [[ -n $homepage ]]; then
            echo "_homepage=\"${homepage}"\"
        fi
        if [[ -z $gives && $name == *-deb ]]; then
            echo "_gives=\"$(dpkg -f ./"${url##*/}" | sed -n "s/^Package: //p")"\"
        elif [[ -n $gives ]]; then
            echo "_gives=\"$gives"\"
        fi
        if [[ -f /tmp/pacstall-pacdeps-"$name" ]]; then
            echo '_pacstall_depends="true"'
        fi
        if [[ $local == 'no' ]]; then
            echo "_remoterepo=\"$pURL"\"
            if [[ $branch == 'yes' ]]; then
                echo "_remotebranch=\"$pBRANCH"\"
            fi
        fi
        if [[ -n ${pacdeps[*]} ]]; then
            echo "_pacdeps=(${pacdeps[*]})"
        fi
    } | sudo tee "$LOGDIR/$name" > /dev/null
}

function compare_remote_version() (
    local input="${1}"
    unset -f pkgver 2> /dev/null
    source "$LOGDIR/$input" || return 1
    if [[ -z ${_remoterepo} ]]; then
        return
    elif [[ ${_remoterepo} == *"github.com"* ]]; then
        local remoterepo="${_remoterepo/'github.com'/'raw.githubusercontent.com'}/${_remotebranch}"
    elif [[ ${_remoterepo} == *"gitlab.com"* ]]; then
        local remoterepo="${_remoterepo}/-/raw/${_remotebranch}"
    else
        local remoterepo="${_remoterepo}"
    fi
    local remotever="$(source <(curl -s -- "$remoterepo/packages/$input/$input.pacscript") && type pkgver &> /dev/null && pkgver || echo "${full_version}")" > /dev/null
    if [[ $input == *"-git" ]]; then
        if [[ $(pacstall -V "$input") != "$remotever" ]]; then
            echo "update"
        else
            echo "no"
        fi
    elif dpkg --compare-versions "$(pacstall -V "$input")" lt "$remotever" > /dev/null 2>&1; then
        echo "update"
    else
        echo "no"
    fi
)

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
            if [[ ${key#*:} == "${distro_version_number}" ]] || [[ ${key#*:} == "${distro_version_name}" ]]; then
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
            if [[ $key == "${distro_name}:${distro_version_name}" ]] || [[ $key == "${distro_name}:${distro_version_number}" ]]; then
                fancy_message error "This Pacscript does not work on ${BBlue}${distro_name}:${distro_version_name}${NC}/${BBlue}${distro_name}:${distro_version_number}${NC}"
                return 1
            fi
        fi
    done
}

function is_compatible_arch() {
    local input=("${@}")
    if [[ " ${input[*]} " =~ " all " ]]; then
        fancy_message warn "${BBlue}all${NC} is deprecated. Use ${BBlue}any${NC} instead"
        suggested_solution "Replace ${UPurple}arch${NC} with ${UCyan}arch=(${arch[*]/all/any})${NC}"
        return 0
    elif [[ " ${input[*]} " =~ " any " ]]; then
        return 0
    elif ! [[ " ${input[*]} " =~ " ${CARCH} " ]]; then
        fancy_message error "This Pacscript does not work on ${BBlue}${CARCH}${NC}"
        return 1
    fi
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
    if [[ -n $depends ]]; then
        if is_array depends; then
            deps=("${depends[@]}")
        else
            mapfile -t deps <<< "${depends// /$'\n'}"
            fancy_message warn "Using '${BCyan}depends${NC}' as a variable instead of array is deprecated"
        fi
    fi
    if ((${#optdepends[@]} != 0)); then
        for i in "${optdepends[@]}"; do
            # Should cover `foo:i386: baz`, `foo: baz`, but not `foo:baz`
            if [[ $i != *": "* ]]; then
                fancy_message error "${i} does not have a description"
                fancy_message info "Cleaning up"
                cleanup
                return 1
            fi
        done

        local suggested_optdeps=()
        for optdep in "${optdepends[@]}"; do
            # Strip the description, `opt` is now the canonical optdep name
            local opt="${optdep%%: *}"
            # Check if package exists in the repos, and if not, go to the next program
            if [[ -z "$(apt-cache search --names-only "^$opt\$")" ]]; then
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

                if [[ ${choices[0]} != "n" && ${choices[0]} != "0" ]]; then
                    for i in "${choices[@]}"; do
                        ((i--))
                        local s="${suggested_optdeps[$i]}"
                        local not_installed_yet_optdeps+=("${s%%: *}")
                    done
                    if [[ -n ${not_installed_yet_optdeps[*]} ]]; then
                        fancy_message info "Selecting packages ${BCyan}${not_installed_yet_optdeps[*]}${NC}"
                        local final_merged_deps=("${not_installed_yet_optdeps[@]}" "${already_installed_optdeps[@]}" "${suggested_optdeps[@]}")
                        deblog "Suggests" "$(sed 's/ /, /g' <<< "${final_merged_deps[@]//: */}")"
                        fancy_message info "Installing selected optional dependencies"
                        sudo -E apt-get install "${not_installed_yet_optdeps[@]}" -y 2> /dev/null
                    fi
                    if is_package_installed "${name}"; then
                        sudo dpkg -r --force-all "${gives:-$name}" > /dev/null
                    fi
                else
                    local final_merged_deps=("${not_installed_yet_optdeps[@]}" "${already_installed_optdeps[@]}" "${suggested_optdeps[@]}")
                    deblog "Suggests" "$(sed 's/ /, /g' <<< "${final_merged_deps[@]//: */}")"
                fi
            else # If `-B` is being used
                for pkg in "${optdepends[@]}"; do
                    local B_suggests+=("${pkg%%: *}")
                done
                deblog "Suggests" "$(sed 's/ /, /g' <<< "${B_suggests[@]//: */}")"
            fi
        fi
    fi

    if [[ -n ${pacdeps[*]} ]]; then
        for i in "${pacdeps[@]}"; do
            (
                source "$LOGDIR/$i"
                if [[ -n $_gives ]]; then
                    echo "$_gives" | tee -a /tmp/pacstall-gives > /dev/null
                else
                    echo "$_name" | tee -a /tmp/pacstall-gives > /dev/null
                fi
            )
        done
        while IFS= read -r line; do
            deps+=("$line")
        done < /tmp/pacstall-gives
    fi
    if [[ -n ${deps[*]} || -n ${not_installed_yet_optdeps[*]} ]]; then
        local all_deps_to_install=("${not_installed_yet_optdeps[@]}" "${deps[@]}")
        deblog "Depends" "$(sed 's/ /, /g' <<< "${all_deps_to_install[@]}")"
    fi
}

function generate_changelog() {
    echo -e "${name} (${full_version}) $(lsb_release -sc); urgency=medium\n"
    echo -e "  * Version now at ${full_version}.\n"
    echo -e " -- $maintainer  $(date +"%a, %d %b %Y %T %z")"
}

function clean_logdir() {
    sudo find -H "/var/log/pacstall/error_log/" -maxdepth 1 -mtime +30 -exec rm -rf {} \;
}

function createdeb() {
    local name="$1"
    if ((PACSTALL_INSTALL == 0)); then
        # We are not going to immediately install, meaning the user might want to share their deb with someone else, so create the highest compression.
        local flags=("-9" "-T0")
        local compression="xz"
        local command="xz"
    else
        # Immediate install (gzip), so we want fast build times over everything else
        local flags=("-1n")
        local compression="gz"
        local command="gzip"
    fi
    cd "$STOWDIR/$name"
    echo "2.0" | sudo tee debian-binary > /dev/null
    sudo tar -cf "$PWD/control.tar" -T /dev/null
    local CONTROL_LOCATION="$PWD/control.tar"
    # avoid having to cd back
    (
        # create control.tar
        cd DEBIAN
        for i in *; do
            if [[ -f $i ]]; then
                local files_for_control+=("$i")
            fi
        done
        fancy_message sub "Packing control.tar"
        sudo tar -rf "$CONTROL_LOCATION" "${files_for_control[@]}"
    )
    sudo tar -cf "$PWD/data.tar" -T /dev/null
    local DATA_LOCATION="$PWD/data.tar"
    # collect every top level dir except for DEBIAN
    for i in *; do
        if [[ -d $i && $i != "DEBIAN" ]]; then
            local files_for_data+=("$i")
        fi
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
    if [[ -n $gives ]]; then
        fancy_message info "Packaging ${BGreen}$name${NC} as ${BBlue}$gives${NC}"
    else
        fancy_message info "Packaging ${BGreen}$name${NC}"
    fi
    deblog "Package" "${gives:-$name}"

    if [[ $version =~ ^[0-9] ]]; then
        deblog "Version" "${full_version}"
        export version="${full_version}"
    else
        deblog "Version" "0${full_version}"
        export version="0${full_version}"
    fi

    deblog "Architecture" "all"
    deblog "Section" "Pacstall"
    deblog "Priority" "optional"

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

    deblog "Maintainer" "${maintainer:-Pacstall <pacstall@pm.me>}"

    # Do we have a long description? (longer than 2 lines)
    while IFS=$'\n' read -r line; do
        if [[ -z ${line} ]]; then
            # Description states that empty lines must contain a single period after the period.
            local description_arr+=(".")
        else
            local description_arr+=("$line")
        fi
    done <<< "${description}"
    if ((${#description_arr[@]} > 1)); then
        deblog "Description" "$(
            echo "${description_arr[0]}"
            for ((i = 1; i < "${#description_arr[@]}"; i++)); do
                echo -e " ${description_arr[i]}"
            done
        )"
    else
        deblog "Description" "${description}"
    fi

    for i in {removescript,postinst,preinst}; do
        case "$i" in
            removescript) export deb_post_file="postrm" ;;
            postinst) export deb_post_file="postinst" ;;
            preinst) export deb_post_file="preinst" ;;
        esac
        if [[ $(type -t "$i") == function ]]; then
            echo '#!/bin/bash
set -e
function ask(){
local default reply
if [[ ${2-} == "Y" ]];then
echo -ne "$1 [Y/n] "
default="Y"
elif [[ ${2-} == "N" ]];then
echo -ne "$1 [y/N] "
fi
default=${2-}
read -r reply <&0
[[ -z $reply ]] && reply=$default
case "$reply" in
Y*|y*)export answer=1
return 0
;;
N*|n*)export answer=0
return 1
esac
}
function fancy_message(){
local MESSAGE_TYPE="$1"
local MESSAGE="$2"
local BOLD="\033[1m"
local NC="\033[0m"
case $MESSAGE_TYPE in
info)echo -e "[$BOLD+$NC] INFO: $MESSAGE";;
warn)echo -e "[$BOLD*$NC] WARNING: $MESSAGE";;
error)echo -e "[$BOLD!$NC] ERROR: $MESSAGE";;
sub)echo -e "	[$BOLD>$NC] $MESSAGE";;
*)echo -e "[$BOLD?$NC] UNKNOWN: $MESSAGE"
esac
}
function get_homedir(){
local PACSTALL_USER=$(logname 2>/dev/null||echo "${SUDO_USER:-$USER}")
eval echo ~"$PACSTALL_USER"
}
export homedir="$(get_homedir)"
if [[ -n $PACSTALL_BUILD_CORES ]];then
declare -gr NCPU="${PACSTALL_BUILD_CORES:-1}"
else
declare -gr NCPU="$(nproc)"
fi' | sudo tee "$STOWDIR/$name/DEBIAN/$deb_post_file" > /dev/null
            {
                cat "${pacfile}"
                echo -e "$i"
            } | sudo tee -a "$STOWDIR/$name/DEBIAN/$deb_post_file" > /dev/null
        fi
    done
    echo -e "sudo rm -f $LOGDIR/$name\nsudo rm -f /etc/apt/preferences.d/$name.pin" | sudo tee -a "$STOWDIR/$name/DEBIAN/postrm" > /dev/null
    for i in {postrm,postinst,preinst}; do
        sudo chmod -x "$STOWDIR/$name/DEBIAN/$i" 1> /dev/null 2>&1
        sudo chmod 755 "$STOWDIR/$name/DEBIAN/$i" 1> /dev/null 2>&1
    done

    # Handle `backup` key
    if [[ -n ${backup[*]} ]]; then
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
        echo "Package: ${gives:-$name}
Pin: version *
Pin-Priority: -1" | sudo tee /etc/apt/preferences.d/"${name}-pin" > /dev/null
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

# NCPU is the core count
if [[ -n $PACSTALL_BUILD_CORES ]]; then
    if [[ $PACSTALL_BUILD_CORES =~ ^[0-9]+$ ]]; then
        function nproc() {
            echo "${PACSTALL_BUILD_CORES:-1}"
        }
        declare -rg NCPU="${PACSTALL_BUILD_CORES:-1}"
    else
        fancy_message error "${UCyan}PACSTALL_BUILD_CORES${NC} is not an integer. Falling back to 1"
        function nproc() {
            echo "1"
        }
        declare -rg NCPU="1"
    fi
else
    declare -rg NCPU="$(nproc)"
fi

ask "(${BPurple}$PACKAGE${NC}) Do you want to view/edit the pacscript" N
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
pacfile=$(readlink -f "/tmp/${PACKAGE}.pacscript")
export pacfile
export CARCH="$(dpkg --print-architecture)"
if ! source "${pacfile}"; then
    fancy_message error "Could not source pacscript"
    error_log 12 "install $PACKAGE"
    fancy_message info "Cleaning up"
    cleanup
    return 1
fi

full_version="${epoch+$epoch:}$version"
if [[ -n ${arch[*]} ]]; then
    if ! is_compatible_arch "${arch[@]}"; then
        cleanup
        exit 1
    fi
fi

if [[ -n ${incompatible[*]} ]]; then
    if ! get_incompatible_releases "${incompatible[@]}"; then
        cleanup
        exit 1
    fi
fi

clean_builddir
sudo mkdir -p "$STOWDIR/$name/DEBIAN"

if type pkgver > /dev/null 2>&1; then
    version=$(pkgver) > /dev/null
fi

# Run checks function
if ! checks; then
    error_log 6 "install $PACKAGE"
    fancy_message info "Cleaning up"
    cleanup
    return 1
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
        if is_package_installed "${i}"; then
            pacstall_pacdep_status="$(compare_remote_version "$i")"
            if [[ -z $UPGRADE && $pacstall_pacdep_status == "update" ]]; then
                fancy_message info "Found newer version for $i pacdep"
                if ! pacstall "$cmd" "$i"; then
                    fancy_message error "Failed to install dependency"
                    error_log 8 "install $PACKAGE"
                    cleanup
                    return 1
                fi
            else
                fancy_message info "The pacstall dependency ${i} is already installed and at latest version"

            fi
        elif fancy_message info "Installing $i" && ! pacstall "$cmd" "$i"; then
            fancy_message error "Failed to install dependency"
            error_log 8 "install $PACKAGE"
            cleanup
            return 1
        fi
        rm -f "/tmp/pacstall-pacdeps-$i"
    done
fi

if ! is_package_installed "${name}"; then
    if [[ -n $breaks ]]; then
        if ! is_array breaks; then
            mapfile -t breaks <<< "${breaks// /$'\n'}"
            fancy_message warn "Using '${BCyan}breaks${NC}' as a variable instead of array is deprecated"
        fi
        for pkg in "${breaks[@]}"; do
            if is_apt_package_installed "${pkg}"; then
                # Check if anything in breaks variable is installed already
                fancy_message error "${RED}$name${NC} breaks $pkg, which is currently installed by apt"
                suggested_solution "Remove the apt package by running '${UCyan}sudo apt remove $pkg${NC}'"
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
        if ! is_array replace; then
            mapfile -t replace <<< "${replace// /$'\n'}"
            fancy_message warn "Using '${BCyan}replace${NC}' as a variable instead of array is deprecated"
        fi
        # Ask user if they want to replace the program
        for pkg in "${replace[@]}"; do
            if is_apt_package_installed "${pkg}"; then
                ask "This script replaces ${pkg}. Do you want to proceed" N
                if ((answer == 0)); then
                    fancy_message info "Cleaning up"
                    cleanup
                    return 1
                fi
                sudo apt-get remove -y "${pkg}"
            fi
        done
    fi
fi

if [[ -n ${build_depends[*]} ]]; then
    # Get all uninstalled build depends
    if ! is_array build_depends; then
        mapfile -t build_depends <<< "${build_depends// /$'\n'}"
        fancy_message warn "Using '${BCyan}build_depends${NC}' as a variable instead of array is deprecated"
    fi
    for build_dep in "${build_depends[@]}"; do
        if ! is_apt_package_installed "${build_dep}"; then
            # If not installed yet, we can mark it as possibly removable
            not_installed_yet_builddepends+=("${build_dep}")
        fi
    done

    if ((${#not_installed_yet_builddepends[@]} != 0)); then
        fancy_message info "${BLUE}$name${NC} requires ${CYAN}${not_installed_yet_builddepends[*]}${NC} to install"
        ask "Do you want to remove them after installing ${BLUE}$name${NC}" N
        if ((answer == 0)); then
            NOBUILDDEP=0
        else
            NOBUILDDEP=1
        fi

        if ! sudo apt-get install -y "${not_installed_yet_builddepends[@]}"; then
            fancy_message error "Failed to install build dependencies"
            error_log 8 "install $PACKAGE"
            fancy_message info "Cleaning up"
            cleanup
            return 1
        fi
    fi
fi

function hashcheck() {
    local inputHash="${hash}"
    # Get hash of file
    local fileHash="$(sha256sum "${1}")"
    fileHash="${fileHash%% *}"

    # Check if the input hash is the same as of the downloaded file.
    # Skip this test if the hash variable doesn't exist in the pacscript.
    if [[ -n ${hash} && ${inputHash} != "${fileHash}" ]]; then
        fancy_message error "Hashes do not match"
        fancy_message sub "Got:      ${BRed}${fileHash}${NC}"
        fancy_message sub "Expected: ${BGreen}${inputHash}${NC}"
        error_log 16 "install $PACKAGE"
        fancy_message info "Cleaning up"
        cleanup
        return 1
    fi
    true
}

fancy_message info "Retrieving packages"
if [[ -f /tmp/pacstall-pacdeps-"$PACKAGE" ]]; then
    mkdir -p "/tmp/pacstall-pacdep"
    if ! cd "/tmp/pacstall-pacdep" 2> /dev/null; then
        error_log 1 "install $PACKAGE"
        fancy_message error "Could not enter ${SRCDIR}"
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

if [[ -n $patch ]]; then
    fancy_message info "Downloading patches"
    mkdir -p PACSTALL_patchesdir
    for i in "${patch[@]}"; do
        wget -q "$i" -P PACSTALL_patchesdir &
    done
    wait
    export PACPATCH="$PWD/PACSTALL_patchesdir"
fi

if [[ -n $PACSTALL_PAYLOAD ]]; then
    file_name="${PACSTALL_PAYLOAD##*/}"
else
    file_name="${url##*/}"
fi

if [[ $name == *-git ]]; then
    # git clone quietly, with no history, and if submodules are there, download with 10 jobs
    git clone --quiet --depth=1 --jobs=10 "$url"
    # cd into the directory
    cd ./*/ 2> /dev/null || {
        error_log 1 "install $PACKAGE"
        fancy_message warn "Could not enter into the cloned git repository"
        fancy_message info "Cleaning up"
        cleanup
        exit 1
    }
    # Check the integrity
    git fsck --full
else
    case "${url,,}" in
        *.zip)
            if ! download "$url"; then
                error_log 1 "download $PACKAGE"
                fancy_message error "Failed to download package"
                fancy_message info "Cleaning up"
                cleanup
                exit 1
            fi
            # hash the file
            hashcheck "${file_name}" || return 1
            # unzip file
            fancy_message info "Extracting ${file_name}"
            unzip -qo "${file_name}" 1>&1 2> /dev/null
            # cd into it
            cd ./*/ 2> /dev/null || {
                error_log 1 "install $PACKAGE"
                fancy_message warn "Could not enter into the downloaded archive"
            }
            ;;
        *.deb)
            if ! download "$url"; then
                error_log 1 "download $PACKAGE"
                fancy_message error "Failed to download package"
                fancy_message info "Cleaning up"
                cleanup
                exit 1
            fi
            hashcheck "${file_name}" || return 1
            if sudo apt install -y -f ./"${file_name}" 2> /dev/null; then
                log
                if [[ -f /tmp/pacstall-pacdeps-"$name" ]]; then
                    sudo apt-mark auto "${gives:-$name}" 2> /dev/null
                fi
                if type -t postinst > /dev/null 2>&1; then
                    if ! postinst; then
                        error_log 5 "postinst hook"
                        fancy_message error "Could not run postinst hook successfully"
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
                return 0

            else
                fancy_message error "Failed to install the package"
                error_log 14 "install $PACKAGE"
                sudo apt purge "${gives:-$name}" -y > /dev/null
                fancy_message info "Cleaning up"
                cleanup
                return 1
            fi
            ;;
        *.appimage)
            if ! download "$url"; then
                error_log 1 "download $PACKAGE"
                fancy_message error "Failed to download package"
                fancy_message info "Cleaning up"
                cleanup
                exit 1
            fi
            hashcheck "${file_name}" || return 1
            ;;
        *)
            if ! download "$url"; then
                error_log 1 "download $PACKAGE"
                fancy_message error "Failed to download package"
                fancy_message info "Cleaning up"
                cleanup
                exit 1
            fi
            hashcheck "${file_name}" || return 1
            fancy_message info "Extracting ${file_name}"
            tar -xf "${file_name}" 1>&1 2> /dev/null
            cd ./*/ 2> /dev/null || {
                error_log 1 "install $PACKAGE"
                fancy_message warn "Could not enter into the downloaded archive"
            }
            ;;
    esac
fi

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
    # NOTE: https://stackoverflow.com/a/29163890 (shorthand for 2>&1 |)
    $func |& sudo tee "/var/log/pacstall/error_log/$(date +"%Y-%m-%d_%T")-$name-$func.log" && return "${PIPESTATUS[0]}"
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

for i in {prepare,build,install}; do
    if [[ $(type -t "$i") == function ]]; then
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

if ((NOBUILDDEP == 1)); then
    fancy_message info "Purging build dependencies"
    sudo apt-get purge --auto-remove -y "${not_installed_yet_builddepends[@]}"
fi

cd "$HOME" 2> /dev/null || (
    error_log 1 "install $PACKAGE"
    fancy_message warn "Could not enter into ${HOME}"
)

makedeb

# Metadata writing
log

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
