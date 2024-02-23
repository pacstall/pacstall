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

# shellcheck source=./misc/scripts/build-local.sh
source "${STGDIR}/scripts/build-local.sh" || {
    fancy_message error "Could not find build-local.sh"
    return 1
}

function parse_source_entry() {
    unset url dest git_branch git_tag git_commit
    local entry="$1"
    url="${entry#*::}"
    dest="${entry%%::*}"
    if [[ $entry != *::* && $entry == *#*=* ]]; then
        dest="${url%%#*}"
        dest="${dest##*/}"
    fi
    case $url in
        *#branch=*)
            git_branch="${url##*#branch=}"
            url="${url%%#branch=*}"
            ;;
        *#tag=*)
            git_tag="${url##*#tag=}"
            url="${url%%#tag=*}"
            ;;
        *#commit=*)
            git_commit="${url##*#commit=}"
            url="${url%%#commit=*}"
            ;;
    esac
    url="${url%%#*}"
    if [[ $entry == *::* ]]; then
        dest="${entry%%::*}"
    elif [[ $entry != *#*=* ]]; then
        url="$entry"
        dest="${url##*/}"
    fi
    if [[ ${dest} == *"?"* ]]; then
        dest="${dest%%\?*}"
    fi
}

function calc_git_pkgver() {
    unset comp_git_pkgver
    local calc_commit
    if [[ $url == git+* ]]; then
        url="${url#git+}"
    fi
    if [[ -n ${git_branch} ]]; then
        calc_commit="$(git ls-remote "${url}" "${git_branch}")"
    elif [[ -n ${git_tag} ]]; then
        calc_commit="$(git ls-remote "${url}" "${git_tag}")"
    elif [[ -n ${git_commit} ]]; then
        calc_commit="${git_commit}"
    else
        calc_commit="$(git ls-remote "${url}" HEAD)"
    fi
    comp_git_pkgver="${calc_commit:0:8}"
}

function genextr_declare() {
    unset ext_method ext_deps
    # shellcheck disable=SC2031,SC2034
    case "${url,,}" in
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
    local inputFile="${1}" inputHash="${2}" fileHash
    # Get hash of file
    fileHash="$(sha256sum "${inputFile}")"
    fileHash="${fileHash%% *}"

    # Check if the input hash is the same as of the downloaded file.
    # Skip this test if the hash variable doesn't exist in the pacscript.
    if [[ -n ${inputHash} && ${inputHash} != "${fileHash}" ]]; then
        fancy_message error "Hashes do not match"
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
    if [[ -z ${pkgbase} ]]; then
        if [[ -n $PACSTALL_PAYLOAD ]]; then
            export pkgbase="/tmp/pacstall-pacdep"
        else
            export pkgbase="${SRCDIR}/${PACKAGE}~${pkgver}"
        fi
    fi
    mkdir -p "${pkgbase}"
    if ! [[ ${PWD} == "${pkgbase}" ]]; then
        find "${PWD}" -mindepth 1 -maxdepth 1 ! -wholename "${pkgbase}" \
            ! -wholename "${SRCDIR}" \
            ! -wholename "/tmp/pacstall-pacdep" \
            ! -wholename "/tmp/pacstall-pacdeps-$PACKAGE" \
            -exec mv {} "${pkgbase}/" \;
        cd "${pkgbase}" || {
            error_log 1 "gather-main $PACKAGE"
            fancy_message error "Could not enter into the main directory ${YELLOW}${pkgbase}${NC}"
            clean_fail_down
        }
    fi
}

function git_down() {
    local revision gitopts
    dest="${dest%.git}"
    if [[ -n ${git_branch} || -n ${git_tag} ]]; then
        if [[ -n ${git_branch} ]]; then
            revision="${git_branch}"
            fancy_message info "Cloning ${BPurple}${dest}${NC} from branch ${CYAN}${git_branch}${NC}"
        elif [[ -n ${git_tag} ]]; then
            revision="${git_tag}"
            fancy_message info "Cloning ${BPurple}${dest}${NC} from tag ${CYAN}${git_tag}${NC}"
        fi
        gitopts="--recurse-submodules -b ${revision}"
    elif [[ -n ${git_commit} ]]; then
        gitopts="--no-checkout --filter=blob:none"
        fancy_message info "Cloning ${BPurple}${dest}${NC} with no blobs"
    else
        gitopts="--recurse-submodules"
        fancy_message info "Cloning ${BPurple}${dest}${NC} from ${CYAN}HEAD${NC}"
    fi
    # git clone quietly, with no history, and if submodules are there, download with 10 jobs
    # shellcheck disable=SC2086,SC2031
    git clone --quiet --depth=1 --jobs=10 "${url}" "${dest}" ${gitopts} &> /dev/null || fail_down
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
        git submodule update --init --recursive
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
    if [[ ${source[i]} != "${source[0]}" ]]; then
        cd ..
        gather_down
    else
        export pkgbase="${PWD}"
    fi
}

function net_down() {
    fancy_message info "Downloading ${BPurple}${dest}${NC}"
    # shellcheck disable=SC2031
    download "$url" "$dest" || fail_down
}

function hashcheck_down() {
    if [[ -n ${expectedHash} && ${expectedHash} != "SKIP" ]]; then
        fancy_message sub "Checking hash ${YELLOW}${expectedHash:0:8}${NC}[${YELLOW}...${NC}]"
        hashcheck "${dest}" "${expectedHash}" || return 1
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
    if [[ ${source[i]} == "${source[0]}" && ${extract} == "true" ]]; then
        cd ./*/ 2> /dev/null || {
            error_log 1 "install $PACKAGE"
            fancy_message warn "Could not enter into the extracted archive"
            gather_down
        }
        export pkgbase="${PWD}"
    else
        gather_down
    fi
}

function deb_down() {
    hashcheck_down
    if type -t pre_install &> /dev/null; then
        if ! pre_install; then
            error_log 5 "pre_install hook"
            fancy_message error "Could not run preinst hook successfully"
            exit 1
        fi
    fi
    if sudo apt install -y -f ./"${dest}" 2> /dev/null; then
        meta_log
        if [[ -f /tmp/pacstall-pacdeps-"$pkgname" ]]; then
            sudo apt-mark auto "${gives:-$pkgname}" 2> /dev/null
        fi
        if type -t post_install &> /dev/null; then
            if ! post_install; then
                error_log 5 "post_install hook"
                fancy_message error "Could not run post_install hook successfully"
                exit 1
            fi
        fi
        fancy_message info "Storing pacscript"
        sudo mkdir -p "/var/cache/pacstall/$PACKAGE/${full_version}"
        if ! cd "$DIR" 2> /dev/null; then
            error_log 1 "install $PACKAGE"
            fancy_message error "Could not enter into ${DIR}"
            exit 1
        fi
        sudo cp -r "${pacfile}" "/var/cache/pacstall/$PACKAGE/${full_version}"
        sudo chmod o+r "/var/cache/pacstall/$PACKAGE/${full_version}/$PACKAGE.pacscript"
        fancy_message info "Cleaning up"
        cleanup
        exit 0
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
    cp -r "${url}" "${dest}" || fail_down
    genextr_declare
    if [[ -n ${ext_method} ]]; then
        genextr_down
    elif [[ ${source[i]} == "${source[0]}" && -d ${dest} ]]; then
        cd "./${dest}" 2> /dev/null || {
            error_log 1 "install $PACKAGE"
            fancy_message warn "Could not enter into the copied archive"
            gather_down
        }
        export pkgbase="${PWD}"
    else
        gather_down
    fi
}

function append_arch_entry() {
    local source_arch hash_arch
    # shellcheck disable=SC2153
    source_arch="source_${CARCH}[*]"
    hash_arch="hash_${CARCH}[*]"
    if [[ -n ${!source_arch} ]]; then
        # shellcheck disable=SC2206
        source+=(${!source_arch})
    fi
    if [[ -n ${!hash_arch} ]]; then
        # shellcheck disable=SC2206
        hash+=(${!hash_arch})
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
    if [[ -n ${makedepends[*]} ]]; then
        for build_dep in "${makedepends[@]}"; do
            if ! is_apt_package_installed "${build_dep}"; then
                # If not installed yet, we can mark it as possibly removable
                not_installed_yet_builddepends+=("${build_dep}")
            fi
        done

        if ((${#not_installed_yet_builddepends[@]} != 0)); then
            fancy_message info "${BLUE}$pkgname${NC} requires ${CYAN}${not_installed_yet_builddepends[*]}${NC} to install"
            if ! sudo apt-get install -y "${not_installed_yet_builddepends[@]}"; then
                fancy_message error "Failed to install build dependencies"
                error_log 8 "install $PACKAGE"
                fancy_message info "Cleaning up"
                cleanup
                return 1
            fi
        fi
    fi
}

function compare_remote_version() {
    local crv_input="${1}"
    unset -f pkgver 2> /dev/null
    source "$METADIR/$crv_input" || return 1
    if [[ -z ${_remoterepo} ]]; then
        return 0
    elif [[ ${_remoterepo} == *"github.com"* ]]; then
        local remoterepo="${_remoterepo/'github.com'/'raw.githubusercontent.com'}/${_remotebranch}"
    elif [[ ${_remoterepo} == *"gitlab.com"* ]]; then
        local remoterepo="${_remoterepo}/-/raw/${_remotebranch}"
    else
        local remoterepo="${_remoterepo}"
    fi
    local remotever
    remotever="$(
        unset pkgrel
        source <(curl -s -- "$remoterepo/packages/$crv_input/$crv_input.pacscript") && \
        if [[ ${pkgname} == *-git ]]; then
            parse_source_entry "${source[0]}"
            calc_git_pkgver
            echo "${epoch+$epoch:}${pkgver}-pacstall${pkgrel:-1}~git${comp_git_pkgver}"
        elif [[ ${pkgname} == *-deb ]]; then
            echo "${epoch+$epoch:}${pkgver}"
        else
            echo "${epoch+$epoch:}${pkgver}-pacstall${pkgrel:-1}"
        fi
    )" > /dev/null
    if [[ $crv_input == *"-git" ]]; then
        if [[ $(pacstall -Qi "$crv_input" version) != "$remotever" ]]; then
            echo "update"
        else
            echo "no"
        fi
    elif dpkg --compare-versions "$(pacstall -Qi "$crv_input" version)" lt "$remotever" > /dev/null 2>&1; then
        echo "update"
    else
        echo "no"
    fi
}

# vim:set ft=sh ts=4 sw=4 noet:
