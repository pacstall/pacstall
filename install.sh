#!/bin/bash

#     ____                  __        ____
#    / __ \____ ___________/ /_____ _/ / /
#   / /_/ / __ `/ ___/ ___/ __/ __ `/ / /
#  / ____/ /_/ / /__(__  ) /_/ /_/ / / /
# /_/	 \__,_/\___/____/\__/\__,_/_/_/
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

# Colors
BOLD='\033[1m'
NC="\033[0m"

RED='\033[0;31m'
GREEN='\033[0;32m'

BRed='\033[1;31m'
BGreen='\033[1;32m'
BYellow='\033[1;33m'
PACCYAN='\e[38;5;30m'
PACYELLOW='\e[38;5;214m'

function fancy_message() {
    # $1 = type , $2 = message
    # Message types
    # 0 - info
    # 1 - warning
    # 2 - error
    if [[ -z ${1} || -z ${2} ]]; then
        return
    fi

    local MESSAGE_TYPE="${1}"
    local MESSAGE="${2}"

    case ${MESSAGE_TYPE} in
        info) echo -e "[${BGreen}+${NC}] INFO: ${MESSAGE}" ;;
        warn) echo >&2 -e "[${BYellow}*${NC}] WARNING: ${MESSAGE}" ;;
        error) echo >&2 -e "[${BRed}!${NC}] ERROR: ${MESSAGE}" ;;
        *) echo >&2 -e "[${BOLD}?${NC}] UNKNOWN: ${MESSAGE}" ;;
    esac
}

((EUID != 0)) && { fancy_message error "Must be root to install Pacstall!"; exit 1; }

if [[ ! -t 0 ]]; then
    NON_INTERACTIVE=true
    fancy_message warn "Reading input from pipe"
fi

if ! command -v apt &> /dev/null; then
    fancy_message error "apt could not be found"
    exit 1
fi

if ! command -v curl &> /dev/null; then
    apt-get install -y -qq curl iputils-ping
fi

echo -e "${PACYELLOW}┌────────────────────────┐\n│   ${PACCYAN}Pacstall Installer${PACYELLOW}   │\n└────────────────────────┘${NC}"

echo
if [[ -z "$(find -H /var/lib/apt/lists -maxdepth 0 -mtime -7)" ]]; then
    fancy_message info "Updating"
    case "${GITHUB_ACTIONS}" in
        true) apt-get update -qq ;;
        *) apt-get update ;;
    esac
fi

fancy_message info "Installing packages"
pacstall_deps=(
    "sudo" "wget" "build-essential" "unzip" "git"
    "zstd" "iputils-ping" "aptitude" "bubblewrap"
    "jq" "distro-info-data" "spdx-licenses"
)
echo -ne "Do you want to install axel (faster downloads)? [${BGreen}Y${NC}/${RED}n${NC}] "
read -r reply <&0
case "$reply" in
    N* | n*) ;;
    *)
        pacstall_deps+=("axel")
        ;;
esac

for pkg in "${pacstall_deps[@]}"; do
    if ! dpkg -s "${pkg}" > /dev/null 2>&1; then
        if [[ ${pkg} == "spdx-licenses" ]]; then
            if [[ -z $(apt-cache search --names-only "^${pkg}$") ]]; then
                curl -s "http://ftp.debian.org/debian/pool/main/s/${pkg}/${pkg}_3.8+dfsg-3_all.deb" -o "/tmp/${pkg}.deb" && \
                    sudo apt install "/tmp/${pkg}.deb" -y && sudo rm -f "/tmp/${pkg}.deb" && continue
            fi
        fi
        to_install+=("${pkg}")
    fi
done
if ((${#to_install[@]} != 0)); then
    if [[ ${GITHUB_ACTIONS} == "true" ]]; then
        apt-get install -qq -y "${to_install[@]}"
    else
        apt-get install -y "${to_install[@]}"
    fi
fi

METADIR="/var/lib/pacstall/metadata"
LOGDIR="/var/log/pacstall/error_log"
SCRIPTDIR="/usr/share/pacstall"
PACDIR="/tmp/pacstall"
MANDIR="/usr/share/man/man8"
BASH_COMPLETION_DIR="/usr/share/bash-completion/completions"
FISH_COMPLETION_DIR="/usr/share/fish/vendor_completions.d"
REPO="https://raw.githubusercontent.com/pacstall/pacstall/master"
PACSTALL_USER=$(logname 2> /dev/null || echo "${SUDO_USER:-${USER:-$(whoami)}}")

fancy_message info "Making directories"
mkdir -p "${SCRIPTDIR}/scripts" "${SCRIPTDIR}/repo" "${PACDIR}" "${METADIR}" "${LOGDIR}" "${MANDIR}" "${BASH_COMPLETION_DIR}" "${FISH_COMPLETION_DIR}"
chown "${PACSTALL_USER}" -cR "${PACDIR}" "${LOGDIR}"

fancy_message info "Pulling scripts from GitHub"
pacstall_scripts=(
    "error-log" "add-repo" "search" "dep-tree" "version-constraints"
    "checks" "get-pacscript" "package" "package-base" "fetch-sources"
    "build" "upgrade" "remove" "update" "query-info" "quality-assurance"
    "bwrap" "srcinfo"
)
rm -f "${SCRIPTDIR}/repo/pacstallrepo" > /dev/null
echo "${REPO/pacstall\/pacstall/pacstall\/pacstall-programs}" > "${SCRIPTDIR}/repo/pacstallrepo"
for script in "${pacstall_scripts[@]}"; do
    wget -q --show-progress -N "${REPO}/misc/scripts/${script}.sh" -P "${SCRIPTDIR}/scripts" &
done
wget -q --show-progress --progress=bar:force -O "/usr/bin/pacstall" "${REPO}/pacstall" &
wget -q --show-progress --progress=bar:force -O "${MANDIR}/pacstall.8" "${REPO}/misc/pacstall.8" &
wget -q --show-progress --progress=bar:force -O "${BASH_COMPLETION_DIR}/pacstall" "${REPO}/misc/completion/bash" &
wget -q --show-progress --progress=bar:force -O "${FISH_COMPLETION_DIR}/pacstall.fish" "${REPO}/misc/completion/fish" &
wait

chmod +x "/usr/bin/pacstall"
chmod +x "${SCRIPTDIR}/scripts/"*
gzip --force -9n "${MANDIR}/pacstall.8"

fancy_message info "Installation complete"
# vim:set ft=sh ts=4 sw=4 et:
