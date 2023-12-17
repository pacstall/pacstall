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

# https://stackoverflow.com/a/17841619/13449010
function dep_const.join_by() {
    local d="${1-}" f="${2-}"
    if shift 2; then
        printf "%s" "${f}" "${@/#/$d}"
    fi
}

function dep_const.pipe_split() {
    local pipe_str="${1}"
    local -n out_var_pipe="${2}"
    mapfile -t out_var_pipe <<< "${pipe_str//\|/$'\n'}"
}

function dep_const.split_name_and_version() {
    local string="${1}"
    local -n out_var="${2}"
    case "${string}" in
        *"<="*) out_var=("${string%%<=*}" "${string##*<=}") ;;
        *">="*) out_var=("${string%%>=*}" "${string##*>=}") ;;
        *"="*) out_var=("${string%%=*}" "${string##*=}") ;;
        *"<"*) out_var=("${string%%<*}" "${string##*<}") ;;
        *">"*) out_var=("${string%%>*}" "${string##*>}") ;;
    esac
}

# The goal of this is to be able to recieve a list of pipes and to put back
# a single package that satifies the list.
function dep_const.get_pipe() {
    local string="${1}" pkg
    local the_array=() formatted=()
    dep_const.pipe_split "${string}" the_array
    for pkg in "${the_array[@]}"; do
        dep_const.format_version "${pkg}" formatted
    done
    for pkg in "${formatted[@]}"; do
        if is_apt_package_installed "${pkg}"; then
            echo "${pkg}"
            return 0
        fi
    done
    # If we haven't got an installed package, select the first one to be used.
    echo "${formatted[0]}"
}

function dep_const.strip_description() {
    local -n desc_out="${2}"
    printf -v desc_out "%s" "${1%%: *}"
}

function dep_const.format_version() {
    local str="${1}" const relation pkg_stuff=() constraints=('<=' '>=' '=' '<' '>')
    local -n out_arr="${2}"
    for const in "${constraints[@]}"; do
        if [[ $str == *"${const}"* ]]; then
            if [[ ${const} =~ ^(<|>)$ ]]; then
                # Debian wants << and >> in the control file instead of < and >, idk why but yeah
                relation="${const}${const}"
            else
                relation="${const}"
            fi
            dep_const.split_name_and_version "${str}" pkg_stuff
            out_arr+=("${pkg_stuff[0]} (${relation} ${pkg_stuff[1]})")
            break
        # Are we at the last element in constraints[@]? If so, that means we have a normal string
        elif [[ ${const} == "${constraints[-1]}" ]]; then
            out_arr+=("${str}")
        fi
    done
}

function dep_const.format_control() {
    local i z strip pipes=() formatted_pipes=() dep_arr=()
    local -n deps="${1}"
    local -n out="${2}"
    for i in "${deps[@]}"; do
        unset formatted_pipes
        # We can strip out the description because the only people that need it are maintainers.
        dep_const.strip_description "${i}" strip
        # Regex to check for pipe delimited strings and that the last char is not a pipe.
        if [[ $strip =~ ^[[:alnum:]]+[[:alnum:]\|].*[^|]+$ ]]; then
            dep_const.pipe_split "${strip}" pipes
            for z in "${pipes[@]}"; do
                dep_const.format_version "${z}" formatted_pipes
            done
            dep_arr+=("$(dep_const.join_by ' | ' "${formatted_pipes[@]}")")
        else
            dep_const.format_version "${strip}" dep_arr
        fi
    done
    out=("${dep_arr[@]}")
}
