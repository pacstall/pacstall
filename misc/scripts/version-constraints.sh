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

# @description Checks if a package is compatible with given constraint
# @internal
#
# @example
#   dep_const.apt_compare_to_constraints "pkg>=1.0.0"
#
# @arg $1 string A versioned string.
function dep_const.apt_compare_to_constraints() {
    { ignore_stack=false; set -o pipefail; trap stacktrace ERR RETURN; }
    local compare_pkg="${1}" split_up=() pkg_version stripped ret
    dep_const.strip_description "${compare_pkg}" stripped
    dep_const.split_name_and_version "${stripped}" split_up
    if ((${#split_up[@]} == 1)); then
        return 0
    fi
    if is_apt_package_installed "${split_up[0]}"; then
        pkg_version="$(dpkg-query --showformat='${Version}' --show "${split_up[0]}")"
    else
        pkg_version="$(aptitude search --quiet --disable-columns "?exact-name(${split_up[0]%:*})?architecture($(dep_const.get_arch "${split_up[0]}"))" -F "%V")"
        if [[ -z ${pkg_version} ]]; then
            pkg_version="$(aptitude search --quiet --disable-columns "?provides(^${split_up[0]%:*}$)?architecture($(dep_const.get_arch "${split_up[0]}"))" -F "%V")"
        fi
    fi
    case "${compare_pkg}" in
        # Example: foo@1.2.4 where foo<=1.2.5 should return true, because 1.2.4 is less than 1.2.5
        *"<="*) dpkg --compare-versions "${pkg_version}" le "${split_up[1]}"; ret=$? ;;
        *">="*) dpkg --compare-versions "${pkg_version}" ge "${split_up[1]}"; ret=$? ;;
        *"="*) dpkg --compare-versions "${pkg_version}" eq "${split_up[1]}"; ret=$? ;;
        *"<"*) dpkg --compare-versions "${pkg_version}" lt "${split_up[1]}"; ret=$? ;;
        *">"*) dpkg --compare-versions "${pkg_version}" gt "${split_up[1]}"; ret=$? ;;
    esac
    { ignore_stack=true; return "${ret}"; }
}

function dep_const.get_arch() {
    { ignore_stack=false; set -o pipefail; trap stacktrace ERR RETURN; }
    if [[ $1 == *":"* ]]; then
        echo "${1##*:}"
    else
        dpkg --print-architecture
    fi
}

# https://stackoverflow.com/a/17841619/13449010
function dep_const.join_by() {
    { ignore_stack=false; set -o pipefail; trap stacktrace ERR RETURN; }
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
    { ignore_stack=false; set -o pipefail; trap stacktrace ERR RETURN; }
    local pipe_str="${1}"
    local -n out_var_pipe="${2}"
    # shellcheck disable=SC2034
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
    { ignore_stack=false; set -o pipefail; trap stacktrace ERR RETURN; }
    local -n input_arr="${1}"
    local -n output_str="${2}"
    printf -v output_str '%s, ' "${input_arr[@]}"
    printf -v output_str '%s' "${output_str%, }"
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
    { ignore_stack=false; set -o pipefail; trap stacktrace ERR RETURN; }
    local string="${1}"
    local -n out_var="${2}"
    # shellcheck disable=SC2034
    case "${string}" in
        *"<="*) out_var=("${string%%<=*}" "${string##*<=}") ;;
        *">="*) out_var=("${string%%>=*}" "${string##*>=}") ;;
        *"="*) out_var=("${string%%=*}" "${string##*=}") ;;
        *"<"*) out_var=("${string%%<*}" "${string##*<}") ;;
        *">"*) out_var=("${string%%>*}" "${string##*>}") ;;
        *) out_var=("${string}") ;;
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
    { ignore_stack=false; set -o pipefail; trap stacktrace ERR RETURN; }
    local string="${1}" pkg the_array=() viable_packages=() check_name=()
    dep_const.pipe_split "${string}" the_array
    for pkg in "${the_array[@]}"; do
        if dep_const.apt_compare_to_constraints "${pkg}"; then
            dep_const.split_name_and_version "${pkg}" check_name
            if is_package_installed "${check_name[0]}" || is_apt_package_installed "${check_name[0]}"; then
                echo "${pkg}"
                return 0
            else
                if [[ -n "$(aptitude search --quiet --disable-columns "?exact-name(${check_name[0]%:*})?architecture($(dep_const.get_arch "${check_name[0]}"))" -F "%p")" ]]; then
                    viable_packages+=("${pkg}")
                fi
            fi
        fi
    done
    if [[ -n ${viable_packages[*]} ]]; then
        echo "${viable_packages[0]}"
    fi
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
    { ignore_stack=false; set -o pipefail; trap stacktrace ERR RETURN; }
    local -n desc_out="${2}"
    # shellcheck disable=SC2034
    printf -v desc_out "%s" "${1%%: *}"
}

# @description Extracts description from string
# @internal
#
# @example
#   dep_const.extract_description "foo: description for foo" doo
#
# @arg $1 string A string description.
# @arg $2 string A variable to output the description to.
function dep_const.extract_description() {
    { ignore_stack=false; set -o pipefail; trap stacktrace ERR RETURN; }
    local -n desc_ext="${2}"
    # shellcheck disable=SC2034
    printf -v desc_ext "%s" "${1##*: }"
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
    { ignore_stack=false; set -o pipefail; trap stacktrace ERR RETURN; }
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
            if [[ ${str} =~ \(.+\) ]]; then
                out_arr+=("${pkg_stuff[0]} ${relation} ${pkg_stuff[1]}")
            else
                out_arr+=("${pkg_stuff[0]} (${relation} ${pkg_stuff[1]})")
            fi
            break
        # Are we at the last element in constraints[@]? If so, that means we have a normal string
        elif [[ ${const} == "${constraints[-1]}" ]]; then
            out_arr+=("${str}")
        fi
    done
}

function dep_const.is_pipe() {
    { ignore_stack=false; set -o pipefail; trap stacktrace ERR RETURN; }
    if perl -ne 'exit 1 unless /^(?:[^\s|:]+(?::[^\s|:]+)?\s\|\s)+[^\s|:]+(?::[^\s|:]+)?(?::\s[^|:]+)?(?<!\s)$/' <<< "$1"; then
        return 0
    else
        { ignore_stack=true; return 1; }
    fi
}

# @description Formats an array into a control file compatible list
# @internal
#
# @example
#   foo=("opt:amd64>=1.2.3 | bruh:arm64<1.2.0: optdepends string" "blorg>=1.2.3 | larp<=0.0.1")
#   dep_const.format_control foo out
#   declare -p out
#   declare -a out=([0]="opt:amd64 (>= 1.2.3) | bruh:arm64 (<< 1.2.0)" [1]="blorg (>= 1.2.3) | larp (<= 0.0.1)")
#
# @arg $1 string An array name.
# @arg $2 string An array name to output to.
function dep_const.format_control() {
    # shellcheck disable=SC2034
    { ignore_stack=false; set -o pipefail; trap stacktrace ERR RETURN; }
    local i z strip pipes=() formatted_pipes=() dep_arr=()
    local -n deps="${1}"
    local -n out="${2}"
    for i in "${deps[@]}"; do
        unset formatted_pipes
        # We can strip out the description because the only people that need it are maintainers.
        dep_const.strip_description "${i}" strip
        # Regex to check for spaced pipe delimited strings ('this | that') and that the last char is not a pipe.
        if dep_const.is_pipe "${strip}"; then
            dep_const.pipe_split "${strip}" pipes
            for z in "${pipes[@]}"; do
                dep_const.format_version "${z}" formatted_pipes
            done
            dep_arr+=("$(dep_const.join_by ' | ' "${formatted_pipes[@]}")")
        else
            dep_const.format_version "${strip}" dep_arr
        fi
    done
    # shellcheck disable=SC2034
    out=("${dep_arr[@]}")
}
# vim:set ft=sh ts=4 sw=4 et:
