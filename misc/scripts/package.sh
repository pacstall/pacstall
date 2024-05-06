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

# shellcheck source=./misc/scripts/checks.sh
source "${SCRIPTDIR}/scripts/checks.sh" || {
    fancy_message error "Could not find checks.sh"
    return 1
}

# shellcheck source=./misc/scripts/fetch-sources.sh
source "${SCRIPTDIR}/scripts/fetch-sources.sh" || {
    fancy_message error "Could not find fetch-sources.sh"
    return 1
}

function trap_ctrlc() {
    fancy_message warn "\nInterrupted, cleaning up"
    if is_apt_package_installed "${pkgname}"; then
        sudo apt-get purge "${gives:-$pkgname}" -y > /dev/null
    fi
    sudo rm -f "/etc/apt/preferences.d/${pkgname:-$PACKAGE}-pin"
    cleanup
    exit 1
}

# NCPU is the core count
if [[ -n $PACSTALL_BUILD_CORES ]]; then
    if [[ $PACSTALL_BUILD_CORES =~ ^[0-9]+$ ]]; then
        function nproc() { echo "${PACSTALL_BUILD_CORES:-1}"; }
        declare -g NCPU="${PACSTALL_BUILD_CORES:-1}"
    else
        fancy_message error "${UCyan}PACSTALL_BUILD_CORES${NC} is not an integer. Falling back to 1"
        function nproc() { echo "1"; }
        declare -g NCPU="1"
    fi
else
    declare -g NCPU="$(nproc)"
fi

ask "(${BPurple}$PACKAGE${NC}) Do you want to view/edit the pacscript?" N
if ((answer == 1)); then
    (
        if [[ -n $PACSTALL_EDITOR ]]; then
            $PACSTALL_EDITOR "$PACKAGE".pacscript
        elif [[ -n $EDITOR ]]; then
            $EDITOR "$PACKAGE".pacscript
        elif [[ -n $VISUAL ]]; then
            $VISUAL "$PACKAGE".pacscript
        else
            sensible-editor "$PACKAGE".pacscript
        fi
    ) || {
        fancy_message warn "Editor not found, falling back to 'sensible-editor'"
        sensible-editor "$PACKAGE".pacscript
    }
fi

fancy_message info "Sourcing pacscript"
DIR="$PWD"
homedir="$(eval echo ~"$PACSTALL_USER")"
export homedir

sudo cp "${PACKAGE}.pacscript" /tmp
sudo chmod a+r "/tmp/${PACKAGE}.pacscript"
pacfile="$(readlink -f "/tmp/${PACKAGE}.pacscript")"
export pacfile
mapfile -t FARCH < <(dpkg --print-foreign-architectures)
export FARCH
export CARCH="$(dpkg --print-architecture)"
export DISTRO="$(set_distro)"

# Running source on an isolated env
safe_source "${pacfile}"
if ! source "${safeenv}"; then
    fancy_message error "Could not source pacscript"
    error_log 12 "install $PACKAGE"
    clean_fail_down
fi

if [[ ${external_connection} == "true" ]]; then
    fancy_message warn "This package will connect to the internet during its build process."
fi

append_archAndHash_entry
for i in {depends,makedepends,optdepends,pacdeps,checkdepends,provides,conflicts,breaks,replaces}; do
    append_var_arch "${i}" "${CARCH}"
done
gives_arch="gives_${CARCH}"
[[ -n ${!gives_arch} && -z ${gives} ]] && gives="${!gives_arch}"

# Running `-B` on a deb package doesn't make sense, so let's download instead
if ((PACSTALL_INSTALL == 0)) && [[ ${pkgname} == *-deb ]]; then
    if ! download "${source[0]}"; then
        fancy_message error "Failed to download '${source[0]}'"
        return 1
    else
        parse_source_entry "${source[0]}"
        fancy_message info "Moving ${BGreen}${PACDIR}/${dest}${NC} to ${BGreen}${PACDEB_DIR}/${dest}${NC}"
        sudo mv ./"${dest}" "${PACDEB_DIR}"
    fi
    return 0
fi

masked_packages=()
getMasks masked_packages
if ((${#masked_packages[@]} != 0)); then
    if array.contains masked_packages "${pkgname:-${PACKAGE}}"; then
        offending_pkg="$(getMasks_offending_pkg "${pkgname:-${PACKAGE}}")"
        # shellcheck disable=SC2181
        if (($? == 0)); then
            fancy_message error "The package ${BBlue}${offending_pkg}${NC} is masking ${BBlue}${pkgname:-${PACKAGE}}${NC}. By installing the masked package, you may cause damage to your operating system"
            exit 1
        else
            fancy_message error "Somehow, 'getMasks' found masked packages that match the package you want to install, but 'getMasks_offending_pkg' could not find it. Report this upstream"
            exit 1
        fi
    fi
fi

if [[ -n ${arch[*]} ]]; then
    if ! is_compatible_arch "${arch[@]}"; then
        cleanup
        exit 1
    fi
fi

if [[ -n ${compatible[*]} ]]; then
    if ! get_compatible_releases "${compatible[@]}"; then
        cleanup
        exit 1
    fi
elif [[ -n ${incompatible[*]} ]]; then
    if ! get_incompatible_releases "${incompatible[@]}"; then
        cleanup
        exit 1
    fi
fi

clean_builddir
sudo mkdir -p "$STAGEDIR/$pkgname/DEBIAN"
sudo chmod a+rx "$STAGEDIR" "$STAGEDIR/$pkgname" "$STAGEDIR/$pkgname/DEBIAN"

# Run checks function
if ! checks; then
    error_log 6 "install $PACKAGE"
    clean_fail_down
fi

# If priority exists and is required, and also that this package has not been installed before (first time)
if [[ -n ${priority} && ${priority} == 'essential' ]] && ! is_package_installed "${pkgname}"; then
    ask "This package has 'priority=essential', meaning once this is installed, it should be assumed to be uninstallable. Do you want to continue?" Y
    if ((answer == 0)); then
        cleanup
        exit 1
    fi
fi

# shellcheck disable=SC2031
if [[ ${pkgname} == *-git ]]; then
    parse_source_entry "${source[0]}"
    calc_git_pkgver
    full_version="${epoch+$epoch:}${pkgver}-pacstall${pkgrel:-1}~git${comp_git_pkgver}"
    git_pkgver="${comp_git_pkgver}"
    export git_pkgver
else
    full_version="${epoch+$epoch:}${pkgver}-pacstall${pkgrel:-1}"
fi

# Trap Crtl+C just before the point cleanup is first needed
trap "trap_ctrlc" 2

if [[ -n $ppa ]]; then
    for i in "${ppa[@]}"; do
        # Add ppa, but ppa bad I guess
        sudo add-apt-repository ppa:"$i"
    done
fi

if [[ -n $pacdeps ]]; then
    for i in "${pacdeps[@]}"; do
        # If /tmp/pacstall-pacdeps-"$i" is available, it will trigger the logger to log it as a dependency
        touch "/tmp/pacstall-pacdeps-$i"

        cmd="-I"
        [[ $KEEP ]] && cmd+="K"
        [[ $DISABLE_PROMPTS == "yes" ]] && cmd+="P"
        [[ $NOCHECK ]] && cmd+="Nc"
        ${PACSTALL_VERBOSE} || cmd+="Q"

        if pacstall -S "${i}@${REPO}" &> /dev/null; then
            repo="@${REPO}"
        fi
        if is_package_installed "${i}"; then
            pacstall_pacdep_status="$(compare_remote_version "$i")"
            if [[ $pacstall_pacdep_status == "update" ]]; then
                fancy_message info "Found newer version for $i pacdep"
                if ! pacstall "$cmd" "${i}${repo}"; then
                    fancy_message error "Failed to install dependency (${i} from ${PACKAGE})"
                    error_log 8 "install $PACKAGE"
                    clean_fail_down
                fi
            else
                fancy_message info "The pacstall dependency ${i} is already installed and at latest version"
            fi
        elif fancy_message info "Installing dependency ${PURPLE}${i}${NC}" && ! pacstall "$cmd" "${i}${repo}"; then
            fancy_message error "Failed to install dependency (${i} from ${PACKAGE})"
            error_log 8 "install $PACKAGE"
            clean_fail_down
        fi
        unset repo
        rm -f "/tmp/pacstall-pacdeps-$i"
    done
fi

if ! is_package_installed "${pkgname}"; then
    if [[ -n ${conflicts[*]} ]]; then
        for pkg in "${conflicts[@]}"; do
            # Do we have an apt package installed (but not pacstall)?
            if is_apt_package_installed "${pkg}" && ! is_package_installed "${pkg}"; then
                # Check if anything in conflicts variable is installed already
                # shellcheck disable=SC2031
                fancy_message error "${RED}$pkgname${NC} conflicts with $pkg, which is currently installed by apt"
                suggested_solution "Remove the apt package by running '${UCyan}sudo apt purge $pkg${NC}'"
                error_log 13 "install $PACKAGE"
                clean_fail_down
            fi
            if [[ ${pkg} != "${pkgname}" ]] && is_package_installed "${pkg}"; then
                # Same thing, but check if anything is installed with pacstall
                # shellcheck disable=SC2031
                fancy_message error "${RED}$pkgname${NC} conflicts with $pkg, which is currently installed by pacstall"
                suggested_solution "Remove the pacstall package by running '${UCyan}pacstall -R $pkg${NC}'"
                error_log 13 "install $PACKAGE"
                clean_fail_down
            fi
        done
    fi

    if [[ -n ${breaks[*]} ]]; then
        for pkg in "${breaks[@]}"; do
            # Do we have an apt package installed (but not pacstall)?
            if is_apt_package_installed "${pkg}" && ! is_package_installed "${pkg}"; then
                # Check if anything in breaks variable is installed already
                fancy_message error "${RED}$pkgname${NC} breaks $pkg, which is currently installed by apt"
                suggested_solution "Remove the apt package by running '${UCyan}sudo apt purge $pkg${NC}'"
                error_log 13 "install $PACKAGE"
                clean_fail_down
            fi
            if [[ ${pkg} != "${pkgname}" ]] && is_package_installed "${pkg}"; then
                # Same thing, but check if anything is installed with pacstall
                fancy_message error "${RED}$pkgname${NC} breaks $pkg, which is currently installed by pacstall"
                suggested_solution "Remove the pacstall package by running '${UCyan}pacstall -R $pkg${NC}'"
                error_log 13 "install $PACKAGE"
                clean_fail_down
            fi
        done
    fi

    if [[ -n ${replaces[*]} ]]; then
        # Ask user if they want to replace the program
        for pkg in "${replaces[@]}"; do
            if is_apt_package_installed "${pkg}"; then
                ask "This script replaces ${pkg}. Do you want to proceed?" Y
                if ((answer == 0)); then
                    clean_fail_down
                fi
                if [[ ${priority} == "essential" ]]; then
                    sudo apt-get remove -y "${pkg}" --allow-remove-essential
                else
                    sudo apt-get remove -y "${pkg}"
                fi
            fi
        done
    fi
fi

unset dest_list
declare -A dest_list
for i in "${!source[@]}"; do
    parse_source_entry "${source[$i]}"
    dest="${dest%.git}"
    if [[ -n ${dest_list[$dest]} && ${dest_list[$dest]} != "${source_url}" ]]; then
        fancy_message error "${dest} is associated with multiple source entries"
        clean_fail_down
    else
        dest_list["${dest}"]="${source_url}"
    fi
    genextr_declare
    unset ext_dep make_dep in_make_deps
    for ext_dep in "${ext_deps[@]}"; do
        in_make_deps=false
        for make_dep in "${makedepends[@]}"; do
            if [[ ${ext_dep} == "${make_dep}" ]]; then
                in_make_deps=true
                break
            fi
        done
        if ! ${in_make_deps}; then
            makedepends+=("${ext_dep}")
        fi
    done
    unset ext_dep make_dep in_make_deps
done
unset dest_list
install_builddepends

prompt_optdepends || return 1

fancy_message info "Retrieving packages"
if [[ -f /tmp/pacstall-pacdeps-"$PACKAGE" ]]; then
    mkdir -p "/tmp/pacstall-pacdep"
    if ! cd "/tmp/pacstall-pacdep" 2> /dev/null; then
        error_log 1 "install $PACKAGE"
        fancy_message error "Could not enter /tmp/pacstall-pacdep"
        exit 1
    fi
else
    mkdir -p "$PACDIR"
    if ! cd "$PACDIR" 2> /dev/null; then
        error_log 1 "install $PACKAGE"
        fancy_message error "Could not enter ${PACDIR}"
        exit 1
    fi
fi

mkdir -p "${PACDIR}"
gather_down

unset payload_arr
if [[ -n $PACSTALL_PAYLOAD && ! -f "/tmp/pacstall-pacdeps-$PACKAGE" ]]; then
    IFS=$'\n' read -rd '' -a payload_arr <<< "$(awk -v RS=';:' '{if (NF) print $0}' <<< "${PACSTALL_PAYLOAD}")"
fi

for i in "${!source[@]}"; do
    parse_source_entry "${source[$i]}"
    expectedHash="${hash[$i]}"
    if [[ -n ${payload_arr[*]} ]]; then
        for p in "${!payload_arr[@]}"; do
            if [[ ${payload_arr[$p]##*/} == "${dest}" ]]; then
                source_url="file://${payload_arr[$p]}"
            fi
        done
    fi
    if [[ $source_url != *://* ]]; then
        if [[ -z ${REPO} ]]; then
            # shellcheck disable=SC2086
            REPO="$(< ${SCRIPTDIR}/repo/pacstallrepo)"
        fi
        # shellcheck disable=SC2031
        source_url="${REPO}/packages/${pkgname}/${source_url}"
    fi
    case "${source_url,,}" in
        *file://*)
            source_url="${source_url#file://}"
            source_url="${source_url#git+}"
            file_down
            ;;
        *.git | git+*)
            if [[ $source_url == git+* ]]; then
                source_url="${source_url#git+}"
            fi
            git_down
            ;;
        *.deb)
            net_down
            deb_down && return 0
            ;;
        *.zip | *.tar.gz | *.tgz | *.tar.bz2 | *.tbz2 | *.tar.xz | *.txz | *.tar.zst | *.tzst | *.gz | *.bz2 | *.xz | *.lz | *.lzma | *.zst | *.7z | *.rar | *.lz4 | *.tar)
            net_down
            genextr_declare
            genextr_down
            ;;
        *)
            net_down
            hashcheck_down
            gather_down
            ;;
    esac
    unset expectedHash dest source_url git_branch git_tag git_commit ext_deps ext_method
done
unset hashsum_method payload_arr

if [[ -z ${_archive} ]]; then
    export _archive="${srcdir}"
fi
export pacdir="$PWD"
sudo chown -R root:root . 2> /dev/null

export pkgdir="$STAGEDIR/$pkgname"
export -f ask fancy_message select_options

# Trap so that we can clean up (hopefully without messing up anything)
trap cleanup ERR
trap - SIGINT

clean_logdir

function fail_out_functions() {
    local func="$1"
    trap - ERR
    eval "$restoreshopt"
    error_log 5 "$func $PACKAGE"
    echo -ne "\t"
    fancy_message error "Could not $func $PACKAGE properly"
    sudo dpkg -r "${gives:-$pkgname}" > /dev/null
    clean_fail_down
}

function safe_run() {
    local func="$1"
    export restoreshopt="$(shopt -p)
$(shopt -p -o)"
    local -
    shopt -o -s errexit errtrace pipefail

    local restoretrap="$(trap -p ERR)"
    trap "fail_out_functions '$func'" ERR

    bwrap_function "$func"

    trap - ERR
    eval "$restoreshopt"
    eval "$restoretrap"
}

unset pac_functions
if [[ $NOCHECK == true ]]; then
    for i in {prepare,build,package}; do
        if is_function "$i"; then
            pac_functions+=("$i")
        fi
    done
else
    for i in {prepare,build,check,package}; do
        if is_function "$i"; then
            pac_functions+=("$i")
        fi
    done
fi
if [[ -n ${pac_functions[*]} ]]; then
    fancy_message info "Running functions"
    for function in "${pac_functions[@]}"; do
        safe_run "$function"
    done
fi

trap - ERR

cd "$HOME" 2> /dev/null || (
    error_log 1 "install $PACKAGE"
    fancy_message warn "Could not enter into ${HOME}"
)

makedeb

# Metadata writing
meta_log

fancy_message info "Performing post install operations"
fancy_message sub "Storing pacscript"
sudo mkdir -p "/var/cache/pacstall/$PACKAGE/${full_version}"
if ! cd "$DIR" 2> /dev/null; then
    error_log 1 "install $PACKAGE"
    fancy_message error "Could not enter into ${DIR}"
    sudo dpkg -r "${gives:-$pkgname}" > /dev/null
    clean_fail_down
fi

sudo cp -r "${pacfile}" "/var/cache/pacstall/$PACKAGE/${full_version}"
sudo chmod o+r "/var/cache/pacstall/$PACKAGE/${full_version}/$PACKAGE.pacscript"

fancy_message sub "Cleaning up"
cleanup

fancy_message info "Done installing ${BPurple}$PACKAGE${NC}"
return 0

# vim:set ft=sh ts=4 sw=4 noet:
