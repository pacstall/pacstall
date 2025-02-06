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
#
# @file srcinfo.sh
# @brief A library for parsing SRCINFO into native bash dictionaries.
# @description
#   This library is used for parsing SRCINFO into native bash dictionaries.
#   Since Bash as of now does not have multidimensional arrays, srcinfo_bash
#   takes a lot of liberties with creating arrays, and tries its hardest to make
#   them easy to access.
#
# @credits
#   Based on Elsie19's srcinfo_bash
#     https://github.com/Elsie19/srcinfo_bash
#
#   Based on makepkg's pkgbuild.sh
#     Copyright (C) 2009-2024 Pacman Development Team
#     <pacman-dev@lists.archlinux.org>

{ ignore_stack=false; set -o pipefail; trap stacktrace ERR RETURN; }

function srcinfo.array_build() {
    { ignore_stack=false; set -o pipefail; trap stacktrace ERR RETURN; }
    local dest="${1}" src="${2}" i keys values
    declare -p "$2" &> /dev/null || { ignore_stack=true; return 1; }
    eval "keys=(\"\${!$2[@]}\")"
    eval "${dest}=()"
    for i in "${keys[@]}"; do
        values+=("printf -v '${dest}[${i}]' %s \"\${${src}[${i}]}\";")
    done
    eval "${values[*]}"
}

function srcinfo.extr_globvar() {
    { ignore_stack=false; set -o pipefail; trap stacktrace ERR RETURN; }
    local attr="${1}" isarray="${2}" outputvar="${3}" ref
    if ((isarray==1)); then
        srcinfo.array_build ref "${attr}"
        if ((${#ref[@]}>=1)); then srcinfo.array_build "${outputvar}" "${attr}"; fi
    else
        if [[ -n ${!attr} ]]; then printf -v "${outputvar}" %s "${!attr}"; fi
    fi
}

function srcinfo.extr_fnvar() {
    { ignore_stack=false; set -o pipefail; trap stacktrace ERR RETURN; }
    local funcname="${1}" attr="${2}" isarray="${3}" outputvar="${4}"
    local attr_regex decl r=1
    if ((isarray==1)); then
        printf -v attr_regex '^[[:space:]]* %s\+?=\(' "${attr}"
    else
        printf -v attr_regex '^[[:space:]]* %s\+?=[^(]' "${attr}"
    fi
    local func_body
    func_body=$(declare -f "${funcname}" 2> /dev/null)
    [[ -z ${func_body} ]] && { ignore_stack=true; return 1; }
    IFS=$'\n' read -r -d '' -a lines <<< "${func_body}"
    for line in "${lines[@]}"; do
        [[ ${line} =~ ${attr_regex} ]] || continue
        decl=${line##*([[:space:]])}
        eval "${decl/#${attr}/${outputvar}}"
        r=0
    done
    { ignore_stack=true; return "${r}"; }
}

function srcinfo.get_attr() {
    { ignore_stack=false; set -o pipefail; trap stacktrace ERR RETURN; }
    local pkgname="${1}" attrname="${2}" isarray="${3}" outputvar="${4}"
    if ((isarray==1)); then
        eval "${outputvar}=()"
    else
        printf -v "${outputvar}" %s ''
    fi
    if [[ -n ${pkgname} ]]; then
        srcinfo.extr_globvar "${attrname}" "${isarray}" "${outputvar}"
        if is_function "package_${pkgname}"; then
            srcinfo.extr_fnvar "package_${pkgname}" "${attrname}" "${isarray}" "${outputvar}" || { ignore_stack=true; return 1; }
        fi
    else
        srcinfo.extr_globvar "${attrname}" "${isarray}" "${outputvar}"
    fi
}

function srcinfo.write_attr() {
    { ignore_stack=false; set -o pipefail; trap stacktrace ERR RETURN; }
    local attrname="${1}" attrvalues=("${@:2}")
    attrvalues=("${attrvalues[@]//+([[:space:]])/ }")
    attrvalues=("${attrvalues[@]#[[:space:]]}")
    attrvalues=("${attrvalues[@]%[[:space:]]}")
    if [[ -n "${attrvalues[*]}" ]]; then
        printf "\t${attrname} = %s\n" "${attrvalues[@]}"
    fi
}

function srcinfo.extract() {
    { ignore_stack=false; set -o pipefail; trap stacktrace ERR RETURN; }
    local pkgname="${1}" attrname="${2}" isarray="${3}" outvalue
    if srcinfo.get_attr "${pkgname}" "${attrname}" "${isarray}" 'outvalue'; then
        srcinfo.write_attr "${attrname}" "${outvalue[@]}"
    fi
}

function srcinfo.write_details() {
    { ignore_stack=false; set -o pipefail; trap stacktrace ERR RETURN; }
    local attr package_arch a
    for attr in "${singlevalued[@]}"; do
        srcinfo.extract "$1" "${attr}" 0
    done

    for attr in "${multivalued[@]}"; do
        srcinfo.extract "$1" "${attr}" 1
    done

    srcinfo.get_attr '' 'arch' 1 'package_arch' || package_arch=("all")
    for a in "${package_arch[@]}"; do
        [[ ${a} == any || ${a} == all ]] && continue

        for attr in "${multivalued_arch_attrs[@]}"; do
            srcinfo.extract "$1" "${attr}_${a}" 1
        done
    done
}

function srcinfo.vars() {
    { ignore_stack=false; set -o pipefail; trap stacktrace ERR RETURN; }
    local _distros _vars _archs _sums distros \
        vars="gives depends makedepends optdepends pacdeps checkdepends provides conflicts breaks replaces enhances recommends suggests makeconflicts checkconflicts source" \
        sums="b2 sha512 sha384 sha256 sha224 sha1 md5"
    allvars=(pkgname gives pkgver pkgrel epoch pkgdesc url priority)
    allars=(arch depends makedepends checkdepends optdepends pacdeps conflicts makeconflicts checkconflicts breaks replaces provides enhances recommends suggests incompatible compatible backup mask noextract nosubmodules license maintainer repology custom_fields source)
    # shellcheck disable=SC2124
    distros="${PACSTALL_KNOWN_DISTROS[@]}"
    _distros="{${distros// /,}}" _vars="{${vars// /,}}" _sums="{${sums// /,}}"
    eval "allars+=(${_sums}sums ${_vars}_${_distros} ${_sums}sums_${_distros})"
    eval "allvars+=(gives_${_distros})"
    eval "multivalued_arch_attrs=(${vars} ${_sums}sums ${_vars}_${_distros} ${_sums}sums_${_distros})"
}

function srcinfo.write_global() {
    { ignore_stack=false; set -o pipefail; trap stacktrace ERR RETURN; }
    # shellcheck disable=SC2034
    local CARCH='CARCH_REPLACE' DISTRO="${DISTRO}" CDISTRO="${CDISTRO}" AARCH='AARCH_REPLACE' var ar aars bar ars rar rep seek multilist
    local -A AARCHS_MAP=(
        ["amd64"]="x86_64"
        ["arm64"]="aarch64"
        ["armel"]="arm"
        ["armhf"]="armv7h"
        ["i386"]="i686"
        ["mips64el"]="mips64el"
        ["ppc64el"]="ppc64el"
        ["riscv64"]="riscv64"
        ["s390x"]="s390x"
    )
    local -A CARCHS_MAP=(
        ["x86_64"]="amd64"
        ["aarch64"]="arm64"
        ["arm"]="armel"
        ["armv7h"]="armhf"
        ["i686"]="i386"
        ["mips64el"]="mips64el"
        ["ppc64el"]="ppc64el"
        ["riscv64"]="riscv64"
        ["s390x"]="s390x"
    )
    multilist=("${multivalued_arch_attrs[@]}")
    for i in "${multivalued_arch_attrs[@]}"; do
        for j in {amd64,x86_64,arm64,aarch64,armel,arm,armhf,armv7h,i386,i686,mips64el,ppc64el,riscv64,s390x}; do
          multilist+=("${i}_${j}")
        done
    done
    for ar in "${multilist[@]}"; do
        local -n bar="${ar}"
        if [[ -n ${bar[*]} ]]; then
            for ars in "${bar[@]}"; do
                ars="${ars//+([[:space:]])/ }"
                ars="${ars#[[:space:]]}"
                ars="${ars%[[:space:]]}"
                if [[ ${ars} =~ CARCH_REPLACE || ${ars} =~ AARCH_REPLACE ]]; then
                    [[ -z ${arch[*]} ]] && arch=('amd64')
                    for aars in "${arch[@]}"; do
                        if [[ ${ars} =~ AARCH_REPLACE ]]; then
                            seek="AARCH_REPLACE"
                            if [[ " ${AARCHS_MAP[*]} " =~ ${aars} ]]; then
                                rep="${aars}"
                            else
                                rep="${AARCHS_MAP[${aars}]}"
                            fi
                        else
                            seek="CARCH_REPLACE"
                            if [[ " ${AARCHS_MAP[*]} " =~ ${aars} ]]; then
                                rep="${CARCHS_MAP[${aars}]}"
                            else
                                rep="${aars}"
                            fi
                        fi
                        local -n fin="${ar}_${rep}"
                        # shellcheck disable=SC2076
                        if [[ " ${AARCHS_MAP[*]} " =~ " ${ar##*_} " || " ${!AARCHS_MAP[*]} " =~ " ${ar##*_} " || ${ar} == *"x86_64" ]]; then
                            : "${ar}=${ars}"
                            [[ ${ar} != *"${aars}" ]] && continue
                        else
                            : "${ar}_${aars}=${ars}"
                        fi
                        if [[ -z ${fin[*]} ]]; then
                            eval "${_//${seek}/${rep}}"
                        fi
                    done
                    # shellcheck disable=SC2076
                    if [[ " ${multivalued_arch_attrs[*]} " =~ " ${ar} " ]]; then
                        unset "${ar}"
                    fi
                fi
            done
        fi
    done
    local singlevalued=("${allvars[@]}")
    local multivalued=("${allars[@]}")
    printf '%s = %s\n' 'pkgbase' "${pkgbase:-${pkgname}}"
    srcinfo.write_details ''
}

function srcinfo.write_package() {
    { ignore_stack=false; set -o pipefail; trap stacktrace ERR RETURN; }
    local singlevalued=(gives pkgdesc url priority)
    local multivalued=(arch license depends checkdepends optdepends pacdeps
        provides checkconflicts conflicts breaks replaces enhances recommends suggests backup repology)
    printf '%s = %s\n' 'pkgname' "$1"
    srcinfo.write_details "$1"
}

function srcinfo.gen() {
    { ignore_stack=false; set -o pipefail; trap stacktrace ERR RETURN; }
    local pkg
    srcinfo.write_global
    for pkg in "${pkgname[@]}"; do
        echo
        srcinfo.write_package "${pkg}"
    done
}

# @description Split a key value pair into an associated array.
#
# @example
#   declare -A out
#   srcinfo.parse_key_val 'foo = bar' out
#
# @arg $1 string Key value assignment
# @arg $2 string Name of associated array
function srcinfo.parse_key_val() {
    { ignore_stack=false; set -o pipefail; trap stacktrace ERR RETURN; }
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
    { ignore_stack=false; set -o pipefail; trap stacktrace ERR RETURN; }
    [[ ${1} == *"="* ]]
}

function srcinfo._contains() {
    { ignore_stack=false; set -o pipefail; trap stacktrace ERR RETURN; }
    local -n arr_name="${1}"
    local key="${2}" z
    for z in "${arr_name[@]}"; do
        if [[ ${z} == "${key}" ]]; then
            return 0
        fi
    done
    # shellcheck disable=SC2034
    { ignore_stack=true; return 1; }
}

# @description Create array based on input
#
# @example
#   srcinfo._create_array base var_name
#
# @arg $1 string The pkgbase of the section
# @arg $2 string The variable name
#
# @stdout Name of array created.
function srcinfo._create_array() {
    { ignore_stack=false; set -o pipefail; trap stacktrace ERR RETURN; }
    local base="${1}" var_name="${2}"
    base="${base//./_}" var_name="${var_name//./_}"
    if ! [[ -v "srcinfo_${base}_array_${var_name}" ]]; then
        declare -ag "srcinfo_${base}_array_${var_name}"
    fi
    echo "srcinfo_${base}_array_${var_name}"
}

function srcinfo.parse() {
    { ignore_stack=false; set -o pipefail; trap stacktrace ERR RETURN; }
    local srcfile access srcinfo_data locbase temp_array ref total_list loop part i suffix
    srcfile="${1:?No .SRCINFO passed to srcinfo.parse}"
    access="${2:?No output file given to srcinfo.parse}"
    srcinfo.cleanup "${PACDIR}-srcinfo-access-${access}"
    [[ ! -s ${srcfile} ]] && return 5
    mapfile -t srcinfo_data < "${srcfile}"
    for line in "${srcinfo_data[@]}"; do
        # Skip blank lines
        [[ -z ${line} || ${line} =~ ^\s*#.* ]] && continue
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
                export globase="${temp_line[value]//./_}"
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
        temp_array="$(srcinfo._create_array "${locbase}" "${temp_line[key]}")"
        declare -n ref="${temp_array}"
        ref+=("${temp_line[value]}")
        if ! srcinfo._contains total_list "${temp_array}"; then
            total_list+=("${temp_array}")
        fi
    done
    unset srcinfo_data
    for loop in "${total_list[@]}"; do
        declare -n part="${loop}"
        # Are we at a new pkgname (pkgbase)?
        if [[ ${loop} == *@(pkgname|pkgbase) ]]; then
            [[ ${loop} == "srcinfo_pkgbase"* ]] && global="pkgbase_"
            for i in "${!part[@]}"; do
                suffix="${global}${part[${i}]//-/_}"
                suffix="${suffix//./_}"
                # Create our inner part
                declare -ga "srcinfo_${suffix}"
            done
            unset global
        fi
    done
    declare -p "${total_list[@]}" | sudo tee -a "${PACDIR}-srcinfo-access-${access}" > /dev/null
}

function srcinfo.cleanup() {
    { ignore_stack=false; set -o pipefail; trap stacktrace ERR RETURN; }
    local compg
    mapfile -t compg < <(compgen -v "srcinfo_")
    unset "${compg[@]}" srcinfo_access globase global 2> /dev/null
    sudo rm -f "${PACDIR}-srcinfo-access-${1}"
}

# @description Output a specific variable from .SRCINFO
#
# @example
#
#   srcinfo.match_pkg ref_base pkgbase
#   srcinfo.match_pkg ref_desc pkgdesc ${ref_base}
# @arg $1 string Reference to append to
# @arg $2 string Variable or Array to search
# @arg $3 string Package name or base to get output for
function srcinfo.match_pkg() {
    { ignore_stack=false; set -o pipefail; trap stacktrace ERR RETURN; }
    local accessfile="${2}" search="${3}" pkg="${4}" output var bases d dec declares
    local -n srcref="${1}"
    mapfile -t declares < "${PACDIR}-srcinfo-access-${accessfile}"
    for d in "${declares[@]}"; do
        dec="${d##*declare -a }"
        bases+=("${dec%=\(*}")
    done
    pkg="${pkg//./_}"
    pkg="${pkg//:/_}"
    pkg="${pkg//-/_}"
    for var in "${bases[@]}"; do
        var="${var//./_}"
        declare -n output="${var}"
        if [[ -n ${output[*]} ]]; then
            if [[ ${search} == "pkgbase" ]]; then
                srcref="pkgbase:${output[0]}"
            elif [[ ${search} == "pkgname" || ${var} == "srcinfo_${pkg}_array_${search}" ]]; then
                srcref+=("${output[@]}")
            fi
        else
            srcref=()
        fi
    done
}

function srcinfo.print_out() {
    # shellcheck disable=SC2034
    { ignore_stack=false; set -o pipefail; trap stacktrace ERR RETURN; }
    (
        # We need this for trimming whitespace without external tools.
        shopt -s extglob
        srcinfo.vars
        srcinfo.gen
        shopt -u extglob
    )
}
# vim:set ft=sh ts=4 sw=4 et:
