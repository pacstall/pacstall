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
YELLOW='\033[1;33m'

BRed='\033[1;31m'
BGreen='\033[1;32m'
BYellow='\033[1;33m'

BIGreen='\033[1;92m'
BIRed='\033[1;91m'

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

if [[ ! -t 0 ]]; then
    NON_INTERACTIVE=true
    fancy_message warn "Reading input from pipe"
fi

# Check if pacstall is installed
if ! command -v pacstall &> /dev/null; then
    fancy_message error "Pacstall is not installed!"
    exit 1
fi

fancy_message info "You can keep the installed packages even after uninstalling Pacstall"
fancy_message info "Choose between the options:"
echo "	1. Remove Pacstall and installed packages."
echo "	2. Remove Pacstall only (Keep installed packages)."

while true; do
    echo -ne "Type selection number [${BIRed}1${NC}/${BIGreen}2${NC}] "
    read -r reply <&0
    if ((reply == 1)) || ((reply == 2)); then
        if ((reply == 1)); then
            fancy_message info "Removing Pacstall and installed packages..."

            # Remove packages
            if [[ -z $(pacstall -L) ]]; then
                fancy_message warn "Nothing is installed using Pacstall yet"
                fancy_message warn "Skipping package uninstallation"
            else
                for i in $(pacstall -L); do
                    pacstall -PR "$i"
                    rm -rfv "/etc/apt/preferences.d/${i//./-}-pin"
                done
            fi
            fancy_message info "Removing package metadata"
            sudo rm -rfv /var/lib/pacstall/metadata/
        fi
        fancy_message info "Removing Pacstall"
        sudo rm -v "$(command -v pacstall)"

        # Remove scripts and repos
        fancy_message info "Removing scripts and repositories"
        sudo rm -rfv /usr/share/pacstall/
        # Remove man page
        fancy_message info "Removing man pages"
        sudo rm -v /usr/share/man/man8/pacstall.8.gz
        sudo rm -v /usr/share/man/man5/pacstall.5.gz

        # Remove logs
        fancy_message info "Removing log files"
        sudo rm -rfv /var/log/pacstall/
        # Remove cache
        fancy_message info "Removing cache"
        sudo rm -rfv /usr/src/pacstall/
        sudo rm -rfv /var/cache/pacstall/
        # Remove tmp files
        fancy_message info "Removing temporary files"
        sudo rm -rfv /tmp/pacstall/
        break
    fi
done
fancy_message info "Uninstallation complete. Thanks for using Pacstall!"
# vim:set ft=sh ts=4 sw=4 et:
