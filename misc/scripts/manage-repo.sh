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
    { ignore_stack=true; set -o pipefail; trap stacktrace ERR RETURN; }
    local line="${1:?No line passed}" split
    local -n prefix="${2:?No prefix passed}"
    mapfile -t split <<< "${line// /$'\n'}"
    # We're assuming the line has been syntactically checked.
    if ((${#split[@]} == 1)); then
        prefix['url']="${split[0]}"
    # Then we either have a specifier + url, or a url + alias
    elif ((${#split[@]} == 2)); then
        # Do we have a specifier
        if [[ ${split[0]:0:1} == '[' ]]; then
            prefix['specifier']="${split[0]:1:-1}"
            prefix['url']="${split[1]}"
        # Then we have a url + alias
        else
            prefix['url']="${split[0]}"
            prefix['alias']="${split[1]:1}"
        fi
    # We have everything
    else
        prefix['specifier']="${split[0]:1:-1}"
        prefix['url']="${split[1]}"
        prefix['alias']="${split[2]:1}"
    fi
}

function repo.unraw_types() {
    { ignore_stack=true; set -o pipefail; trap stacktrace ERR RETURN; }
    local rep="${1}" type="${2}"
    case "${type}" in
        "github")
            pURL="${rep/'raw.githubusercontent.com'/'github.com'}"
            pURL="${pURL%/*}"
            export pURL pBRANCH="${rep##*/}" pISSUES="${pURL}/issues" branch="yes"
            ;;
        "gitlab")
            pURL="${rep%/-/raw/*}"
            export pURL pBRANCH="${rep##*/-/raw/}" pISSUES="${pURL}/-/issues" branch="yes"
            ;;
        "sourcehut")
            pURL="${rep%/blob*}"
            export pURL pBRANCH="${rep##*/}" pISSUES="https://lists.sr.ht/~${pURL#*~}" branch="yes"
            ;;
        "codeberg")
            pURL="${rep%raw/branch/*}"
            export pURL pBRANCH="${rep##*/}" pISSUES="${pURL}/issues" branch="yes"
            ;;
        *)
            export pURL="$rep" branch="no"
            ;;
    esac
}

function repo.unraw() {
    { ignore_stack=true; set -o pipefail; trap stacktrace ERR RETURN; }
    local rep="${1}"
    local -A repo_unraw
    repo.split_components "${rep}" "repo_unraw"
    if [[ -n ${repo_unraw['specifier']} ]]; then
        repo.unraw_types "${repo_unraw['url']}" "${repo_unraw['specifier']}"
    else
        case "${rep}" in
            *"githubusercontent"*) repo.unraw_types "${rep}" "github" ;;
            *"gitlab"*) repo.unraw_types "${rep}" "gitlab" ;;
            *"git.sr.ht"*) repo.unraw_types "${rep}" "sourcehut" ;;
            *"codeberg"*) repo.unraw_types "${rep}" "codeberg" ;;
            *) repo.unraw_types "${rep}" "UNSET" ;;
        esac
    fi
}

# Something like `repo.get_where alias "foo"`
function repo.get_where() {
    { ignore_stack=true; set -o pipefail; trap stacktrace ERR RETURN; }
    local where="${1:?no type passed}" name="${2:?no specifier or alias passed}" line
    ```
    while IFS= read -r line; do
        local -A get_where
        repo.split_components "${line}" "get_where"
        case "${where}" in
            "specifier") if [[ "${get_where['specifier']}" == "${name}" ]]; then echo "${get_where['url']}"; fi ;;
            "alias") if [[ "${get_where['alias']}" == "${name}" ]]; then echo "${get_where['url']}"; fi ;;
            *) fancy_message error "'repo.get_where' valid types are: 'alias', 'specificer'; return 1 ;;
        esac
        unset get_where
    done < "${SCRIPTDIR}/repo/pacstallrepo"
}

function repo.get_all_type() {
    { ignore_stack=true; set -o pipefail; trap stacktrace ERR RETURN; }
    local type="${1}" line
    while IFS= read -r line; do
        local -A get_all_type
        repo.split_components "${line}" "get_all_type"
        case "${type}" in
            "specifier") if [[ -n "${get_all_type['specifier']}" ]]; then echo "${get_all_type['specifier']}"; fi ;;
            "url") if [[ -n "${get_all_type['url']}" ]]; then echo "${get_all_type['url']}"; fi ;;
            "alias") if [[ -n "${get_all_type['alias']}" ]]; then echo "${get_all_type['alias']}"; fi ;;
        esac
        unset get_all_type
    done < "${SCRIPTDIR}/repo/pacstallrepo"
}

# vim:set ft=sh ts=4 sw=4 et:
