#!/bin/bash

# Functions and variables used across pacstall

# Colors
export BOLD=$(tput bold)
export NORMAL=$(tput sgr0)
export NC='\033[0m'
# Curtesy of https://stackoverflow.com/a/28938235/13449010

# Regular Colors
export BLACK='\033[0;30m'        # Black
export RED='\033[0;31m'          # Red
export GREEN='\033[0;32m'        # Green
export YELLOW='\033[0;33m'       # Yellow
export BLUE='\033[0;34m'         # Blue
export PURPLE='\033[0;35m'       # Purple
export CYAN='\033[0;36m'         # Cyan
export WHITE='\033[0;37m'        # White

# Bold
export BBlack='\033[1;30m'       # Black
export BRed='\033[1;31m'         # Red
export BGreen='\033[1;32m'       # Green
export BYellow='\033[1;33m'      # Yellow
export BBlue='\033[1;34m'        # Blue
export BPurple='\033[1;35m'      # Purple
export BCyan='\033[1;36m'        # Cyan
export BWhite='\033[1;37m'       # White

# Underline
export UBlack='\033[4;30m'       # Black
export URed='\033[4;31m'         # Red
export UGreen='\033[4;32m'       # Green
export UYellow='\033[4;33m'      # Yellow
export UBlue='\033[4;34m'        # Blue
export UPurple='\033[4;35m'      # Purple
export UCyan='\033[4;36m'        # Cyan
export UWhite='\033[4;37m'       # White

# Background
export On_Black='\033[40m'       # Black
export On_Red='\033[41m'         # Red
export On_Green='\033[42m'       # Green
export On_Yellow='\033[43m'      # Yellow
export On_Blue='\033[44m'        # Blue
export On_Purple='\033[45m'      # Purple
export On_Cyan='\033[46m'        # Cyan
export On_White='\033[47m'       # White

# High Intensity
export IBlack='\033[0;90m'       # Black
export IRed='\033[0;91m'         # Red
export IGreen='\033[0;92m'       # Green
export IYellow='\033[0;93m'      # Yellow
export IBlue='\033[0;94m'        # Blue
export IPurple='\033[0;95m'      # Purple
export ICyan='\033[0;96m'        # Cyan
export IWhite='\033[0;97m'       # White

# Bold High Intensity
export BIBlack='\033[1;90m'      # Black
export BIRed='\033[1;91m'        # Red
export BIGreen='\033[1;92m'      # Green
export BIYellow='\033[1;93m'     # Yellow
export BIBlue='\033[1;94m'       # Blue
export BIPurple='\033[1;95m'     # Purple
export BICyan='\033[1;96m'       # Cyan
export BIWhite='\033[1;97m'      # White

# High Intensity backgrounds
export On_IBlack='\033[0;100m'   # Black
export On_IRed='\033[0;101m'     # Red
export On_IGreen='\033[0;102m'   # Green
export On_IYellow='\033[0;103m'  # Yellow
export On_IBlue='\033[0;104m'    # Blue
export On_IPurple='\033[0;105m'  # Purple
export On_ICyan='\033[0;106m'    # Cyan
export On_IWhite='\033[0;107m'   # White

# This is the ask function. You can source this code block and then run something like:
# ask "Do you like the color blue? " Y
# if [[ $answer -eq 1 ]]; then
#   echo "You like blue"
# else
#   echo "You don't like blue"
# fi
#
# Y=1 and N=0
# You can specify {Y,N} or leave it out to prevent entering the default but this is not allowed in pacstall because of the -P flag which gives unattended installs
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

# fancy_message allows visually appealing output.
# Source the code block and run:
#
# `fancy_message {info,warn,error} "What you want to say"`
function fancy_message() {
	local MESSAGE_TYPE="${1}"
	local MESSAGE="${2}"

	case ${MESSAGE_TYPE} in
		info) echo -e "[${BGreen}+${NC}] INFO: ${MESSAGE}";;
		warn) echo -e "[${BYellow}*${NC}] WARNING: ${MESSAGE}";;
		error) echo -e "[${BRed}!${NC}] ERROR: ${MESSAGE}";;
		*) echo -e "[${BOLD}?${NORMAL}] UNKNOWN: ${MESSAGE}";;
	esac
}

# vim:set ft=sh ts=4 sw=4 noet:
