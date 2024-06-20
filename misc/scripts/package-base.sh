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
    # shellcheck disable=SC2031
    if is_apt_package_installed "${pacname}"; then
        # shellcheck disable=SC2031
        sudo apt-get purge "${gives:-$pacname}" -y > /dev/null
    fi
    # shellcheck disable=SC2031
    sudo rm -f "/etc/apt/preferences.d/${pacname:-$PACKAGE}-pin"
    cleanup
    exit 1
}

function package_override() {
    local o
    # variables
    for o in "gives" "pkgdesc" "url" "priority"; do
        local look lbase
        # shellcheck disable=SC2034
        local -n over="${o}"
        # check for override
        look="$(srcinfo.match_pkg "${srcinfile}" "${o}" "${pacname}")"
        if [[ -n ${look} ]]; then
            # shellcheck disable=SC2034
            over="${look}"
        else
            # fall back to pkgbase def
            lbase="$(srcinfo.match_pkg "${srcinfile}" "${o}" "pkgbase:${pkgbase}")"
            # shellcheck disable=SC2034
            [[ -n ${lbase} ]] && over="${lbase}"
        fi
        # shellcheck disable=SC2163
        export "${o}"
    done
    # arrays
    for o in "arch" "license" "checkdepends" "optdepends" "pacdeps" "provides" "conflicts" "breaks" "replaces" "enhances" "recommends" "backup"; do
        local look lbase
        # shellcheck disable=SC2034
        local -n over="${o}"
        mapfile -t look < <(srcinfo.match_pkg "${srcinfile}" "${o}" "${pacname}")
        # check for override
        if [[ -n ${look[*]} ]]; then
            # shellcheck disable=SC2034
            over=("${look[@]}")
        else
            # fall back to pkgbase def
            mapfile -t lbase < <(srcinfo.match_pkg "${srcinfile}" "${o}" "pkgbase:${pkgbase}")
            # shellcheck disable=SC2034
            [[ -n ${lbase[*]} ]] && over=("${lbase[@]}")
        fi
        # shellcheck disable=SC2163
        export "${o}"
    done
}

function package_pkg() {
    # shellcheck disable=SC2031
    if [[ -n ${pkgbase} ]]; then
        # shellcheck disable=SC2031
        fancy_message info "Found pkgbase: ${PURPLE}${pkgbase}${NC}"
        if ((${#pkgname[@]} > 1)); then
            if [[ -z ${CHILD} ]]; then
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
                        local skip_pkg+=("$i")
                        unset 'choices[$choice_inc]'
                    fi
                    ((choice_inc++))
                done
                if [[ -n ${skip_pkg[*]} ]]; then
                    fancy_message warn "${BGreen}${skip_pkg[*]}${NC} has exceeded the maximum number of packages to build. Skipping"
                fi
            fi
            # Did we get actual answers?
            if [[ ${choices[0]} != "n" && ${choices[0]} != "0" ]] || [[ -n ${CHILD} ]]; then
                local pacnames
                if [[ -n ${CHILD} ]]; then
                    pacnames=("${CHILD}")
                else
                    for i in "${choices[@]}"; do
                        # Set our user array that started at 1 down to 0 based
                        pacnames+=("${pkgname[$((i - 1))]}")
                    done
                fi
                if [[ -n ${pacnames[*]} ]]; then
                    fancy_message info "Selecting packages ${BCyan}${pacnames[*]%%:\ *}${NC}"
                    for pacname in "${pacnames[@]}"; do
                        # shellcheck disable=SC2031
                        fancy_message info "Packaging ${GREEN}${pacname}${NC}"
                        # shellcheck source=./misc/scripts/package.sh
                        if ! source "$SCRIPTDIR/scripts/package.sh"; then
                            # shellcheck disable=SC2031
                            fancy_message error "Failed to install ${GREEN}${pacname}${NC}"
                            # shellcheck disable=SC2031
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
            return 0
        fi
    else
        pacname="${pkgname}"
        # shellcheck source=./misc/scripts/package.sh
        if ! source "$SCRIPTDIR/scripts/package.sh"; then
            # shellcheck disable=SC2031
            fancy_message error "Failed to install ${GREEN}${pacname}${NC}"
            # shellcheck disable=SC2031
            if ! [[ -f "/tmp/pacstall-pacdeps-${pacname}" ]]; then
                sudo rm -rf "${PACDIR:?}"
            fi
            exit 1
        fi
        fancy_message info "Cleaning up"
        cleanup
        return 0
    fi

    if is_apt_package_installed "${PACKAGE}-dummy-builddeps"; then
        sudo apt-get purge "${PACKAGE}-dummy-builddeps" -y > /dev/null
    fi
}

# NCPU is the core count
if [[ -n $PACSTALL_BUILD_CORES ]]; then
    if [[ $PACSTALL_BUILD_CORES =~ ^[0-9]+$ ]]; then
        function nproc() { echo "${PACSTALL_BUILD_CORES:-1}"; }
        NCPU="${PACSTALL_BUILD_CORES:-1}"
    else
        fancy_message error "${UCyan}PACSTALL_BUILD_CORES${NC} is not an integer. Falling back to 1"
        function nproc() { echo "1"; }
        NCPU="1"
    fi
else
    NCPU="$(nproc)"
fi
export NCPU

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
(srcinfo.print_out "${pacfile}" > "/tmp/${PACKAGE}.SRCINFO")
srcinfile="$(readlink -f "/tmp/${PACKAGE}.SRCINFO")"
export srcinfile
mapfile -t FARCH < <(dpkg --print-foreign-architectures)
CARCH="$(dpkg --print-architecture)"
case ${CARCH} in
    i386) AARCH='i686' ;;
    armhf) AARCH='armv7h' ;;
    *) AARCH="${HOSTTYPE}" ;;
esac
DISTRO="$(set_distro)"
export FARCH CARCH AARCH DISTRO

# Running source on an isolated env
safe_source "${pacfile}"
if ! source "${safeenv}"; then
    fancy_message error "Could not source pacscript"
    error_log 12 "install $PACKAGE"
    clean_fail_down
fi

package_pkg

# vim:set ft=sh ts=4 sw=4 et:
