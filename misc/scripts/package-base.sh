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

# shellcheck source=./misc/scripts/checks.sh
source "${SCRIPTDIR}/scripts/checks.sh" || {
    fancy_message error $"Could not find checks.sh"
    { ignore_stack=true; return 1; }
}

# shellcheck source=./misc/scripts/fetch-sources.sh
source "${SCRIPTDIR}/scripts/fetch-sources.sh" || {
    fancy_message error $"Could not find fetch-sources.sh"
    { ignore_stack=true; return 1; }
}

function trap_ctrlc() {
    { ignore_stack=false; set -o pipefail; trap stacktrace ERR RETURN; }
    fancy_message warn $"\nInterrupted, cleaning up"
    # shellcheck disable=SC2031
    if is_apt_package_installed "${pacname}"; then
        # shellcheck disable=SC2031
        sudo apt-get purge "${gives:-$pacname}" -y > /dev/null
    fi
    # shellcheck disable=SC2031
    true_pkg="${pacname:-$PACKAGE}"
    sudo rm -f "/etc/apt/preferences.d/${true_pkg//./-}-pin"
    cleanup
    exit 1
}

function package_override() {
    { ignore_stack=false; set -o pipefail; trap stacktrace ERR RETURN; }
    # shellcheck disable=SC2031
    local o all_ovars opac="${pacname}" obase="${pkgbase}" ovars=("gives" "pkgdesc" "url" "priority")
    all_ovars=("${ovars[@]}" "arch" "license" "depends" "checkdepends" "optdepends" "pacdeps" "provides" "checkconflicts" "conflicts" "breaks" "replaces" "enhances" "recommends" "suggests" "backup" "repology")
    for o in "${all_ovars[@]}"; do
        local look lbase
        # shellcheck disable=SC2034
        local -n over="${o}"
        mapfile -t look < <(unset "${pacstallvars[@]}" && srcinfo.match_pkg "${srcinfile}" "${o}" "${opac}")
        if [[ -n ${look[*]} ]]; then
            if array.contains ovars "${o}"; then
                # shellcheck disable=SC2178,SC2034
                over="${look}"
            else
                # shellcheck disable=SC2034
                over=("${look[@]}")
            fi
        else
            mapfile -t lbase < <(unset "${pacstallvars[@]}" && srcinfo.match_pkg "${srcinfile}" "${o}" "pkgbase:${obase}")
            if [[ -n ${lbase[*]} ]]; then
                if array.contains ovars "${o}"; then
                    # shellcheck disable=SC2178,SC2034
                    over="${lbase}"
                else
                    # shellcheck disable=SC2034
                    over=("${lbase[@]}")
                fi
            fi
        fi
    done
}

function package_pkg() {
    { ignore_stack=false; set -o pipefail; trap stacktrace ERR RETURN; }
    # shellcheck disable=SC2031
    if [[ -n ${pkgbase} ]]; then
        # shellcheck disable=SC2031
        fancy_message info $"Found pkgbase: ${PURPLE}${pkgbase}${NC}"
        if ((${#pkgname[@]} > 1)); then
            if [[ -z ${CHILD} || ${CHILD} == "pkgbase" ]]; then
                # We do this so that arrays 'start at' 1 to the user
                z=1
                echo -e "\t\t[${BIRed}0${NC}] Exit"
                for i in "${pkgname[@]}"; do
                    # print optdepends with bold package name
                    echo -e "\t\t[${BICyan}$z${NC}] ${BOLD}${i%%:\ *}${NC}"
                    { ignore_stack=true; ((z++)); }
                done
                unset z
                # tab over the next line
                echo -ne "\t"
                select_options "Select packages to be built" "${#pkgname[@]}" "pkgbase"
                read -ra choices < "${PACDIR}-selectopts-pkgbase-${pkgbase}"
                local choice_inc=0
                for i in "${choices[@]}"; do
                    # have we gone over the maximum number in choices[@]?
                    if [[ $i != "n" && $i != "y" ]] && ((i > ${#pkgname[@]})); then
                        local skip_pkg+=("$i")
                        unset 'choices[$choice_inc]'
                    fi
                    { ignore_stack=true; ((choice_inc++)); }
                done
                if [[ -n ${skip_pkg[*]} ]]; then
                    fancy_message warn $"${BGreen}${skip_pkg[*]}${NC} has exceeded the maximum number of packages to build. Skipping"
                fi
            fi
            # Did we get actual answers?
            if [[ ${choices[0]} != "n" && ${choices[0]} != "0" ]] || [[ -n ${CHILD} ]]; then
                local pacnames
                if [[ -n ${CHILD} && ${CHILD} != "pkgbase" ]]; then
                    if array.contains pkgname "${CHILD}"; then
                        pacnames=("${CHILD}")
                    else
                        fancy_message error $"${PKGPATH:+${PKGPATH}/}${PACKAGE}${PKGPATH:+.pacscript}:${CHILD} does not exist"
                        cleanup
                        exit 1
                    fi
                else
                    for i in "${choices[@]}"; do
                        # Set our user array that started at 1 down to 0 based
                        pacnames+=("${pkgname[$((i - 1))]}")
                    done
                fi
                if [[ -n ${pacnames[*]} ]]; then
                    fancy_message info $"Selecting packages ${BCyan}${pacnames[*]%%:\ *}${NC}"
                    for pacname in "${pacnames[@]}"; do
                        package_override
                        # shellcheck disable=SC2031
                        fancy_message info $"Packaging ${GREEN}${pacname}${NC}"
                        # shellcheck source=./misc/scripts/package.sh
                        if ! source "$SCRIPTDIR/scripts/package.sh"; then
                            # shellcheck disable=SC2031
                            fancy_message error $"Failed to install ${GREEN}${pacname}${NC}"
                            # shellcheck disable=SC2031
                            if ! [[ -f "${PACDIR}-pacdeps-${pacname}" ]]; then
                                sudo rm -rf "${PACDIR:?}"
                            fi
                            exit 1
                        fi
                    done
                fi
            fi
            fancy_message info $"Cleaning up"
            if is_apt_package_installed "${PACKAGE}-dummy-builddeps"; then
                sudo apt-get purge "${PACKAGE}-dummy-builddeps" -y > /dev/null
            fi
            cleanup
            return 0
        fi
    else
        pacname="${pkgname}"
        # shellcheck source=./misc/scripts/package.sh
        if ! source "$SCRIPTDIR/scripts/package.sh"; then
            # shellcheck disable=SC2031
            fancy_message error $"Failed to install ${GREEN}${pacname}${NC}"
            # shellcheck disable=SC2031
            if ! [[ -f "${PACDIR}-pacdeps-${pacname}" ]]; then
                sudo rm -rf "${PACDIR:?}"
            fi
            exit 1
        fi
        fancy_message info $"Cleaning up"
        if is_apt_package_installed "${PACKAGE}-dummy-builddeps"; then
            sudo apt-get purge "${PACKAGE}-dummy-builddeps" -y > /dev/null
        fi
        cleanup
        return 0
    fi
}

# NCPU is the core count
if [[ -n $PACSTALL_BUILD_CORES ]]; then
    if [[ $PACSTALL_BUILD_CORES =~ ^[0-9]+$ ]]; then
        function nproc() { echo "${PACSTALL_BUILD_CORES:-1}"; }
        NCPU="${PACSTALL_BUILD_CORES:-1}"
    else
        fancy_message error $"${UCyan}PACSTALL_BUILD_CORES${NC} is not an integer. Falling back to 1"
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
        fancy_message warn $"Editor not found, falling back to 'sensible-editor'"
        sensible-editor "$PACKAGE".pacscript
    }
fi

fancy_message info $"Sourcing pacscript"
DIR="$PWD"
homedir="$(eval echo ~"$PACSTALL_USER")"
export homedir

sudo cp "${PACKAGE}.pacscript" /tmp
sudo chmod a+r "/tmp/${PACKAGE}.pacscript"
pacfile="$(readlink -f "/tmp/${PACKAGE}.pacscript")"
export pacfile
mapfile -t FARCH < <(dpkg --print-foreign-architectures)
CARCH="$(dpkg --print-architecture)"
case ${CARCH} in
    i386) AARCH='i686' ;;
    armhf) AARCH='armv7h' ;;
    *) AARCH="${HOSTTYPE}" ;;
esac
DISTRO="$(set_distro parent)"
CDISTRO="$(set_distro)"
export FARCH CARCH AARCH DISTRO CDISTRO

# Running source on an isolated env
safe_source "${pacfile}"
if ! source "${safeenv}"; then
    fancy_message error $"Could not source pacscript"
    error_log 12 "install $PACKAGE"
    clean_fail_down
fi
srcinfo.print_out > "/tmp/${PACKAGE}.SRCINFO"
srcinfile="$(readlink -f "/tmp/${PACKAGE}.SRCINFO")"
export srcinfile

package_pkg

# vim:set ft=sh ts=4 sw=4 et:
