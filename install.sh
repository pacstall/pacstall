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

function check_url() {
    http_code="$(curl -o /dev/null -s --head --write-out '%{http_code}\n' -- "${1}")"
    case "${http_code}" in
        000)
            fancy_message error "Failed to download file, check your connection"
            error_log 1 "get ${PACKAGE} pacscript"
            return 1
            ;;
        404)
            fancy_message error "The URL cannot be found"
            return 1
            ;;
        200 | 301 | 302)
            true
            ;;
        *)
            fancy_message error "Failed with http code ${http_code}"
            return 1
            ;;
    esac
}

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

if [[ ${GITHUB_ACTIONS} != "true" ]]; then
    check_url "https://github.com" || {
        fancy_message error "Could not connect to the internet"
        exit 1
    }
fi

echo
if [[ -z "$(find -H /var/lib/apt/lists -maxdepth 0 -mtime -7)" ]]; then
    fancy_message info "Updating"
    case "${GITHUB_ACTIONS}" in
        true) apt-get update -qq ;;
        *) apt-get update ;;
    esac
fi

fancy_message info "Installing packages"

echo -ne "Do you want to install axel (faster downloads)? [${BGreen}Y${NC}/${RED}n${NC}] "
read -r reply <&0
case "$reply" in
    N* | n*) unset axel_inst ;;
    *)
        axel_inst=axel
        ;;
esac

if [[ ${GITHUB_ACTIONS} == "true" ]]; then
    apt-get install -qq -y sudo wget build-essential unzip git zstd iputils-ping lsb-release aptitude bubblewrap jq distro-info-data ${axel_inst}
else
    apt-get install -y sudo wget build-essential unzip git zstd iputils-ping lsb-release aptitude bubblewrap jq distro-info-data ${axel_inst}
fi

METADIR="/var/lib/pacstall/metadata"
LOGDIR="/var/log/pacstall/error_log"
SCRIPTDIR="/usr/share/pacstall"
PACDIR="/tmp/pacstall"
PACSTALL_USER=$(logname 2> /dev/null || echo "${SUDO_USER:-${USER:-$(whoami)}}")

fancy_message info "Making directories"
mkdir -p "$SCRIPTDIR"
mkdir -p "$SCRIPTDIR/scripts"
mkdir -p "$SCRIPTDIR/repo"

mkdir -p "$PACDIR"
chown "$PACSTALL_USER" -R "$PACDIR"

mkdir -p "$METADIR"
mkdir -p "$LOGDIR"
chown "$PACSTALL_USER" -R "$LOGDIR"

mkdir -p "/usr/share/man/man8"
mkdir -p "/usr/share/bash-completion/completions"

rm -f "$SCRIPTDIR/repo/pacstallrepo" > /dev/null
touch "$SCRIPTDIR/repo/pacstallrepo"
echo "https://raw.githubusercontent.com/pacstall/pacstall-programs/master" > $SCRIPTDIR/repo/pacstallrepo

fancy_message info "Pulling scripts from GitHub"
for i in {error-log.sh,add-repo.sh,search.sh,dep-tree.sh,version-constraints.sh,checks.sh,get-pacscript.sh,package.sh,fetch-sources.sh,build.sh,upgrade.sh,remove.sh,update.sh,query-info.sh,quality-assurance.sh,bwrap.sh,srcinfo.sh}; do
    wget -q --show-progress -N https://raw.githubusercontent.com/pacstall/pacstall/master/misc/scripts/"$i" -P "$SCRIPTDIR/scripts" &
done

wget -q --show-progress --progress=bar:force -O "/bin/pacstall" "https://raw.githubusercontent.com/pacstall/pacstall/master/pacstall" &
wget -q --show-progress --progress=bar:force -O "/usr/share/man/man8/pacstall.8.gz" "https://raw.githubusercontent.com/pacstall/pacstall/master/misc/pacstall.8.gz" &

mkdir -p "/usr/share/bash-completion/completions"
mkdir -p "/usr/share/fish/vendor_completions.d"
wget -q --show-progress --progress=bar:force -O "/usr/share/bash-completion/completions/pacstall" "https://raw.githubusercontent.com/pacstall/pacstall/master/misc/completion/bash" &
wget -q --show-progress --progress=bar:force -O "/usr/share/fish/vendor_completions.d/pacstall.fish" "https://raw.githubusercontent.com/pacstall/pacstall/master/misc/completion/fish" &

wait

chmod +x "/bin/pacstall"
chmod +x $SCRIPTDIR/scripts/*
# vim:set ft=sh ts=4 sw=4 noet:
