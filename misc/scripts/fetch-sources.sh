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

# shellcheck source=./misc/scripts/build.sh
source "${SCRIPTDIR}/scripts/build.sh" || {
    fancy_message error "Could not find build.sh"
    return 1
}

function parse_source_entry() {
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
        *.tar.bz2 | *.tbz2)
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
    fancy_message info "Cleaning up"
    cleanup
    exit 1
}

function hashcheck() {
    local inputFile="${1}" inputHash="${2}" hashMethod="${3}sum" fileHash
    # Get hash of file
    fileHash="$(${hashMethod} "${inputFile}")"
    fileHash="${fileHash%% *}"

    # Check if the input hash is the same as of the downloaded file.
    # Skip this test if the hash variable doesn't exist in the pacscript.
    if [[ -n ${inputHash} && ${inputHash} != "${fileHash}" ]]; then
        fancy_message error "Hashes do not match (with method ${hashMethod})"
        fancy_message sub "Got:      ${BRed}${fileHash}${NC}"
        fancy_message sub "Expected: ${BGreen}${inputHash}${NC}"
        error_log 16 "install $PACKAGE"
        clean_fail_down
    fi
}

function fail_down() {
    error_log 1 "download $PACKAGE"
    fancy_message error "Failed to download package"
    clean_fail_down
}

function gather_down() {
    if [[ -z ${srcdir} ]]; then
        export srcdir="${PACDIR}/${PACKAGE}~${pkgver}"
    fi
    mkdir -p "${srcdir}"
    cd "${srcdir}" || {
        error_log 1 "gather-main $PACKAGE"
        fancy_message error "Could not enter into the main directory ${YELLOW}${srcdir}${NC}"
        clean_fail_down
    }
}

function git_down() {
    local revision gitopts submodules=true no_submodule
    dest="${dest%.git}"
    if [[ -n ${git_branch} || -n ${git_tag} ]]; then
        if [[ -n ${git_branch} ]]; then
            revision="${git_branch}"
            fancy_message info "Cloning ${BPurple}${dest}${NC} from branch ${CYAN}${git_branch}${NC}"
        elif [[ -n ${git_tag} ]]; then
            revision="${git_tag}"
            fancy_message info "Cloning ${BPurple}${dest}${NC} from tag ${CYAN}${git_tag}${NC}"
        fi
        gitopts="-b ${revision}"
    elif [[ -n ${git_commit} ]]; then
        gitopts="--no-checkout --filter=blob:none"
        fancy_message info "Cloning ${BPurple}${dest}${NC} with no blobs"
    else
        unset gitopts
        fancy_message info "Cloning ${BPurple}${dest}${NC} from ${CYAN}HEAD${NC}"
    fi
    # git clone quietly, with no history, and if submodules are there, download with 10 jobs
    # shellcheck disable=SC2086,SC2031
    git clone --quiet --depth=1 --jobs=10 "${source_url}" "${dest}" ${gitopts} &> /dev/null || fail_down
    # cd into the directory
    cd "./${dest}" 2> /dev/null || {
        error_log 1 "install $PACKAGE"
        fancy_message error "Could not enter into the cloned git repository"
        clean_fail_down
    }
    if [[ -n ${git_commit} ]]; then
        fancy_message sub "Fetching commit ${CYAN}${git_commit:0:8}${NC}"
        git fetch --quiet origin "${git_commit}" &> /dev/null || fail_down
        git checkout --quiet --force "${git_commit}" &> /dev/null || fail_down
    fi
    for no_submodule in "${nosubmodules[@]}"; do
        if [[ ${no_submodule} == "${dest}" ]]; then
            submodules=false
            break
        fi
    done
    if ${submodules}; then
        # don't send this one to /dev/null like the others
        git submodule update --quiet --init --recursive --depth=1 || fail_down
    else
        fancy_message sub "Not cloning submodules for ${PURPLE}${dest}${NC}"
    fi
    # Check the integrity
    calc_git_pkgver
    local cloned_git_hash
    cloned_git_hash="$(git rev-parse HEAD)"
    fancy_message sub "Checking integrity of ${YELLOW}${cloned_git_hash:0:8}${NC}"
    git fsck --full --no-progress --no-verbose || fancy_message warn "Could not check integrity of cloned git repository"
    if [[ ${cloned_git_hash:0:8} != "${comp_git_pkgver}" ]]; then
        fancy_message error "Cloned git repository does not match upstream hash"
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
    fancy_message info "Downloading ${BPurple}${dest}${NC}"
    # shellcheck disable=SC2031
    download "$source_url" "$dest" || fail_down
}

function hashcheck_down() {
    if [[ -n ${expectedHash} && ${expectedHash} != "SKIP" ]]; then
        fancy_message sub "Checking hash ${YELLOW}${expectedHash:0:8}${NC}[${YELLOW}...${NC}]"
        hashcheck "${dest}" "${expectedHash}" "${hashsum_method}" || return 1
    fi
}

function genextr_down() {
    hashcheck_down
    local extract=true keep_archive
    for keep_archive in "${noextract[@]}"; do
        if [[ ${keep_archive} == "${dest}" ]]; then
            extract=false
            break
        fi
    done
    if ${extract}; then
        fancy_message sub "Extracting ${CYAN}${dest}${NC}"
        ${ext_method} "${dest}" 1>&1 2> /dev/null
        if [[ -f ${dest} ]]; then
            rm -f "${dest}"
        fi
    fi
    # if first source and extract is true, enter it for archive check
    if [[ ${source[i]} == "${source[0]}" && ${extract} == "true" ]]; then
        # cd in
        cd ./*/ 2> /dev/null || {
            error_log 1 "install $PACKAGE"
            fancy_message warn "Could not enter into the extracted archive"
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
    hashcheck_down
    local upgrade=false
    if is_package_installed "${pkgname}" && type -t pre_upgrade &> /dev/null; then
        upgrade=true
        fancy_message sub "Running pre_upgrade hook"
        if ! pre_upgrade; then
            error_log 5 "pre_upgrade hook"
            fancy_message error "Could not run preinst hook successfully"
            exit 1
        fi
    elif type -t pre_install &> /dev/null; then
        fancy_message sub "Running pre_install hook"
        if ! pre_install; then
            error_log 5 "pre_install hook"
            fancy_message error "Could not run preinst hook successfully"
            exit 1
        fi
    fi
    if [[ -n ${pacdeps[*]} || ${depends[*]} || ${makedepends[*]} || ${checkdepends[*]} ]] && repacstall "${dest}" || sudo apt install -y -f ./"${dest}" 2> /dev/null; then
        meta_log
        if [[ -f /tmp/pacstall-pacdeps-"$pkgname" ]]; then
            sudo apt-mark auto "${gives:-$pkgname}" 2> /dev/null
        fi
        fancy_message info "Performing post install operations"
        if type -t post_upgrade &> /dev/null && ${upgrade}; then
            fancy_message sub "Running post_upgrade hook"
            if ! post_upgrade; then
                error_log 5 "post_upgrade hook"
                fancy_message error "Could not run postinst hook successfully"
                exit 1
            fi
        elif type -t post_install &> /dev/null; then
            fancy_message sub "Running post_install hook"
            if ! post_install; then
                error_log 5 "post_install hook"
                fancy_message error "Could not run postinst hook successfully"
                exit 1
            fi
        fi
        fancy_message sub "Storing pacscript"
        sudo mkdir -p "/var/cache/pacstall/$PACKAGE/${full_version}"
        if ! cd "$DIR" 2> /dev/null; then
            error_log 1 "install $PACKAGE"
            fancy_message error "Could not enter into ${DIR}"
            exit 1
        fi
        sudo cp -r "${pacfile}" "/var/cache/pacstall/$PACKAGE/${full_version}"
        sudo chmod o+r "/var/cache/pacstall/$PACKAGE/${full_version}/$PACKAGE.pacscript"
        fancy_message sub "Cleaning up"
        cleanup
        fancy_message info "Done installing ${BPurple}$PACKAGE${NC}"
        unset expectedHash dest source_url git_branch git_tag git_commit ext_deps ext_method hashsum_method payload_arr
        return 0
    else
        fancy_message error "Failed to install the package"
        error_log 14 "install $PACKAGE"
        sudo apt purge "${gives:-$pkgname}" -y > /dev/null
        clean_fail_down
    fi
}

function file_down() {
    fancy_message info "Copying local archive ${BPurple}${dest}${NC}"
    # shellcheck disable=SC2031
    cp -r "${source_url}" "${dest}" || fail_down
    genextr_declare
    if [[ ${dest} == *".deb" ]]; then
        deb_down
    elif [[ -n ${ext_method} ]]; then
        genextr_down
    elif [[ ${source[i]} == "${source[0]}" && -d ${dest} ]]; then
        # cd in
        cd "./${dest}" 2> /dev/null || {
            error_log 1 "install $PACKAGE"
            fancy_message warn "Could not enter into the copied archive"
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

function append_archAndHash_entry() {
    local source_arch hash_arch hashsum_type hashsum_style hashsums=("b2" "sha512" "sha384" "sha256" "sha224" "sha1" "md5")
    unset hashsum_method
    # shellcheck disable=SC2153
    source_arch="source_${CARCH}[*]"
    if [[ -n ${!source_arch} ]]; then
        if [[ -z ${source[*]} ]]; then
            # shellcheck disable=SC2206
            source=(${!source_arch})
        else
            # shellcheck disable=SC2206
            source+=(${!source_arch})
        fi
    fi
    for hashsum_type in "${hashsums[@]}"; do
        hashsum_style="${hashsum_type}sums[*]"
        if [[ -n ${!hashsum_style} ]]; then
            # shellcheck disable=SC2206
            hash=(${!hashsum_style})
            export hashsum_method="${hashsum_type}"
            break
        fi
    done
    for hashsum_type in "${hashsums[@]}"; do
        hashsum_style="${hashsum_type}sums[*]"
        # shellcheck disable=SC2153
        hash_arch="${hashsum_type}sums_${CARCH}[*]"
        if [[ -n ${!hash_arch} ]]; then
            if [[ -z ${!hashsum_style} && -z ${hash[*]} ]]; then
                # shellcheck disable=SC2206
                hash=(${!hash_arch})
                export hashsum_method="${hashsum_type}"
            else
                # shellcheck disable=SC2206
                hash+=(${!hash_arch})
            fi
            break
        fi
    done
}

function append_var_arch() {
    local inp inputvar="${1}" inputvar_array="${1}[*]" inputvar_arch="${1}_${2}[*]"
    declare -n ref_inputvar="${inputvar}"
    if [[ -n ${!inputvar_arch} ]]; then
        for inp in ${!inputvar_arch}; do
            if [[ -z ${!inputvar_array} ]]; then
                ref_inputvar=("${inp}")
            elif ! array.contains ref_inputvar "${inp}"; then
                ref_inputvar+=("${inp}")
            fi
        done
    fi
}

function calc_distro() {
    distro_name="$(lsb_release -si 2> /dev/null)"
    distro_name="${distro_name,,}"
    if [[ "$(lsb_release -ds 2> /dev/null | tail -c 4)" == "sid" ]]; then
        distro_version_name="sid"
        distro_version_number="sid"
    else
        distro_version_name="$(lsb_release -sc 2> /dev/null)"
        distro_version_number="$(lsb_release -sr 2> /dev/null)"
    fi
}

function set_distro() {
    local distro_name distro_version_name distro_version_number
    calc_distro
    echo "${distro_name}:${distro_version_name}"
}

function get_compatible_releases() {
    # example for this function is "ubuntu:jammy"
    local distro_name distro_version_name distro_version_number
    calc_distro
    # lowercase
    local input=("${@,,}")
    local is_compat=false
    for key in "${input[@]}"; do
        # check for `*:jammy`
        if [[ $key == "*:"* ]]; then
            # check for `22.04` or `jammy`
            if [[ ${key#*:} == "${distro_version_number}" || ${key#*:} == "${distro_version_name}" ]]; then
                is_compat=true
                return 0
            fi
        # check for `ubuntu:*`
        elif [[ $key == *":*" ]]; then
            # check for `ubuntu`
            if [[ ${key%%:*} == "${distro_name}" ]]; then
                is_compat=true
                return 0
            fi
        elif [[ $key == "${distro_name}:${distro_version_name}" || $key == "${distro_name}:${distro_version_number}" ]]; then
            # check for `ubuntu:jammy` or `ubuntu:22.04`
            is_compat=true
            return 0
        fi
    done
    if [[ ${is_compat} == "false" || ${is_compat} != "true" ]]; then
        fancy_message error "This Pacscript does not work on ${BBlue}${distro_name}:${distro_version_name}${NC}/${BBlue}${distro_name}:${distro_version_number}${NC}"
        return 1
    fi
}

function get_incompatible_releases() {
    # example for this function is "ubuntu:jammy"
    local distro_name distro_version_name distro_version_number
    calc_distro
    # lowercase
    local input=("${@,,}")
    for key in "${input[@]}"; do
        # check for `*:jammy`
        if [[ $key == "*:"* ]]; then
            # check for `22.04` or `jammy`
            if [[ ${key#*:} == "${distro_version_number}" || ${key#*:} == "${distro_version_name}" ]]; then
                fancy_message error "This Pacscript does not work on ${BBlue}${distro_version_name}${NC}/${BBlue}${distro_version_number}${NC}"
                return 1
            fi
        # check for `ubuntu:*`
        elif [[ $key == *":*" ]]; then
            # check for `ubuntu`
            if [[ ${key%%:*} == "${distro_name}" ]]; then
                fancy_message error "This Pacscript does not work on ${BBlue}${distro_name}${NC}"
                return 1
            fi
        else
            # check for `ubuntu:jammy` or `ubuntu:22.04`
            if [[ $key == "${distro_name}:${distro_version_name}" || $key == "${distro_name}:${distro_version_number}" ]]; then
                fancy_message error "This Pacscript does not work on ${BBlue}${distro_name}:${distro_version_name}${NC}/${BBlue}${distro_name}:${distro_version_number}${NC}"
                return 1
            fi
        fi
    done
}

function is_compatible_arch() {
    local input=("${@}") ret=1 pacarch farch
    # shellcheck disable=SC2076
    if [[ " ${input[*]} " =~ " any " ]]; then
        ret=0
    elif [[ " ${input[*]} " =~ " ${CARCH} " ]]; then
        ret=0
    elif [[ -n ${FARCH[*]} ]]; then
        for pacarch in "${input[@]}"; do
            for farch in "${FARCH[@]}"; do
                if [[ ${pacarch} == "${farch}" ]]; then
                    fancy_message warn "This package is for ${BBlue}${farch}${NC}, which is a foreign architecture"
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
        fancy_message error "This Pacscript does not work on ${BBlue}${CARCH}${NC}"
    fi
    return "${ret}"
}

function install_builddepends() {
    # shellcheck disable=SC2034
    local build_dep not_installed_yet_builddepends bdeps_array bdeps_str check_dep not_installed_yet_checkdepends cdeps_array
    if [[ -n ${makedepends[*]} ]]; then
        for build_dep in "${makedepends[@]}"; do
            if ! is_apt_package_installed "${build_dep}"; then
                # If not installed yet, we can mark it as possibly removable
                not_installed_yet_builddepends+=("${build_dep}")
            fi
        done
        # format for apt satisfy/deb control file
        dep_const.format_control not_installed_yet_builddepends bdeps_array
    fi
    if [[ -n ${checkdepends[*]} ]] && is_function "check"; then
        for check_dep in "${checkdepends[@]}"; do
            if ! is_apt_package_installed "${check_dep}"; then
                not_installed_yet_checkdepends+=("${check_dep}")
            fi
        done
        dep_const.format_control not_installed_yet_checkdepends cdeps_array
    fi
    if ((${#not_installed_yet_builddepends[@]} != 0)) && ((${#not_installed_yet_checkdepends[@]} == 0)); then
        # if any makedeps are not installed, and there are no checkdeps to install
        dep_const.comma_array bdeps_array bdeps_str
        fancy_message info "${BLUE}$pkgname${NC} requires ${CYAN}${not_installed_yet_builddepends[*]}${NC} to build"
    elif ((${#not_installed_yet_builddepends[@]} == 0)) && ((${#not_installed_yet_checkdepends[@]} != 0)); then
        # if any checkdeps are not installed, and there are no makedeps to install
        dep_const.comma_array cdeps_array bdeps_str
        fancy_message info "${BLUE}$pkgname${NC} requires ${CYAN}${not_installed_yet_checkdepends[*]}${NC} to perform checks"
    elif ((${#not_installed_yet_builddepends[@]} != 0)) && ((${#not_installed_yet_checkdepends[@]} != 0)); then
        # if both need installs, append needed checkdeps to makedeps
        bdeps_array+=("${cdeps_array[@]}")
        dep_const.comma_array bdeps_array bdeps_str
        fancy_message info "${BLUE}$pkgname${NC} requires ${CYAN}${not_installed_yet_builddepends[*]}${NC} to build, and ${CYAN}${not_installed_yet_checkdepends[*]}${NC} to perform checks"
    fi
    if ((${#not_installed_yet_builddepends[@]} != 0)) || ((${#not_installed_yet_checkdepends[@]} != 0)); then
        fancy_message sub "Fetching apt repositories"
        # shellcheck disable=SC2015
        sudo apt-get update -qq --allow-releaseinfo-change \
            && sudo apt-get satisfy -yq "${bdeps_str}" \
            || {
                fancy_message error "Failed to install build or check dependencies"
                error_log 8 "install $PACKAGE"
                clean_fail_down
            }
    fi
}

function compare_remote_version() {
    local crv_input="${1}" remote_tmp remote_safe
    source "$METADIR/$crv_input" || return 1
    [[ ${_remoterepo} == "orphan" ]] && _remoterepo="${REPO}"
    if [[ -z ${_remoterepo} ]]; then
        return 0
    elif [[ ${_remoterepo} == *"github.com"* ]]; then
        local remoterepo="${_remoterepo/'github.com'/'raw.githubusercontent.com'}/${_remotebranch}"
    elif [[ ${_remoterepo} == *"gitlab.com"* ]]; then
        local remoterepo="${_remoterepo}/-/raw/${_remotebranch}"
    else
        local remoterepo="${_remoterepo}"
    fi
    local remotever localver
    remotever="$(
        unset pkgrel
        remote_tmp="$(sudo mktemp -p "${PACDIR}" -t "compare-repo-ver-$crv_input.XXXXXX")"
        remote_safe="${remote_tmp}"
        sudo curl -fsSL "$remoterepo/packages/$crv_input/$crv_input.pacscript" -o "${remote_safe}" \
            && safe_source "${remote_safe}" \
            && source "${safeenv}" \
            && if [[ ${pkgname} == *-git ]]; then
                parse_source_entry "${source[0]}"
                calc_git_pkgver
                echo "${epoch+$epoch:}${pkgver}-pacstall${pkgrel:-1}~git${comp_git_pkgver}"
            else
                echo "${epoch+$epoch:}${pkgver}-pacstall${pkgrel:-1}"
            fi
        sudo rm -rf "${remote_safe}"
    )" > /dev/null
    localver=$(source "/var/lib/pacstall/metadata/${crv_input}" && echo "${_version}")
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

# vim:set ft=sh ts=4 sw=4 noet:
