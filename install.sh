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
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'

BIGreen='\033[1;92m'
BIRed='\033[1;91m'

function fancy_message() {
	# $1 = type , $2 = message
	# Message types
	# 0 - info
	# 1 - warning
	# 2 - error
	if [[ -z "${1}" ]] || [[ -z "${2}" ]]; then
		return
	fi

	local MESSAGE_TYPE=""
	local MESSAGE=""
	MESSAGE_TYPE="${1}"
	MESSAGE="${2}"

	case ${MESSAGE_TYPE} in
		info) echo -e "[${GREEN}+${NC}] INFO: ${MESSAGE}";;
		warn) echo -e "[${YELLOW}*${NC}] WARNING: ${MESSAGE}";;
		error) echo -e "[${RED}!${NC}] ERROR: ${MESSAGE}";;
		*) echo -e "[?] UNKNOWN: ${MESSAGE}";;
	esac
}

function ask() {
	local prompt default reply

	if [[ ${2:-} = 'Y' ]]; then
		prompt="${BIGreen}Y${NC}/${RED}n${NC}"
		default='Y'
	elif [[ ${2:-} = 'N' ]]; then
		prompt="${GREEN}y${NC}/${BIRed}N${NC}"
		default='N'
	else
		prompt="${GREEN}y${NC}/${RED}n${NC}"
	fi

	# Ask the question (not using "read -p" as it uses stderr not stdout)
	echo -ne "$1 [$prompt] "

	# Read the answer (use /dev/tty in case stdin is redirected from somewhere else)
	if [[ -z "$DISABLE_PROMPTS" ]]; then
		read -r reply < /dev/tty
	else
		echo "$default"
		reply=$default
	fi

	# Default?
	if [[ -z $reply ]]; then
		reply=$default
	fi

	while true; do
		# Check if the reply is valid
		case "$reply" in
			Y*|y*)
				export answer=1
				return 0	#return code for backwards compatibility
				break
				;;
			N*|n*)
				export answer=0
				return 1	#return code
				break
				;;
			*)
				echo -ne "$1 [$prompt] "
				read -r reply < /dev/tty
				;;
		esac
	done
}

function banner() {
	echo -e "|------------------------|"
	echo -e "|---${GREEN}Pacstall Installer${NC}---|"
	echo -e "|------------------------|"
	echo " "
}

if ! command -v apt &> /dev/null; then
	fancy_message error "apt could not be found"
	exit 1
fi
# Install wget and sudo (probably already installed but this is important for the tester)
apt-get install -y -qq sudo wget


banner

printf "Checking for internet access: "

wget -q --tries=10 --timeout=20 --spider https://github.com &
PID=$!
i=1
sp="/-\|"
printf ' '
while [[ -d /proc/$PID ]]
do
	sleep 0.1
	printf "\b%s" "${sp:i++%${#sp}:1}"
done
if [[ $? -eq 1 ]] ; then
	fancy_message warn "You seem to be offline"
	exit 1
fi

echo ""
fancy_message info "Updating"
sudo apt-get -qq update

fancy_message info "Installing packages"


ask "Do you want to install axel?" Y
if [[ "$answer" -eq 1 ]]; then
    sudo apt-get install -qq -y axel
fi
ask "Do you want to install ripgrep?" Y
if [[ "$answer" -eq 1 ]]; then
    sudo apt-get install -qq -y ripgrep
fi

sudo apt-get install -qq -y curl wget stow build-essential unzip tree bc fakeroot


export STGDIR="/usr/share/pacstall"
export SRCDIR="/tmp/pacstall"

fancy_message info "Making directories"
mkdir -p $STGDIR
mkdir -p $STGDIR/scripts
mkdir -p $STGDIR/repo

mkdir -p $SRCDIR
sudo chown "$(logname)" -R $SRCDIR

mkdir -p /var/log/pacstall/metadata
mkdir -p /var/log/pacstall/error_log
sudo chown "$(logname)" -R /var/log/pacstall/error_log
sudo mkdir -p /usr/share/man/man8/
sudo mkdir -p /usr/share/bash-completion/completions

rm -f $STGDIR/repo/pacstallrepo.txt > /dev/null
touch $STGDIR/repo/pacstallrepo.txt
echo 'https://raw.githubusercontent.com/pacstall/pacstall-programs/master' > $STGDIR/repo/pacstallrepo.txt

fancy_message info "Pulling scripts from GitHub "
for i in {error_log.sh,add-repo.sh,search.sh,download.sh,install-local.sh,upgrade.sh,remove.sh,update.sh,query-info.sh}; do
	wget -q --show-progress -N https://raw.githubusercontent.com/pacstall/pacstall/master/misc/scripts/"$i" -P $STGDIR/scripts &
done

PID=$!
i=1
sp="/-\|"
echo -n ' '
while [[ -d /proc/$PID ]]
do
	sleep 0.1
	printf "\b%s" "${sp:i++%${#sp}:1}"
done
echo ""

fancy_message info "Pulling ${BLUE}pacstall${NC} from ${RED}https://raw.githubusercontent.com/pacstall/pacstall/master/pacstall${NC}"

sudo wget -q --show-progress --progress=bar:force -O /bin/pacstall https://raw.githubusercontent.com/pacstall/pacstall/master/pacstall &
wget -q --show-progress --progress=bar:force -O /usr/share/man/man8/pacstall.8.gz https://raw.githubusercontent.com/pacstall/pacstall/master/misc/pacstall.8.gz &
sudo wget -q --show-progress --progress=bar:force -O /usr/share/bash-completion/completions/pacstall https://raw.githubusercontent.com/pacstall/pacstall/master/misc/completion/bash &

if command -v fish &>/dev/null; then
	sudo wget -q --show-progress --progress=bar:force -O /usr/share/fish/vendor_completions.d/pacstall.fish https://raw.githubusercontent.com/pacstall/pacstall/master/misc/completion/fish &
fi

wait

sudo chmod +x /bin/pacstall
chmod +x $STGDIR/scripts/*
# vim:set ft=sh ts=4 sw=4 noet:
