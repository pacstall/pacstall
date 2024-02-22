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
apt-get install -y -qq sudo wget curl iputils-ping

echo -e "|------------------------|"
echo -e "|---${GREEN}Pacstall Installer${NC}---|"
echo -e "|------------------------|"

if [[ ${GITHUB_ACTIONS} != "true" ]]; then
    check_url "https://github.com" || {
        fancy_message error "Could not connect to the internet"
        exit 1
    }
fi

echo
if [[ -z "$(find -H /var/lib/apt/lists -maxdepth 0 -mtime -7)" ]]; then
    fancy_message info "Updating"
    apt-get -qq update
fi

fancy_message info "Installing packages"

echo -ne "Do you want to install axel (faster downloads)? [${BGreen}Y${NC}/${RED}n${NC}] "
read -r reply <&0
case "$reply" in
    N* | n*) ;;
    *) apt-get install -qq -y axel ;;
esac

apt-get install -qq -y curl wget build-essential unzip git zstd iputils-ping lsb-release

LOGDIR="/var/lib/pacstall/metadata"
STGDIR="/usr/share/pacstall"
SRCDIR="/tmp/pacstall"
PACSTALL_USER=$(logname 2> /dev/null || echo "${SUDO_USER:-${USER}}")

fancy_message info "Making directories"
mkdir -p "$STGDIR"
mkdir -p "$STGDIR/scripts"
mkdir -p "$STGDIR/repo"

mkdir -p "$SRCDIR"
chown "$PACSTALL_USER" -R "$SRCDIR"

mkdir -p "$LOGDIR"
mkdir -p "/var/log/pacstall/error_log"
chown "$PACSTALL_USER" -R "/var/log/pacstall/error_log"

mkdir -p "/usr/share/man/man8"
mkdir -p "/usr/share/bash-completion/completions"

rm -f "$STGDIR/repo/pacstallrepo" > /dev/null
touch "$STGDIR/repo/pacstallrepo"
echo "https://raw.githubusercontent.com/pacstall/pacstall-programs/master" > $STGDIR/repo/pacstallrepo

fancy_message info "Pulling scripts from GitHub"
for i in {error_log.sh,add-repo.sh,search.sh,dep-tree.sh,checks.sh,download.sh,install-local.sh,download-local.sh,build-local.sh,upgrade.sh,remove.sh,update.sh,query-info.sh}; do
    wget -q --show-progress -N https://raw.githubusercontent.com/pacstall/pacstall/master/misc/scripts/"$i" -P "$STGDIR/scripts" &
done

wget -q --show-progress --progress=bar:force -O "/bin/pacstall" "https://raw.githubusercontent.com/pacstall/pacstall/master/pacstall" &
wget -q --show-progress --progress=bar:force -O "/usr/share/man/man8/pacstall.8.gz" "https://raw.githubusercontent.com/pacstall/pacstall/master/misc/pacstall.8.gz" &

mkdir -p "/usr/share/bash-completion/completions"
mkdir -p "/usr/share/fish/vendor_completions.d"
wget -q --show-progress --progress=bar:force -O "/usr/share/bash-completion/completions/pacstall" "https://raw.githubusercontent.com/pacstall/pacstall/master/misc/completion/bash" &
wget -q --show-progress --progress=bar:force -O "/usr/share/fish/vendor_completions.d/pacstall.fish" "https://raw.githubusercontent.com/pacstall/pacstall/master/misc/completion/fish" &

wait

chmod +x "/bin/pacstall"
chmod +x $STGDIR/scripts/*
# vim:set ft=sh ts=4 sw=4 noet:
