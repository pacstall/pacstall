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

function ver_compare() {
    local first second
    first="${1#${1/[0-9]*/}}"
    second="${2#${2/[0-9]*/}}"
    return $(dpkg --compare-versions "$first" lt "$second")
}

export UPGRADE="yes"

# Get the list of the installed packages
mapfile -t list < <(pacstall -L)
up_list="$(mktemp /tmp/XXXXXX-pacstall-up-list)"
up_print="$(mktemp /tmp/XXXXXX-pacstall-up-print)"
up_urls="$(mktemp /tmp/XXXXXX-pacstall-up-urls)"

fancy_message info "Checking for updates"

N="$(nproc)"
(
    for i in "${list[@]}"; do
        ((n = n % N))
        ((n++ == 0)) && wait
        (
            source "$LOGDIR/$i"

            # localver is the current version of the package
            localver="${_version}"

            if [[ -z ${_remoterepo} ]]; then
                # TODO: upgrade for local pacscripts
                return
            elif [[ ${_remoterepo} == *"github.com"* ]]; then
                remoterepo="${_remoterepo/'github.com'/'raw.githubusercontent.com'}/${_remotebranch}"
            elif [[ ${_remoterepo} == *"gitlab.com"* ]]; then
                remoterepo="${_remoterepo}/-/raw/${_remotebranch}"
            else
                remoterepo="${_remoterepo}"
            fi

            unset _remoterepo

            # shellcheck source=./misc/scripts/search.sh
            source "$STGDIR/scripts/search.sh"

            IDXMATCH=$(printf "%s\n" "${REPOS[@]}" | awk "\$1 ~ /^${remoterepo//\//\\/}$/ {print NR-1}")

            if [[ -n $IDXMATCH ]]; then
                remotever=$(source <(curl -s -- "$remoterepo/packages/$i/$i.pacscript") && type pkgver &> /dev/null && pkgver || echo "${epoch:+$epoch:}$version") > /dev/null
                remoteurl="${REPOS[$IDXMATCH]}"
            else
                fancy_message warn "Package ${GREEN}${i}${CYAN} is not on ${CYAN}$(parseRepo "${remoterepo}")${NC} anymore"
                sudo sed -i "/_remote/d" "$LOGDIR/$i"
            fi

            if [[ $i != *"-git" ]]; then
                alterver="0.0.0"
                for IDX in "${!REPOS[@]}"; do
                    if [[ $IDX -eq $IDXMATCH ]]; then
                        continue
                    else
                        ver=$(source <(curl -s -- "${REPOS[$IDX]}"/packages/"$i"/"$i".pacscript) && type pkgver &> /dev/null && pkgver || echo "${epoch:+$epoch:}$version") > /dev/null
                        if ! ver_compare "$alterver" "$ver"; then
                            alterver="$ver"
                            alterurl="$REPO"
                        fi
                    fi
                done
                if [[ -n $remotever ]]; then
                    if ver_compare "$remotever" "$alterver"; then
                        echo -e "${GREEN}${i}${CYAN} has a newer version at ${CYAN}$(parseRepo "${alterurl}")${NC}."
                        ask "Keep the package from the current repo?" Y
                        if [[ $answer -eq 0 ]]; then
                            remoterepo="$alterver"
                            remoteurl="$alterurl"
                        fi
                    fi
                elif [[ $alterver != "0.0.0" ]]; then
                    remoterepo="$alterver"
                    remoteurl="$alterurl"
                fi
                # If the remote version equals the local version minus the first character (0) or they both equal the same
            elif [[ $remotever == "${localver:1}" ]] || [[ $remotever == "$localver" ]]; then
                return
            fi

            if [[ -n $remotever ]]; then
                if [[ $i == *"-git" ]] || ver_compare "$localver" "$remotever"; then
                    echo "$i" | tee -a "${up_list}" > /dev/null
                    echo "\t${GREEN}${i}${CYAN} @ $(parseRepo "${remoteurl}")${NC} ( ${BLUE}${localver:-unknown}${NC} -> ${BLUE}${remotever:-unknown}${NC} )" | tee -a "${up_print}" > /dev/null
                    echo "$remoteurl" | tee -a "${up_urls}" > /dev/null
                fi
            fi
        ) &
    done
    wait
)

if [[ $(wc -l < "${up_list}") -eq 0 ]]; then
    fancy_message info "Nothing to upgrade"
else
    fancy_message info "Packages can be upgraded"
    echo -e "Upgradable: $(wc -l < "${up_print}")
${BOLD}$(cat "${up_print}")${NORMAL}\n"

    upgrade=()
    while IFS= read -r line; do
        upgrade+=("$line")
    done < "${up_list}"

    while IFS= read -r line; do
        remotes+=("$line")
    done < "${up_urls}"

    export local='no'
    mkdir -p "$SRCDIR"
    if ! cd "$SRCDIR" 2> /dev/null; then
        error_log 1 "upgrade"
        fancy_message error "Could not enter ${SRCDIR}"
        exit 1
    fi
    for i in "${!upgrade[@]}"; do
        PACKAGE=${upgrade[$i]}
        ask "Do you want to upgrade ${GREEN}${PACKAGE}${NC}?" Y
        if [[ $answer -eq 0 ]]; then
            continue
        fi
        REPO="${remotes[$i]}"
        export URL="$REPO/packages/$PACKAGE/$PACKAGE.pacscript"
        # shellcheck source=./misc/scripts/download.sh
        if ! source "$STGDIR/scripts/download.sh"; then
            fancy_message error "Failed to download the ${GREEN}${PACKAGE}${NC} pacscript"
            continue
        fi
        # shellcheck source=./misc/scripts/install-local.sh
        source "$STGDIR/scripts/install-local.sh"
    done
fi

rm -f "${up_list}" "${up_print}" "${up_urls}"
# vim:set ft=sh ts=4 sw=4 noet:
