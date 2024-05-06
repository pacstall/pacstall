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
    local ret=0 test_source has_source=0 known_archs_source=("amd64" "arm64" "armel" "armhf" "i386" "mips64el" "ppc64el" "riscv64" "s390x")
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
            local source_arch="source_${sarch}[@]" raw_carch_source="source_${CARCH}[@]" carch_source
            carch_source=("${!raw_carch_source}")
            [[ ${sarch} != "${CARCH}" ]] && if [[ -n ${!source_arch} ]]; then
                test_source=()
                if [[ -n ${source[0]} ]]; then
                    { (("${#carch_source[@]}" <= 1 && "${#source[@]}" <= 1)) \
                        && [[ ${carch_source[0]} == "${source[0]}" ]]; } \
                        || test_source+=("${source[@]}")
                fi
                test_source+=("${!source_arch}")
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

function lint_var_arch() {
    local tinp tinputvar="${1}" tinputvar_array="${1}[*]" tinputvar_arch="${1}_${2}[*]"
    declare -n test_ref_inputvar="test_${tinputvar}"
    if [[ -n ${!tinputvar_arch} ]]; then
        for tinp in ${!tinputvar_arch}; do
            if [[ -z ${!tinputvar_array} ]]; then
                test_ref_inputvar=("${tinp}")
            elif ! array.contains ref_inputvar "${tinp}"; then
                test_ref_inputvar+=("${tinp}")
            fi
        done
    fi
}

function lint_pipe_check() {
    perl -ne 'exit 1 unless /^(?:[^\s|:]+(?::[^\s|:]+)?\s\|\s)+[^\s|:]+(?::[^\s|:]+)?(?::\s[^|:]+)?(?<!\s)$/' <<< "$1"
}

function lint_deps() {
    local dep_type dep_array ret=0 dep idx kdarch known_archs_deps=("amd64" "arm64" "armel" "armhf" "i386" "mips64el" "ppc64el" "riscv64" "s390x")
    for dep_type in "depends" "makedepends" "optdepends" "checkdepends" "pacdeps"; do
        local -n dep_array="test_${dep_type}"
        local -n type_array="${dep_type}"
        dep_array=("${type_array[@]}")
        for kdarch in "${known_archs_deps[@]}"; do
            [[ ${kdarch} != "${CARCH}" ]] && lint_var_arch "${dep_type}" "${kdarch}"
        done
        idx=0
        if [[ -n ${dep_array[*]} ]]; then
            for dep in "${dep_array[@]}"; do
                if [[ -z ${dep} ]]; then
                    fancy_message error "'${dep_type}' index '${idx}' cannot be empty"
                    ret=1
                elif [[ ${dep} == *"|"* ]]; then
                    if [[ ${dep_type} == "pacdeps" ]] || ! lint_pipe_check "${dep}"; then
                        fancy_message error "'${dep_type}' index '${idx}' is not formatted correctly"
                        ret=1
                    fi
                elif [[ ${dep_type} == "optdepends" ]] && [[ ${dep} != *": "* ]]; then
                    fancy_message error "'${dep_type}' index '${idx}' is not formatted correctly"
                    ret=1
                fi
                ((idx++))
            done
        fi
        if ((ret == 1)); then
            break
        fi
    done
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

function lint_relations() {
    local rel_type rel_array ret=0 rela idx rdarch known_archs_rel=("amd64" "arm64" "armel" "armhf" "i386" "mips64el" "ppc64el" "riscv64" "s390x")
    for rel_type in "conflicts" "breaks" "replaces" "provides"; do
        local -n rel_array="test_${rel_type}"
        local -n rtype_array="${rel_type}"
        rel_array=("${rtype_array[@]}")
        for rdarch in "${known_archs_rel[@]}"; do
            [[ ${rdarch} != "${CARCH}" ]] && lint_var_arch "${rel_type}" "${rdarch}"
        done
        idx=0
        if [[ -n ${rel_array[*]} ]]; then
            for rela in "${rel_array[@]}"; do
                if [[ -z ${rela} ]]; then
                    fancy_message error "'${rel_type}' index '${idx}' cannot be empty"
                    ret=1
                fi
                ((idx++))
            done
        fi
        if ((ret == 1)); then
            break
        fi
    done
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
            [[ ${harch} != "${CARCH}" ]] && if [[ -n ${!test_hash_arch} ]]; then
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

function lint_license() {
    # shellcheck disable=SC2034
    local ret=0 linlicense idx=0 license_list=("0BSD" "ADSL" "AFL-1.1" "AFL-1.2" "AFL-2.0" "AFL-2.1" "AFL-3.0" "AGPL-1.0-only" "AGPL-1.0-or-later" "AGPL-3.0-only" "AGPL-3.0-or-later" "AMDPLPA" "AML" "AMPAS" "APAFML" "APSL-1.0" "APSL-1.1" "APSL-1.2" "APSL-2.0" "Abstyles" "Adobe-2006" "Adobe-Glyph" "Afmparse" "Aladdin" "Apache-1.0" "Apache-1.1" "Apache-2.0" "Artistic-1.0-Perl" "Artistic-1.0-cl8" "Artistic-1.0" "Artistic-2.0" "BSD-1-Clause" "BSD-2-Clause-FreeBSD" "BSD-2-Clause-NetBSD" "BSD-2-Clause-Patent" "BSD-2-Clause" "BSD-3-Clause-Attribution" "BSD-3-Clause-Clear" "BSD-3-Clause-LBNL" "BSD-3-Clause-No-Nuclear-License-2014" "BSD-3-Clause-No-Nuclear-License" "BSD-3-Clause-No-Nuclear-Warranty" "BSD-3-Clause-Open-MPI" "BSD-3-Clause" "BSD-4-Clause-UC" "BSD-4-Clause" "BSD-Protection" "BSD-Source-Code" "BSL-1.0" "Bahyph" "BitTorrent-1.0" "BitTorrent-1.1" "BlueOak-1.0.0" "Borceux" "CATOSL-1.1" "CC-BY-1.0" "CC-BY-2.0" "CC-BY-2.5" "CC-BY-3.0" "CC-BY-4.0" "CC-BY-NC-1.0" "CC-BY-NC-2.0" "CC-BY-NC-2.5" "CC-BY-NC-3.0" "CC-BY-NC-4.0" "CC-BY-NC-ND-1.0" "CC-BY-NC-ND-2.0" "CC-BY-NC-ND-2.5" "CC-BY-NC-ND-3.0" "CC-BY-NC-ND-4.0" "CC-BY-NC-SA-1.0" "CC-BY-NC-SA-2.0" "CC-BY-NC-SA-2.5" "CC-BY-NC-SA-3.0" "CC-BY-NC-SA-4.0" "CC-BY-ND-1.0" "CC-BY-ND-2.0" "CC-BY-ND-2.5" "CC-BY-ND-3.0" "CC-BY-ND-4.0" "CC-BY-SA-1.0" "CC-BY-SA-2.0" "CC-BY-SA-2.5" "CC-BY-SA-3.0" "CC-BY-SA-4.0" "CC-PDDC" "CC0-1.0" "CDDL-1.0" "CDDL-1.1" "CDLA-Permissive-1.0" "CDLA-Sharing-1.0" "CECILL-1.0" "CECILL-1.1" "CECILL-2.0" "CECILL-2.1" "CECILL-B" "CECILL-C" "CERN-OHL-1.1" "CERN-OHL-1.2" "CNRI-Jython" "CNRI-Python-GPL-Compatible" "CNRI-Python" "CPAL-1.0" "CPL-1.0" "CPOL-1.02" "CUA-OPL-1.0" "Caldera" "ClArtistic" "Condor-1.1" "Cube" "D-FSL-1.0" "DSDP" "Dotseqn" "ECL-1.0" "ECL-2.0" "EFL-1.0" "EFL-2.0" "EPL-1.0" "EPL-2.0" "EUDatagrid" "EUPL-1.0" "EUPL-1.1" "EUPL-1.2" "Entessa" "Eurosym" "FSFAP" "FSFUL" "FSFULLR" "FTL" "Frameworx-1.0" "GFDL-1.1-only" "GFDL-1.1-or-later" "GFDL-1.2-only" "GFDL-1.2-or-later" "GFDL-1.3-only" "GFDL-1.3-or-later" "GL2PS" "GPL-1.0-only" "GPL-1.0-or-later" "GPL-2.0-only" "GPL-2.0-or-later" "GPL-3.0-linking-exception" "GPL-3.0-linking-source-exception" "GPL-3.0-only" "GPL-3.0-or-later" "GPL-CC-1.0" "Giftware" "Glulxe" "HPND-sell-variant" "HPND" "HaskellReport" "IBM-pibs" "ICU" "IJG" "IPA" "IPL-1.0" "ISC" "ImageMagick" "Imlib2" "Info-ZIP" "Intel-ACPI" "Intel" "JPNIC" "JSON" "JasPer-2.0" "LAL-1.2" "LAL-1.3" "LGPL-2.0-only" "LGPL-2.0-or-later" "LGPL-2.1-only" "LGPL-2.1-or-later" "LGPL-3.0-only" "LGPL-3.0-or-later" "LGPLLR" "LPL-1.0" "LPL-1.02" "LPPL-1.0" "LPPL-1.1" "LPPL-1.2" "LPPL-1.3a" "LPPL-1.3c" "Latex2e" "Leptonica" "LiLiQ-P-1.1" "LiLiQ-R-1.1" "LiLiQ-Rplus-1.1" "Libpng" "Linux-OpenIB" "Linux-syscall-note" "MIT-0" "MIT-CMU" "MIT-advertising" "MIT-enna" "MIT-feh" "MIT" "MITNFA" "MPL-1.0" "MPL-1.1" "MPL-2.0" "MS-PL" "MS-RL" "MTLL" "MakeIndex" "MirOS" "MulanPSL-1.0" "Multics" "Mup" "NASA-1.3" "NBPL-1.0" "NCSA" "NGPL" "NLOD-1.0" "NLPL" "NPL-1.0" "NPL-1.1" "NPOSL-3.0" "NRL" "NTP-0" "NTP" "Naumen" "Net-SNMP" "NetCDF" "Newsletr" "Nokia" "Noweb" "OCCT-PL" "OCLC-2.0" "ODC-By-1.0" "ODbL-1.0" "OFL-1.0-RFN" "OFL-1.0-no-RFN" "OFL-1.0" "OFL-1.1-RFN" "OFL-1.1-no-RFN" "OFL-1.1" "OGL-Canada-2.0" "OGL-UK-1.0" "OGL-UK-2.0" "OGL-UK-3.0" "OGTSL" "OLDAP-1.1" "OLDAP-1.2" "OLDAP-1.3" "OLDAP-1.4" "OLDAP-2.0.1" "OLDAP-2.0" "OLDAP-2.1" "OLDAP-2.2.1" "OLDAP-2.2.2" "OLDAP-2.2" "OLDAP-2.3" "OLDAP-2.4" "OLDAP-2.5" "OLDAP-2.6" "OLDAP-2.7" "OLDAP-2.8" "OML" "OPL-1.0" "OSET-PL-2.1" "OSL-1.0" "OSL-1.1" "OSL-2.0" "OSL-2.1" "OSL-3.0" "OpenSSL" "PDDL-1.0" "PHP-3.0" "PHP-3.01" "PSF-2.0" "Plexus" "PostgreSQL" "Python-2.0" "QPL-1.0" "Qhull" "RHeCos-1.1" "RPL-1.1" "RPL-1.5" "RPSL-1.0" "RSA-MD" "RSCPL" "Rdisc" "Ruby" "SAX-PD" "SCEA" "SGI-B-1.0" "SGI-B-1.1" "SGI-B-2.0" "SHL-0.5" "SHL-0.51" "SISSL-1.2" "SISSL" "SMLNJ" "SMPPL" "SNIA" "SPL-1.0" "SSH-OpenSSH" "SSPL-1.0" "SWL" "Saxpath" "Sendmail-8.23" "Sendmail" "SimPL-2.0" "Sleepycat" "TAPR-OHL-1.0" "TCL" "TCP-wrappers" "TMate" "TORQUE-1.1" "TOSL" "TU-Berlin-1.0" "TU-Berlin-2.0" "UCL-1.0" "UPL-1.0" "Unicode-DFS-2015" "Unicode-DFS-2016" "Unlicense" "VOSTROM" "VSL-1.0" "Vim" "W3C-19980720" "W3C-20150513" "W3C" "WTFPL" "Wsuipa" "X11" "XFree86-1.1" "Xerox" "Xnet" "ZPL-1.1" "ZPL-2.0" "ZPL-2.1" "Zed" "Zend-2.0" "Zlib" "bzip2-1.0.5" "bzip2-1.0.6" "curl" "eGenix" "etalab-2.0" "gSOAP-1.3b" "gnuplot" "iMatix" "libpng-2.0" "libselinux-1.0" "libtiff" "mpich2" "psfrag" "psutils" "xinetd" "xpp")
    if [[ -n ${license[*]} ]]; then
        for linlicense in "${license[@]}"; do
            if [[ -z ${linlicense} ]]; then
                fancy_message error "'license' index '${idx}' cannot be empty"
                ret=1
            fi
            ((idx++))
            if ! array.contains license_list "${linlicense}"; then
                if [[ ${linlicense} != "custom:"* ]]; then
                    fancy_message error "'${linlicense}' is not a valid license"
                    ret=1
                fi
            fi
        done
    fi
    return "${ret}"
}

function checks() {
    local ret=0 check linting_checks=(lint_pkgname lint_gives lint_pkgrel lint_epoch lint_version lint_source lint_pkgdesc lint_maintainer lint_deps lint_ppa lint_relations lint_hash lint_incompatible lint_arch lint_mask lint_priority lint_license)
    for check in "${linting_checks[@]}"; do
        "${check}" || ret=1
    done
    return "${ret}"
}
