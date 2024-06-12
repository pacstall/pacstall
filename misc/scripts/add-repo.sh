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

parse_repo() {
    local ADDR
    IFS=':' read -ra ADDR <<< "$1"
    PROV="${ADDR[0]}"
    USER=$(echo "${ADDR[1]}" | cut -d'/' -f1)
    HEAD=$(echo "${ADDR[1]}" | cut -d'/' -f2 | cut -d'#' -f1)
    if [[ ${ADDR[1]} =~ "#" ]]; then
        BRANCH="$(echo "${ADDR[1]}" | cut -d'#' -f2)"
    else
        BRANCH="master"
        fancy_message warn "Assuming that git branch is ${GREEN}master${NC}"
    fi
}

REPO="${2%/}"

case ${REPO} in
    *"github.com"*)
        REPO="${REPO/'github.com'/'raw.githubusercontent.com'}"
        if [[ $REPO != *"/tree/"* ]]; then
            REPO="$REPO/master"
            fancy_message warn "Assuming that git branch is ${GREEN}master${NC}"
        else
            REPO="${REPO/'/tree/'/'/'}"
        fi
        ;;
    *"gitlab.com"*)
        if [[ $REPO != *"/tree/"* ]]; then
            REPO="$REPO/-/raw/master"
            fancy_message warn "Assuming that git branch is ${GREEN}master${NC}"
        else
            REPO="${REPO/"/tree/"/"/raw/"}"
        fi
        ;;
    *"github:"*)
        parse_repo "${REPO}"
        REPO="https://raw.${PROV}usercontent.com/${USER}/${HEAD}/${BRANCH}"
        ;;
    *"gitlab:"*)
        parse_repo "${REPO}"
        REPO="https://${PROV}.com/${USER}/${HEAD}/-/raw/${BRANCH}"
        ;;
    *)
        [[ ${REPO} == "local:"* ]] && REPO="file://${REPO/local:/}"
        if [[ -d $REPO ]] > /dev/null; then
            if [[ $REPO != *"file://"* ]]; then
                REPO="file://$(readlink -f "$REPO")"
            fi
        fi
        ;;
esac

case ${REPOCMD} in
    add)
        ask "Do you want to add ${CYAN}${REPO}${NC} to the repo list?" Y
        if ((answer == 0)); then
            exit 3
        fi
        if ! curl --head --location -s --fail -- "$REPO/packagelist" > /dev/null; then
            fancy_message warn "If the URL is a private repo, edit ${CYAN}\e]8;;file://$SCRIPTDIR/repo/pacstallrepo\a$SCRIPTDIR/repo/pacstallrepo\e]8;;\a${NC}"
            fancy_message error "packagelist file not found"
            exit 3
        fi
        REPOLIST=()
        while IFS= read -r REPOURL; do
            REPOLIST+=("${REPOURL}")
        done < "$SCRIPTDIR/repo/pacstallrepo"
        REPOLIST+=("$REPO")
        ;;
    remove)
        ask "Do you want to remove ${CYAN}${REPO}${NC} from the repo list?" Y
        if ((answer == 0)); then
            exit 3
        fi
        REPOLIST=()
        while IFS= read -r REPOURL; do
            [[ ${REPOURL} != "$REPO" ]] && REPOLIST+=("${REPOURL}")
        done < "$SCRIPTDIR/repo/pacstallrepo"
        ;;
esac

printf "%s\n" "${REPOLIST[@]}" | sort -u | sudo tee "$SCRIPTDIR/repo/pacstallrepo" > /dev/null
fancy_message info "The repo list has been updated"
# vim:set ft=sh ts=4 sw=4 et:
