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

# @file srcinfo.sh
# @brief A library for parsing SRCINFO into native bash dictionaries.
# @description
#   This library is used for parsing SRCINFO into native bash dictionaries.
#   Since Bash as of now does not have multidimensional arrays, srcinfo_bash
#   takes a lot of liberties with creating arrays, and tries its hardest to make
#   them easy to access.
#
# @credits Yoinked from https://github.com/Elsie19/srcinfo_bash

# @description Split a key value pair into an associated array.
#
# @example
#   declare -A out
#   srcinfo.parse_key_val 'foo = bar' out
#
# @arg $1 string Key value assignment
# @arg $2 string Name of associated array
function srcinfo.parse_key_val() {
    local key value input="${1}"
    declare -n out_array="${2}"
    key="${input%%=*}"
    value="${input#*=}"
    key="${key#"${key%%[![:space:]]*}"}"
    key="${key%"${key##*[![:space:]]}"}"
    value="${value#"${value%%[![:space:]]*}"}"
    value="${value%"${value##*[![:space:]]}"}"
    # shellcheck disable=SC2034
    out_array=([key]="${key}" [value]="${value}")
}

function srcinfo._basic_check() {
    [[ ${1} == *"="* ]]
}

function srcinfo._contains() {
    local -n arr_name="${1}"
    local key="${2}" z
    for z in "${arr_name[@]}"; do
        if [[ ${z} == "${key}" ]]; then
            return 0
        fi
    done
    return 1
}

# @description Create array based on input
#
# @example
#   srcinfo._create_array pkgbase var_name var_prefix
#
# @arg $1 string (optional) The pkgbase of the section
# @arg $2 string The variable name
# @arg $3 string (optional) The variable prefix
#
# @stdout Name of array created.
function srcinfo._create_array() {
    local pkgbase="${1}" var_name="${2}" var_pref="${3}"
    if [[ -n ${pkgbase} ]]; then
        if ! [[ -v "${var_pref}_${pkgbase}_array_${var_name}" ]]; then
            declare -ag "${var_pref}_${pkgbase}_array_${var_name}"
        fi
        echo "${var_pref}_${pkgbase}_array_${var_name}"
    else
        if ! [[ -v "${var_pref}_array_${var_name}" ]]; then
            declare -ag "${var_pref}_array_${var_name}"
        fi
        echo "${var_pref}_array_${var_name}"
    fi
}

# @description Promote array to variable
#
# @example
#   foo=('bar')
#   srcinfo._promote_to_variable foo
#
# @arg $1 string Name of array to promote
function srcinfo._promote_to_variable() {
    local var_name="${1}" key value
    key="${var_name}"
    value="${!var_name[0]}"
    declare -g "${key}=${value}"
}

function srcinfo.parse() {
    # We need this for trimming whitespace without external tools.
    shopt -s extglob
    local srcinfo_file var_prefix locbase temp_array ref total_list loop part i part_two split_up
    srcinfo_file="${1:?No .SRCINFO passed to srcinfo.parse}"
    var_prefix="${2:?Variable prefix not passed to srcinfo.parse}"
    srcinfo.cleanup "${var_prefix}"
    [[ ! -s ${srcinfo_file} ]] && return 5
    while IFS= read -r line; do
        # Skip blank lines
        [[ -z ${line} ]] && continue
        [[ ${line} =~ ^\s*#.* ]] && continue
        # Trim leading whitespace.
        line="${line##+([[:space:]])}"
        declare -A temp_line
        if ! srcinfo._basic_check "${line}"; then
            echo "Could not parse line: '${line}'" >&2
            return 3
        fi
        srcinfo.parse_key_val "${line}" temp_line
        if [[ -z ${temp_line[value]} ]]; then
            echo "Empty value for: '${line}'" >&2
            return 4
        fi
        # Define pkgbase first, it must be the first thing listed
        if [[ -z ${globase} ]]; then
            # Do we have pkgbase first?
            if [[ ${temp_line[key]} == "pkgbase" ]]; then
                locbase="pkgbase_${temp_line[value]//-/_}"
                export globase="${temp_line[value]}"
            else
                locbase="${temp_line[value]//-/_}"
                export globase="temporary_pacstall_pkgbase"
            fi
        elif [[ ${temp_line[key]} == *"pkgname" ]]; then
            # Bash can't have dashes in variable names
            locbase="${temp_line[value]//-/_}"
        fi
        # Next we need to parse out individual keys.
        # So the strategy is to create arrays of every key and at the end,
        # we can promote array.len() == 1 to variables instead. After that we
        # can work back upwards.
        temp_array="$(srcinfo._create_array "${locbase}" "${temp_line[key]}" "${var_prefix}")"
        declare -n ref="${temp_array}"
        ref+=("${temp_line[value]}")
        #TODO: In the linux SRCINFO, the pkgbase pkgdesc and pkgname=linux pkgdesc
        # get merged into an array, so I suppose we need to check if both pkgbase and
        # pkgname have the same keys, and if so, use pkgname, and if not, inherit from
        # pkgbase.
        if [[ ${locbase} == "pkgbase_"* ]] || ! srcinfo._contains total_list "${temp_array}"; then
            total_list+=("${temp_array}")
        fi
    done < "${srcinfo_file}"
    declare -Ag "${var_prefix}_access"
    for loop in "${total_list[@]}"; do
        declare -n part="${loop}"
        # Are we at a new pkgname (pkgbase)?
        if [[ ${loop} == *"pkgname" || ${loop} == *"pkgbase" ]]; then
            declare -n var_name="${var_prefix}_access"
            [[ ${loop} == "${var_prefix}_pkgbase"* ]] && global="pkgbase_"
            for i in "${!part[@]}"; do
                # Create our inner part
                declare -ga "${var_prefix}_${global}${part[${i}]//-/_}"
                # Declare that relationship
                var_name["${var_prefix}_${global}${part[${i}]//-/_}"]="${var_prefix}_${global}${part[${i}]//-/_}"
            done
            unset global
        fi
    done
    for part_two in "${total_list[@]}"; do
        # Now we need to go and check every loop over, and parse it out so we get something like ("prefix", "key"), so we can then work with that.
        # But first actually we should promote single element arrays to variables
        declare -n referoo="${part_two}"
        if (("${#referoo[@]}" == 1)); then
            srcinfo._promote_to_variable "${part_two}"
        fi
        mapfile -t split_up <<< "${part_two/_array_/$'\n'}"
        declare -n addarr="${split_up[0]}"

        # So now we need to check if the thing we're trying to insert is a variable,
        # or an array.
        if [[ "$(declare -p -- "${part_two}")" == "declare -a "* ]]; then
            declare -ga "${part_two}"
            # shellcheck disable=SC2004
            addarr[${split_up[1]}]="${part_two}"
        else
            # shellcheck disable=SC2034,SC2004
            addarr[${split_up[1]}]="${!part_two}"
        fi
    done
}

function srcinfo.cleanup() {
    local var_prefix="${1:?No var_prefix passed to srcinfo.cleanup}" i z
    local main_loop_template="${var_prefix}_access" comp
    declare -n main_loop="${main_loop_template}"
    for i in "${main_loop[@]}"; do
        declare -n cleaner="${i}"
        for z in "${cleaner[@]}"; do
            unset "${var_prefix}_array_${z}"
        done
        unset cleaner
    done
    unset "${var_prefix}_access" globase global
    # So now lets clean the stragglers that we can't reasonably infer
    mapfile -t comp < <(compgen -v)
    for i in "${comp[@]}"; do
        if [[ ${i} == "${var_prefix}_"* ]]; then
            unset -v "${i}"
        fi
    done
}

# @description Reformat numbered associative array to indexed
#
# @example
#   srcinfo_depends_vala_panel_appmenu_xfce_git=(["vala-panel-appmenu-valapanel-git-0"]="gtk3")
#   srcinfo.reformat_assarr "srcinfo_depends_vala_panel_appmenu_xfce_git" "eviler"
#
#   converts to `srcinfo_depends_vala_panel_appmenu_valapanel_git=([0]="gtk3")`
#
# @arg $1 string Associative array to reformat
# @arg $2 string Name of indexed array to append to append conversion to (can be anything)
function srcinfo.reformat_assarr() {
    local pfx base ida new pfs in_name="${1}"
    local -n in_arr="${in_name}" app="${2}"
    IFS='_' read -r -a pfs <<< "${in_name}"
    for pfx in "${!in_arr[@]}"; do
        base="${pfx%-*}" ida="${pfx##*-}" new="${base//-/_}"
        app+=("$(printf "%s[%s]=\"%s\"\n" "${pfs[0]}_${pfs[1]}_${new}" "${ida}" "${in_arr[${pfx}]}")")
    done
}

# @description Parse a specific variable from .SRCINFO
#
# @example
#
#   srcinfo.print_var .SRCINFO source
# @arg $1 string .SRCINFO file path
# @arg $2 string Variable or Array to print
function srcinfo.print_var() {
    local srcinfo_file="${1}" found="${2}" var_prefix="srcinfo" pkgbase output var name idx evil eviler e printed
    local -n bases="${var_prefix}_access"
    srcinfo.parse "${srcinfo_file}" "${var_prefix}"
    if [[ ${found} == "pkgbase" ]]; then
        if [[ -n ${globase} && ${globase} != "temporary_pacstall_pkgbase" ]]; then
            pkgbase="${globase}"
            declare -p pkgbase
            return 0
        else
            return 3
        fi
    fi
    for var in "${bases[@]}"; do
        declare -n output="${var}_array_${found}"
        declare -n name="${var}_array_pkgname"
        if [[ -n ${output[*]} ]]; then
            for idx in "${!output[@]}"; do
                if ((${#bases[@]} > 1)); then
                    # shellcheck disable=SC2076
                    if [[ ${var} =~ "pkgbase_${globase//-/_}" ]]; then
                        evil+=("$(printf "${var_prefix}_${found}_${globase//-/_}[\"${globase}-pkgbase-%d\"]=\"%s\"\n" "${idx}" "${output[${idx}]}")")
                    else
                        evil+=("$(printf "${var_prefix}_${found}_${globase//-/_}[\"${name}-%d\"]=\"%s\"\n" "${idx}" "${output[${idx}]}")")
                    fi
                else
                    evil+=("$(printf "${var_prefix}_${found}_${name//-/_}[\"${name}-%d\"]=\"%s\"\n" "${idx}" "${output[${idx}]}")")
                fi
            done
        fi
    done
    if [[ -n ${globase} && ${globase} != "temporary_pacstall_pkgbase" ]]; then
        unset "${var_prefix}_${found}_${globase//-/_}"
        declare -Ag "${var_prefix}_${found}_${globase//-/_}"
    else
        unset "${var_prefix}_${found}_${name//-/_}"
        declare -Ag "${var_prefix}_${found}_${name//-/_}"
    fi
    # shellcheck disable=SC2294
    eval "${evil[@]}"
    if [[ -n ${globase} && ${globase} != "temporary_pacstall_pkgbase" ]]; then
        srcinfo.reformat_assarr "${var_prefix}_${found}_${globase//-/_}" "eviler"
        unset "${var_prefix}_${found}_${globase//-/_}"
        # shellcheck disable=SC2294
        eval "${eviler[@]}"
    else
        srcinfo.reformat_assarr "${var_prefix}_${found}_${name//-/_}" "eviler"
        unset "${var_prefix}_${found}_${name//-/_}"
        # shellcheck disable=SC2294
        eval "${eviler[@]}"
    fi
    for e in "${eviler[@]}"; do
        if ! srcinfo._contains printed "${e%\[*}"; then
            printed+=("${e%\[*}")
            declare -p "${e%\[*}"
        fi
        unset "${e%\[*}"
    done
}

# @description Output a specific variable from .SRCINFO
#
# @example
#
#   srcinfo.match_pkg .SRCINFO pkgbase
#   srcinfo.match_pkg .SRCINFO pkgdesc $(srcinfo.match_pkg .SRCINFO pkgbase)
# @arg $1 string .SRCINFO file path
# @arg $2 string Variable or Array to search
# @arg $3 string Package name or base to get output for
srcinfo.match_pkg() {
    local declares d bases b guy match out srcfile="${1}" search="${2}" pkg="${3}"
    if [[ ${pkg} == "pkgbase:"* || ${search} == "pkgbase" ]]; then
        pkg="${pkg/pkgbase:/}"
        match="srcinfo_${search}_${pkg//-/_}_pkgbase"
    else
        match="srcinfo_${search}_${pkg//-/_}"
    fi
    mapfile -t declares < <(srcinfo.print_var "${srcfile}" "${search}" | awk '{sub(/^declare -a |^declare -- /, ""); print}')
    [[ ${search} == "pkgbase" && -z ${declares[*]} ]] \
        && mapfile -t declares < <(srcinfo.print_var "${srcfile}" "pkgname" | awk '{sub(/^declare -a |^declare -- /, ""); print}')
    for d in "${declares[@]}"; do
        if [[ "${d%=\(*}" =~ = ]]; then
            declare -- "${d}"
            bases+=("${d%=*}")
        else
            declare -a "${d}"
            bases+=("${d%=\(*}")
        fi
    done
    for b in "${bases[@]}"; do
        guy="${b}[@]"
        if [[ -z "${pkg}" ]]; then
            if [[ ${search} == "pkgname" || ${search} == "pkgbase" ]]; then
                if [[ -n ${pkgbase} ]]; then
                    out="${pkgbase/\"/}"
                    out="${out/\"/}"
                    echo "pkgbase:${out}"
                    continue
                fi
                echo "${!guy}"
                continue
            else
                echo "${guy}"
                continue
            fi
        fi
        [[ ${b} == "${match}" ]] && echo "${!guy}"
    done
}
# vim:set ft=sh ts=4 sw=4 noet:
