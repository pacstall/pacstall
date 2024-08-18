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

if [[ ${external_connection} == "true" ]]; then
    fancy_message warn $"This package will connect to the internet during its build process."
fi

# if using arch-style architectures
if array.contains arch "${AARCH}"; then
    # only append arch-style
    TARCH="${AARCH}"
else
    # only append debian-style
    TARCH="${CARCH}"
fi
export TARCH
# FARCH will be useful here when pkgbase is implemented
append_modifier_entries "${TARCH}" "${DISTRO}"

# Running `-B` on a deb package doesn't make sense, so let's download instead
if ((PACSTALL_INSTALL == 0)) && [[ ${pacname} == *-deb ]]; then
    parse_source_entry "${source[0]}"
    if ! download "${source[0]}" "${dest}"; then
        fancy_message error $"Failed to download '${source[0]}'"
        { ignore_stack=true; return 1; }
    else
        fancy_message info $"Moving ${BGreen}${PACDIR}/${dest}${NC} to ${BGreen}${PACDEB_DIR}/${dest}${NC}"
        sudo mv ./"${dest}" "${PACDEB_DIR}"
    fi
    return 0
fi

masked_packages=()
getMasks masked_packages
if ((${#masked_packages[@]} != 0)); then
    if array.contains masked_packages "${pacname:-${PACKAGE}}"; then
        offending_pkg="$(getMasks_offending_pkg "${pacname:-${PACKAGE}}")"
        # shellcheck disable=SC2181
        if (($? == 0)); then
            fancy_message error $"The package ${BBlue}${offending_pkg}${NC} is masking ${BBlue}${pacname:-${PACKAGE}}${NC}. By installing the masked package, you may cause damage to your operating system"
            exit 1
        else
            fancy_message error $"Somehow, 'getMasks' found masked packages that match the package you want to install, but 'getMasks_offending_pkg' could not find it. Report this upstream"
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
        [[ ${GITHUB_ACTIONS} == "true" ]] && exit 0 || exit 1
    fi
elif [[ -n ${incompatible[*]} ]]; then
    if ! get_incompatible_releases "${incompatible[@]}"; then
        cleanup
        [[ ${GITHUB_ACTIONS} == "true" ]] && exit 0 || exit 1
    fi
fi

clean_builddir
sudo mkdir -p "$STAGEDIR/$pacname/DEBIAN"
sudo chmod a+rx "$STAGEDIR" "$STAGEDIR/$pacname" "$STAGEDIR/$pacname/DEBIAN"

# Run checks function
if ! checks; then
    error_log 6 "install ${pacname}"
    clean_fail_down
fi

# If priority exists and is required, and also that this package has not been installed before (first time)
if [[ -n ${priority} && ${priority} == 'essential' ]] && ! is_package_installed "${pacname}"; then
    ask "This package has 'priority=essential', meaning once this is installed, it should be assumed to be uninstallable. Do you want to continue?" Y
    if ((answer == 0)); then
        cleanup
        exit 1
    fi
fi

# shellcheck disable=SC2031
if [[ ${pacname} == *-git ]]; then
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

if ! is_package_installed "${pacname}"; then
    if [[ -n ${replaces[*]} ]]; then
        # Ask user if they want to replace the program
        for pkg in "${replaces[@]}"; do
            if is_apt_package_installed "${pkg}"; then
                ask "This script replaces ${pkg}. Do you want to proceed?" Y
                if ((answer == 0)); then
                    clean_fail_down
                fi
            fi
        done
    fi
    # shellcheck disable=SC2031
    if [[ -n ${conflicts[*]} || -n ${makeconflicts[*]} || -n ${checkconflicts[*]} ]]; then
        # shellcheck disable=SC2031
        for pkg in "${conflicts[@]}" "${makeconflicts[@]}" "${checkconflicts[@]}"; do
            if ! array.contains replaces "${pkg}"; then
                # Do we have an apt package installed (but not pacstall)?
                if is_apt_package_installed "${pkg}" && ! is_package_installed "${pkg}"; then
                    # Check if anything in conflicts variable is installed already
                    # shellcheck disable=SC2031
                    fancy_message error $"${RED}$pacname${NC} conflicts with $pkg, which is currently installed by apt"
                    suggested_solution "Remove the apt package by running '${UCyan}sudo apt purge $pkg${NC}'"
                    error_log 13 "install ${pacname}"
                    clean_fail_down
                fi
                if [[ ${pkg} != "${pacname}" ]] && is_package_installed "${pkg}"; then
                    # Same thing, but check if anything is installed with pacstall
                    # shellcheck disable=SC2031
                    fancy_message error $"${RED}$pacname${NC} conflicts with $pkg, which is currently installed by pacstall"
                    suggested_solution "Remove the pacstall package by running '${UCyan}pacstall -R $pkg${NC}'"
                    error_log 13 "install ${pacname}"
                    clean_fail_down
                fi
            fi
        done
    fi
    if [[ -n ${breaks[*]} ]]; then
        for pkg in "${breaks[@]}"; do
            if ! array.contains replaces "${pkg}"; then
                # Do we have an apt package installed (but not pacstall)?
                if is_apt_package_installed "${pkg}" && ! is_package_installed "${pkg}"; then
                    # Check if anything in breaks variable is installed already
                    fancy_message error $"${RED}$pacname${NC} breaks $pkg, which is currently installed by apt"
                    suggested_solution "Remove the apt package by running '${UCyan}sudo apt purge $pkg${NC}'"
                    error_log 13 "install ${pacname}"
                    clean_fail_down
                fi
                if [[ ${pkg} != "${pacname}" ]] && is_package_installed "${pkg}"; then
                    # Same thing, but check if anything is installed with pacstall
                    fancy_message error $"${RED}$pacname${NC} breaks $pkg, which is currently installed by pacstall"
                    suggested_solution "Remove the pacstall package by running '${UCyan}pacstall -R $pkg${NC}'"
                    error_log 13 "install ${pacname}"
                    clean_fail_down
                fi
            fi
        done
    fi
fi

if [[ -n $ppa ]]; then
    for i in "${ppa[@]}"; do
        # Add ppa, but ppa bad I guess
        sudo add-apt-repository ppa:"$i"
    done
fi

if [[ -n ${pacdeps[*]} ]]; then
    fancy_message info $"Checking pacstall dependencies"
    for pdep in "${pacdeps[@]}"; do
        # If "${PACDIR}-pacdeps-$i" is available, it will trigger the logger to log it as a dependency
        touch "${PACDIR}-pacdeps-$pdep"
        cmd="-I"
        [[ $KEEP ]] && cmd+="K"
        [[ $DISABLE_PROMPTS == "yes" ]] && cmd+="P"
        [[ $NOCHECK ]] && cmd+="Nc"
        [[ $NOSANDBOX ]] && cmd+="Ns"
        ${PACSTALL_VERBOSE} || cmd+="Q"

        if [[ -n ${REPO} ]] && pacstall -S "${pdep}@${REPO}" &> /dev/null; then
            repo="@${REPO}"
        fi
        if is_package_installed "${pdep}"; then
            pacstall_pacdep_status="$(compare_remote_version "$pdep")"
            if [[ $pacstall_pacdep_status == "update" ]]; then
                fancy_message sub $"${PURPLE}${pdep}${NC} ${GREEN}↑${YELLOW}↓${NC} [update]"
                if ! pacstall "$cmd" "${pdep}${repo}"; then
                    fancy_message error $"Failed to install dependency (${pdep} from ${PACKAGE})"
                    error_log 8 "install ${pacname}"
                    clean_fail_down
                fi
            else
                fancy_message sub $"${PURPLE}${pdep}${NC} ${GREEN}✓${NC} [installed]"
                if ! awk '/_pacstall_depends="true"/ {found=1; exit} END {if (found != 1) exit 1}' "${METADIR}/${pdep}"; then
                    echo '_pacstall_depends="true"' | sudo tee -a "${METADIR}/${pdep}" > /dev/null
                fi
            fi
        elif fancy_message sub $"${PURPLE}${pdep}${NC} ${RED}✗${NC} [required]" && ! pacstall "$cmd" "${pdep}${repo}"; then
            fancy_message error $"Failed to install dependency (${pdep} from ${PACKAGE})"
            error_log 8 "install ${pacname}"
            clean_fail_down
        fi
        unset repo
        rm -f "${PACDIR}-pacdeps-$pdep"
    done
fi

unset dest_list
declare -A dest_list
for i in "${!source[@]}"; do
    parse_source_entry "${source[$i]}"
    dest="${dest%.git}"
    if [[ -n ${dest_list[$dest]} && ${dest_list[$dest]} != "${source_url}" ]]; then
        fancy_message error $"${dest} is associated with multiple source entries"
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

# shellcheck disable=SC2034
prompt_depends || { ignore_stack=true; return 1; }

fancy_message info $"Retrieving packages"
mkdir -p "${PACDIR}"
gather_down

unset payload_arr
if [[ -n $PACSTALL_PAYLOAD && ! -f "${PACDIR}-pacdeps-${pacname}" ]]; then
    mapfile -t payload_arr < <(awk -v RS=';:' '{if (NF) print $0}' <<< "${PACSTALL_PAYLOAD}")
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
        if [[ -f "${PKGPATH}/${dest}" ]]; then
            source_url="file://${PKGPATH}/${dest}"
        else
            if [[ -z ${REPO} ]]; then
                REPO="$(head -n1 "${SCRIPTDIR}/repo/pacstallrepo")"
            fi
            # shellcheck disable=SC2031
            source_url="${REPO}/packages/${pacname}/${source_url}"
        fi
    fi
    case "${source_url}" in
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
        *.zip | *.tar.gz | *.tgz | *.tar.bz2 | *.tbz2 | *.tar.bz | *.tbz | *.tar.xz | *.txz | *.tar.zst | *.tzst | *.gz | *.bz2 | *.xz | *.lz | *.lzma | *.zst | *.7z | *.rar | *.lz4 | *.tar)
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

export pkgdir="$STAGEDIR/$pacname"
export -f ask fancy_message select_options

clean_logdir

unset pac_functions
if [[ $NOCHECK == true ]]; then
    for i in "prepare" "build" "package${pkgbase:+_$pacname}"; do
        if is_function "$i"; then
            pac_functions+=("$i")
        fi
    done
else
    for i in "prepare" "build" "check" "package${pkgbase:+_$pacname}"; do
        if is_function "$i"; then
            pac_functions+=("$i")
        fi
    done
fi
if [[ -n ${pac_functions[*]} ]]; then
    fancy_message info $"Running functions"
    for function in "${pac_functions[@]}"; do
        if ! bwrap_function "${function}"; then
            error_log 5 "${function} ${pacname}"
            echo -ne "\t"
            fancy_message error $"Could not ${function} ${pacname} properly"
            clean_fail_down
        fi
    done
fi

cd "$HOME" 2> /dev/null || (
    error_log 1 "install ${pacname}"
    fancy_message warn $"Could not enter into ${HOME}"
)

# shellcheck source=/dev/null
source "${safeenv}"
makedeb

# Metadata writing
meta_log

fancy_message info $"Performing post install operations"
fancy_message sub $"Storing pacscript"
sudo mkdir -p "/var/cache/pacstall/${pacname}/${full_version}"
if ! cd "$DIR" 2> /dev/null; then
    error_log 1 "install ${pacname}"
    fancy_message error $"Could not enter into ${DIR}"
    sudo dpkg -r "${gives:-$pacname}" 2> /dev/null
    clean_fail_down
fi

sudo cp -r "${pacfile}" "/var/cache/pacstall/${pacname}/${full_version}"
sudo chmod o+r "/var/cache/pacstall/${pacname}/${full_version}/${PACKAGE}.pacscript"
sudo cp -r "${srcinfile}" "/var/cache/pacstall/${pacname}/${full_version}/.SRCINFO"
sudo chmod o+r "/var/cache/pacstall/${pacname}/${full_version}/.SRCINFO"

fancy_message info $"Done installing ${BPurple}${pacname}${NC}"
return 0

# vim:set ft=sh ts=4 sw=4 et:
