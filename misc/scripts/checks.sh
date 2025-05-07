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

# A collection of checks to verify a pacscript is correct

{ ignore_stack=false; set -o pipefail; trap stacktrace ERR RETURN; }

function lint_pacname() {
    { ignore_stack=false; set -o pipefail; trap stacktrace ERR RETURN; }
    local ret=0
    if [[ -z $pacname ]]; then
        fancy_message error $"Package does not contain '%s'" "pacname"
        { ignore_stack=true; return 1; }
    fi
    # https://www.debian.org/doc/debian-policy/ch-controlfields.html#source
    if ((${#pacname} < 2)); then
        fancy_message error $"%s: '%s' must be at least two characters long" "pacname" "${pacname}"
        ret=1
    fi
    # shellcheck disable=SC1001
    if [[ ${pacname:0:1} == [.\-+] ]]; then
        fancy_message error $"%s: '%s' must start with an alphanumeric character" "pacname" "${pacname}"
        ret=1
    fi
    if [[ $pacname =~ [[:upper:]] ]]; then
        fancy_message error $"%s: '%s' contains uppercase characters" "pacname" "${pacname}"
        ret=1
    fi
    if [[ $pacname == *[^[:alnum:]+.-]* ]]; then
        fancy_message error $"%s: '%s' contains characters that are not lowercase, digits, minus, or periods" "pacname" "${pacname}"
        ret=1
    fi
    { ignore_stack=true; return "${ret}"; }
}

function lint_gives() {
    { ignore_stack=false; set -o pipefail; trap stacktrace ERR RETURN; }
    local ret=0
    if [[ -z $gives && $pacname == *-deb ]]; then
        fancy_message warn $"Deb package does not contain gives"
        ret=1
    fi
    if [[ -n $gives ]]; then
        # https://www.debian.org/doc/debian-policy/ch-controlfields.html#source
        if ((${#gives} < 2)); then
            fancy_message error $"'%s' must be at least two characters long" "gives"
            ret=1
        fi
        # shellcheck disable=SC1001
        if [[ ${gives:0:1} == [.\-+] ]]; then
            fancy_message error $"'%s' must start with an alphanumeric character" "gives"
            ret=1
        fi
        if [[ $gives =~ [[:upper:]] ]]; then
            fancy_message error $"'%s' contains uppercase characters" "gives"
            ret=1
        fi
        if [[ $gives == *[^[:alnum:]+.-]* ]]; then
            fancy_message error $"'%s' contains characters that are not lowercase, digits, minus, or periods" "gives"
            ret=1
        fi
    fi
    { ignore_stack=true; return "${ret}"; }
}

function lint_pkgrel() {
    { ignore_stack=false; set -o pipefail; trap stacktrace ERR RETURN; }
    local ret=0
    if [[ -v pkgrel ]]; then
        if [[ -z ${pkgrel} ]]; then
            fancy_message error $"'%s' is empty" "pkgrel"
            ret=1
        elif [[ ! ${pkgrel} =~ ^[0-9]+$ ]]; then
            fancy_message error $"'%s' must be an unsigned integer" "pkgrel"
            ret=1
        fi
    fi
    { ignore_stack=true; return "${ret}"; }
}

function lint_epoch() {
    { ignore_stack=false; set -o pipefail; trap stacktrace ERR RETURN; }
    local ret=0
    if [[ -v epoch ]]; then
        if [[ -z ${epoch} ]]; then
            fancy_message error $"'%s' is empty" "epoch"
            ret=1
        elif [[ ! ${epoch} =~ ^[0-9]+$ ]]; then
            fancy_message error $"'%s' must be an unsigned integer" "epoch"
            ret=1
        fi
    fi
    { ignore_stack=true; return "${ret}"; }
}

function lint_version() {
    { ignore_stack=false; set -o pipefail; trap stacktrace ERR RETURN; }
    local ret=0
    if [[ -n $pkgver ]]; then
        # https://www.debian.org/doc/debian-policy/ch-controlfields.html#version
        if [[ ! $pkgver =~ ^[0-9][a-zA-Z0-9.+-~]+$ ]]; then
            fancy_message error $"'%s' must contain only alphanumerics and the characters . + - ~ and should start with a digit" "pkgver"
            ret=1
        fi
    elif [[ -z $pkgver ]]; then
        fancy_message error $"Package does not contain '%s'" "pkgver"
        ret=1
    fi
    { ignore_stack=true; return "${ret}"; }
}

function lint_source_deb_test() {
    { ignore_stack=false; set -o pipefail; trap stacktrace ERR RETURN; }
    # shellcheck disable=SC2206
    local input_source=($@)
    for i in "${!input_source[@]}"; do
        local test_source_url="${input_source[$i]}"
        local file_name="${test_source_url##*/}"
        if [[ ${file_name} == *"?"* ]]; then
            file_name="${file_name%%\?*}"
        fi
        if [[ ${file_name} == *.deb ]]; then
            fancy_message error $".deb files can only be provided as a singular '%s'" "source"
            ret=1
            break
        fi
    done
}

function lint_source() {
    { ignore_stack=false; set -o pipefail; trap stacktrace ERR RETURN; }
    local ret=0 test_source has_source=0 source_distro_archs
    for source_distro in "${PACSTALL_KNOWN_DISTROS[@]}"; do
        for known_arch in "${PACSTALL_KNOWN_ARCH[@]}"; do
            source_distro_archs+=("${source_distro}_${known_arch}")
        done
    done
    if [[ -n ${source[0]} ]]; then
        has_source=1
    else
        for sarch in "${PACSTALL_KNOWN_ARCH[@]}" "${PACSTALL_KNOWN_DISTROS[@]}" "${source_distro_archs[@]}"; do
            local source_arch="source_${sarch}[@]"
            if [[ -n ${!source_arch} ]]; then
                has_source=1
                break
            fi
        done
    fi
    local source_host="source_${TARCH}[*]"
    if [[ -z ${source[*]} && -z ${!source_host} ]]; then
        has_source=0
    fi
    if ((has_source == 0)); then
        fancy_message error $"Package does not contain '%s'" "source"
        ret=1
    else
        for sarch in "${PACSTALL_KNOWN_ARCH[@]}" "${PACSTALL_KNOWN_DISTROS[@]}" "${source_distro_archs[@]}"; do
            local source_arch="source_${sarch}[@]" raw_carch_source="source_${TARCH}[@]" raw_distbase_source="source_${DISTRO%:*}[@]" \
                raw_distver_source="source_${DISTRO#*:}[@]" raw_distbase_carch_source="source_${DISTRO%:*}_${TARCH}[@]" \
                raw_distver_carch_source="source_${DISTRO#*:}_${TARCH}[@]" carch_source distbase_source distver_source distbase_carch_source distver_carch_source
            carch_source=("${!raw_carch_source}")
            distbase_source=("${!raw_distbase_source}")
            distver_source=("${!raw_distver_source}")
            distbase_carch_source=("${!raw_distbase_carch_source}")
            distver_carch_source=("${!raw_distver_carch_source}")
            [[ ${sarch} != "${TARCH}" &&
                ${sarch} != "${DISTRO%:*}" &&
                ${sarch} != "${DISTRO#*:}" &&
                ${sarch} != "${DISTRO%:*}_${TARCH}" &&
                ${sarch} != "${DISTRO#*:}_${TARCH}" ]] \
                && if [[ -n ${!source_arch} ]]; then
                    test_source=()
                    if [[ -n ${source[0]} ]]; then
                        { (("${#source[@]}" <= 1 && \
                            "${#carch_source[@]}" <= 1 && \
                            "${#distbase_source[@]}" <= 1 && \
                            "${#distver_source[@]}" <= 1 && \
                            "${#distbase_carch_source[@]}" <= 1 && \
                            "${#distver_carch_source[@]}" <= 1)) \
                                && [[ ${carch_source[0]} == "${source[0]}" ||
                                    ${distbase_source[0]} == "${source[0]}" ||
                                    ${distver_source[0]} == "${source[0]}" ||
                                    ${distbase_carch_source[0]} == "${source[0]}" ||
                                    ${distver_carch_source[0]} == "${source[0]}" ]]; } \
                            || test_source+=("${source[@]}")
                    fi
                    [[ ${pacname} == *"-deb" ]] && test_source=("${!source_arch}") || test_source+=("${!source_arch}")
                    if [[ -n ${test_source[1]} ]]; then
                        lint_source_deb_test "${test_source[@]}"
                        if ((ret == 1)); then
                            break
                        fi
                    fi
                fi
        done
        if [[ -n ${source[1]} ]]; then
            lint_source_deb_test "${source[@]}"
        fi
    fi
    { ignore_stack=true; return "${ret}"; }
}

function lint_pkgdesc() {
    { ignore_stack=false; set -o pipefail; trap stacktrace ERR RETURN; }
    local ret=0
    if [[ -z $pkgdesc ]]; then
        fancy_message error $"Package does not contain '%s'" "pkgdesc"
        ret=1
    fi
    { ignore_stack=true; return "${ret}"; }
}

function lint_maintainer() {
    { ignore_stack=false; set -o pipefail; trap stacktrace ERR RETURN; }
    if [[ -z ${maintainer[*]} ]]; then
        fancy_message warn $"Package does not have a maintainer. Please be advised"
    fi
    return 0
}

function lint_var_arch() {
    { ignore_stack=false; set -o pipefail; trap stacktrace ERR RETURN; }
    local tinp tinputvar="${1}"
    local -n test_ref_inputvar="test_${tinputvar}" tinputvar_arch="${tinputvar}_${2}${3:+_$3}"
    if [[ -n ${tinputvar_arch[*]} ]]; then
        for tinp in "${tinputvar_arch[@]}"; do
            if ! array.contains ref_inputvar "${tinp}"; then
                test_ref_inputvar+=("${tinp}")
            fi
        done
    fi
}

function lint_pipe_check() {
    { ignore_stack=false; set -o pipefail; trap stacktrace ERR RETURN; }
    perl -ne 'exit 1 unless /^(?:[^\s|:]+(?::[^\s|:]+)?\s\|\s)+[^\s|:]+(?::[^\s|:]+)?(?::\s[^|:]+)?(?<!\s)$/' <<< "$1"
}

function lint_deps() {
    { ignore_stack=false; set -o pipefail; trap stacktrace ERR RETURN; }
    local dep_type dep_array ret=0 dep idx kdarch kdistro kddarch
    for dep_type in "depends" "makedepends" "optdepends" "checkdepends" "pacdeps"; do
        local -n dep_array="test_${dep_type}"
        local -n type_array="${dep_type}"
        dep_array=("${type_array[@]}")
        for kdarch in "${PACSTALL_KNOWN_ARCH[@]}"; do
            [[ ${kdarch} != "${TARCH}" ]] && lint_var_arch "${dep_type}" "${kdarch}"
        done
        for kdistro in "${PACSTALL_KNOWN_DISTROS[@]}"; do
            if [[ ${kdistro} != "${DISTRO%:*}" && ${kdistro} != "${DISTRO#*:}" ]]; then
                lint_var_arch "${dep_type}" "${kdistro}"
                for kddarch in "${PACSTALL_KNOWN_ARCH[@]}"; do
                    [[ ${kddarch} != "${TARCH}" ]] && lint_var_arch "${dep_type}" "${kdistro}" "${kddarch}"
                done
            fi
        done
        idx=0
        if [[ -n ${dep_array[*]} ]]; then
            for dep in "${dep_array[@]}"; do
                if [[ -z ${dep} ]]; then
                    fancy_message error $"'%s' index '%s' cannot be empty" "${dep_type}" "${idx}"
                    ret=1
                elif [[ ${dep} == *"|"* ]]; then
                    if [[ ${dep_type} == "pacdeps" ]] || ! lint_pipe_check "${dep}"; then
                        fancy_message error $"'%s' index '%s' is not formatted correctly" "${dep_type}" "${idx}"
                        ret=1
                    fi
                elif [[ ${dep_type} == "optdepends" ]] && [[ ${dep} != *": "* ]]; then
                    fancy_message error $"'%s' index '%s' is not formatted correctly" "${dep_type}" "${idx}"
                    ret=1
                fi
                { ignore_stack=true; ((idx++)); }
            done
        fi
        if ((ret == 1)); then
            break
        fi
    done
    { ignore_stack=true; return "${ret}"; }
}

function lint_ppa() {
    { ignore_stack=false; set -o pipefail; trap stacktrace ERR RETURN; }
    local ret=0 el_ppa idx=0
    if [[ -n ${ppa[*]} ]]; then
        for el_ppa in "${ppa[@]}"; do
            if [[ -z ${el_ppa} ]]; then
                fancy_message error $"'%s' index '%s' cannot be empty" "ppa" "${idx}"
                ret=1
            fi
            { ignore_stack=true; ((idx++)); }
        done
        if ((ret != 0)); then
            { ignore_stack=true; return 1; }
        fi
        idx=0
        for el_ppa in "${ppa[@]}"; do
            if [[ $el_ppa =~ ^ppa: ]]; then
                fancy_message error $"'%s' index '%s' cannot start with %s" "ppa" "${idx}" "'ppa:'"
                ret=1
            fi
            { ignore_stack=true; ((idx++)); }
        done
        idx=0
        for el_ppa in "${ppa[@]}"; do
            if [[ ! $el_ppa =~ ^[a-zA-Z0-9]+\/[a-zA-Z0-9]+ ]]; then
                fancy_message error $"%s index '%s' is improperly formatted" "'ppa'" "${idx}"
                ret=1
            fi
            { ignore_stack=true; ((idx++)); }
        done
    fi
    { ignore_stack=true; return "${ret}"; }
}

function lint_relations() {
    { ignore_stack=false; set -o pipefail; trap stacktrace ERR RETURN; }
    local rel_type rel_array ret=0 rela idx rdarch rdistro rddarch
    for rel_type in "conflicts" "breaks" "replaces" "provides" "enhances" "recommends" "suggests" "makeconflicts" "checkconflicts"; do
        local -n rel_array="test_${rel_type}"
        local -n rtype_array="${rel_type}"
        rel_array=("${rtype_array[@]}")
        for rdarch in "${PACSTALL_KNOWN_ARCH[@]}"; do
            [[ ${rdarch} != "${TARCH}" ]] && lint_var_arch "${rel_type}" "${rdarch}"
        done
        for rdistro in "${PACSTALL_KNOWN_DISTROS[@]}"; do
            if [[ ${rdistro} != "${DISTRO%:*}" && ${rdistro} != "${DISTRO#*:}" ]]; then
                lint_var_arch "${rel_type}" "${rdistro}"
                for rddarch in "${PACSTALL_KNOWN_ARCH[@]}"; do
                    [[ ${rddarch} != "${TARCH}" ]] && lint_var_arch "${rel_type}" "${rdistro}" "${rddarch}"
                done
            fi
        done
        idx=0
        if [[ -n ${rel_array[*]} ]]; then
            for rela in "${rel_array[@]}"; do
                if [[ -z ${rela} ]]; then
                    fancy_message error $"'%s' index '%s' cannot be empty" "${rel_type}" "${idx}"
                    ret=1
                fi
                { ignore_stack=true; ((idx++)); }
            done
        fi
        if ((ret == 1)); then
            break
        fi
    done
    { ignore_stack=true; return "${ret}"; }
}

function lint_capital_check() {
    { ignore_stack=false; set -o pipefail; trap stacktrace ERR RETURN; }
    local str="${1}" i=0 c x z split_chars=()
    while printf -v c "%s%n" "${str:i++:1}" x; do
        if ((x)); then
            split_chars+=("${c}")
        else
            break
        fi
    done
    for z in "${!split_chars[@]}"; do
        if [[ ${split_chars[$z]} == '-' ]]; then
            # Is the next letter a capital?
            if [[ ${split_chars[z + 1]} != "${split_chars[z + 1]^}" ]]; then
                { ignore_stack=true; return 1; }
            fi
        fi
    done
}

function lint_field_fmt() {
    { ignore_stack=false; set -o pipefail; trap stacktrace ERR RETURN; }
    local infield="${1}"
    # Ensure no spaces
    if [[ ${infield} =~ [[:space:]] ]]; then
        { ignore_stack=true; return 1; }
    # Ensure no numbers
    elif [[ ${infield} =~ [0-9] ]]; then
        return 2
    # Ensure first letter is Capital
    elif [[ ${infield} != "${infield^}" ]]; then
        return 3
    # Ensure hyphenated field names are capitalized only on the first letter of each word
    elif ! lint_capital_check "${infield}"; then
        return 4
    # Ensure last or first letter isn't a hyphen
    elif [[ ${infield: -1} != '-' || ${infield:1} != '-' ]]; then
        return 5
    else
        return 0
    fi
}

function lint_fields() {
    { ignore_stack=false; set -o pipefail; trap stacktrace ERR RETURN; }
    # shellcheck disable=SC2034
    local ret=0 idx=0 tfield tlogvar deblog_used=("Suggests" "Depends" "Package" "Version" "Architecture" "Section" "Priority"
        "Essential" "Vcs-Git" "Build-Depends" "Build-Depends-Arch" "Build-Conflicts" "Build-Conflicts-Arch"
        "Provides" "Conflicts" "Breaks" "Enhances" "Recommends" "Replaces" "Homepage" "License" "Maintainer"
        "Uploaders" "Description" "Installed-Size")
    if [[ -n ${custom_fields[*]} ]]; then
        for tfield in "${custom_fields[@]}"; do
            if [[ -z ${tfield} ]]; then
                fancy_message error $"'%s' index '%s' cannot be empty" "custom_fields" "${idx}"
                ret=1
            fi
            tlogvar="${tfield%:*}"
            if array.contains deblog_used "${tlogvar}"; then
                fancy_message error $"'%s' is already used as a field in pacstall" "${tlogvar}"
                ret=1
            else
                lint_field_fmt "${tlogvar}"
                case "$?" in
                    1)
                        fancy_message error $"'%s' custom field cannot contain a space in field name" "${tlogvar}"
                        ret=1
                        ;;
                    2)
                        fancy_message error $"'%s' custom field cannot contain a number in field name" "${tlogvar}"
                        ret=1
                        ;;
                    3 | 4)
                        fancy_message error $"'%s' custom field must capitalize only the first letter of each word in field name" "${tlogvar}"
                        ret=1
                        ;;
                    5)
                        fancy_message error $"'%s' custom field cannot start or end with a hyphen" "${tlogvar}"
                        ret=1
                        ;;
                esac
            fi
            { ignore_stack=true; ((idx++)); }
        done
        { ignore_stack=true; return "${ret}"; }
    fi
}

function lint_hash() {
    { ignore_stack=false; set -o pipefail; trap stacktrace ERR RETURN; }
    local ret=0 test_hash harch test_hashsum_type test_hashsum_style test_hash_arch test_hashsum_method test_hashsum_value \
        hash_distro_archs
    for hash_distro in "${PACSTALL_KNOWN_DISTROS[@]}"; do
        for known_arch in "${PACSTALL_KNOWN_ARCH[@]}"; do
            hash_distro_archs+=("${hash_distro}_${known_arch}")
        done
    done
    for test_hashsum_type in "${PACSTALL_KNOWN_SUMS[@]}"; do
        local -n test_hashsum_style="${test_hashsum_type}sums"
        if [[ -n ${test_hashsum_style[*]} ]]; then
            if [[ -z ${test_hash[*]} ]]; then
                test_hash=("${test_hashsum_style[@]}")
                test_hashsum_method="${test_hashsum_type}"
            else
                fancy_message error $"Only one checksum method can be provided for hashes"
                unset test_hash
                ret=1
                break
            fi
        fi
    done
    for test_hashsum_type in "${PACSTALL_KNOWN_SUMS[@]}"; do
        if ((ret == 1)); then
            break
        fi
        local -n test_hashsum_style="${test_hashsum_type}sums"
        for harch in "${PACSTALL_KNOWN_ARCH[@]}" "${PACSTALL_KNOWN_DISTROS[@]}" "${hash_distro_archs[@]}"; do
            local -n test_hash_arch="${test_hashsum_type}sums_${harch}"
            [[ ${harch} != "${TARCH}" &&
                ${harch} != "${DISTRO%:*}" &&
                ${harch} != "${DISTRO#*:}" &&
                ${harch} != "${DISTRO%:*}_${TARCH}" &&
                ${harch} != "${DISTRO#*:}_${TARCH}" ]] \
                && if [[ -n ${test_hash_arch[*]} ]]; then
                    if [[ -z ${test_hashsum_style[*]} && -z ${test_hash[*]} ]]; then
                        if [[ -z ${test_hashsum_method} ]]; then
                            test_hash=("${test_hash_arch[@]}")
                            test_hashsum_method="${test_hashsum_type}"
                        else
                            fancy_message error $"Only one checksum method can be provided for hashes"
                            unset test_hash
                            ret=1
                            break
                        fi
                    elif [[ -n ${test_hashsum_method} && ${test_hashsum_method} == "${test_hashsum_type}" ]]; then
                        test_hash+=("${test_hash_arch[@]}")
                    else
                        fancy_message error $"Only one checksum method can be provided for hashes"
                        unset test_hash
                        ret=1
                        break
                    fi
                fi
        done
    done
    if [[ -n ${test_hash[*]} ]]; then
        case ${test_hashsum_method} in
            # b2 or sha512
            "${PACSTALL_KNOWN_SUMS[0]}" | "${PACSTALL_KNOWN_SUMS[1]}") test_hashsum_value=128 ;;
            # sha384
            "${PACSTALL_KNOWN_SUMS[2]}") test_hashsum_value=96 ;;
            # sha256
            "${PACSTALL_KNOWN_SUMS[3]}") test_hashsum_value=64 ;;
            # sha224
            "${PACSTALL_KNOWN_SUMS[4]}") test_hashsum_value=56 ;;
            # sha1
            "${PACSTALL_KNOWN_SUMS[5]}") test_hashsum_value=40 ;;
            # md5
            "${PACSTALL_KNOWN_SUMS[6]}") test_hashsum_value=32 ;;
        esac
        for i in "${!test_hash[@]}"; do
            if [[ ${test_hash[i]} == "SKIP" ]]; then
                ret=0

            elif ((${#test_hash[i]} != test_hashsum_value)) || [[ ! ${test_hash[i]} =~ ^[a-fA-F0-9]+$ ]]; then
                fancy_message error $"'%s' is improperly formatted" "hash"
                ret=1
                break
            fi
        done
    fi
    { ignore_stack=true; return "${ret}"; }
}

function lint_incompatible() {
    { ignore_stack=false; set -o pipefail; trap stacktrace ERR RETURN; }
    local ret=0 incompat compat idx=0 comp_err=0
    if [[ -n ${compatible[*]} ]]; then
        if [[ -n ${incompatible[*]} ]]; then
            if [[ ${comp_err} != 1 ]]; then
                fancy_message error $"'%s' and '%s' indices cannot both be provided" "compatible" "incompatible"
                comp_err=1
            fi
            ret=1
        fi
        for compat in "${compatible[@]}"; do
            if [[ -z ${compat} ]]; then
                fancy_message error $"'%s' index '%s' cannot be empty" "compatible" "${idx}"
                ret=1
            fi
            { ignore_stack=true; ((idx++)); }
        done
        idx=0
        for compat in "${compatible[@]}"; do
            if [[ $compat != *:* ]] || [[ $compat == "*:*" ]]; then
                fancy_message error $"'%s' index '%s' is improperly formatted" "compatible" "${idx}"
                ret=1
            fi
            { ignore_stack=true; ((idx++)); }
        done
    elif [[ -n ${incompatible[*]} ]]; then
        if [[ -n ${compatible[*]} ]]; then
            if [[ ${comp_err} != 1 ]]; then
                fancy_message error $"'%s' and '%s' indices cannot both be provided" "compatible" "incompatible"
                comp_err=1
            fi
            ret=1
        fi
        for incompat in "${incompatible[@]}"; do
            if [[ -z ${incompat} ]]; then
                fancy_message error $"'%s' index '%s' cannot be empty" "incompatible" "${idx}"
                ret=1
            fi
            { ignore_stack=true; ((idx++)); }
        done
        idx=0
        for incompat in "${incompatible[@]}"; do
            if [[ $incompat != *:* ]] || [[ $incompat == "*:*" ]]; then
                fancy_message error $"'%s' index '%s' is improperly formatted" "incompatible" "${idx}"
                ret=1
            fi
            { ignore_stack=true; ((idx++)); }
        done
    fi
    { ignore_stack=true; return "${ret}"; }
}

function lint_arch() {
    { ignore_stack=false; set -o pipefail; trap stacktrace ERR RETURN; }
    # shellcheck disable=SC2034
    local ret=0 el_arch key idx=0 has_carch=false has_aarch=false known_archs=("any" "all" "${PACSTALL_KNOWN_ARCH[@]}")
    local -A AARCHS_MAP=(
        ["amd64"]="x86_64"
        ["arm64"]="aarch64"
        ["armel"]="arm"
        ["armhf"]="armv7h"
        ["i386"]="i686"
    )
    if [[ -z ${arch[*]} ]]; then
        fancy_message error $"Package does not contain '%s'" "arch"
        ret=1
    else
        for el_arch in "${arch[@]}"; do
            if [[ -z ${el_arch} ]]; then
                fancy_message error $"'%s' index '%s' cannot be empty" "arch" "${idx}"
                ret=1
            fi
            { ignore_stack=true; ((idx++)); }
        done
        # Fail point
        if ((ret != 0)); then
            { ignore_stack=true; return 1; }
        fi
        for el_arch in "${arch[@]}"; do
            if ! array.contains known_archs "${el_arch}"; then
                fancy_message error $"'%s' is not a valid architecture" "${el_arch}"
                ret=1
            else
                for key in "${!AARCHS_MAP[@]}"; do
                    if [[ ${el_arch} == "${AARCHS_MAP[$key]}" ]]; then
                        has_aarch=true
                    elif [[ ${el_arch} == "${key}" ]]; then
                        has_carch=true
                    fi
                done
            fi
        done
        if ${has_carch} && ${has_aarch}; then
            fancy_message error $"cannot use both Debian and Arch style naming in '%s' array" "arch"
            ret=1
        fi
    fi
    { ignore_stack=true; return "${ret}"; }
}

function lint_mask() {
    { ignore_stack=false; set -o pipefail; trap stacktrace ERR RETURN; }
    local ret=0 masked idx=0
    if [[ -n ${mask[*]} ]]; then
        for masked in "${mask[@]}"; do
            if [[ -z ${masked} ]]; then
                fancy_message error $"'%s' index '%s' cannot be empty" "mask" "${idx}"
                ret=1
            fi
            { ignore_stack=true; ((idx++)); }
        done
    fi
    { ignore_stack=true; return "${ret}"; }
}

function lint_bugs() {
    { ignore_stack=false; set -o pipefail; trap stacktrace ERR RETURN; }
    local ret=0
    if [[ -n ${bugs} ]]; then
		if [[ ${bugs} != *"://"* ]]; then
			fancy_message error $"'%s' is improperly formatted" "bugs"
			ret=1
		fi
    fi
    { ignore_stack=true; return "${ret}"; }
}

function lint_priority() {
    { ignore_stack=false; set -o pipefail; trap stacktrace ERR RETURN; }
    shopt -s extglob
    local ret=0
    if [[ -v priority ]]; then
        if [[ -z ${priority} ]]; then
            fancy_message error $"'%s' is empty" "priority"
            ret=1
        elif [[ ${priority} != @(essential|required|important|standard|optional) ]]; then
            fancy_message error $"'%s' must be either: '%s', '%s', '%s', '%s', or '%s'" "priority" "essential" "required" "important" "standard" "optional"
            ret=1
        fi
    fi
    shopt -u extglob
    { ignore_stack=true; return "${ret}"; }
}

function lint_license() {
    { ignore_stack=false; set -o pipefail; trap stacktrace ERR RETURN; }
    # shellcheck disable=SC2034
    local ret=0 linlicense idx=0 license_list=("0BSD" "AAL" "ADSL" "AFL-1.1" "AFL-1.2" "AFL-2.0" "AFL-2.1" "AFL-3.0" "AGPL-1.0-only" "AGPL-1.0-or-later" "AGPL-1.0" "AGPL-3.0-only" "AGPL-3.0-or-later" "AGPL-3.0" "AMDPLPA" "AML" "AMPAS" "ANTLR-PD-fallback" "ANTLR-PD" "APAFML" "APL-1.0" "APSL-1.0" "APSL-1.1" "APSL-1.2" "APSL-2.0" "ASWF-Digital-Assets-1.0" "ASWF-Digital-Assets-1.1" "Abstyles" "AdaCore-doc" "Adobe-2006" "Adobe-Glyph" "Afmparse" "Aladdin" "Apache-1.0" "Apache-1.1" "Apache-2.0" "App-s2p" "Arphic-1999" "Artistic-1.0-Perl" "Artistic-1.0-cl8" "Artistic-1.0" "Artistic-2.0" "BSD-1-Clause" "BSD-2-Clause-FreeBSD" "BSD-2-Clause-NetBSD" "BSD-2-Clause-Patent" "BSD-2-Clause-Views" "BSD-2-Clause" "BSD-3-Clause-Attribution" "BSD-3-Clause-Clear" "BSD-3-Clause-LBNL" "BSD-3-Clause-Modification" "BSD-3-Clause-No-Military-License" "BSD-3-Clause-No-Nuclear-License-2014" "BSD-3-Clause-No-Nuclear-License" "BSD-3-Clause-No-Nuclear-Warranty" "BSD-3-Clause-Open-MPI" "BSD-3-Clause" "BSD-4-Clause-Shortened" "BSD-4-Clause-UC" "BSD-4-Clause" "BSD-4.3RENO" "BSD-4.3TAHOE" "BSD-Advertising-Acknowledgement" "BSD-Attribution-HPND-disclaimer" "BSD-Protection" "BSD-Source-Code" "BSL-1.0" "BUSL-1.1" "Baekmuk" "Bahyph" "Barr" "Beerware" "BitTorrent-1.0" "BitTorrent-1.1" "Bitstream-Charter" "Bitstream-Vera" "BlueOak-1.0.0" "Boehm-GC" "Borceux" "Brian-Gladman-3-Clause" "C-UDA-1.0" "CAL-1.0-Combined-Work-Exception" "CAL-1.0" "CATOSL-1.1" "CC-BY-1.0" "CC-BY-2.0" "CC-BY-2.5-AU" "CC-BY-2.5" "CC-BY-3.0-AT" "CC-BY-3.0-DE" "CC-BY-3.0-IGO" "CC-BY-3.0-NL" "CC-BY-3.0-US" "CC-BY-3.0" "CC-BY-4.0" "CC-BY-NC-1.0" "CC-BY-NC-2.0" "CC-BY-NC-2.5" "CC-BY-NC-3.0-DE" "CC-BY-NC-3.0" "CC-BY-NC-4.0" "CC-BY-NC-ND-1.0" "CC-BY-NC-ND-2.0" "CC-BY-NC-ND-2.5" "CC-BY-NC-ND-3.0-DE" "CC-BY-NC-ND-3.0-IGO" "CC-BY-NC-ND-3.0" "CC-BY-NC-ND-4.0" "CC-BY-NC-SA-1.0" "CC-BY-NC-SA-2.0-DE" "CC-BY-NC-SA-2.0-FR" "CC-BY-NC-SA-2.0-UK" "CC-BY-NC-SA-2.0" "CC-BY-NC-SA-2.5" "CC-BY-NC-SA-3.0-DE" "CC-BY-NC-SA-3.0-IGO" "CC-BY-NC-SA-3.0" "CC-BY-NC-SA-4.0" "CC-BY-ND-1.0" "CC-BY-ND-2.0" "CC-BY-ND-2.5" "CC-BY-ND-3.0-DE" "CC-BY-ND-3.0" "CC-BY-ND-4.0" "CC-BY-SA-1.0" "CC-BY-SA-2.0-UK" "CC-BY-SA-2.0" "CC-BY-SA-2.1-JP" "CC-BY-SA-2.5" "CC-BY-SA-3.0-AT" "CC-BY-SA-3.0-DE" "CC-BY-SA-3.0-IGO" "CC-BY-SA-3.0" "CC-BY-SA-4.0" "CC-PDDC" "CC0-1.0" "CDDL-1.0" "CDDL-1.1" "CDL-1.0" "CDLA-Permissive-1.0" "CDLA-Permissive-2.0" "CDLA-Sharing-1.0" "CECILL-1.0" "CECILL-1.1" "CECILL-2.0" "CECILL-2.1" "CECILL-B" "CECILL-C" "CERN-OHL-1.1" "CERN-OHL-1.2" "CERN-OHL-P-2.0" "CERN-OHL-S-2.0" "CERN-OHL-W-2.0" "CFITSIO" "CMU-Mach" "CNRI-Jython" "CNRI-Python-GPL-Compatible" "CNRI-Python" "COIL-1.0" "CPAL-1.0" "CPL-1.0" "CPOL-1.02" "CUA-OPL-1.0" "Caldera" "ClArtistic" "Clips" "Community-Spec-1.0" "Condor-1.1" "Cornell-Lossless-JPEG" "Crossword" "CrystalStacker" "Cube" "D-FSL-1.0" "DL-DE-BY-2.0" "DOC" "DRL-1.0" "DSDP" "Dotseqn" "ECL-1.0" "ECL-2.0" "EFL-1.0" "EFL-2.0" "EPICS" "EPL-1.0" "EPL-2.0" "EUDatagrid" "EUPL-1.0" "EUPL-1.1" "EUPL-1.2" "Elastic-2.0" "Entessa" "ErlPL-1.1" "Eurosym" "FDK-AAC" "FSFAP" "FSFUL" "FSFULLR" "FSFULLRWD" "FTL" "Fair" "Frameworx-1.0" "FreeBSD-DOC" "FreeImage" "GD" "GFDL-1.1-invariants-only" "GFDL-1.1-invariants-or-later" "GFDL-1.1-no-invariants-only" "GFDL-1.1-no-invariants-or-later" "GFDL-1.1-only" "GFDL-1.1-or-later" "GFDL-1.1" "GFDL-1.2-invariants-only" "GFDL-1.2-invariants-or-later" "GFDL-1.2-no-invariants-only" "GFDL-1.2-no-invariants-or-later" "GFDL-1.2-only" "GFDL-1.2-or-later" "GFDL-1.2" "GFDL-1.3-invariants-only" "GFDL-1.3-invariants-or-later" "GFDL-1.3-no-invariants-only" "GFDL-1.3-no-invariants-or-later" "GFDL-1.3-only" "GFDL-1.3-or-later" "GFDL-1.3" "GL2PS" "GLWTPL" "GPL-1.0+" "GPL-1.0-only" "GPL-1.0-or-later" "GPL-1.0" "GPL-2.0+" "GPL-2.0-only" "GPL-2.0-or-later" "GPL-2.0-with-GCC-exception" "GPL-2.0-with-autoconf-exception" "GPL-2.0-with-bison-exception" "GPL-2.0-with-classpath-exception" "GPL-2.0-with-font-exception" "GPL-2.0" "GPL-3.0+" "GPL-3.0-only" "GPL-3.0-or-later" "GPL-3.0-with-GCC-exception" "GPL-3.0-with-autoconf-exception" "GPL-3.0" "Giftware" "Glide" "Glulxe" "Graphics-Gems" "HP-1986" "HPND-Markus-Kuhn" "HPND-export-US" "HPND-sell-variant-MIT-disclaimer" "HPND-sell-variant" "HPND" "HTMLTIDY" "HaskellReport" "Hippocratic-2.1" "IBM-pibs" "ICU" "IEC-Code-Components-EULA" "IJG-short" "IJG" "IPA" "IPL-1.0" "ISC" "ImageMagick" "Imlib2" "Info-ZIP" "Inner-Net-2.0" "Intel-ACPI" "Intel" "Interbase-1.0" "JPL-image" "JPNIC" "JSON" "Jam" "JasPer-2.0" "Kazlib" "Knuth-CTAN" "LAL-1.2" "LAL-1.3" "LGPL-2.0+" "LGPL-2.0-only" "LGPL-2.0-or-later" "LGPL-2.0" "LGPL-2.1+" "LGPL-2.1-only" "LGPL-2.1-or-later" "LGPL-2.1" "LGPL-3.0+" "LGPL-3.0-only" "LGPL-3.0-or-later" "LGPL-3.0" "LGPLLR" "LOOP" "LPL-1.0" "LPL-1.02" "LPPL-1.0" "LPPL-1.1" "LPPL-1.2" "LPPL-1.3a" "LPPL-1.3c" "LZMA-SDK-9.11-to-9.20" "LZMA-SDK-9.22" "Latex2e-translated-notice" "Latex2e" "Leptonica" "LiLiQ-P-1.1" "LiLiQ-R-1.1" "LiLiQ-Rplus-1.1" "Libpng" "Linux-OpenIB" "Linux-man-pages-1-para" "Linux-man-pages-copyleft-2-para" "Linux-man-pages-copyleft-var" "Linux-man-pages-copyleft" "MIT-0" "MIT-CMU" "MIT-Festival" "MIT-Modern-Variant" "MIT-Wu" "MIT-advertising" "MIT-enna" "MIT-feh" "MIT-open-group" "MIT" "MITNFA" "MPL-1.0" "MPL-1.1" "MPL-2.0-no-copyleft-exception" "MPL-2.0" "MS-LPL" "MS-PL" "MS-RL" "MTLL" "MakeIndex" "Martin-Birgmeier" "Minpack" "MirOS" "Motosoto" "MulanPSL-1.0" "MulanPSL-2.0" "Multics" "Mup" "NAIST-2003" "NASA-1.3" "NBPL-1.0" "NCGL-UK-2.0" "NCSA" "NGPL" "NICTA-1.0" "NIST-PD-fallback" "NIST-PD" "NIST-Software" "NLOD-1.0" "NLOD-2.0" "NLPL" "NOSL" "NPL-1.0" "NPL-1.1" "NPOSL-3.0" "NRL" "NTP-0" "NTP" "Naumen" "Net-SNMP" "NetCDF" "Newsletr" "Nokia" "Noweb" "Nunit" "O-UDA-1.0" "OCCT-PL" "OCLC-2.0" "ODC-By-1.0" "ODbL-1.0" "OFFIS" "OFL-1.0-RFN" "OFL-1.0-no-RFN" "OFL-1.0" "OFL-1.1-RFN" "OFL-1.1-no-RFN" "OFL-1.1" "OGC-1.0" "OGDL-Taiwan-1.0" "OGL-Canada-2.0" "OGL-UK-1.0" "OGL-UK-2.0" "OGL-UK-3.0" "OGTSL" "OLDAP-1.1" "OLDAP-1.2" "OLDAP-1.3" "OLDAP-1.4" "OLDAP-2.0.1" "OLDAP-2.0" "OLDAP-2.1" "OLDAP-2.2.1" "OLDAP-2.2.2" "OLDAP-2.2" "OLDAP-2.3" "OLDAP-2.4" "OLDAP-2.5" "OLDAP-2.6" "OLDAP-2.7" "OLDAP-2.8" "OLFL-1.3" "OML" "OPL-1.0" "OPL-UK-3.0" "OPUBL-1.0" "OSET-PL-2.1" "OSL-1.0" "OSL-1.1" "OSL-2.0" "OSL-2.1" "OSL-3.0" "OpenPBS-2.3" "OpenSSL" "PDDL-1.0" "PHP-3.0" "PHP-3.01" "PSF-2.0" "Parity-6.0.0" "Parity-7.0.0" "Plexus" "PolyForm-Noncommercial-1.0.0" "PolyForm-Small-Business-1.0.0" "PostgreSQL" "Python-2.0.1" "Python-2.0" "QPL-1.0-INRIA-2004" "QPL-1.0" "Qhull" "RHeCos-1.1" "RPL-1.1" "RPL-1.5" "RPSL-1.0" "RSA-MD" "RSCPL" "Rdisc" "Ruby" "SAX-PD" "SCEA" "SGI-B-1.0" "SGI-B-1.1" "SGI-B-2.0" "SGP4" "SHL-0.5" "SHL-0.51" "SISSL-1.2" "SISSL" "SMLNJ" "SMPPL" "SNIA" "SPL-1.0" "SSH-OpenSSH" "SSH-short" "SSPL-1.0" "SWL" "Saxpath" "SchemeReport" "Sendmail-8.23" "Sendmail" "SimPL-2.0" "Sleepycat" "Spencer-86" "Spencer-94" "Spencer-99" "StandardML-NJ" "SugarCRM-1.1.3" "SunPro" "Symlinks" "TAPR-OHL-1.0" "TCL" "TCP-wrappers" "TMate" "TORQUE-1.1" "TOSL" "TPDL" "TPL-1.0" "TTWL" "TU-Berlin-1.0" "TU-Berlin-2.0" "TermReadKey" "UCAR" "UCL-1.0" "UPL-1.0" "Unicode-DFS-2015" "Unicode-DFS-2016" "Unicode-TOU" "UnixCrypt" "Unlicense" "VOSTROM" "VSL-1.0" "Vim" "W3C-19980720" "W3C-20150513" "W3C" "WTFPL" "Watcom-1.0" "Widget-Workshop" "Wsuipa" "X11-distribute-modifications-variant" "X11" "XFree86-1.1" "XSkat" "Xdebug-1.03" "Xerox" "Xfig" "Xnet" "YPL-1.0" "YPL-1.1" "ZPL-1.1" "ZPL-2.0" "ZPL-2.1" "Zed" "Zend-2.0" "Zimbra-1.3" "Zimbra-1.4" "Zlib" "blessing" "bzip2-1.0.5" "bzip2-1.0.6" "checkmk" "copyleft-next-0.3.0" "copyleft-next-0.3.1" "curl" "diffmark" "dtoa" "dvipdfm" "eCos-2.0" "eGenix" "etalab-2.0" "exceptions" "gSOAP-1.3b" "gnuplot" "iMatix" "libpng-2.0" "libselinux-1.0" "libtiff" "libutil-David-Nugent" "metamail" "mpi-permissive" "mpich2" "mplus" "psfrag" "psutils" "snprintf" "w3m" "wxWindows" "xinetd" "xlock" "xpp" "zlib-acknowledgement")
    if [[ -n ${license[*]} ]]; then
        for linlicense in "${license[@]}"; do
            if [[ -z ${linlicense} ]]; then
                fancy_message error $"'%s' index '%s' cannot be empty" "license" "${idx}"
                ret=1
            fi
            { ignore_stack=true; ((idx++)); }
            if ! array.contains license_list "${linlicense}"; then
                if [[ ${linlicense} != "custom:"* ]]; then
                    fancy_message error $"'%s' is not a valid license" "${linlicense}"
                    ret=1
                fi
            fi
        done
    fi
    { ignore_stack=true; return "${ret}"; }
}

function lint_kver() {
    { ignore_stack=false; set -o pipefail; trap stacktrace ERR RETURN; }
    local ret=0
    if [[ -n ${limit_kver} ]]; then
        if ! [[ ${limit_kver} =~ ^[<>=] ]]; then
            fancy_message error $"'%s' must be prefixed with a constraint (<=|>=|=|<|>)" "limit_kver"
            ret=1
        fi
    fi
    { ignore_stack=true; return "${ret}"; }
}

function checks() {
    { ignore_stack=false; set -o pipefail; trap stacktrace ERR RETURN; }
    local ret=0 check linting_checks=(lint_pacname lint_gives lint_pkgrel lint_epoch lint_version lint_source lint_pkgdesc lint_maintainer lint_deps lint_ppa lint_relations lint_fields lint_hash lint_incompatible lint_arch lint_mask lint_priority lint_license lint_bugs lint_kver)
    for check in "${linting_checks[@]}"; do
        "${check}" || ret=1
    done
    # shellcheck disable=SC2034
    { ignore_stack=true; return "${ret}"; }
}
