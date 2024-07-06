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

function repo_split_components() {
    local line="${1:?No line passed}" prefix="${2:?No prefix passed}" split
    mapfile -t split <<< "${line// /$'\n'}"
    # We're assuming the line has been syntactically checked.
    if ((${#split[@]} == 1)); then
        declare -g "${prefix}_url"="${split[0]}"
    # Then we either have a specifier + url, or a url + alias
    elif ((${#split[@]} == 2)); then
        # Do we have a specifier
        if [[ ${split[0]:0:1} == '[' ]]; then
            declare -g "${prefix}_specifier"="${split[0]:1:-1}"
            declare -g "${prefix}_url"="${split[1]}"
        # Then we have a url + alias
        else
            declare -g "${prefix}_url"="${split[0]}"
            declare -g "${prefix}_alias"="${split[1]:1}"
        fi
    # We have everything
    else
        declare -g "${prefix}_specifier"="${split[0]:1:-1}"
        declare -g "${prefix}_url"="${split[1]}"
        declare -g "${prefix}_alias"="${split[2]:1}"
    fi
}

# vim:set ft=sh ts=4 sw=4 et:
