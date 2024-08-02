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

{ ignore_stack=false; set -o pipefail; trap stacktrace ERR RETURN; }

if [[ -n $UPGRADE ]]; then
    [[ ! -f "${PACDIR}-pacdeps-${PACKAGE%@*}" ]] && PACKAGE="${i}"
    [[ -n ${_pkgbase} ]] && PACKAGE="${_pkgbase}:${PACKAGE}"
fi

if [[ -z ${SEARCH} ]]; then
    unset DESCON
fi

if [[ -z ${INFOQUERY} ]]; then
    unset SEARCHINFO
fi

function getPath() {
    { ignore_stack=false; set -o pipefail; trap stacktrace ERR RETURN; }
    local path="${1}"
    local var="${2}"
    path="${path/"file://"/}"
    path="${path/"~"/"$HOME"}"
    path="$(realpath "${path}")"
    path="${path/"$HOME"/"~"}"
    printf -v "${var}" "%s" "${path}"
}

function specifyRepo() {
    { ignore_stack=false; set -o pipefail; trap stacktrace ERR RETURN; }
    local SPLIT
    mapfile -t SPLIT <<< "${1//[\/]/$'\n'}"
    if [[ $1 == "file://"* ]] || [[ $1 == "/"* ]] || [[ $1 == "~"* ]] || [[ $1 == "."* ]]; then
        export URLNAME
        getPath "${1}" URLNAME
    elif [[ $1 == "github:"* ]] || [[ $1 == "gitlab:"* ]]; then
        export URLNAME="${1}"
    elif [[ $1 == *"github"* ]]; then
        if [[ ${SPLIT[-1]} == "master" || ${SPLIT[-1]} == "main" ]]; then
            export URLNAME="github:${SPLIT[-3]}/${SPLIT[-2]}"
        else
            export URLNAME="github:${SPLIT[-3]}/${SPLIT[-2]}#${SPLIT[-1]}"
        fi
    elif [[ $1 == *"gitlab"* ]]; then
        if [[ ${SPLIT[-1]} == "master" || ${SPLIT[-1]} == "main" ]]; then
            export URLNAME="github:${SPLIT[-4]}/${SPLIT[-3]}"
        else
            export URLNAME="github:${SPLIT[-4]}/${SPLIT[-3]}#${SPLIT[-1]}"
        fi
    else
        export URLNAME="$REPO"
    fi
}

# Parses github and gitlab URL's
# url -> maintainer/repo
# Also adds hyperlink for the
# terminals that support them
function parseRepo() {
    { ignore_stack=false; set -o pipefail; trap stacktrace ERR RETURN; }
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
    { ignore_stack=false; set -o pipefail; trap stacktrace ERR RETURN; }
    ! [[ $1 =~ ^\ *# ]] \
        && [[ $1 =~ ^([^[:space:]]+)([[:space:]]+#.*)?$ ]] \
        && echo "${BASH_REMATCH[1]}"
}

# Usage: see srclist.parse
function srclist.search() {
    { ignore_stack=false; set -o pipefail; trap stacktrace ERR RETURN; }
    local -n FILE="${1}"
    printf "%s\n" "${FILE[@]}" | awk -v kw="${2}" '
    BEGIN {
        FS = "[[:space:]]*=[[:space:]]*"
        OFS = " - "
        found = 0
        kw = tolower(kw)
    }
    function print_pkgbase_and_pkgname() {
        if (pkgbase != "") {
            print pkgbase, pkgbase_desc
            if (pkgname != "") {
                desc = (pkgname_desc != "" ? pkgname_desc : pkgbase_desc)
                print pkgbase ":" pkgname, desc
            }
        }
    }
    /^---$/ {
        if (pkgbase != "" && (pkgbase ~ kw || tolower(pkgbase_desc) ~ kw)) {
            print_pkgbase_and_pkgname()
            found = 1
        } else if (pkgname != "" && (pkgname ~ kw || tolower(pkgname_desc) ~ kw)) {
            print_pkgbase_and_pkgname()
            found = 1
        }
        pkgname = ""; pkgbase = ""; pkgbase_desc = ""; pkgname_desc = ""; next
    }
    /^[[:space:]]*pkgbase[[:space:]]*=/ {
        pkgbase = $2
        pkgbase_desc = ""
    }
    /^[[:space:]]*pkgname[[:space:]]*=/ {
        if (pkgname != "") {
            desc = (pkgname_desc != "" ? pkgname_desc : pkgbase_desc)
            if (pkgname ~ kw || tolower(desc) ~ kw) {
                print pkgbase ":" pkgname, desc
                found = 1
            }
        }
        pkgname = $2
        pkgname_desc = ""
    }
    /^[[:space:]]*pkgdesc[[:space:]]*=/ {
        if (pkgname == "") {
            pkgbase_desc = $2
        } else {
            pkgname_desc = $2
        }
    }
    END {
        if (!found) {
            print "No matching packages found"
        }
    }
    '
}

# Usage: eval "$(srclist.parse SRCLIST PACKAGELIST desc_array <pkgname | pkgbase:pkgname | keyword | "spaced keyword" | "'Case Sensitive Keyword'">)"
function srclist.parse() {
    { ignore_stack=false; set -o pipefail; trap stacktrace ERR RETURN; }
    local SRCFILE="${1}" DESCARR="${3}" KWD="${4}" SEARCH CHILD searchlist foundname founddesc exact=false
    # shellcheck disable=SC2034
    local -n PKGFILE="${2}" LOCARR="${DESCARR}"
    # shellcheck disable=SC2034
    declare -A LOCARR=()
    SEARCH="${KWD%% *}"
    if [[ ${KWD} == \'*\' ]]; then
        exact=true
        KWD="${KWD%*\'}"
        KWD="${KWD#\'*}"
    elif [[ ${KWD} == \"*\" ]]; then
        exact=true
        KWD="${KWD%*\"}"
        KWD="${KWD#\"*}"
    else
        KWD="${KWD,,}"
    fi
    if [[ ${SEARCH} == *':'* && ${SEARCH} == "${KWD##* }" ]]; then
        CHILD="${SEARCH#*:}" KWD="${SEARCH%:*}"
    fi
    mapfile -t searchlist < <(srclist.search "${SRCFILE}" "${KWD}")
    for i in "${searchlist[@]}"; do
        foundname="${i%% -*}"
        founddesc="${i#* - }"
        if [[ -n ${CHILD} && ${CHILD} != "pkgbase" && ${foundname} != "${KWD}:${CHILD}" ]] \
            || [[ ${CHILD} == "pkgbase" && ${foundname} =~ ':' && ${foundname} != *":${CHILD}" ]] \
            || [[ ${exact} == true && ${i} != *"${KWD}"* ]] \
            || [[ ${exact} == false && -n ${KWD} && ${i,,} != *"${KWD}"* ]]; then
            continue
        fi
        if array.contains PKGFILE "${foundname}"; then
            # shellcheck disable=SC2034
            LOCARR["${foundname}"]="${founddesc}"
        elif array.contains PKGFILE "${foundname}:pkgbase"; then
            # shellcheck disable=SC2034
            LOCARR["${foundname}:pkgbase"]="${founddesc}"
        fi
    done
    declare -p "${DESCARR}"
}

# Usage: srclist.info SRCLIST <pkgname | pkgbase:pkgname>
function srclist.info() {
    { ignore_stack=false; set -o pipefail; trap stacktrace ERR RETURN; }
    local SEARCH="${2}" NAME FIELD
    local -n FILE="${1}"
    NAME="${SEARCH#*:}" PARENT="${SEARCH%:*}"
    if [[ ${SEARCH} != *':'* || ${NAME} == "pkgbase" ]]; then
        FIELD="pkgbase"
    else
        FIELD="pkgname"
    fi
    [[ ${NAME} == "pkgbase" ]] && NAME="${PARENT}"
    printf "%s\n" "${FILE[@]}" | awk -v pkg="${NAME}" -v field="${FIELD}" '
    BEGIN { print_pkg = 0 }
    /^[[:space:]]*$/ || /^---$/ {
        if (print_pkg && field == "pkgname") {
            exit
        }
    }
    /^---$/ {
        print_pkg = 0
    }
    {
        if ($1 == "pkgbase" && $3 != pkg && field == "pkgname") {
            print_pkg = 0
        }
        if ($1 == field && $3 == pkg) {
            print_pkg = 1
        }
        if (print_pkg) {
            print
        }
    }
    '
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
            if [[ ${DESCON} || ${SEARCHINFO} ]]; then
                # shellcheck disable=SC2034
                mapfile -t SRCLIST < <(curl -s -- "$URL"/srclist)
            fi
            any_masks=()
            getMasks any_masks
            if ((${#any_masks[@]} != 0)); then
                mask_itr=0
                for pkg in "${PACKAGELIST[@]}"; do
                    if array.contains any_masks "${pkg}"; then
                        unset "PACKAGELIST[$mask_itr]"
                    fi
                    { ignore_stack=true; ((mask_itr++)); }
                done
                PACKAGELIST=("${PACKAGELIST[@]}")
                unset mask_itr
            fi
            if [[ -n $SEARCH ]]; then
                if [[ ${DESCON} ]]; then
                    eval "$(srclist.parse SRCLIST PACKAGELIST SEARCHDESC "${SEARCH}")"
                    IDXSEARCH="${!SEARCHDESC[*]}"
                else
                    IDXSEARCH=$(printf "%s\n" "${PACKAGELIST[@]}" | awk "\$1 ~ /${SEARCH}/ {print NR-1}")
                fi
            else
                if [[ -n ${CHILD} ]]; then
                    IDXSEARCH=$(printf "%s\n" "${PACKAGELIST[@]}" | awk "\$1 ~ /^${PACKAGE:CHILD}$/ {print NR-1}")
                else
                    IDXSEARCH=$(printf "%s\n" "${PACKAGELIST[@]}" | awk "\$1 ~ /^${PACKAGE}$/ {print NR-1}")
                    if [[ -z $IDXSEARCH ]]; then
                        IDXSEARCH=$(printf "%s\n" "${PACKAGELIST[@]}" | awk "\$1 ~ /^${PACKAGE}:pkgbase$/ {print NR-1}")
                    fi
                fi
            fi
            _LEN=($IDXSEARCH)
            mapfile -t _LEN < <(printf "%s\n" "${_LEN[@]}" | sort -V)
            LEN=${#_LEN[@]}
            if ((LEN == 0)) || [[ -z ${_LEN[*]} ]]; then
                if [[ -n $SEARCH ]]; then
                    fancy_message warn "There is no package with the name $IRed${SEARCH%%@*}$NC in the repo $CYAN$REPONAME$NC"
                else
                    fancy_message warn "There is no package with the name $IRed${PACKAGE%%@*}$NC in the repo $CYAN$REPONAME$NC"
                fi
                error_log 3 "search $PACKAGE@$REPONAME"
                exit 1
            fi
            if [[ -n $SEARCH ]]; then
                searchedrepo="$(parseRepo "${URL}")"
                if [[ ${URL} == *"github"* ]]; then
                    srBRANCH="${URL##*/}"
                elif [[ ${URL} == *"gitlab"* ]]; then
                    srBRANCH="${URL##*/-/raw/}"
                else
                    unset srBRANCH
                fi
                [[ -n ${srBRANCH} && ${srBRANCH} != "master" && ${srBRANCH} != "main" ]] && searchedrepo+="${YELLOW}#${srBRANCH}${NC}"
                for ids in "${_LEN[@]}"; do
                    if [[ ${DESCON} ]]; then
                        echo -e "$GREEN${ids} ${BLUE}-${NC} ${SEARCHDESC[$ids]} $PURPLE@ $CYAN${searchedrepo} $NC"
                    else
                        echo -e "$GREEN${PACKAGELIST[$ids]} $PURPLE@ $CYAN${searchedrepo} $NC"
                    fi
                done
                unset searchedrepo srBRANCH
            elif [[ ${SEARCHINFO} ]]; then
                INFORESULTS=()
                # shellcheck disable=SC2034
                mapfile -t PARTRESULTS < <(srclist.info SRCLIST "${INFOQUERY%%@*}")
                if [[ -n ${PARTRESULTS[*]} ]]; then
                    searchedrepo="$(parseRepo "${URL}")"
                    if [[ ${URL} == *"github"* ]]; then
                        srBRANCH="${URL##*/}"
                    elif [[ ${URL} == *"gitlab"* ]]; then
                        srBRANCH="${URL##*/-/raw/}"
                    else
                        unset srBRANCH
                    fi
                    [[ -n ${srBRANCH} && ${srBRANCH} != "master" && ${srBRANCH} != "main" ]] && searchedrepo+="${YELLOW}#${srBRANCH}${NC}"
                    PARTRESULTS=("${PURPLE}---${NC} ${CYAN}${searchedrepo}${NC} ${PURPLE}---${NC}" "${PARTRESULTS[@]}")
                    INFORESULTS+=("${PARTRESULTS[@]}")
                    unset searchedrepo srBRANCH
                fi
                if [[ -z ${INFORESULTS[*]} ]]; then
                    fancy_message error "There is no package with the name $IRed${INFOQUERY%%@*}$NC in the repo $CYAN$REPONAME$NC"
                    error_log 3 "search $INFOQUERY"
                    exit 1
                fi
                for inres in "${INFORESULTS[@]}"; do
                    echo -e "${inres}"
                done
                unset INFORESULTS
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

if [[ -n ${SEARCH} ]]; then
    searchout=()
    while IFS= read -r URL; do
        mapfile -t PACKAGELIST < <(curl -s -- "$URL"/packagelist)
        if [[ ${DESCON} ]]; then
            # shellcheck disable=SC2034
            mapfile -t SRCLIST < <(curl -s -- "$URL"/srclist)
        fi
        any_masks=()
        getMasks any_masks
        if ((${#any_masks[@]} != 0)); then
            mask_itr=0
            for pkg in "${PACKAGELIST[@]}"; do
                if array.contains any_masks "${pkg}"; then
                    unset "PACKAGELIST[$mask_itr]"
                fi
                { ignore_stack=true; ((mask_itr++)); }
            done
            PACKAGELIST=("${PACKAGELIST[@]}")
            unset mask_itr
        fi
        if [[ ${DESCON} ]]; then
            eval "$(srclist.parse SRCLIST PACKAGELIST SEARCHDESC "${SEARCH}")"
            IDXSEARCH="${!SEARCHDESC[*]}"
        else
            IDXSEARCH=$(printf "%s\n" "${PACKAGELIST[@]}" | awk "\$1 ~ /${SEARCH}/ {print NR-1}")
        fi
        _LEN=($IDXSEARCH)
        mapfile -t _LEN < <(printf "%s\n" "${_LEN[@]}" | sort -V)
        LEN=${#_LEN[@]}
        if ((LEN == 0)) || [[ -z ${_LEN[*]} ]]; then
            continue
        fi
        searchedrepo="$(parseRepo "${URL}")"
        if [[ ${URL} == *"github"* ]]; then
            srBRANCH="${URL##*/}"
        elif [[ ${URL} == *"gitlab"* ]]; then
            srBRANCH="${URL##*/-/raw/}"
        else
            unset srBRANCH
        fi
        [[ -n ${srBRANCH} && ${srBRANCH} != "master" && ${srBRANCH} != "main" ]] && searchedrepo+="${YELLOW}#${srBRANCH}${NC}"
        for ids in "${_LEN[@]}"; do
            if [[ ${DESCON} ]]; then
                searchout+=("$GREEN${ids} ${BLUE}-${NC} ${SEARCHDESC[$ids]} $PURPLE@ $CYAN${searchedrepo} $NC")
            else
                searchout+=("$GREEN${PACKAGELIST[$ids]} $PURPLE@ $CYAN${searchedrepo} $NC")
            fi
        done
        unset searchedrepo srBRANCH
    done < "$SCRIPTDIR/repo/pacstallrepo"
    mapfile -t searchout < <(printf "%s\n" "${searchout[@]}" | sort -V)
    LEN=${#searchout[@]}
    if ((LEN == 0)) || [[ -z ${searchout[*]} ]]; then
        fancy_message warn "There is no package with the name $IRed${SEARCH%%@*}$NC"
        exit 1
    fi
    for s in "${searchout[@]}"; do
        echo -e "${s}"
    done
    unset searchout
    return 0
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
        { ignore_stack=true; ((mask_itr++)); }
    done
    PACKAGELIST=("${PACKAGELIST[@]}")
    unset mask_itr
fi

# Gets index of packages that the search returns
# Complete name if download, upgrade or install
# Partial word if search
if [[ -n ${CHILD} ]]; then
    IDXSEARCH=$(printf "%s\n" "${PACKAGELIST[@]}" | awk "\$1 ~ /^${PACKAGE:CHILD}$/ {print NR-1}")
else
    IDXSEARCH=$(printf "%s\n" "${PACKAGELIST[@]}" | awk "\$1 ~ /^${PACKAGE}$/ {print NR-1}")
    if [[ -z $IDXSEARCH ]]; then
        IDXSEARCH=$(printf "%s\n" "${PACKAGELIST[@]}" | awk "\$1 ~ /^${PACKAGE}:pkgbase$/ {print NR-1}")
    fi
fi
_LEN=($IDXSEARCH)
mapfile -t _LEN < <(printf "%s\n" "${_LEN[@]}" | sort -V)
LEN=${#_LEN[@]}

# Check if there are results
if ((LEN == 0)) || [[ -z ${_LEN[*]} ]]; then
    fancy_message error "There is no package with the name $IRed$PACKAGE$NC"
    error_log 3 "search $PACKAGE"
    exit 1
# Check if it's upgrading packages
elif [[ -n $UPGRADE ]]; then
    REPOS=()
    # Return list of repos with the package
    for IDX in "${_LEN[@]}"; do
        ! array.contains REPOS "${URLLIST[$IDX]}" && mapfile -t -O"${#REPOS[@]}" REPOS <<< "${URLLIST[$IDX]}"
    done
    export REPOS
    return 0
# check if we are looking at info
elif [[ ${SEARCHINFO} ]]; then
    INFORESULTS=()
    while IFS= read -r URL; do
        # shellcheck disable=SC2034
        mapfile -t SRCLIST < <(curl -s -- "$URL"/srclist)
        mapfile -t PARTRESULTS < <(srclist.info SRCLIST "${INFOQUERY}")
        if [[ -n ${PARTRESULTS[*]} ]]; then
            searchedrepo="$(parseRepo "${URL}")"
            if [[ ${URL} == *"github"* ]]; then
                srBRANCH="${URL##*/}"
            elif [[ ${URL} == *"gitlab"* ]]; then
                srBRANCH="${URL##*/-/raw/}"
            else
                unset srBRANCH
            fi
            [[ -n ${srBRANCH} && ${srBRANCH} != "master" && ${srBRANCH} != "main" ]] && searchedrepo+="${YELLOW}#${srBRANCH}${NC}"
            PARTRESULTS=("${PURPLE}---${NC} ${CYAN}${searchedrepo}${NC} ${PURPLE}---${NC}" "${PARTRESULTS[@]}")
            INFORESULTS+=("${PARTRESULTS[@]}")
            unset searchedrepo srBRANCH
        fi
    done < "$SCRIPTDIR/repo/pacstallrepo"
    if [[ -z ${INFORESULTS[*]} ]]; then
        fancy_message error "There is no package with the name $IRed$INFOQUERY$NC"
        error_log 3 "search $INFOQUERY"
        exit 1
    fi
    for inres in "${INFORESULTS[@]}"; do
        echo -e "${inres}"
    done
    unset INFORESULTS
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
        for IDX in "${_LEN[@]}"; do
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
        for IDX in "${_LEN[@]}"; do
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

# vim:set ft=sh ts=4 sw=4 et:
