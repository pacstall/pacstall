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

# This script searches for packages in all repos saved on pacstallrepo

if [[ -n $UPGRADE ]]; then
    PACKAGE="$i"
fi

function getPath() {
    local path="${1}"
    local var="${2}"
    path="${path/"file://"/}"
    path="${path/"~"/"$HOME"}"
    path="$(realpath "${path}")"
    path="${path/"$HOME"/"~"}"
    printf -v "${var}" "%s" "${path}"
}

function specifyRepo() {
    local SPLIT
    mapfile -t SPLIT <<< "${1//[\/]/$'\n'}"

    if [[ $1 == "file://"* ]] || [[ $1 == "/"* ]] || [[ $1 == "~"* ]] || [[ $1 == "."* ]]; then
        export URLNAME
        getPath "${1}" URLNAME
    elif [[ $1 == "github:"* ]] || [[ $1 == "gitlab:"* ]]; then
        export URLNAME="${1}"
    elif [[ $1 == *"github"* ]]; then
        export URLNAME="github:${SPLIT[-3]}/${SPLIT[-2]}"
    elif [[ $1 == *"gitlab"* ]]; then
        export URLNAME="gitlab:${SPLIT[-4]}/${SPLIT[-3]}"
    else
        export URLNAME="$REPO"
    fi

}

# Parses github and gitlab URL's
# url -> maintainer/repo
# Also adds hyperlink for the
# terminals that support them
function parseRepo() {
    local REPO="${1}"
    local SPLIT REPODIR
    mapfile -t SPLIT <<< "${REPO//[\/]/$'\n'}"

    if [[ $REPO == "file://"* ]]; then
        getPath "${REPO}" REPODIR
        echo "\e]8;;$REPO\a$REPODIR\e]8;;\a"
    elif [[ $REPO == *"github"* ]]; then
        echo -e "\e]8;;https://github.com/${SPLIT[-3]}/${SPLIT[-2]}\agithub:${SPLIT[-3]}/${SPLIT[-2]}\e]8;;\a"
    elif [[ $REPO == *"gitlab"* ]]; then
        echo -e "\e]8;;https://gitlab.com/${SPLIT[-4]}/${SPLIT[-3]}\agitlab:${SPLIT[-4]}/${SPLIT[-3]}\e]8;;\a"
    else
        echo "\e]8;;$REPO\a$REPO\e]8;;\a"
    fi
}

function formatRepo() {
    ! [[ $1 =~ ^\ *# ]] \
        && [[ $1 =~ ^([^[:space:]]+)([[:space:]]+#.*)?$ ]] \
        && echo "${BASH_REMATCH[1]}"
}

# Repo specific search
if [[ $SEARCH == *@* ]] || [[ $PACKAGE == *@* ]]; then
    if [[ -n $SEARCH ]]; then
        REPONAME=${SEARCH#*@}
        SEARCH=${SEARCH%%@*}
    else
        REPONAME=${PACKAGE#*@}
        PACKAGE=${PACKAGE%%@*}
    fi
    if [[ $REPONAME == "file://"* ]] || [[ $REPONAME == "/"* ]] || [[ $REPONAME == "~"* ]] || [[ $REPONAME == "."* ]]; then
        getPath "${REPONAME}" REPONAME
    else
        specifyRepo "$REPONAME"
        REPONAME="$URLNAME"
    fi

    while IFS= read -r URL; do
        specifyRepo "$URL"
        if [[ $URLNAME == "$REPONAME" ]]; then
            mapfile -t PACKAGELIST < <(curl -s -- "$URL"/packagelist)
            if [[ -n $SEARCH ]]; then
                IDXSEARCH=$(printf "%s\n" "${PACKAGELIST[@]}" | awk "\$1 ~ /${SEARCH}/ {print NR-1}")
            else
                IDXSEARCH=$(printf "%s\n" "${PACKAGELIST[@]}" | awk "\$1 ~ /^${PACKAGE}$/ {print NR-1}")
            fi
            _LEN=($IDXSEARCH)
            LEN=${#_LEN[@]}
            if ((LEN == 0)); then
                if [[ -n $SEARCH ]]; then
                    fancy_message warn "There is no package with the name $IRed${SEARCH%%@*}$NC in the repo $CYAN$REPONAME$NC"
                else
                    fancy_message warn "There is no package with the name $IRed${PACKAGE%%@*}$NC in the repo $CYAN$REPONAME$NC"
                fi
                error_log 3 "search $PACKAGE@$REPONAME"
                exit 1
            fi
            if [[ -n $SEARCH ]]; then
                echo -e "$GREEN${PACKAGELIST[$IDXSEARCH]} $PURPLE@ $CYAN$(parseRepo "$URL") $NC"
            else
                export PACKAGE
                export REPO="$URL"
            fi
            return 0
        fi
    done < "$SCRIPTDIR/repo/pacstallrepo"

    fancy_message warn "$IRed$REPONAME$NC is not on your repo list or does not exist"
    error_log 3 "search $PACKAGE@$REPONAME"
    exit 1
fi

# Makes array of packages and array
# of their respective URL's
PACKAGELIST=()
URLLIST=()
while IFS= read -r URL; do
    if [[ ${URL} == "/"* ]] || [[ ${URL} == "~"* ]] || [[ ${URL} == "."* ]]; then
        sed -i "s#${URL}#file://$(readlink -f ${URL})#g" "$SCRIPTDIR/repo/pacstallrepo" 2> /dev/null \
            || fancy_message warn "Add \"file://\" to the local repo absolute path on \e]8;;file://$SCRIPTDIR/repo/pacstallrepo\a$CYAN$SCRIPTDIR/repo/pacstallrepo$NC\e]8;;\a"
        URL="file://$(readlink -f ${URL})"
    elif [[ ${URL} == "file://"* && ${URL} == *"/~/"* ]]; then
        sed -i "s#${URL}#${URL/'~'/$HOME}#g" "$SCRIPTDIR/repo/pacstallrepo" 2> /dev/null \
            || fancy_message warn "Replace '~' with the full home path on \e]8;;file://$SCRIPTDIR/repo/pacstallrepo\a$CYAN$SCRIPTDIR/repo/pacstallrepo$NC\e]8;;\a"
        URL="${URL/'~'/$HOME}"
    fi
    URL="$(formatRepo "${URL}")"
    if [[ -n ${URL} ]] && ! check_url "${URL}/packagelist"; then
        if [[ -z $REPOMSG ]]; then
            fancy_message error "Pacstall repo line improperly formatted: ${CYAN}${URL}${NC}"
            fancy_message warn "You can remove or fix the URL by editing $CYAN$SCRIPTDIR/repo/pacstallrepo$NC"
            exit 1
        fi
        continue
    fi
    mapfile -t PARTIALLIST < <(curl -s -- "$URL"/packagelist)
    URLLIST+=("${PARTIALLIST[@]/*/$URL}")
    PACKAGELIST+=("${PARTIALLIST[@]}")
    unset PARTIALLIST
done < "$SCRIPTDIR/repo/pacstallrepo"

REPOMSG=1

# Remove any `mask` from output
any_masks=()
getMasks any_masks
if ((${#any_masks[@]} != 0)); then
    mask_itr=0
    for pkg in "${PACKAGELIST[@]}"; do
        if array.contains any_masks "${pkg}"; then
            unset "PACKAGELIST[$mask_itr]"
        fi
        ((mask_itr++))
    done
    PACKAGELIST=("${PACKAGELIST[@]}")
    unset mask_itr
fi

# Gets index of packages that the search returns
# Complete name if download, upgrade or install
# Partial word if search
if [[ -n $SEARCH ]]; then
    IDXSEARCH=$(printf "%s\n" "${PACKAGELIST[@]}" | awk "\$1 ~ /${SEARCH}/ {print NR-1}")
else
    IDXSEARCH=$(printf "%s\n" "${PACKAGELIST[@]}" | awk "\$1 ~ /^${PACKAGE}$/ {print NR-1}")
fi
_LEN=($IDXSEARCH)
LEN=${#_LEN[@]}

# Check if there are results
if ((LEN == 0)); then
    if [[ -z $SEARCH ]]; then
        fancy_message error "There is no package with the name $IRed$PACKAGE$NC"
        error_log 3 "search $PACKAGE"
        exit 1
    else
        fancy_message error "There is no package with the name $IRed$SEARCH$NC"
        exit 1
    fi

    return 1
# Check if it's upgrading packages
elif [[ -n $UPGRADE ]]; then
    REPOS=()
    # Return list of repos with the package
    for IDX in $IDXSEARCH; do
        ! array.contains REPOS "${URLLIST[$IDX]}" && mapfile -t -O"${#REPOS[@]}" REPOS <<< "${URLLIST[$IDX]}"
    done
    export REPOS
    return 0
# Check if its being used for search
elif [[ -n $SEARCH ]]; then
    for IDX in $IDXSEARCH; do
        searchedrepo="$(parseRepo "${URLLIST[$IDX]}")"
        if [[ ${URLLIST[$IDX]} == *"github"* ]]; then
            srBRANCH="${URLLIST[$IDX]##*/}"
        elif [[ ${URLLIST[$IDX]} == *"gitlab"* ]]; then
            srBRANCH="${URLLIST[$IDX]##*/-/raw/}"
        else
            unset srBRANCH
        fi
        [[ -n ${srBRANCH} && ${srBRANCH} != "master" && ${srBRANCH} != "main" ]] && searchedrepo+="${YELLOW}#${srBRANCH}${NC}"
        echo -e "$GREEN${PACKAGELIST[$IDX]} $PURPLE@ $CYAN${searchedrepo} $NC"
        unset searchedrepo srBRANCH
    done
    return 0
# Options left: install or download
# Variable $type used for the prompt
else
    # If there is only one result, proceed
    if ((LEN == 1)); then
        export PACKAGE=${PACKAGELIST[$IDXSEARCH]}
        export REPO=${URLLIST[$IDXSEARCH]}
        return 0
        # If there are multiple results, ask
    else
        echo -e "There are $LEN package(s) with the name $GREEN$PACKAGE$NC."
        echo
        # Pacstall repo first
        for IDX in $IDXSEARCH; do
            if [[ ${URLLIST[$IDX]} == 'https://raw.githubusercontent.com/pacstall/pacstall-programs/master' ]]; then
                PACSTALLREPO=$IDX
                break
            fi
        done
        if [[ -n $PACSTALLREPO ]]; then
            # Overwrite last question
            ask "\e[1A\e[KDo you want to $type $GREEN${PACKAGELIST[$IDX]}$NC from the official repo?" Y
            if ((answer == 1)); then
                export PACKAGE=${PACKAGELIST[$PACSTALLREPO]}
                export REPO=${URLLIST[$PACSTALLREPO]}
                unset PACSTALLREPO
                return 0
            fi
        fi
        # If other repos, ask, if Pacstall repo, skip
        for IDX in $IDXSEARCH; do
            if [[ $IDX == "$PACSTALLREPO" ]]; then
                continue
            fi
            # Overwrite last question
            ask "\e[1A\e[KDo you want to $type $GREEN${PACKAGELIST[$IDX]}$NC from the repo $CYAN$(parseRepo "${URLLIST[$IDX]}")$NC?" Y
            if ((answer == 1)); then
                export PACKAGE=${PACKAGELIST[$IDX]}
                export REPO=${URLLIST[$IDX]}
                return 0
            fi
        done
    fi
fi

error_log 1 "search $PACKAGE"
return 1

# vim:set ft=sh ts=4 sw=4 noet:
