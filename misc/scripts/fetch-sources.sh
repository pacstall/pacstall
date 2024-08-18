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

# shellcheck source=./misc/scripts/build.sh
source "${SCRIPTDIR}/scripts/build.sh" || {
    fancy_message error $"Could not find build.sh"
    { ignore_stack=true; return 1; }
}

function parse_source_entry() {
    { ignore_stack=false; set -o pipefail; trap stacktrace ERR RETURN; }
    unset source_url dest git_branch git_tag git_commit
    local entry="$1"
    source_url="${entry#*::}"
    dest="${entry%%::*}"
    if [[ $entry != *::* && $entry == *#*=* ]]; then
        dest="${source_url%%#*}"
        dest="${dest##*/}"
    fi
    case $source_url in
        *#branch=*)
            git_branch="${source_url##*#branch=}"
            source_url="${source_url%%#branch=*}"
            ;;
        *#tag=*)
            git_tag="${source_url##*#tag=}"
            source_url="${source_url%%#tag=*}"
            ;;
        *#commit=*)
            git_commit="${source_url##*#commit=}"
            source_url="${source_url%%#commit=*}"
            ;;
    esac
    source_url="${source_url%%#*}"
    if [[ $entry == *::* ]]; then
        dest="${entry%%::*}"
    elif [[ $entry != *#*=* ]]; then
        source_url="$entry"
        dest="${source_url##*/}"
    fi
    if [[ ${dest} == *"?"* ]]; then
        dest="${dest%%\?*}"
    fi
}

function calc_git_pkgver() {
    { ignore_stack=false; set -o pipefail; trap stacktrace ERR RETURN; }
    unset comp_git_pkgver
    local calc_commit
    if [[ $source_url == git+* ]]; then
        source_url="${source_url#git+}"
    fi
    if [[ -n ${git_branch} ]]; then
        calc_commit="$(git ls-remote "${source_url}" "${git_branch}")"
    elif [[ -n ${git_tag} ]]; then
        calc_commit="$(git ls-remote "${source_url}" "${git_tag}")"
    elif [[ -n ${git_commit} ]]; then
        calc_commit="${git_commit}"
    else
        calc_commit="$(git ls-remote "${source_url}" HEAD)"
    fi
    comp_git_pkgver="${calc_commit:0:8}"
}

function genextr_declare() {
    { ignore_stack=false; set -o pipefail; trap stacktrace ERR RETURN; }
    unset ext_method ext_deps
    # shellcheck disable=SC2031,SC2034
    case "${source_url,,}" in
        *.zip)
            ext_method="unzip -qo"
            ext_deps=("unzip")
            ;;
        *.tar.gz | *.tgz)
            ext_method="tar -xzf"
            ext_deps=("tar" "gzip")
            ;;
        *.tar.bz2 | *.tbz2 | *.tar.bz | *.tbz)
            ext_method="tar -xjf"
            ext_deps=("tar" "bzip2")
            ;;
        *.tar.xz | *.txz)
            ext_method="tar -xJf"
            ext_deps=("tar" "xz-utils")
            ;;
        *.tar.zst | *.tzst)
            ext_method="tar -xf"
            ext_deps=("tar" "zstd")
            ;;
        *.gz)
            ext_method="gunzip"
            ext_deps=("gzip")
            ;;
        *.bz2)
            ext_method="bunzip2"
            ext_deps=("bzip2")
            ;;
        *.xz)
            ext_method="unxz"
            ext_deps=("xz-utils")
            ;;
        *.lz)
            ext_method="lzip -d"
            ext_deps=("lzip")
            ;;
        *.lzma)
            ext_method="unlzma"
            ext_deps=("xz-utils")
            ;;
        *.zst)
            ext_method="unzstd -q"
            ext_deps=("zstd")
            ;;
        *.7z)
            ext_method="7za x"
            ext_deps=("p7zip-full")
            ;;
        *.rar)
            ext_method="unrar x -inul"
            ext_deps=("unrar")
            ;;
        *.lz4)
            ext_method="lz4 -d"
            ext_deps=("liblz4-tool")
            ;;
        *.tar)
            ext_method="tar -xf"
            ext_deps=("tar")
            ;;
    esac
}

function clean_fail_down() {
    { ignore_stack=false; set -o pipefail; trap stacktrace ERR RETURN; }
    fancy_message info $"Cleaning up"
    cleanup
    exit 1
}

function hashcheck() {
    { ignore_stack=false; set -o pipefail; trap stacktrace ERR RETURN; }
    local inputFile="${1}" inputHash="${2}" hashMethod="${3}sum" fileHash
    # Get hash of file
    fileHash="$(${hashMethod} "${inputFile}")"
    fileHash="${fileHash%% *}"

    # Check if the input hash is the same as of the downloaded file.
    # Skip this test if the hash variable doesn't exist in the pacscript.
    if [[ -n ${inputHash} && ${inputHash} != "${fileHash}" ]]; then
        fancy_message error $"Hashes do not match (with method ${hashMethod})"
        fancy_message sub $"Got:      ${BRed}${fileHash}${NC}"
        fancy_message sub $"Expected: ${BGreen}${inputHash}${NC}"
        error_log 16 "install ${pacname}"
        clean_fail_down
    fi
}

function fail_down() {
    { ignore_stack=false; set -o pipefail; trap stacktrace ERR RETURN; }
    error_log 1 "download ${pacname}"
    fancy_message error $"Failed to download package"
    clean_fail_down
}

function gather_down() {
    { ignore_stack=false; set -o pipefail; trap stacktrace ERR RETURN; }
    export srcdir="${PACDIR}/${pacname}~${pkgver}"
    mkdir -p "${srcdir}"
    cd "${srcdir}" || {
        error_log 1 "gather-main ${pacname}"
        fancy_message error $"Could not enter into the main directory ${YELLOW}${srcdir}${NC}"
        clean_fail_down
    }
}

function git_down() {
    { ignore_stack=false; set -o pipefail; trap stacktrace ERR RETURN; }
    local revision gitopts submodules=true no_submodule silence quiet
    ${PACSTALL_VERBOSE} || silence=("&>" "/dev/null") quiet="--quiet"
    dest="${dest%.git}"
    if [[ -n ${git_branch} || -n ${git_tag} ]]; then
        if [[ -n ${git_branch} ]]; then
            revision="${git_branch}"
            fancy_message info $"Cloning ${BPurple}${dest}${NC} from branch ${CYAN}${git_branch}${NC}"
        elif [[ -n ${git_tag} ]]; then
            revision="${git_tag}"
            fancy_message info $"Cloning ${BPurple}${dest}${NC} from tag ${CYAN}${git_tag}${NC}"
        fi
        gitopts="-b ${revision}"
    elif [[ -n ${git_commit} ]]; then
        gitopts=("--no-checkout" "--filter=blob:none")
        fancy_message info $"Cloning ${BPurple}${dest}${NC} with no blobs"
    else
        unset gitopts
        fancy_message info $"Cloning ${BPurple}${dest}${NC} from ${CYAN}HEAD${NC}"
    fi
    # git clone quietly, with no history, and if submodules are there, download with 10 jobs
    # shellcheck disable=SC2086,SC2031
    eval "git clone --depth=1 --jobs=10 ${quiet} \"${source_url}\" \"${dest}\" ${gitopts[*]} ${silence[*]}" || fail_down
    # cd into the directory
    cd "./${dest}" 2> /dev/null || {
        error_log 1 "install ${pacname}"
        fancy_message error $"Could not enter into the cloned git repository"
        clean_fail_down
    }
    if [[ -n ${git_commit} ]]; then
        fancy_message sub $"Fetching commit ${CYAN}${git_commit:0:8}${NC}"
        eval "git fetch ${quiet} origin \"${git_commit}\" ${silence[*]}" || fail_down
        eval "git checkout ${quiet} --force \"${git_commit}\" ${silence[*]}" || fail_down
    fi
    for no_submodule in "${nosubmodules[@]}"; do
        if [[ ${no_submodule} == "${dest}" ]]; then
            submodules=false
            break
        fi
    done
    if ${submodules}; then
        # don't send this one to /dev/null like the others
        git submodule update "${quiet[@]}" --init --recursive --depth=1 || fail_down
    else
        fancy_message sub $"Not cloning submodules for ${PURPLE}${dest}${NC}"
    fi
    # Check the integrity
    calc_git_pkgver
    local cloned_git_hash
    cloned_git_hash="$(git rev-parse HEAD)"
    fancy_message sub $"Checking integrity of ${YELLOW}${cloned_git_hash:0:8}${NC}"
    git fsck --full --no-progress --no-verbose || fancy_message warn $"Could not check integrity of cloned git repository"
    if [[ ${cloned_git_hash:0:8} != "${comp_git_pkgver}" ]]; then
        fancy_message error $"Cloned git repository does not match upstream hash"
        clean_fail_down
    fi
    # if first source entry & archive is not set, this becomes archive
    if [[ ${source[i]} == "${source[0]}" && -z ${_archive} ]]; then
        export _archive="${PWD}"
    fi
    # cd back to srcdir
    gather_down
}

function net_down() {
    { ignore_stack=false; set -o pipefail; trap stacktrace ERR RETURN; }
    fancy_message info $"Downloading ${BPurple}${dest}${NC}"
    # shellcheck disable=SC2031
    download "$source_url" "$dest" || fail_down
}

function hashcheck_down() {
    { ignore_stack=false; set -o pipefail; trap stacktrace ERR RETURN; }
    if [[ -n ${expectedHash} && ${expectedHash} != "SKIP" ]]; then
        fancy_message sub $"Checking hash ${YELLOW}${expectedHash:0:8}${NC}[${YELLOW}...${NC}]"
        hashcheck "${dest}" "${expectedHash}" "${hashsum_method}" || { ignore_stack=true; return 1; }
    fi
}

function genextr_down() {
    { ignore_stack=false; set -o pipefail; trap stacktrace ERR RETURN; }
    hashcheck_down
    local extract=true keep_archive
    for keep_archive in "${noextract[@]}"; do
        if [[ ${keep_archive} == "${dest}" ]]; then
            extract=false
            break
        fi
    done
    if ${extract}; then
        fancy_message sub $"Extracting ${CYAN}${dest}${NC}"
        ${ext_method} "${dest}" 1>&1 2> /dev/null
        if [[ -f ${dest} ]]; then
            rm -f "${dest:?}"
        fi
    fi
    # if first source and extract is true, enter it for archive check
    if [[ ${source[i]} == "${source[0]}" && ${extract} == "true" ]]; then
        # cd in
        cd ./*/ 2> /dev/null || {
            error_log 1 "install ${pacname}"
            fancy_message warn $"Could not enter into the extracted archive"
        }
        # if archive is not set and we entered something, this becomes archive
        if [[ -z ${_archive} && ${PWD} != "${srcdir}" ]]; then
            export _archive="${PWD}"
        fi
    fi
    # cd back to srcdir
    gather_down
}

function deb_down() {
    { ignore_stack=false; set -o pipefail; trap stacktrace ERR RETURN; }
    hashcheck_down
    local upgrade=false
    if is_package_installed "${pacname}" && type -t pre_upgrade &> /dev/null; then
        upgrade=true
        fancy_message sub $"Running pre_upgrade hook"
        if ! pre_upgrade; then
            error_log 5 "pre_upgrade hook"
            fancy_message error $"Could not run preinst hook successfully"
            exit 1
        fi
    elif type -t pre_install &> /dev/null; then
        fancy_message sub $"Running pre_install hook"
        if ! pre_install; then
            error_log 5 "pre_install hook"
            fancy_message error $"Could not run preinst hook successfully"
            exit 1
        fi
    fi
    if [[ -n ${pacdeps[*]} || ${depends[*]} || ${makedepends[*]} || ${checkdepends[*]} ]] && repacstall "${dest}" || sudo apt install -y -f ./"${dest}" 2> /dev/null; then
        meta_log
        if [[ -f "${PACDIR}-pacdeps-$pacname" ]]; then
            sudo apt-mark auto "${gives:-$pacname}" 2> /dev/null
        fi
        fancy_message info $"Performing post install operations"
        if type -t post_upgrade &> /dev/null && ${upgrade}; then
            fancy_message sub $"Running post_upgrade hook"
            if ! post_upgrade; then
                error_log 5 "post_upgrade hook"
                fancy_message error $"Could not run postinst hook successfully"
                exit 1
            fi
        elif type -t post_install &> /dev/null; then
            fancy_message sub $"Running post_install hook"
            if ! post_install; then
                error_log 5 "post_install hook"
                fancy_message error $"Could not run postinst hook successfully"
                exit 1
            fi
        fi
        fancy_message sub $"Storing pacscript"
        sudo mkdir -p "/var/cache/pacstall/${pacname}/${full_version}"
        if ! cd "$DIR" 2> /dev/null; then
            error_log 1 "install ${pacname}"
            fancy_message error $"Could not enter into ${DIR}"
            exit 1
        fi
        sudo cp -r "${pacfile}" "/var/cache/pacstall/${pacname}/${full_version}"
        sudo chmod o+r "/var/cache/pacstall/${pacname}/${full_version}/${PACKAGE}.pacscript"
        sudo cp -r "${srcinfile}" "/var/cache/pacstall/${pacname}/${full_version}/.SRCINFO"
        sudo chmod o+r "/var/cache/pacstall/${pacname}/${full_version}/.SRCINFO"
        fancy_message info $"Done installing ${BPurple}${pacname}${NC}"
        unset expectedHash dest source_url git_branch git_tag git_commit ext_deps ext_method hashsum_method payload_arr
        return 0
    else
        fancy_message error $"Failed to install the package"
        error_log 14 "install ${pacname}"
        sudo apt purge "${gives:-$pacname}" -y > /dev/null
        clean_fail_down
    fi
}

function file_down() {
    { ignore_stack=false; set -o pipefail; trap stacktrace ERR RETURN; }
    fancy_message info $"Copying local archive ${BPurple}${dest}${NC}"
    # shellcheck disable=SC2031
    cp -r "${source_url}" "${dest}" || fail_down
    genextr_declare
    if [[ ${dest} == *".deb" ]]; then
        if deb_down; then
            exit 0
        else
            clean_fail_down
        fi
    elif [[ -n ${ext_method} ]]; then
        genextr_down
    elif [[ ${source[i]} == "${source[0]}" && -d ${dest} ]]; then
        # cd in
        cd "./${dest}" 2> /dev/null || {
            error_log 1 "install ${pacname}"
            fancy_message warn $"Could not enter into the copied archive"
        }
        # if archive not exist and we entered, its here
        if [[ -z ${_archive} && ${PWD} != "${srcdir}" ]]; then
            export _archive="${PWD}"
        fi
    else
        hashcheck_down
    fi
    # back to srcdir
    gather_down
}

# currently expecting: 1=hash 2=PACSTALL_KNOWN_SUMS 3=hashum_method 4=${CARCH}/${DISTRO} 5=${CARCH}
function append_hash_entry() {
    { ignore_stack=false; set -o pipefail; trap stacktrace ERR RETURN; }
    local -n append="${1}" sums="${2}" exp_method="${3}"
    local hash_arch hash_arr extend="${4}${5:+_$5}"
    for type in "${sums[@]}"; do
        local -n hash_arr="${type}sums"
        [[ ${extend} ]] && local -n hash_arch="${type}sums_${extend}"
        if [[ ${exp_method} == "${type}" || -z ${exp_method} ]]; then
            if [[ -n ${hash_arr[*]} && -z ${extend} ]]; then
                export exp_method="${type}"
                for a in "${hash_arr[@]}"; do
                    [[ ${pacname} == *"-deb" ]] && append=("${a}") || append+=("${a}")
                done
                break
            elif [[ -n ${hash_arch[*]} ]]; then
                [[ -z ${hash_arr[*]} && -z ${append[*]} ]] && export exp_method="${type}"
                for a in "${hash_arch[@]}"; do
                    [[ ${pacname} == *"-deb" ]] && append=("${a}") || append+=("${a}")
                done
                break
            fi
        fi
    done
}

function append_var_arch() {
    { ignore_stack=false; set -o pipefail; trap stacktrace ERR RETURN; }
    local inp inputvar="${1}"
    local -n ref_inputvar="${inputvar}" inputvar_arch="${inputvar}_${2}${3:+_$3}"
    if [[ -n ${inputvar_arch[*]} ]]; then
        for inp in "${inputvar_arch[@]}"; do
            if [[ ${pacname} == *"-deb" && ${inputvar} == "source" ]]; then
                ref_inputvar=("${inp}")
            elif ! array.contains ref_inputvar "${inp}" || [[ ${inputvar} == "source" ]]; then
                ref_inputvar+=("${inp}")
            fi
        done
    fi
}

function append_modifier_entries() {
    { ignore_stack=false; set -o pipefail; trap stacktrace ERR RETURN; }
    unset hashsum_method
    # shellcheck disable=SC2034
    local APPARCH="${1}" APPDISTRO="${2}"
    # append arrays from least to most specific
    append_hash_entry hash PACSTALL_KNOWN_SUMS hashsum_method
    append_hash_entry hash PACSTALL_KNOWN_SUMS hashsum_method "${APPARCH}"
    # distro base
    append_hash_entry hash PACSTALL_KNOWN_SUMS hashsum_method "${APPDISTRO%:*}"
    # distro version
    append_hash_entry hash PACSTALL_KNOWN_SUMS hashsum_method "${APPDISTRO#*:}"
    append_hash_entry hash PACSTALL_KNOWN_SUMS hashsum_method "${APPDISTRO%:*}" "${APPARCH}"
    append_hash_entry hash PACSTALL_KNOWN_SUMS hashsum_method "${APPDISTRO#*:}" "${APPARCH}"
    for i in {source,depends,makedepends,optdepends,pacdeps,checkdepends,provides,conflicts,breaks,replaces,enhances,recommends,suggests,makeconflicts,checkconflicts}; do
        append_var_arch "${i}" "${APPARCH}"
        append_var_arch "${i}" "${APPDISTRO%:*}"
        append_var_arch "${i}" "${APPDISTRO#*:}"
        append_var_arch "${i}" "${APPDISTRO%:*}" "${APPARCH}"
        append_var_arch "${i}" "${APPDISTRO#*:}" "${APPARCH}"
    done
    # overwrite gives from least to most specific
    # gives_arch | gives_distrobase | gives_distrover | gives_distrobase_arch | gives_distrover_arch
    gives_array=("gives_${APPARCH}" "gives_${APPDISTRO%:*}" "gives_${APPDISTRO#*:}" "gives_${APPDISTRO%:*}_${APPARCH}" "gives_${APPDISTRO#*:}_${APPARCH}")
    for gives_choice in "${gives_array[@]}"; do
        if [[ -n ${!gives_choice} ]]; then
            gives="${!gives_choice}"
            break
        fi
    done
}

function calc_distro() {
    { ignore_stack=false; set -o pipefail; trap stacktrace ERR RETURN; }
    local distro_pretty_name key value
    while IFS='=' read -r key value; do
        case "${key}" in
            "ID") distro_name="${value//\"/}" ;;
            "VERSION_CODENAME") distro_version_name="${value//\"/}" ;;
            "VERSION_ID") distro_version_number="${value//\"/}" ;;
            "DEBIAN_CODENAME") distro_parent="debian" distro_parent_vname="${value//\"/}" ;;
            "UBUNTU_CODENAME") distro_parent="ubuntu" distro_parent_vname="${value//\"/}" ;;
            "PRETTY_NAME") distro_pretty_name="${value//\"/}" ;;
        esac
    done < /etc/os-release
    if [[ "${distro_name}" == "debian" ]]; then
        distro_version_number="$(awk -F',' -v ver="${distro_version_name}" '$3 == ver {print $1}' "/usr/share/distro-info/debian.csv")"
    elif [[ "${distro_name}" == "devuan" ]]; then
        distro_parent="debian"
        if [[ ${distro_version_name##* } == "ceres" ]]; then
            distro_version_name="${distro_version_name%% *}"
            distro_parent_vname="sid"
        else
            read -r distro_parent_vname < /etc/debian_version
            if [[ "${distro_parent_vname}" =~ '.' ]]; then
                distro_parent_vname="$(awk -F',' -v ver="${distro_parent_vname%%.*}" '$1 == ver {print $3}' "/usr/share/distro-info/debian.csv")"
            fi
        fi
    fi
    if [[ ${distro_pretty_name##*/} == "sid" || ${distro_version_name} == "kali-rolling" ]]; then
        distro_parent="debian"
        distro_parent_vname="sid"
    fi
    if [[ -n "${distro_parent}" ]]; then
        if [[ ${distro_name} == "ubuntu" && ${distro_version_name} == "${distro_parent_vname}" ]]; then
            # have to set this empty instead of unsetting as the local is higher up
            distro_parent_vname=""
        else
            distro_parent_number="$(awk -F',' -v ver="${distro_parent_vname}" '$3 == ver { gsub(" LTS", "", $1); print $1 }' "/usr/share/distro-info/${distro_parent}.csv")"
            if [[ ${distro_parent_vname} == "sid" ]]; then
                distro_parent_number="sid"
            fi
        fi
    fi
}

function set_distro() {
    { ignore_stack=false; set -o pipefail; trap stacktrace ERR RETURN; }
    local distro_name distro_version_name distro_version_number distro_parent distro_parent_vname distro_parent_number
    calc_distro
    if [[ ${1} == "parent" ]]; then
        echo "${distro_parent:-${distro_name}}:${distro_parent_vname:-${distro_version_name}}"
    else
        echo "${distro_name}:${distro_version_name}"
    fi
}

function get_compatible_releases() {
    { ignore_stack=false; set -o pipefail; trap stacktrace ERR RETURN; }
    # example for this function is "ubuntu:jammy"
    local distro_name distro_version_name distro_version_number distro_parent distro_parent_vname distro_parent_number is_compat=false comp_list=("${@,,}")
    calc_distro
    for key in "${comp_list[@]}"; do
        # check for `*:jammy`
        if [[ $key == "*:"* ]]; then
            # check for `22.04` or `jammy`
            if [[ ${key#*:} == "${distro_version_number}" ||
                ${key#*:} == "${distro_version_name}" ||
                ${key#*:} == "${distro_parent_number}" ||
                ${key#*:} == "${distro_parent_vname}" ]]; then
                is_compat=true
                break
            fi
        # check for `ubuntu:*`
        elif [[ $key == *":*" ]]; then
            # check for `ubuntu`
            if [[ ${key%%:*} == "${distro_name}" || ${key%%:*} == "${distro_parent}" ]]; then
                is_compat=true
                break
            fi
        elif [[ ${key} == "${distro_name}:${distro_version_name}" ||
            ${key} == "${distro_name}:${distro_version_number}" ||
            ${key} == "${distro_parent}:${distro_parent_vname}" ||
            ${key} == "${distro_parent}:${distro_parent_number}" ]]; then
            # check for `ubuntu:jammy` or `ubuntu:22.04`
            is_compat=true
            break
        fi
    done
    if [[ ${is_compat} == "false" || ${is_compat} != "true" ]]; then
        fancy_message error $"This Pacscript does not work on ${BBlue}${distro_name}:${distro_version_name}${NC}/${BBlue}${distro_name}:${distro_version_number}${NC}"
        { ignore_stack=true; return 1; }
    fi
    return 0
}

function get_incompatible_releases() {
    { ignore_stack=false; set -o pipefail; trap stacktrace ERR RETURN; }
    # example for this function is "ubuntu:jammy"
    local distro_name distro_version_name distro_version_number distro_parent distro_parent_vname distro_parent_number incomp_list=("${@,,}")
    calc_distro


    if ! array.contains incomp_list "${distro_name}:${distro_version_name}" && \
        ! array.contains incomp_list "${distro_name}:${distro_version_number}" && \
        ! array.contains incomp_list "${distro_name}:*" && \
        ! array.contains incomp_list "*:${distro_version_name}" && \
        ! array.contains incomp_list "*:${distro_version_number}"; then
        if [[ -n ${distro_parent_vname} ]] && \
            { array.contains incomp_list "*:${distro_parent_vname}" || \
            array.contains incomp_list "*:${distro_parent_number}";
        }; then
            distro_name="${distro_parent}"
            distro_version_name="${distro_parent_vname}"
            if [[ -n ${distro_parent_number} ]]; then
                distro_version_number="${distro_parent_number}"
            fi
        fi
    fi
    for key in "${incomp_list[@]}"; do
        # check for `*:jammy`
        if [[ $key == "*:"* ]]; then
            # check for `22.04` or `jammy`
            if [[ ${key#*:} == "${distro_version_number}" || ${key#*:} == "${distro_version_name}" ]]; then
                fancy_message error $"This Pacscript does not work on ${BBlue}${distro_version_name}${NC}/${BBlue}${distro_version_number}${NC}"
                { ignore_stack=true; return 1; }
            fi
        # check for `ubuntu:*`
        elif [[ $key == *":*" ]]; then
            # check for `ubuntu`
            if [[ ${key%%:*} == "${distro_name}" ]]; then
                fancy_message error $"This Pacscript does not work on ${BBlue}${distro_name}${NC}"
                { ignore_stack=true; return 1; }
            fi
        else
            # check for `ubuntu:jammy` or `ubuntu:22.04`
            if [[ $key == "${distro_name}:${distro_version_name}" || $key == "${distro_name}:${distro_version_number}" ]]; then
                fancy_message error $"This Pacscript does not work on ${BBlue}${distro_name}:${distro_version_name}${NC}/${BBlue}${distro_name}:${distro_version_number}${NC}"
                { ignore_stack=true; return 1; }
            fi
        fi
    done
}

function is_compatible_arch() {
    { ignore_stack=false; set -o pipefail; trap stacktrace ERR RETURN; }
    local inarch=("${@}") ret=1 pacarch farch
    # shellcheck disable=SC2076,SC2153
    if array.contains inarch "any" \
        || array.contains inarch "all" \
        || array.contains inarch "${CARCH}" \
        || array.contains inarch "${AARCH}"; then
        ret=0
    elif [[ -n ${FARCH[*]} ]]; then
        for pacarch in "${inarch[@]}"; do
            for farch in "${FARCH[@]}"; do
                if [[ ${pacarch} == "${farch}" ]]; then
                    fancy_message warn $"This package is for ${BBlue}${farch}${NC}, which is a foreign architecture"
                    # ideally we want to `export CARCH="${farch}"`, but this won't fundamentally work until we utilize .SRCINFO properly
                    ret=0
                    break
                fi
            done
            if ((ret == 0)); then
                break
            fi
        done
    fi
    if ((ret == 1)); then
        fancy_message error $"This Pacscript does not work on ${BBlue}${CARCH}/${AARCH}${NC}"
    fi
    { ignore_stack=true; return "${ret}"; }
}

function check_builddepends() {
    { ignore_stack=false; set -o pipefail; trap stacktrace ERR RETURN; }
    local build_dep="${1}" type="${2}" realbuild just_build just_arch
    realbuild="${build_dep}"
    if dep_const.is_pipe "${build_dep}"; then
         build_dep="$(dep_const.get_pipe "${build_dep}")"
    fi
    dep_const.split_name_and_version "${build_dep}" just_build
    just_arch="$(dep_const.get_arch "${just_build[0]}")"
    if [[ ${just_build[0]} == *":${just_arch}" ]]; then
        if [[ -z "$(aptitude search --quiet --disable-columns "?exact-name(${just_build[0]%:*})?architecture(${just_arch})" -F "%p")" ]]; then
            if [[ -z "$(aptitude search --quiet --disable-columns "?provides(^${just_build[0]%:*}$)?architecture(${just_arch})" -F "%p")" ]]; then
                fancy_message sub $"${CYAN}${realbuild}${NC} ${RED}✗${NC} [required]"
                echo "${realbuild}" >> "${PACDIR}-missing-${type}-${pacname}"
                return 0
            fi
        fi
    else
        if [[ -z "$(apt-cache search --no-generate --names-only "^${just_build[0]}\$" 2> /dev/null || apt-cache search --names-only "^${just_build[0]}\$")" ]]; then
            if [[ -z "$(aptitude search --quiet --disable-columns "?exact-name(${just_build[0]})?architecture(${just_arch})" -F "%p")" ]]; then
                if [[ -z "$(aptitude search --quiet --disable-columns "?provides(^${just_build[0]}$)?architecture(${just_arch})" -F "%p")" ]]; then
                    fancy_message sub $"${CYAN}${realbuild}${NC} ${RED}✗${NC} [required]"
                    echo "${realbuild}" >> "${PACDIR}-missing-${type}-${pacname}"
                    return 0
                fi
            fi
        fi
    fi
    if dep_const.apt_compare_to_constraints "${build_dep}"; then
        if ! is_apt_package_installed "${just_build[0]}"; then
            echo "${realbuild}" >> "${PACDIR}-needed-${type}-${pacname}"
            just_arch="$(dep_const.get_arch "${just_build[0]}")"
            fancy_message sub $"${CYAN}${just_build[0]}${NC} ${GREEN}↑${YELLOW}↓${NC} [remote]"
        else
            fancy_message sub $"${CYAN}${just_build[0]}${NC} ${GREEN}✓${NC} [installed]"
        fi
    else
        echo "${realbuild}" >> "${PACDIR}-unsatisifed-${type}-${pacname}"
        fancy_message sub $"${CYAN}${realbuild}${NC} ${RED}✗${NC} [required]"
    fi
}

function install_builddepends() {
    { ignore_stack=false; set -o pipefail; trap stacktrace ERR RETURN; }
    # shellcheck disable=SC2034
    local c m needed_builddepends missing_builddepends unsatisfied_builddepends needed_checkdepends missing_checkdepends unsatisfied_checkdepends bdeps_array bdeps_str cdeps_array bcons_array bcons_str
    if [[ -n ${makedepends[*]} ]]; then
        fancy_message info $"Checking build dependencies"
        for i in "needed-builddepends" "missing-builddepends" "unsatisfied-builddepends"; do
            sudo rm -rf "${PACDIR}-${i}-${pacname}"
            touch "${PACDIR}-${i}-${pacname}"
        done
        for m in "${makedepends[@]}"; do
            check_builddepends "${m}" "builddepends" &
        done
        wait
        for i in "needed-builddepends" "missing-builddepends" "unsatisfied-builddepends"; do
            mapfile -t "${i//-/_}" <"${PACDIR}-${i}-${pacname}"
            sudo rm -rf "${PACDIR}-${i}-${pacname}"
        done
        if [[ -n ${missing_builddepends[*]} ]]; then
            echo -ne "\t"
            fancy_message error $"${CYAN}$(printf "${CYAN}%s${NC}, " "${missing_builddepends[@]}" | sed 's/, $/\n/')${NC} does not exist in apt repositories"
        fi
        if [[ -n ${unsatisfied_builddepends[*]} ]]; then
            echo -ne "\t"
            fancy_message error $"${CYAN}$(printf "${CYAN}%s${NC}, " "${unsatisfied_builddepends[@]}" | sed 's/, $/\n/')${NC} version(s) cannot be satisfied"
        fi
        if [[ -n ${missing_builddepends[*]} || -n ${unsatisfied_builddepends[*]} ]]; then
            fancy_message info $"Cleaning up"
            cleanup
            exit 1
        fi
        # format for apt satisfy/deb control file
        dep_const.format_control needed_builddepends bdeps_array
    fi
    if [[ -n ${checkdepends[*]} ]]; then
        fancy_message info $"Checking check dependencies"
        for i in "needed-checkdepends" "missing-checkdepends" "unsatisfied-checkdepends"; do
            sudo rm -rf "${PACDIR}-${i}-${pacname}"
            touch "${PACDIR}-${i}-${pacname}"
        done
        for c in "${checkdepends[@]}"; do
            check_builddepends "${c}" "checkdepends" &
        done
        wait
        for i in "needed-checkdepends" "missing-checkdepends" "unsatisfied-checkdepends"; do
            mapfile -t "${i//-/_}" <"${PACDIR}-${i}-${pacname}"
            sudo rm -rf "${PACDIR}-${i}-${pacname}"
        done
        if [[ -n ${missing_checkdepends[*]} ]]; then
            echo -ne "\t"
            fancy_message error $"${CYAN}$(printf "${CYAN}%s${NC}, " "${missing_checkdepends[@]}" | sed 's/, $/\n/')${NC} does not exist in apt repositories"
        fi
        if [[ -n ${unsatisfied_checkdepends[*]} ]]; then
            echo -ne "\t"
            fancy_message error $"${CYAN}$(printf "${CYAN}%s${NC}, " "${unsatisfied_checkdepends[@]}" | sed 's/, $/\n/')${NC} version(s) cannot be satisfied"
        fi
        if [[ -n ${missing_checkdepends[*]} || -n ${unsatisfied_checkdepends[*]} ]]; then
            fancy_message info $"Cleaning up"
            cleanup
            exit 1
        fi
        # format for apt satisfy/deb control file
        dep_const.format_control needed_checkdepends cdeps_array
    fi
    if ((${#needed_builddepends[@]} != 0)) && ((${#needed_checkdepends[@]} == 0)); then
        # if any makedeps are not installed, and there are no checkdeps to install
        dep_const.comma_array bdeps_array bdeps_str
    elif ((${#needed_builddepends[@]} == 0)) && ((${#needed_checkdepends[@]} != 0)); then
        # if any checkdeps are not installed, and there are no makedeps to install
        dep_const.comma_array cdeps_array bdeps_str
    elif ((${#needed_builddepends[@]} != 0)) && ((${#needed_checkdepends[@]} != 0)); then
        # if both need installs, append needed checkdeps to makedeps
        bdeps_array+=("${cdeps_array[@]}")
        dep_const.comma_array bdeps_array bdeps_str
    fi
    if ((${#needed_builddepends[@]} != 0 || ${#needed_checkdepends[@]} != 0 || ${#makeconflicts[@]} != 0 || ${#checkconflicts[@]} != 0)); then
        fancy_message sub $"Creating build dependency/conflicts dummy package"
        (
            unset pre_{upgrade,install,remove} post_{upgrade,install,remove} priority provides conflicts replaces breaks gives enhances recommends suggests custom_fields
            # shellcheck disable=SC2030
            PACSTALL_INSTALL=1
            # shellcheck disable=SC2030
            pacname="${PACKAGE}-dummy-builddeps"
            sudo mkdir -p "${STAGEDIR}/${pacname}/DEBIAN"
            deblog "Depends" "${bdeps_str}"
            # shellcheck disable=SC2034
            bcons_array=("${makeconflicts[@]}" "${checkconflicts[@]}")
            dep_const.comma_array bcons_array bcons_str
            deblog "Conflicts" "${bcons_str}"
            makedeb
        ) || {
            fancy_message error $"Failed to install build or check dependencies"
            # shellcheck disable=SC2031
            error_log 8 "install ${pacname}"
            clean_fail_down
        }
    fi
}

function compare_remote_version() {
    { ignore_stack=false; set -o pipefail; trap stacktrace ERR RETURN; }
    local crv_input="${1}" remote_tmp remote_safe remoterepo remotever localver crv_pkgver crv_pkgrel crv_epoch crv_source remv crv_fetch crv_base
    unset _pkgbase
    # shellcheck source=/dev/null
    source "$METADIR/$crv_input" || { ignore_stack=true; return 1; }
    [[ ${_remoterepo} == "orphan" ]] && _remoterepo="${REPO}"
    if [[ -z ${_remoterepo} ]]; then
        return 0
    fi
    case "${_remoterepo}" in
        *"github.com"*)
            remoterepo="${_remoterepo/'github.com'/'raw.githubusercontent.com'}/${_remotebranch}" ;;
        *"gitlab.com"*)
            remoterepo="${_remoterepo}/-/raw/${_remotebranch}" ;;
        *"git.sr.ht"*)
            remoterepo="${_remoterepo}/blob/${_remotebranch}" ;;
        *"codeberg"*)
            remoterepo="${_remoterepo}/raw/branch/${_remotebranch}" ;;
        *)
            remoterepo="${_remoterepo}" ;;
    esac
    if [[ -n ${_pkgbase} ]]; then
        crv_fetch="${_pkgbase}"
    else
        crv_fetch="${crv_input}"
    fi
    remotever="$(
        unset pkgrel
        remote_tmp="$(sudo mktemp -p "${PACDIR}" -t "compare-repo-ver-$crv_input.XXXXXX")"
        remote_safe="${remote_tmp}"
        # shellcheck disable=SC2034
        curl -fsSL "$remoterepo/packages/$crv_fetch/.SRCINFO" | sudo tee "${remote_safe}" > /dev/null || { ignore_stack=true; return 1; }
        sudo chown "${PACSTALL_USER}" "${remote_safe}"
        crv_base="$(srcinfo.match_pkg "${remote_safe}" pkgbase)"
        for remv in "pkgver" "pkgrel" "epoch"; do
            local -n deremv="crv_${remv}"
            # shellcheck disable=SC2034
            deremv="$(srcinfo.match_pkg "${remote_safe}" "${remv}" "${crv_base}")"
        done
        mapfile -t crv_source < <(srcinfo.match_pkg "${remote_safe}" "source" "${crv_base}")
        if [[ ${crv_input} == *-git ]]; then
            parse_source_entry "${crv_source[0]}"
            calc_git_pkgver
            echo "${crv_epoch:+$crv_epoch:}${crv_pkgver}-pacstall${crv_pkgrel:-1}~git${comp_git_pkgver}"
        else
            echo "${crv_epoch:+$crv_epoch:}${crv_pkgver}-pacstall${crv_pkgrel:-1}"
        fi
        sudo rm -rf "${remote_safe:?}"
    )" > /dev/null
    localver=$(source "${METADIR}/${crv_input}" && echo "${_version}")
    if [[ $crv_input == *"-git" ]]; then
        if [[ ${localver} != "$remotever" ]]; then
            echo "update"
        else
            echo "no"
        fi
    elif dpkg --compare-versions "${localver}" lt "$remotever" > /dev/null 2>&1; then
        echo "update"
    else
        echo "no"
    fi
}

# vim:set ft=sh ts=4 sw=4 et:
