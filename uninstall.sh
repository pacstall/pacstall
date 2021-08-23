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

	local MESSAGE_TYPE="${1}"
	local MESSAGE="${2}"

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
				answer=1
				return 0	#return code for backwards compatibility
				break
			;;
			N*|n*)
				answer=0
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

# Check if pacstall is installed
if ! command -v pacstall &>/dev/null; then
	fancy_message error "Pacstall is not installed!"
	exit 1
fi


fancy_message info "Choose what you want:"
fancy_message info "y. Remove Pacstall and installed packages."
fancy_message info "n. Remove Pacstall only (Keep installed packages)."
ask "Your choice"
if [[ "$answer" -eq 1 ]]; then
	fancy_message info "Removing Pacstall and installed packages..."

	# Remove packages
	if [[ -z $(pacstall -L) ]]; then
		fancy_message warn "Nothing is installed using Pacstall yet"
		fancy_message warn "Skipping package uninstallation"

		for i in $(pacstall -L); do
			pacstall -P -R "$i"
		done
	fi

	fancy_message info "Removing Pacstall"
	sudo rm "$(command -v pacstall)"

	# Remove scripts and repos
	fancy_message info "Removing scripts and repositories"
	sudo rm -rf /usr/share/pacstall/
	# Remove man page
	fancy_message info "Removing man page"
	sudo rm /usr/share/man/man8/pacstall.8.gz

	# Remove logs
	fancy_message info "Removing log files"
	sudo rm -rf /var/log/pacstall/
	# Remove cache
	fancy_message info "Removing cache"
	sudo rm -rf /var/cache/pacstall/
	# Remove tmp files
	fancy_message info "Removing temporary files"
	sudo rm -rf /tmp/pacstall/
else
	fancy_message info "Only uninstalling Pacstall..."
	sudo rm "$(command -v pacstall)"

	# Remove scripts and repos
	fancy_message info "Removing scripts and repositories"
	sudo rm -rf /usr/share/pacstall/
	# Remove man page
	fancy_message info "Removing man page"
	sudo rm /usr/share/man/man8/pacstall.8.gz

	# Remove logs
	fancy_message info "Removing log files"
	sudo rm -rf /var/log/pacstall/
	# Remove cache
	fancy_message info "Removing cache"
	sudo rm -rf /var/cache/pacstall/
	# Remove tmp files
	fancy_message info "Removing temporary files"
	sudo rm -rf /tmp/pacstall/
fi

fancy_message info "Uninstallation complete. Thanks for using Pacstall!"
# vim:set ft=sh ts=4 sw=4 noet:
