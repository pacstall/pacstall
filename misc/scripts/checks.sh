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

function lint_pkgname() {
    local ret=0
    if [[ -z $pkgname ]]; then
        fancy_message error "Package does not contain 'pkgname'"
        return 1
    fi
    if [[ $pkgname != "$PACKAGE" ]]; then
        fancy_message error "Package name does not match file"
        suggested_solution "Change '${UPurple}pkgname${NC}' to '${UCyan}$PACKAGE${NC}'" "Change package name to '${UCyan}$pkgname${NC}'"
        ret=1
    fi
    # https://www.debian.org/doc/debian-policy/ch-controlfields.html#source
    if ((${#pkgname} < 2)); then
        fancy_message error "'pkgname' must be at least two characters long"
        ret=1
    fi
    if [[ ${pkgname:0:1} == [.\-+] ]]; then
        fancy_message error "'pkgname' must start with an alphanumeric character"
        ret=1
    fi
    if [[ $pkgname =~ [[:upper:]] ]]; then
        fancy_message error "'pkgname' contains uppercase characters"
        ret=1
    fi
    if [[ $pkgname == *[^[:alnum:]+.-]* ]]; then
        fancy_message error "'pkgname' contains characters that are not lowercase, digits, minus, or periods"
        ret=1
    fi
    return "${ret}"
}

function lint_gives() {
    local ret=0
    if [[ -z $gives && $pkgname == *-deb ]]; then
        fancy_message warn "Deb package does not contain gives"
        ret=1
    fi
    if [[ -n $gives ]]; then
        # https://www.debian.org/doc/debian-policy/ch-controlfields.html#source
        if ((${#gives} < 2)); then
            fancy_message error "'gives' must be at least two characters long"
            ret=1
        fi
        if [[ ${gives:0:1} == [.\-+] ]]; then
            fancy_message error "'gives' must start with an alphanumeric character"
            ret=1
        fi
        if [[ $gives =~ [[:upper:]] ]]; then
            fancy_message error "'gives' contains uppercase characters"
            ret=1
        fi
        if [[ $gives == *[^[:alnum:]+.-]* ]]; then
            fancy_message error "'gives' contains characters that are not lowercase, digits, minus, or periods"
            ret=1
        fi
    fi
    return "${ret}"
}

function lint_pkgrel() {
    local ret=0
    if [[ -v pkgrel ]]; then
        if [[ -z ${pkgrel} ]]; then
            fancy_message error "'pkgrel' is empty"
            ret=1
        elif [[ ! ${pkgrel} =~ ^[0-9]+$ ]]; then
            fancy_message error "'pkgrel' must be an unsigned integer"
            ret=1
        fi
    fi
    return "${ret}"
}

function lint_epoch() {
    local ret=0
    if [[ -v epoch ]]; then
        if [[ -z ${epoch} ]]; then
            fancy_message error "'epoch' is empty"
            ret=1
        elif [[ ! ${epoch} =~ ^[0-9]+$ ]]; then
            fancy_message error "'epoch' must be an unsigned integer"
            ret=1
        fi
    fi
    return "${ret}"
}

function lint_version() {
    local ret=0 lint_pkgver
    if [[ -n $pkgver ]]; then
        # https://www.debian.org/doc/debian-policy/ch-controlfields.html#version
        if [[ ! $pkgver =~ ^[0-9][a-zA-Z0-9.+-~]+$ ]]; then
            fancy_message error "'pkgver' must contain only alphanumerics and the characters . + - ~ and should start with a digit"
            ret=1
        fi
    elif [[ -z $pkgver ]]; then
        fancy_message error "Package does not contain 'pkgver'"
        ret=1
    fi
    return "${ret}"
}

function lint_source_deb_test() {
    # shellcheck disable=SC2206
    local input_source=($@)
    for i in "${!input_source[@]}"; do
        local test_source_url="${input_source[$i]}"
        local file_name="${test_source_url##*/}"
        if [[ ${file_name} == *"?"* ]]; then
            file_name="${file_name%%\?*}"
        fi
        if [[ ${file_name} == *.deb ]]; then
            fancy_message error ".deb files can only be provided as a singular 'source'"
            ret=1
            break
        fi
    done
}

function lint_source() {
    local ret=0 test_source has_source=0 known_archs_source=()
    mapfile -t known_archs_source < <(dpkg-architecture --list-known)
    for i in "${!known_archs_source[@]}"; do
        # shellcheck disable=SC2004
        known_archs_source[$i]=${known_archs_source[$i]//-/_}
    done
    if [[ -n ${source[0]} ]]; then
        has_source=1
    else
        for sarch in "${known_archs_source[@]}"; do
            local source_arch="source_${sarch}[@]"
            if [[ -n ${!source_arch} ]]; then
                has_source=1
                break
            fi
        done
    fi
    local source_host="source_${CARCH}[*]"
    if [[ -z ${source[*]} && -z ${!source_host} ]]; then
        has_source=0
    fi
    if ((has_source == 0)); then
        fancy_message error "Package does not contain 'source'"
        ret=1
    else
        for sarch in "${known_archs_source[@]}"; do
            local source_arch="source_${sarch}[@]"
            if [[ -n ${!source_arch} ]]; then
                test_source=()
                if [[ -n ${source[0]} ]]; then
                    # shellcheck disable=SC2206
                    test_source+=(${source[*]})
                fi
                # shellcheck disable=SC2206
                test_source+=(${!source_arch})
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
    return "${ret}"
}

function lint_pkgdesc() {
    local ret=0
    if [[ -z $pkgdesc ]]; then
        fancy_message error "Package does not contain 'pkgdesc'"
        ret=1
    fi
    return "${ret}"
}

function lint_maintainer() {
    if [[ -z ${maintainer[*]} ]]; then
        fancy_message warn "Package does not have a maintainer. Please be advised"
    fi
    return 0
}

function lint_makedepends() {
    local ret=0 makedepend idx=0
    if [[ -n ${makedepends[*]} ]]; then
        for makedepend in "${makedepends[@]}"; do
            if [[ -z ${makedepend} ]]; then
                fancy_message error "'makedepends' index '${idx}' cannot be empty"
                ret=1
            fi
            ((idx++))
        done
    fi
    return "${ret}"
}

function lint_depends() {
    local ret=0 depend idx=0
    if [[ -n ${depends[*]} ]]; then
        for depend in "${depends[@]}"; do
            if [[ -z ${depend} ]]; then
                fancy_message error "'depends' index '${idx}' cannot be empty"
                ret=1
            fi
            ((idx++))
        done
    fi
    return "${ret}"
}

function lint_pacdeps() {
    local ret=0 pacdep idx=0
    if [[ -n ${pacdeps[*]} ]]; then
        for pacdep in "${pacdeps[@]}"; do
            if [[ -z ${pacdep} ]]; then
                fancy_message error "'pacdeps' index '${idx}' cannot be empty"
                ret=1
            fi
            ((idx++))
        done
    fi
    return "${ret}"
}

function lint_ppa() {
    local ret=0 el_ppa idx=0
    if [[ -n ${ppa[*]} ]]; then
        for el_ppa in "${ppa[@]}"; do
            if [[ -z ${el_ppa} ]]; then
                fancy_message error "'ppa' index '${idx}' cannot be empty"
                ret=1
            fi
            ((idx++))
        done
        if ((ret != 0)); then
            return 1
        fi
        idx=0
        for el_ppa in "${ppa[@]}"; do
            if [[ $el_ppa =~ ^ppa: ]]; then
                fancy_message error "'ppa' index '${idx}' cannot start with 'ppa:'"
                ret=1
            fi
            ((idx++))
        done
        idx=0
        for el_ppa in "${ppa[@]}"; do
            if [[ ! $el_ppa =~ ^[a-zA-Z0-9]+\/[a-zA-Z0-9]+ ]]; then
                fancy_message error "'ppa' index '${idx}' is improperly formatted"
                ret=1
            fi
            ((idx++))
        done
    fi
    return "${ret}"
}

function lint_optdepends() {
    local ret=0 optdepend idx=0
    if [[ -n ${optdepends[*]} ]]; then
        for optdepend in "${optdepends[@]}"; do
            if [[ -z ${optdepend} ]]; then
                fancy_message error "'optdepends' index '${idx}' cannot be empty"
                ret=1
            elif [[ $optdepend != *": "* ]]; then
                fancy_message error "'optdepends' index '${idx}' is not formatted correctly"
                ret=1
            fi
            ((idx++))
        done
    fi
    return "${ret}"
}

function lint_conflicts() {
    local ret=0 conflict idx=0
    if [[ -n ${conflicts[*]} ]]; then
        for conflict in "${conflicts[@]}"; do
            if [[ -z ${conflict} ]]; then
                fancy_message error "'conflicts' index '${idx}' cannot be empty"
                ret=1
            fi
            ((idx++))
        done
    fi
    return "${ret}"
}

function lint_breaks() {
    local ret=0 break idx=0
    if [[ -n ${breaks[*]} ]]; then
        for break in "${breaks[@]}"; do
            if [[ -z ${break} ]]; then
                fancy_message error "'breaks' index '${idx}' cannot be empty"
                ret=1
            fi
            ((idx++))
        done
    fi
    return "${ret}"
}

function lint_replaces() {
    local ret=0 repl idx=0
    if [[ -n ${replaces[*]} ]]; then
        for repl in "${replaces[@]}"; do
            if [[ -z ${repl} ]]; then
                fancy_message error "'replaces' index '${idx}' cannot be empty"
                ret=1
            fi
            ((idx++))
        done
    fi
    return "${ret}"
}

function lint_hash() {
    local ret=0 test_hash harch test_hashsum_type test_hashsum_style test_hash_arch test_hashsum_method test_hashsum_value
    local known_archs_hash=("amd64" "arm64" "armel" "armhf" "i386" "mips64el" "ppc64el" "riscv64" "s390x")
    local test_hashsums=("b2" "sha512" "sha384" "sha256" "sha224" "sha1" "md5")
    for test_hashsum_type in "${test_hashsums[@]}"; do
        test_hashsum_style="${test_hashsum_type}sums[*]"
        if [[ -n ${!test_hashsum_style} ]]; then
            if [[ -z ${test_hash[*]} ]]; then
                # shellcheck disable=SC2206
                test_hash=(${!test_hashsum_style})
                test_hashsum_method="${test_hashsum_type}"
            else
                fancy_message error "Only one checksum method can be provided for hashes"
                unset test_hash
                ret=1
                break
            fi
        fi
    done
    for test_hashsum_type in "${test_hashsums[@]}"; do
        if ((ret == 1)); then
            break
        fi
        test_hashsum_style="${test_hashsum_type}sums[*]"
        for harch in "${known_archs_hash[@]}"; do
            test_hash_arch="${test_hashsum_type}sums_${harch}[*]"
            if [[ -n ${!test_hash_arch} ]]; then
                if [[ -z ${!test_hashsum_style} && -z ${test_hash[*]} ]]; then
                    if [[ -z ${test_hashsum_method} ]]; then
                        # shellcheck disable=SC2206
                        test_hash=(${!test_hash_arch})
                        test_hashsum_method="${test_hashsum_type}"
                    else
                        fancy_message error "Only one checksum method can be provided for hashes"
                        unset test_hash
                        ret=1
                        break
                    fi
                elif [[ -n ${test_hashsum_method} && ${test_hashsum_method} == "${test_hashsum_type}" ]]; then
                    # shellcheck disable=SC2206
                    test_hash+=(${!test_hash_arch})
                else
                    fancy_message error "Only one checksum method can be provided for hashes"
                    unset test_hash
                    ret=1
                    break
                fi
            fi
        done
    done
    # shellcheck disable=SC2128
    if [[ -n ${test_hash} ]]; then
        case ${test_hashsum_method} in
            "${test_hashsums[0]}" | "${test_hashsums[1]}") test_hashsum_value=128 ;;
            "${test_hashsums[2]}") test_hashsum_value=96 ;;
            "${test_hashsums[3]}") test_hashsum_value=64 ;;
            "${test_hashsums[4]}") test_hashsum_value=56 ;;
            "${test_hashsums[5]}") test_hashsum_value=40 ;;
            "${test_hashsums[6]}") test_hashsum_value=32 ;;
        esac
        for i in ${!test_hash[*]}; do
            if [[ ${test_hash[i]} == "SKIP" ]]; then
                ret=0

            elif ((${#test_hash[i]} != test_hashsum_value)) || [[ ! ${test_hash[i]} =~ ^[a-fA-F0-9]+$ ]]; then
                fancy_message error "'hash' is improperly formatted"
                ret=1
                break
            fi
        done
    fi
    return "${ret}"
}

function lint_patch() {
    local ret=0 el_patch idx=0
    if [[ -n ${patch[*]} ]]; then
        for el_patch in "${patch[@]}"; do
            if [[ -z ${el_patch} ]]; then
                fancy_message error "'patch' index '${idx}' cannot be empty"
                ret=1
            fi
            ((idx++))
        done
    fi
    return "${ret}"
}

function lint_provides() {
    local ret=0 provide idx=0
    if [[ -n ${provides[*]} ]]; then
        for provide in "${provides[@]}"; do
            if [[ -z ${provide} ]]; then
                fancy_message error "'provides' index '${idx}' cannot be empty"
                ret=1
            fi
            ((idx++))
        done
    fi
    return "${ret}"
}

function lint_incompatible() {
    local ret=0 incompat compat idx=0 comp_err=0
    if [[ -n ${compatible[*]} ]]; then
        if [[ -n ${incompatible[*]} ]]; then
            if [[ ${comp_err} != 1 ]]; then
                fancy_message error "'compatible' and 'incompatible' indices cannot both be provided"
                comp_err=1
            fi
            ret=1
        fi
        for compat in "${compatible[@]}"; do
            if [[ -z ${compat} ]]; then
                fancy_message error "'compatible' index '${idx}' cannot be empty"
                ret=1
            fi
            ((idx++))
        done
        idx=0
        for compat in "${compatible[@]}"; do
            if [[ $compat != *:* ]] || [[ $compat == "*:*" ]]; then
                fancy_message error "'compatible' index '${idx}' is improperly formatted"
                ret=1
            fi
            ((idx++))
        done
    elif [[ -n ${incompatible[*]} ]]; then
        if [[ -n ${compatible[*]} ]]; then
            if [[ ${comp_err} != 1 ]]; then
                fancy_message error "'compatible' and 'incompatible' indices cannot both be provided"
                comp_err=1
            fi
            ret=1
        fi
        for incompat in "${incompatible[@]}"; do
            if [[ -z ${incompat} ]]; then
                fancy_message error "'incompatible' index '${idx}' cannot be empty"
                ret=1
            fi
            ((idx++))
        done
        idx=0
        for incompat in "${incompatible[@]}"; do
            if [[ $incompat != *:* ]] || [[ $incompat == "*:*" ]]; then
                fancy_message error "'incompatible' index '${idx}' is improperly formatted"
                ret=1
            fi
            ((idx++))
        done
    fi
    return "${ret}"
}

function lint_arch() {
    local ret=0 el_arch idx=0 known_archs=("any")
    if [[ -n ${arch[*]} ]]; then
        for el_arch in "${arch[@]}"; do
            if [[ -z ${el_arch} ]]; then
                fancy_message error "'arch' index '${idx}' cannot be empty"
                ret=1
            fi
            ((idx++))
        done
        # Fail point
        if ((ret != 0)); then
            return 1
        fi
        mapfile -t -O"${#known_archs[@]}" known_archs < <(dpkg-architecture --list-known)
        for el_arch in "${arch[@]}"; do
            if ! array.contains known_archs "${el_arch}"; then
                fancy_message error "'${el_arch}' is not a valid architecture"
                ret=1
            fi
        done
    fi
    return "${ret}"
}

function lint_mask() {
    local ret=0 masked idx=0
    if [[ -n ${mask[*]} ]]; then
        for masked in "${mask[@]}"; do
            if [[ -z ${masked} ]]; then
                fancy_message error "'mask' index '${idx}' cannot be empty"
                ret=1
            fi
            ((idx++))
        done
    fi
    return "${ret}"
}

function lint_priority() {
    shopt -s extglob
    local ret=0
    if [[ -v priority ]]; then
        if [[ -z ${priority} ]]; then
            fancy_message error "'priority' is empty"
            ret=1
        elif [[ ${priority} != @(essential|required|important|standard|optional) ]]; then
            fancy_message error "'priority' must be either: 'essential', 'required', 'important', 'standard', or 'optional'"
            ret=1
        fi
    fi
    shopt -u extglob
    return "${ret}"
}

function checks() {
    local ret=0 check linting_checks=(lint_pkgname lint_gives lint_pkgrel lint_epoch lint_version lint_source lint_pkgdesc lint_maintainer lint_makedepends lint_depends lint_pacdeps lint_ppa lint_optdepends lint_conflicts lint_breaks lint_replaces lint_hash lint_patch lint_provides lint_incompatible lint_arch lint_mask lint_priority)
    for check in "${linting_checks[@]}"; do
        "${check}" || ret=1
    done
    return "${ret}"
}
