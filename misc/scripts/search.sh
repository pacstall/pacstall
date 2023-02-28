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

# This script searches for packages in all repos saved on pacstallrepo.txt

if [[ -n $UPGRADE ]]; then
    PACKAGE="$i"
fi

function getPath() {
    local path="${1}"
    path="${path/"file://"/}"
    path="${path/"~"/"$HOME"}"
    path="$(readlink -f ${path})"
    path="${path/"$HOME"/"~"}"
    echo $path
}

function specifyRepo() {
    mapfile -t SPLIT < <(echo "${1//[\/]/$'\n'}")

    if [[ $1 == "file://"* ]] || [[ $1 == "/"* ]] || [[ $1 == "~"* ]] || [[ $1 == "."* ]]; then
        export URLNAME="$(getPath ${1})"
    elif [[ $1 == *"github"* ]]; then
        export URLNAME="${SPLIT[-3]}/${SPLIT[-2]}"
    elif [[ $1 == *"gitlab"* ]]; then
        export URLNAME="${SPLIT[-4]}/${SPLIT[-3]}"
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

    mapfile -t SPLIT < <(echo "${REPO//[\/]/$'\n'}")

    if [[ $REPO == *"file://"* ]]; then
        local REPODIR="$(getPath ${REPO})"
        echo "\e]8;;$REPO\a$REPODIR\e]8;;\a"
    elif [[ $REPO == *"github"* ]]; then
        echo -e "\e]8;;https://github.com/${SPLIT[-3]}/${SPLIT[-2]}\a${SPLIT[-3]}/${SPLIT[-2]}\e]8;;\a"
    elif [[ $REPO == *"gitlab"* ]]; then
        echo -e "\e]8;;https://gitlab.com/${SPLIT[-4]}/${SPLIT[-3]}\a${SPLIT[-4]}/${SPLIT[-3]}\e]8;;\a"
    else
        echo "\e]8;;$REPO\a$REPO\e]8;;\a"
    fi
}

if [[ $PACKAGE == *@* ]]; then
    REPONAME=${PACKAGE#*@}
    if [[ $REPONAME == "file://"* ]] || [[ $REPONAME == "/"* ]] || [[ $REPONAME == "~"* ]] || [[ $REPONAME == "."* ]]; then
        REPONAME="$(getPath ${REPONAME})"
    fi
    PACKAGE=${PACKAGE%%@*}

    while IFS= read -r URL; do
        specifyRepo "$URL"
        if [[ $URLNAME == "$REPONAME" ]]; then
            mapfile -t PACKAGELIST < <(curl -s -- "$URL"/packagelist)
            IDXSEARCH=$(printf "%s\n" "${PACKAGELIST[@]}" | awk -e "\$1 ~ /^${PACKAGE}$/ {print NR-1}")
            _LEN=($IDXSEARCH)
            LEN=${#_LEN[@]}
            if [[ $LEN -eq 0 ]]; then
                fancy_message warn "There is no package with the name $IRed${PACKAGE%%@*}$NC in the repo $CYAN$REPONAME$NC"
                error_log 3 "search $PACKAGE@$REPONAME"
                exit 1
            fi
            export PACKAGE
            export REPO="$URL"
            return 0
        fi
    done < "$STGDIR/repo/pacstallrepo.txt"

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
        sed -i "s#${URL}#file://$(readlink -f ${URL})#g" "$STGDIR/repo/pacstallrepo.txt" 2> /dev/null \
            || fancy_message warn "Add \"file://\" to the local repo absolute path on \e]8;;file://$STGDIR/repo/pacstallrepo.txt\a$CYAN$STGDIR/repo/pacstallrepo.txt$NC\e]8;;\a"
        URL="file://$(readlink -f ${URL})"
    elif [[ ${URL} == "file://"* ]] && [[ ${URL} == *"/~/"* ]]; then
        sed -i "s#${URL}#${URL/'~'/$HOME}#g" "$STGDIR/repo/pacstallrepo.txt" 2> /dev/null \
            || fancy_message warn "Replace '~' with the full home path on \e]8;;file://$STGDIR/repo/pacstallrepo.txt\a$CYAN$STGDIR/repo/pacstallrepo.txt$NC\e]8;;\a"
        URL="${URL/'~'/$HOME}"
    fi
    if ! check_url "${URL}/packagelist"; then
        if [[ -z $REPOMSG ]]; then
            fancy_message warn "Skipping repo $CYAN$(parseRepo ${URL})$NC"
            fancy_message warn "You can remove or fix the URL by editing $CYAN$STGDIR/repo/pacstallrepo.txt$NC"
        fi
        continue
    fi
    mapfile -t PARTIALLIST < <(curl -s -- "$URL"/packagelist)
    URLLIST+=("${PARTIALLIST[@]/*/$URL}")
    PACKAGELIST+=("${PARTIALLIST[@]}")
done < "$STGDIR/repo/pacstallrepo.txt"

REPOMSG=1

# Gets index of packages that the search returns
# Complete name if download, upgrade or install
# Partial word if search
if [[ -z $PACKAGE ]]; then
    IDXSEARCH=$(printf "%s\n" "${PACKAGELIST[@]}" | awk -e "\$1 ~ /${SEARCH}/ {print NR-1}")
else
    IDXSEARCH=$(printf "%s\n" "${PACKAGELIST[@]}" | awk -e "\$1 ~ /^${PACKAGE}$/ {print NR-1}")
fi
_LEN=($IDXSEARCH)
LEN=${#_LEN[@]}

# Check if there are results
if [[ $LEN -eq 0 ]]; then
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
        mapfile -t REPOS <<< "${URLLIST[$IDX]}"
    done
    export REPOS
    return 0
# Check if its being used for search
elif [[ -z $PACKAGE ]]; then
    for IDX in $IDXSEARCH; do
        echo -e "$GREEN${PACKAGELIST[$IDX]} $PURPLE@ $CYAN$(parseRepo "${URLLIST[$IDX]}") $NC"
    done
    return 0
# Options left: install or download
# Variable $type used for the prompt
else
    # If there is only one result, proceed
    if [[ $LEN -eq 1 ]]; then
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
            if [[ $answer -eq 1 ]]; then
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
            if [[ $answer -eq 1 ]]; then
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
