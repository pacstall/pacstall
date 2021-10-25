#!/bin/bash

#     ____                  __        ____
#    / __ \____ ___________/ /_____ _/ / /
#   / /_/ / __ `/ ___/ ___/ __/ __ `/ / /
#  / ____/ /_/ / /__(__  ) /_/ /_/ / / /
# /_/	 \__,_/\___/____/\__/\__,_/_/_/
#
# Copyright (C) 2020-2021
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
NC="\033[0m"

RED='\033[0;31m'
YELLOW='\033[1;33m'
GREEN='\033[0;32m'
BIGreen='\033[1;92m'





function fancy_message() {
	# $1 = type , $2 = message
	# Message types
	# 0 - info
	# 1 - warning
	# 2 - error
	if [[ -z "${1}" ]] || [[ -z "${2}" ]]; then
		return
	fi

	local MESSAGE_TYPE="${1}"
	local MESSAGE="${2}"

	case ${MESSAGE_TYPE} in
		info) echo -e "[${GREEN}+${NC}] INFO: ${MESSAGE}";;
		warn) echo -e "[${YELLOW}*${NC}] WARNING: ${MESSAGE}";;
		error) echo -e "[${RED}!${NC}] ERROR: ${MESSAGE}";;
		*) echo -e "[?] UNKNOWN: ${MESSAGE}";;
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
apt-get install -y -qq sudo wget iputils-ping

echo -e "|------------------------|"
echo -e "|---${GREEN}Pacstall Installer${NC}---|"
echo -e "|------------------------|"

if [[ -n $PACSTALL_SKIP_NETWORK_CHECK ]]; then
	if ! (command -v nm-online -qx > /dev/null || ping -c 1 github.com > /dev/null); then
		fancy_message warn "You seem to be offline"
		exit 1
	fi
fi

echo ""
if [[ -z "$(find -H /var/lib/apt/lists -maxdepth 0 -mtime -7)" ]]; then
	fancy_message info "Updating"
	apt-get -qq update
fi

fancy_message info "Installing packages"

echo -ne "Do you want to install axel (faster downloads)? [${BIGreen}Y${NC}/${RED}n${NC}] "
read -r reply <&0
case "$reply" in
	N*|n*) ;;
	*) apt-get install -qq -y axel;;
esac

apt-get install -qq -y curl wget stow build-essential unzip tree bc git iputils-ping

LOGDIR="/var/log/pacstall/metadata"
STGDIR="/usr/share/pacstall"
SRCDIR="/tmp/pacstall"

fancy_message info "Making directories"
mkdir -p "$STGDIR"
mkdir -p "$STGDIR/scripts"
mkdir -p "$STGDIR/repo"

mkdir -p "$SRCDIR"
chown "$(logname)" -R "$SRCDIR"

mkdir -p "$LOGDIR"
mkdir -p "/var/log/pacstall/error_log"
chown "$(logname)" -R "/var/log/pacstall/error_log"

mkdir -p "/usr/share/man/man8"
mkdir -p "/usr/share/bash-completion/completions"

rm -f "$STGDIR/repo/pacstallrepo.txt" > /dev/null
touch "$STGDIR/repo/pacstallrepo.txt"
echo "https://raw.githubusercontent.com/pacstall/pacstall-programs/master" > $STGDIR/repo/pacstallrepo.txt

fancy_message info "Pulling scripts from GitHub"
for i in {error_log.sh,add-repo.sh,search.sh,download.sh,install-local.sh,upgrade.sh,remove.sh,update.sh,query-info.sh}; do
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
