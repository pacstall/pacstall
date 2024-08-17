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

# shellcheck source=./misc/scripts/manage-repo.sh
source "${SCRIPTDIR}/scripts/manage-repo.sh" || {
    fancy_message error $"Could not find manage-repo.sh"
    # shellcheck disable=SC2034
    { ignore_stack=true; return 1; }
}

case ${REPO} in
    *"github.com"*)
        REPO="${REPO/'github.com'/'raw.githubusercontent.com'}"
        if [[ $REPO != *"/tree/"* ]]; then
            REPO="$REPO/master"
            fancy_message warn $"Assuming that git branch is ${GREEN}master${NC}"
        else
            REPO="${REPO/'/tree/'/'/'}"
        fi
        ;;
    *"gitlab.com"*)
        if [[ $REPO != *"/tree/"* ]]; then
            REPO="$REPO/-/raw/master"
            fancy_message warn $"Assuming that git branch is ${GREEN}master${NC}"
        else
            REPO="${REPO/"/tree/"/"/raw/"}"
        fi
        ;;
    *"git.sr.ht"*)
        if [[ $REPO != *"/tree/"* ]]; then
            REPO="${REPO%/tree*}/blob/master"
            fancy_message warn $"Assuming that git branch is ${GREEN}master${NC}"
        else
            REPO="${REPO/"/tree/"/"/blob/"}"
        fi
        ;;
    *"codeberg.org"*)
        if [[ $REPO != *"/src/branch/"* ]]; then
            REPO="$REPO/raw/branch/master"
            fancy_message warn $"Assuming that git branch is ${GREEN}master${NC}"
        else
            REPO="${REPO/"/src/branch/"/"/raw/branch/"}"
        fi
        ;;
    *"github:"*|*"gitlab:"*|*"sourcehut:"*|*"codeberg:"*)
        if ! [[ "${REPO}" =~ "#" ]]; then
            fancy_message warn $"Assuming that git branch is ${GREEN}master${NC}"
        fi
        REPO="$(repo.from_metalink "${REPO}")"
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
        mapfile -t aliaslist < <(repo.get_all_type alias)
        mapfile -t urllist < <(repo.get_all_type url)
        if [[ -n ${ALIAS} ]]; then
            if [[ ${ALIAS} == "none" ]]; then
                fancy_message error $"Repository alias cannot be 'none'"
                exit 1
            elif [[ ${ALIAS} =~ "://" ]]; then
                fancy_message error $"Repository alias cannot be a hyperlink"
                exit 1
            elif [[ ${ALIAS} == "/"* || ${ALIAS} == "~"* || ${ALIAS} == "."* ]]; then
                fancy_message error $"Repository alias cannot start with '/', '~', or '.'"
                exit 1
            elif array.contains aliaslist "${ALIAS}"; then
                fancy_message error $"The alias ${RED}@${ALIAS}${NC} is already in use by ${CYAN}$(repo.get_where alias "${ALIAS}")${NC}"
                exit 1
            fi
        fi
        if array.contains urllist "${REPO}"; then
            fancy_message warn $"${CYAN}${REPO}${NC} is already in the repo list, doing nothing${NC}"
            exit 0
        fi
        ask "Do you want to add ${CYAN}${REPO}${NC}${ALIAS:+ ${BLUE}@${ALIAS}${NC}} to the repo list?" Y
        if ((answer == 0)); then
            exit 3
        fi
        if ! curl --head --location -s --fail -- "$REPO/packagelist" > /dev/null; then
            fancy_message warn $"If the URL is a private repo, edit ${CYAN}\e]8;;file://$SCRIPTDIR/repo/pacstallrepo\a$SCRIPTDIR/repo/pacstallrepo\e]8;;\a${NC}"
            fancy_message error $"packagelist file not found"
            exit 3
        fi
        REPOLIST=()
        while IFS= read -r REPOURL; do
            REPOLIST+=("${REPOURL}")
        done < "$SCRIPTDIR/repo/pacstallrepo"
        REPOLIST+=("${REPO}${ALIAS:+ @$ALIAS}")
        ;;
    remove)
        if [[ ${REPO} == "@"* || -z ${ALIAS} ]]; then
            # shellcheck disable=SC2034
            mapfile -t aliaslist < <(repo.get_all_type alias)
            mapfile -t urllist < <(repo.get_all_type url)
            if array.contains aliaslist "${REPO#*@}"; then
                ALIAS="${REPO#*@}"
                REPO="$(repo.get_where alias "${ALIAS}")"
            else
                for i in "${!urllist[@]}"; do
                    if [[ ${urllist[i]} == "${REPO}" ]]; then
                        ALIAS="${aliaslist[i]}"
                        if [[ ${ALIAS} == "none" ]]; then
                            unset ALIAS
                        fi
                        break
                    fi
                done
            fi
        fi
        ask "Do you want to remove ${CYAN}${REPO}${NC}${ALIAS:+ ${BLUE}@${ALIAS}${NC}} from the repo list?" Y
        if ((answer == 0)); then
            exit 3
        fi
        REPOLIST=()
        while IFS= read -r REPOURL; do
            [[ ${REPOURL} != "${REPO}${ALIAS:+ @$ALIAS}" ]] && REPOLIST+=("${REPOURL}")
        done < "$SCRIPTDIR/repo/pacstallrepo"
        ;;
esac

printf "%s\n" "${REPOLIST[@]}" | sort -u | sudo tee "$SCRIPTDIR/repo/pacstallrepo" > /dev/null
fancy_message info $"The repo list has been updated"
# vim:set ft=sh ts=4 sw=4 et:
