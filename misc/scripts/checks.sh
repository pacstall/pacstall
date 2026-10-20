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
            elif [[ ${tlogvar} =~ [[:space:]] ]]; then
                fancy_message error $"'%s' custom field cannot contain a space in field name" "${tlogvar}"
                ret=1
            elif [[ ${tlogvar} =~ [0-9] ]]; then
                fancy_message error $"'%s' custom field cannot contain a number in field name" "${tlogvar}"
                ret=1
            elif [[ ${tlogvar} != "${tlogvar^}" ]] || ! lint_capital_check "${tlogvar}"; then
                fancy_message error $"'%s' custom field must capitalize only the first letter of each word in field name" "${tlogvar}"
                ret=1
            elif [[ ${tlogvar} =~ ^-|-$ ]]; then
                fancy_message error $"'%s' custom field cannot start or end with a hyphen" "${tlogvar}"
                ret=1
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
    local ret=0 incompat compat idx=0 comp_err=0 incompat_regex='^[^:[]+:[^:[]+(\[[^]]+\])?$'
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
            if [[ ${compat} != *":"* ]] || [[ ${compat} =~ "*:*" ]]; then
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
            if [[ ${incompat} != *":"* ]] || [[ ${incompat} =~ "*:*" ]] || [[ ! ${incompat} =~ ${incompat_regex} ]]; then
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
    local ret=0 linlicense idx=0 license_list=()
    license_list=(/usr/share/spdx-licenses/xml/*.xml /usr/share/spdx-licenses/*.txt)
    license_list=("${license_list[@]##*/}")
    license_list=("${license_list[@]%.xml}")
    license_list=("${license_list[@]%.txt}")
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
        if ! [[ ${limit_kver} =~ ^(<|>|=) ]]; then
            fancy_message error $"'%s' must be prefixed with a constraint (<=|>=|=|<|>)" "limit_kver"
            ret=1
        fi
    fi
    { ignore_stack=true; return "${ret}"; }
}

function checks() {
    { ignore_stack=false; set -o pipefail; trap stacktrace ERR RETURN; }
    local ret=0 check linting_checks=(lint_gives lint_pkgrel lint_epoch lint_version lint_source lint_pkgdesc lint_maintainer lint_deps lint_relations lint_fields lint_hash lint_priority lint_license lint_bugs)
    for check in "${linting_checks[@]}"; do
        "${check}" || ret=1
    done
    # shellcheck disable=SC2034
    { ignore_stack=true; return "${ret}"; }
}

function pre_checks() {
    { ignore_stack=false; set -o pipefail; trap stacktrace ERR RETURN; }
    local ret=0 check linting_checks=(lint_pacname lint_incompatible lint_arch lint_mask lint_kver)
    for check in "${linting_checks[@]}"; do
        "${check}" || ret=1
    done
    # shellcheck disable=SC2034
    { ignore_stack=true; return "${ret}"; }
}
