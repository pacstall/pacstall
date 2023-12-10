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

function lint_name() {
    local ret=0
    if [[ -z $name ]]; then
        fancy_message error "Package does not contain name"
        return 1
    fi
    if [[ $name != "$PACKAGE" ]]; then
        fancy_message error "Package name does not match file"
        suggested_solution "Change '${UPurple}name${NC}' to '${UCyan}$PACKAGE${NC}'" "Change package name to '${UCyan}$name${NC}'"
        ret=1
    fi
    # https://www.debian.org/doc/debian-policy/ch-controlfields.html#source
    if ((${#name} < 2)); then
        fancy_message error "'name' must be at least two characters long"
        ret=1
    fi
    if [[ ${name:0:1} == [.\-+] ]]; then
        fancy_message error "'name' must start with an alphanumeric character"
        ret=1
    fi
    if [[ $name =~ [[:upper:]] ]]; then
        fancy_message error "'name' contains uppercase characters"
        ret=1
    fi
    if [[ $name == *[^[:alnum:]+.-]* ]]; then
        fancy_message error "'name' contains characters that are not lowercase, digits, minus, or periods"
        ret=1
    fi
    return "${ret}"
}

function lint_gives() {
    local ret=0
    if [[ -z $gives && $name == *-deb ]]; then
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
    if is_function pkgver; then
        if [[ -z $pkgver ]]; then
            fancy_message error "Package contains 'pkgver()' but not the variable as well"
            ret=1
        fi
        lint_pkgver="$(pkgver)"
        if [[ -z ${lint_pkgver} ]]; then
            fancy_message error "'pkgver()' has no output"
            ret=1
        fi
    elif [[ -n $pkgver ]]; then
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

function lint_url() {
    local ret=0
    if [[ -z $url ]]; then
        fancy_message error "Package does not contain 'url'"
        ret=1
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
    if [[ -z $maintainer ]]; then
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

function lint_replace() {
    local ret=0 repl idx=0
    if [[ -n ${replace[*]} ]]; then
        for repl in "${replace[@]}"; do
            if [[ -z ${repl} ]]; then
                fancy_message error "'replace' index '${idx}' cannot be empty"
                ret=1
            fi
            ((idx++))
        done
    fi
    return "${ret}"
}

function lint_hash() {
    local ret=0
    if [[ -n ${hash} ]]; then
        if ((${#hash} != 64)); then
            fancy_message error "'hash' is improperly formatted"
            ret=1
        fi
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
                comp_error=1
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
                comp_error=1
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
        elif [[ ${priority} != @(required|important|standard|optional) ]]; then
            fancy_message error "'priority' must be either: 'required', 'important', 'standard', or 'optional'"
            ret=1
        fi
    fi
    shopt -u extglob
    return "${ret}"
}

function checks() {
    local ret=0 check linting_checks=(lint_name lint_gives lint_pkgrel lint_epoch lint_version lint_url lint_pkgdesc lint_maintainer lint_makedepends lint_depends lint_pacdeps lint_ppa lint_optdepends lint_breaks lint_replace lint_hash lint_patch lint_provides lint_incompatible lint_arch lint_mask lint_priority)
    for check in "${linting_checks[@]}"; do
        "${check}" || ret=1
    done
    return "${ret}"
}
