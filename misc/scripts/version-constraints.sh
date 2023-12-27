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

# @description Checks if a package is compatible with given constraint
# @internal
#
# @example
#   dep_const.apt_compare_to_constraints "pkg>=1.0.0"
#
# @arg $1 string A versioned string.
function dep_const.apt_compare_to_constraints() {
    local compare_pkg="${1}" split_up=() pkg_version
    dep_const.split_name_and_version "${compare_pkg}" split_up
    if is_apt_package_installed "${split_up[0]}"; then
        pkg_version="$(dpkg-query --showformat='${Version}' --show "${split_up[0]}")"
    else
        pkg_version="$(aptitude search "${split_up[0]}" -F "%V")"
    fi
    case "${compare_pkg}" in
        # Example: foo@1.2.4 where foo<=1.2.5 should return true, because 1.2.4 is less than 1.2.5
        *"<="*) dpkg --compare-versions "${split_up[0]}" le "${pkg_version}" ;;
        *">="*) dpkg --compare-versions "${split_up[0]}" ge "${pkg_version}" ;;
        *"="*) dpkg --compare-versions "${split_up[0]}" eq "${pkg_version}" ;;
        *"<"*) dpkg --compare-versions "${split_up[0]}" lt "${pkg_version}" ;;
        *">"*) dpkg --compare-versions "${split_up[0]}" gt "${pkg_version}" ;;
    esac
}

# https://stackoverflow.com/a/17841619/13449010
function dep_const.join_by() {
    local d="${1-}" f="${2-}"
    if shift 2; then
        printf "%s" "${f}" "${@/#/$d}"
    fi
}

# @description Splits a pipe delimited string into newlines
# @internal
#
# @example
#   dep_const.pipe_split "foo | bar | baz" out_array
#
# @arg $1 string A pipe delimited string.
# @arg $2 string An array name to save split into.
function dep_const.pipe_split() {
    local pipe_str="${1}"
    local -n out_var_pipe="${2}"
    mapfile -t out_var_pipe <<< "${pipe_str// \| /$'\n'}"
}

# @description Formats a bash array into a control file array style
# @internal
#
# @example
#   dep_const.comma_array input_arr output_str
#
# @arg $1 string A bash array.
# @arg $2 string An output string.
function dep_const.comma_array() {
    local -n input_arr="${1}"
    local -n output_str="${2}"
    local loopie ctr=1
    printf -v output_str '%s, ' "${input_arr[@]}"
    printf -v output_str '%s\n' "${output_str%, }"
}

# @description Splits a versioned package into its name and version
# @internal
#
# @example
#   dep_const.split_name_and_version "pkg>=1.0.0" out_array
#
# @arg $1 string A versioned package.
# @arg $2 string An array name to save name and version into.
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

# @description Returns the best package based on an alt dependency string
# @internal
#
# @example
#   dep_const.get_pipe "mutt | nala"
#
# @arg $1 string A pipe delimited string of packages.
#
# @stdout A best chosen package name
#
# How this works is that we loop through the list and check if it is installed, and if so,
# we use that, if not, we go to the next one, and repeat. If no package is installed, we choose list[0].
function dep_const.get_pipe() {
    local string="${1}" pkg
    local the_array=() formatted=()
    dep_const.pipe_split "${string}" the_array
    for pkg in "${the_array[@]}"; do
        dep_const.format_version "${pkg}" formatted
    done
    for pkg in "${formatted[@]}"; do
        if is_package_installed "${pkg}"; then
            echo "${pkg}"
            return 0
        fi
    done
    # If we haven't got an installed package, select the first one to be used.
    echo "${formatted[0]}"
}

# @description Removes description from string
# @internal
#
# @example
#   dep_const.strip_description "foo: description for foo" boo
#
# @arg $1 string A string description.
# @arg $2 string A variable to output the package to.
function dep_const.strip_description() {
    local -n desc_out="${2}"
    printf -v desc_out "%s" "${1%%: *}"
}

# @description Formats a string into a control file compatible version string
# @internal
#
# @example
#   dep_const.format_version "pkg>=1.2.3"
#   dep_const.format_version "pkg<=0.0.1"
#
# @arg $1 string A versioned string.
# @arg $2 string An array name to append to.
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

# @description Formats an array into a control file compatible list
# @internal
#
# @example
#	foo=("opt:amd64>=1.2.3 | bruh:arm64<1.2.0: optdepends string" "blorg>=1.2.3 | larp<=0.0.1")
#   dep_const.format_control foo out
#   declare -p out
#   declare -a out=([0]="opt:amd64 (>= 1.2.3) | bruh:arm64 (<< 1.2.0)" [1]="blorg (>= 1.2.3) | larp (<= 0.0.1)")
#
# @arg $1 string An array name.
# @arg $2 string An array name to output to.
function dep_const.format_control() {
    local i z strip pipes=() formatted_pipes=() dep_arr=()
    local -n deps="${1}"
    local -n out="${2}"
    for i in "${deps[@]}"; do
        unset formatted_pipes
        # We can strip out the description because the only people that need it are maintainers.
        dep_const.strip_description "${i}" strip
        # Regex to check for spaced pipe delimited strings ('this | that') and that the last char is not a pipe.
        if [[ ${strip} =~ ^[[:alnum:]]+[[:alnum:]\|].*\ [^|]+$ ]]; then
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
