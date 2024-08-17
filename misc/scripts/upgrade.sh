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

# shellcheck source=./misc/scripts/dep-tree.sh
source "${SCRIPTDIR}/scripts/dep-tree.sh" || {
    fancy_message error $"Could not load dep-tree.sh"
    { ignore_stack=true; return 1; }
}

# shellcheck source=./misc/scripts/fetch-sources.sh
source "${SCRIPTDIR}/scripts/fetch-sources.sh" || {
    fancy_message error $"Could not find fetch-sources.sh"
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

function ver_compare() {
    { ignore_stack=false; set -o pipefail; trap stacktrace ERR RETURN; }
    local first second first_git second_git result
    first="${1#"${1/[0-9]*/}"}"
    second="${2#"${2/[0-9]*/}"}"
    if [[ ${first} =~ "~git" && ${second} =~ "~git" ]]; then
        first_git="${first#*~git}"; first="${first%~git*}"
        second_git="${second#*~git}"; second="${second%~git*}"
    fi
    if [[ -n ${second_git} && ${first_git} != "${second_git}" ]]; then
        result=0
    else
        { dpkg --compare-versions "${first}" lt "${second}"; result=$?; }
    fi
    { ignore_stack=true; return "${result}"; }
}

function calc_repo_ver() {
    { ignore_stack=false; set -o pipefail; trap stacktrace ERR RETURN; }
    local compare_repo="$1" compare_package="$2" compare_tmp compare_safe compare_pkgver compare_pkgrel compare_epoch compare_source comp compare_base
    unset comp_repo_ver
    compare_tmp="$(sudo mktemp -p "${PACDIR}" -t "calc-repo-ver-$compare_package.XXXXXX")"
    compare_safe="${compare_tmp}"
    curl -fsSL "$compare_repo/packages/$compare_package/.SRCINFO" | sudo tee "${compare_safe}" > /dev/null || { ignore_stack=true; return 1; }
    sudo chown "${PACSTALL_USER}" "${compare_safe}"
    compare_base="$(srcinfo.match_pkg "${compare_safe}" pkgbase)"
    for comp in "pkgver" "pkgrel" "epoch"; do
        local -n decomp="compare_${comp}"
        # shellcheck disable=SC2034
        decomp="$(srcinfo.match_pkg "${compare_safe}" "${comp}" "${compare_base}")"
    done
    mapfile -t compare_source < <(srcinfo.match_pkg "${compare_safe}" "source" "${compare_base}")
    if [[ ${compare_package} == *-git ]]; then
        parse_source_entry "${compare_source[0]}"
        calc_git_pkgver
        comp_repo_ver="${compare_epoch:+$compare_epoch:}${compare_pkgver}-pacstall${compare_pkgrel:-1}~git${comp_git_pkgver}"
    else
        comp_repo_ver="${compare_epoch:+$compare_epoch:}${compare_pkgver}-pacstall${compare_pkgrel:-1}"
    fi
    sudo rm -rf "${compare_safe:?}"
}

export UPGRADE="yes"
CARCH="$(dpkg --print-architecture)"
case ${CARCH} in
    i386) AARCH='i686' ;;
    armhf) AARCH='armv7h' ;;
    *) AARCH="${HOSTTYPE}" ;;
esac
DISTRO="$(set_distro parent)"
CDISTRO="$(set_distro)"
export CARCH AARCH DISTRO CDISTRO

fancy_message info $"Checking for updates"

# Get the list of the installed packages
mapfile -t list < <(pacstall -L)
if ((${#list[@]} == 0)); then
    fancy_message info $"Nothing to upgrade"
    return 0
fi
fancy_message sub $"Building dependency tree"
tput civis # Hide cursor
dep_tree.loop_traits update_order "${list[@]}"
tput cnorm # Show cursor again
list=("${update_order[@]}")

mkdir -p "${PACDIR}"
up_list="$(mktemp /tmp/XXXXXX-pacstall-up-list)"
up_print="$(mktemp /tmp/XXXXXX-pacstall-up-print)"
up_urls="$(mktemp /tmp/XXXXXX-pacstall-up-urls)"

fancy_message sub $"Checking versions"

tty_settings=$(stty -g)
N="$(nproc)"
(
    for i in "${list[@]}"; do
        ((n = n % N))
        ((n++ == 0)) && wait && stty "$tty_settings"
        (
            unset _pkgbase
            source "$METADIR/$i"
            if [[ -n ${_pkgbase} ]]; then
                localbase="${_pkgbase}"
            else
                localbase="${i}"
            fi

            # localver is the current version of the package
            localver="${_version}"
            # if localver does not end with the correct pacstall version format, append it
            [[ ! $localver =~ -pacstall[0-9]+$ && ! $localver =~ -pacstall[0-9]+~git[a-zA-Z0-9_-]{8}$ ]] && localver="${localver}-pacstall1"

            case "${_remoterepo}" in
                *"github.com"*)
                    remoterepo="${_remoterepo/'github.com'/'raw.githubusercontent.com'}/${_remotebranch}" ;;
                *"gitlab.com"*)
                    remoterepo="${_remoterepo}/-/raw/${_remotebranch}" ;;
                *"git.sr.ht"*)
                    remoterepo="${_remoterepo}/blob/${_remotebranch}" ;;
                *"codeberg"*)
                    remoterepo="${_remoterepo}/raw/branch/${_remotebranch}" ;;
                *)
                    remoterepo="${_remoterepo}" ;;
            esac
            unset _remoterepo

            # shellcheck source=./misc/scripts/search.sh
            source "$SCRIPTDIR/scripts/search.sh"

            IDXMATCH=$(printf "%s\n" "${REPOS[@]}" | awk "\$1 ~ /^${remoterepo//\//\\/}$/ {print NR-1}")

            if [[ -n $IDXMATCH ]]; then
                calc_repo_ver "$remoterepo" "$localbase" \
                    && remotever="${comp_repo_ver}"
                unset comp_repo_ver
                remoteurl="${REPOS[$IDXMATCH]}"
            else
                parsedrepo="$(repo.parse "${remoterepo}")"
                if [[ ${parsedrepo} =~ "#" ]]; then
                    parsedrepo="${parsedrepo%%#*}${YELLOW}#${parsedrepo##*#}${NC}"
                fi
                if [[ ${remoterepo} != "orphan" ]]; then
                    fancy_message warn $"Package ${GREEN}${i}${NC} is not on ${CYAN}${parsedrepo}${NC} anymore"
                    sudo sed -i 's/_remoterepo=".*"/_remoterepo="orphan"/g' "$METADIR/$i"
                    sudo sed -i '/_remotebranch=/d' "$METADIR/$i"
                fi
                unset parsedrepo
            fi

            if [[ $remotever != "${localver}" ]]; then
                alterver="0.0.0"
                for IDX in "${!REPOS[@]}"; do
                    if [[ -n $IDXMATCH ]] && ((IDX == IDXMATCH)); then
                        continue
                    else
                        calc_repo_ver "${REPOS[$IDX]}" "$localbase" \
                            && ver="${comp_repo_ver}"
                        unset comp_repo_ver
                        if ver_compare "$alterver" "$ver"; then
                            alterver="$ver"
                            alterurl="${REPOS[$IDX]}"
                        else
                            alterurl="$REPO"
                        fi
                    fi
                done
                if [[ -n $remotever ]]; then
                    if ver_compare "$remotever" "$alterver"; then
                        remotever="$alterver"
                        remoteurl="$alterurl"
                    fi
                elif [[ $alterver != "0.0.0" ]]; then
                    remotever="$alterver"
                    remoteurl="$alterurl"
                fi
            else
                return
            fi

            if [[ -n $remotever ]]; then
                if ver_compare "$localver" "$remotever"; then
                    if [[ -n ${_pkgbase} ]]; then
                        echo "${_pkgbase}:${i}" | tee -a "${up_list}" > /dev/null
                    else
                        echo "$i" | tee -a "${up_list}" > /dev/null
                    fi
                    updaterepo="$(repo.parse "${remoteurl}")"
                    if [[ ${updaterepo} =~ "#" ]]; then
                        updaterepo="${updaterepo%%#*}${YELLOW}#${updaterepo##*#}${NC}"
                    fi
                    printf "\t%s%s%s @ %s%s%s ( %s%s%s -> %s%s%s )\n" \
                        "${GREEN}" "${i}" "${PURPLE}" "${CYAN}" "${updaterepo}" "${NC}" "${BLUE}" "${localver:-unknown}" "${NC}" "${BLUE}" "${remotever:-unknown}" "${NC}" | tee -a "${up_print}" > /dev/null
                    echo "$remoteurl" | tee -a "${up_urls}" > /dev/null
                    unset updaterepo
                fi
            fi
        ) &
    done
    wait && stty "$tty_settings"
)

if [[ ! -s ${up_list} ]]; then
    fancy_message info $"Nothing to upgrade"
else
    echo
    fancy_message info $"Packages can be upgraded"
    echo -e "Upgradable: $(wc -l < "${up_print}")
${BOLD}$(cat "${up_print}")${NC}\n"

    declare -A remotes=()
    declare -A bases=()
    while read -r pkg && read -r remote <&3; do
        upgrade+=("${pkg#*:}")
        remotes[${pkg#*:}]="${remote}"
        [[ ${pkg} =~ ':' ]] && bases[${pkg#*:}]="${pkg%:*}"
    done < "${up_list}" 3< "${up_urls}"

    dep_tree.loop_traits update_order "${upgrade[@]}"
    dep_tree.trim_pacdeps update_order
    upgrade=("${update_order[@]}")

    export local='no'
    if ! cd "$PACDIR" 2> /dev/null; then
        error_log 1 "upgrade"
        fancy_message error $"Could not enter ${PACDIR}"
        exit 1
    fi
    for to_upgrade in "${upgrade[@]}"; do
        PACKAGE="${to_upgrade}"
        ask "Do you want to upgrade ${GREEN}${PACKAGE}${NC}?" Y
        if ((answer == 0)); then
            continue
        fi

        export REPO="${remotes[${PACKAGE}]}"
        if [[ -n ${bases[$PACKAGE]} ]]; then
            CHILD="${PACKAGE}"
            PACKAGE="${bases[$PACKAGE]}"
            export CHILD PACKAGE
        fi
        export URL="$REPO/packages/$PACKAGE/$PACKAGE.pacscript"
        # shellcheck source=./misc/scripts/get-pacscript.sh
        if ! source "$SCRIPTDIR/scripts/get-pacscript.sh"; then
            fancy_message error $"Failed to download the ${GREEN}${PACKAGE}${NC} pacscript"
            continue
        fi
        # shellcheck source=./misc/scripts/package-base.sh
        source "$SCRIPTDIR/scripts/package-base.sh"
    done
fi

rm -f "${up_list:?}" "${up_print:?}" "${up_urls:?}"
# vim:set ft=sh ts=4 sw=4 et:
