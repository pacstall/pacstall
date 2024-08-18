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

function repo.split_components() {
    { ignore_stack=false; set -o pipefail; trap stacktrace ERR RETURN; }
    local line="${1:?No line passed}" split
    local -n prefix="${2:?No prefix passed}"
    mapfile -t split <<< "${line// /$'\n'}"
    # We're assuming the line has been syntactically checked.
    if ((${#split[@]} == 1)); then
        prefix['url']="${split[0]}"
        prefix['alias']="none"
    # Then we either have a specifier + url, or a url + alias
    elif ((${#split[@]} == 2)); then
        prefix['url']="${split[0]}"
        # shellcheck disable=SC2034
        prefix['alias']="${split[1]:1}"
    fi
}

function repo.unraw_types() {
    { ignore_stack=false; set -o pipefail; trap stacktrace ERR RETURN; }
    unset pURL pBRANCH pISSUES pTYPE pREPO pOWNER
    local rep="${1}" type="${2}" pSPLIT
    case "${type}" in
        "github")
            pTYPE="${type}"
            pURL="${rep/'raw.githubusercontent.com'/'github.com'}"
            pURL="${pURL%/*}"
            pBRANCH="${rep##*/}"
            pISSUES="${pURL}/issues"
            mapfile -t pSPLIT <<< "${pURL//[\/]/$'\n'}"
            pREPO="${pSPLIT[-1]}" pOWNER="${pSPLIT[-2]}"
            export pURL pBRANCH pISSUES pTYPE pREPO pOWNER
            ;;
        "gitlab")
            pTYPE="${type}"
            pURL="${rep%/-/raw/*}"
            pBRANCH="${rep##*/-/raw/}"
            pISSUES="${pURL}/-/issues"
            mapfile -t pSPLIT <<< "${pURL//[\/]/$'\n'}"
            pREPO="${pSPLIT[-1]}" pOWNER="${pSPLIT[-2]}"
            export pURL pBRANCH pISSUES pTYPE pREPO pOWNER
            ;;
        "sourcehut")
            pTYPE="${type}"
            pURL="${rep%/blob*}"
            pBRANCH="${rep##*/}"
            pISSUES="https://lists.sr.ht/~${pURL#*~}"
            mapfile -t pSPLIT <<< "${pURL//[\/]/$'\n'}"
            pREPO="${pSPLIT[-1]}" pOWNER="${pSPLIT[-2]/\~/}"
            export pURL pBRANCH pISSUES pTYPE pREPO pOWNER
            ;;
        "codeberg")
            pTYPE="${type}"
            pURL="${rep%raw/branch/*}"
            pBRANCH="${rep##*/}"
            pISSUES="${pURL}/issues"
            pTYPE="${type}"
            mapfile -t pSPLIT <<< "${pURL//[\/]/$'\n'}"
            pREPO="${pSPLIT[-1]}" pOWNER="${pSPLIT[-2]}"
            export pURL pBRANCH pISSUES pTYPE pREPO pOWNER
            ;;
        *)
            export pURL="$rep"
            ;;
    esac
}

function repo.unraw() {
    { ignore_stack=false; set -o pipefail; trap stacktrace ERR RETURN; }
    local rep="${1}"
    local -A repo_unraw
    repo.split_components "${rep}" "repo_unraw"
    case "${repo_unraw['url']}" in
        *"githubusercontent"*) repo.unraw_types "${repo_unraw['url']}" "github" ;;
        *"gitlab"*) repo.unraw_types "${repo_unraw['url']}" "gitlab" ;;
        *"git.sr.ht"*) repo.unraw_types "${repo_unraw['url']}" "sourcehut" ;;
        *"codeberg"*) repo.unraw_types "${repo_unraw['url']}" "codeberg" ;;
        *) repo.unraw_types "${repo_unraw['url']}" "UNSET" ;;
    esac
}

function repo.to_metalink() {
    { ignore_stack=false; set -o pipefail; trap stacktrace ERR RETURN; }
    local linklist=("${@}")
    local metalinks
    for i in "${linklist[@]}"; do
        local metalink
        repo.unraw "${i}"
        if [[ -n ${pTYPE} && -n ${pOWNER} && -n ${pREPO} ]]; then
            metalink="${pTYPE}:${pOWNER}/${pREPO}"
            if [[ -n ${pBRANCH} && ${pBRANCH} != "master" && ${pBRANCH} != "main" ]]; then
                metalink+="#${pBRANCH}"
            fi
        else
            metalink="${pURL}"
        fi
        metalinks+=("${metalink}")
    done
    printf '%s\n' "${metalinks[@]}"
}

function repo.from_metalink() {
    { ignore_stack=false; set -o pipefail; trap stacktrace ERR RETURN; }
    local fromlist=("${@}") outlist PROV USER HEAD
    for i in "${fromlist[@]}"; do
        local ADDR PROV USER HEAD BRANCH
        IFS=':' read -ra ADDR <<< "${i}"
        PROV="${ADDR[0]}"
        USER=$(echo "${ADDR[1]}" | cut -d'/' -f1)
        HEAD=$(echo "${ADDR[1]}" | cut -d'/' -f2 | cut -d'#' -f1)
        if [[ ${ADDR[1]} =~ "#" ]]; then
            BRANCH="$(echo "${ADDR[1]}" | cut -d'#' -f2)"
        else
            BRANCH="master"
        fi
        case ${i} in
            *"github:"*)
                outlist+=("https://raw.${PROV}usercontent.com/${USER}/${HEAD}/${BRANCH}")
                ;;
            *"gitlab:"*)
                outlist+=("https://${PROV}.com/${USER}/${HEAD}/-/raw/${BRANCH}")
                ;;
            *"sourcehut:"*)
                outlist+=("https://git.sr.ht/~${USER}/${HEAD}/blob/${BRANCH}")
                ;;
            *"codeberg:"*)
                outlist+=("https://${PROV}.org/${USER}/${HEAD}/raw/branch/${BRANCH}")
                ;;
        esac
    done
    printf '%s\n' "${outlist[@]}"
}

# Something like `repo.get_where alias "foo"`
function repo.get_where() {
    { ignore_stack=false; set -o pipefail; trap stacktrace ERR RETURN; }
    local where="${1:?no type passed}" name="${2:?no alias or metalink passed}" line
    while IFS= read -r line; do
        local -A get_where
        repo.split_components "${line}" "get_where"
        case "${where}" in
            "alias") if [[ "${get_where['alias']}" == "${name}" && "${name}" != "none" ]]; then echo "${get_where['url']}"; fi ;;
            "metalink") repo.from_metalink "${get_where['url']}" ;;
            *) fancy_message error $"'repo.get_where' valid types are: 'alias', 'metalink'"; { ignore_stack=true; return 1; } ;;
        esac
        unset get_where
    done < "${SCRIPTDIR}/repo/pacstallrepo"
}

function repo.get_all_type() {
    { ignore_stack=false; set -o pipefail; trap stacktrace ERR RETURN; }
    local type="${1:?no type passed}" line
    while IFS= read -r line; do
        local -A get_all_type
        repo.split_components "${line}" "get_all_type"
        case "${type}" in
            "url") if [[ -n "${get_all_type['url']}" ]]; then echo "${get_all_type['url']}"; fi ;;
            "alias") if [[ -n "${get_all_type['alias']}" ]]; then echo "${get_all_type['alias']}"; fi ;;
            "metalink") repo.to_metalink "${get_where['url']}" ;;
            *) fancy_message error $"'repo.get_all_type' valid types are: 'url', 'alias', 'metalink'"; { ignore_stack=true; return 1; } ;;
        esac
        unset get_all_type
    done < "${SCRIPTDIR}/repo/pacstallrepo"
}

function repo.get_path() {
    { ignore_stack=false; set -o pipefail; trap stacktrace ERR RETURN; }
    local path="${1}"
    local var="${2}"
    path="${path/"file://"/}"
    path="${path/"~"/"$HOME"}"
    path="$(realpath "${path}")"
    path="${path/"$HOME"/"~"}"
    printf -v "${var}" "%s" "${path}"
}

function repo.specify() {
    { ignore_stack=false; set -o pipefail; trap stacktrace ERR RETURN; }
    if [[ $1 == "file://"* ]] || [[ $1 == "/"* ]] || [[ $1 == "~"* ]] || [[ $1 == "."* ]]; then
        repo.get_path "${1}" URLNAME
        export URLNAME
    elif [[ $1 == "github:"* ]] || [[ $1 == "gitlab:"* ]] || [[ $1 == "sourchut:"* ]] || [[ $1 == "codeberg:"* ]]; then
        export URLNAME="${1}"
    elif [[ $1 == *"github"* ]] || [[ $1 == *"gitlab"* ]] || [[ $1 == *"git.sr.ht"* ]] || [[ $1 == *"codeberg"* ]]; then
        URLNAME="$(repo.to_metalink "${1}")"
        export URLNAME
    else
        export URLNAME="$REPO"
    fi
}

# Parses github and gitlab URL's
# url -> maintainer/repo
# Also adds hyperlink for the
# terminals that support them
function repo.parse() {
    { ignore_stack=false; set -o pipefail; trap stacktrace ERR RETURN; }
    local REPO="${1}" REPODIR
    case "${REPO}" in
        "file://"*)
            repo.get_path "${REPO}" REPODIR
            echo -e "\e]8;;${REPO}\a${REPODIR}\e]8;;\a"
            ;;
        *"github"*|*"git.sr.ht"*)
            repo.unraw "${REPO}"
            echo -e "\e]8;;${pURL}/tree/${pBRANCH}\a$(repo.to_metalink "${REPO}")\e]8;;\a"
            ;;
        *"gitlab"*)
            repo.unraw "${REPO}"
            echo -e "\e]8;;${pURL}/-/tree/${pBRANCH}\a$(repo.to_metalink "${REPO}")\e]8;;\a"
            ;;
        *"codeberg"*)
            repo.unraw "${REPO}"
            echo -e "\e]8;;${pURL}/src/branch/${pBRANCH}\a$(repo.to_metalink "${REPO}")\e]8;;\a"
            ;;
        *)
            echo -e "\e]8;;$REPO\a$REPO\e]8;;\a"
        ;;
    esac
}

function repo.format() {
    # shellcheck disable=SC2034
    { ignore_stack=false; set -o pipefail; trap stacktrace ERR RETURN; }
    if ! [[ ${1} =~ ^\ *# ]] && [[ ${1} =~ ^([^[:space:]]+)([[:space:]]@[a-zA-Z0-9_-]+)?([[:space:]]+#.*)?$ ]]; then
        echo "${BASH_REMATCH[1]}"
    fi
}

# vim:set ft=sh ts=4 sw=4 et:
