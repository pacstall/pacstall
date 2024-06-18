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
source "${SCRIPTDIR}/scripts/checks.sh" || {
    fancy_message error "Could not find checks.sh"
    return 1
}

# shellcheck source=./misc/scripts/fetch-sources.sh
source "${SCRIPTDIR}/scripts/fetch-sources.sh" || {
    fancy_message error "Could not find fetch-sources.sh"
    return 1
}

function trap_ctrlc() {
    fancy_message warn "\nInterrupted, cleaning up"
    if is_apt_package_installed "${pacname}"; then
        sudo apt-get purge "${gives:-$pacname}" -y > /dev/null
    fi
    sudo rm -f "/etc/apt/preferences.d/${pacname:-$PACKAGE}-pin"
    cleanup
    exit 1
}

function package_pkg() {
    if [[ -n ${pkgbase} ]]; then
        fancy_message info "Found pkgbase: ${PURPLE}${pkgbase}${NC}"
        if ((${#pkgname[@]} > 1)); then
            # We do this so that arrays 'start at' 1 to the user
            z=1
            echo -e "\t\t[${BIRed}0${NC}] Exit"
            for i in "${pkgname[@]}"; do
                # print optdepends with bold package name
                echo -e "\t\t[${BICyan}$z${NC}] ${BOLD}${i%%:\ *}${NC}"
                ((z++))
            done
            unset z
            # tab over the next line
            echo -ne "\t"
            select_options "Select packages to be built" "${#pkgname[@]}"
            read -ra choices < /tmp/pacstall-select-options
            local choice_inc=0
            for i in "${choices[@]}"; do
                # have we gone over the maximum number in choices[@]?
                if [[ $i != "n" && $i != "y" ]] && ((i > ${#pkgname[@]})); then
                    local skip_opt+=("$i")
                    unset 'choices[$choice_inc]'
                fi
                ((choice_inc++))
            done
            if [[ -n ${skip_opt[*]} ]]; then
                fancy_message warn "${BGreen}${skip_opt[*]}${NC} has exceeded the maximum number of packages to build. Skipping"
            fi

            # Did we get actual answers?
            if [[ ${choices[0]} != "n" && ${choices[0]} != "0" ]]; then
                for i in "${choices[@]}"; do
                    # Set our user array that started at 1 down to 0 based
                    local pacnames+=("${pkgname[$((i - 1))]}")
                done
                if [[ -n ${pacnames[*]} ]]; then
                    fancy_message info "Selecting packages ${BCyan}${pacnames[*]%%:\ *}${NC}"
                    for pacname in "${pacnames[@]}"; do
                        fancy_message info "Packaging ${GREEN}${pacname}${NC}"
                        # shellcheck source=./misc/scripts/package.sh
                        if ! source "$SCRIPTDIR/scripts/package.sh"; then
                            fancy_message error "Failed to install ${GREEN}${pacname}${NC}"
                            if ! [[ -f "/tmp/pacstall-pacdeps-${pacname}" ]]; then
                                sudo rm -rf "${PACDIR:?}"
                            fi
                            exit 1
                        fi
                    done
                fi
            fi
            fancy_message info "Cleaning up"
            cleanup
            exit 0
        fi
    else
        pacname="${pkgname}"
        # shellcheck source=./misc/scripts/package.sh
        if ! source "$SCRIPTDIR/scripts/package.sh"; then
            fancy_message error "Failed to install ${GREEN}${pacname}${NC}"
            if ! [[ -f "/tmp/pacstall-pacdeps-${pacname}" ]]; then
                sudo rm -rf "${PACDIR:?}"
            fi
            exit 1
        fi
    fi

    if is_apt_package_installed "${PACKAGE}-dummy-builddeps"; then
        sudo apt-get purge "${PACKAGE}-dummy-builddeps" -y > /dev/null
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
case ${CARCH} in
    i386) AARCH='i686' ;;
    armhf) AARCH='armv7h' ;;
    *) AARCH="${HOSTTYPE}" ;;
esac
export AARCH
export DISTRO="$(set_distro)"

# Running source on an isolated env
safe_source "${pacfile}"
if ! source "${safeenv}"; then
    fancy_message error "Could not source pacscript"
    error_log 12 "install $PACKAGE"
    clean_fail_down
fi

package_pkg

# vim:set ft=sh ts=4 sw=4 et: