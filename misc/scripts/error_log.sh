#!/bin/bash

#     ____                  __        ____
#    / __ \____ ___________/ /_____ _/ / /
#   / /_/ / __ `/ ___/ ___/ __/ __ `/ / /
#  / ____/ /_/ / /__(__  ) /_/ /_/ / / /
# /_/    \__,_/\___/____/\__/\__,_/_/_/
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

if [[ ! -d "$LOGDIR/error_log" ]]; then
	sudo mkdir -p "$LOGDIR/error_log"
fi

function error_log() {
	local code="${1}"
	local scope="${2}"
	
	if [[ ! -f "$LOGFILE" ]]; then
		sudo touch "$LOGFILE"
	fi
	
	case "$code" in
		1)
			echo "[$(date) | $scope ] Error 1 - Unknown cause of failure." | sudo tee -a "$LOGFILE"  > /dev/null
			return 0
		;;
		2)
			echo "[$(date) | $scope ] Error 2 - Error in configuration file." | sudo tee -a "$LOGFILE"  > /dev/null
			return 0
		;;
		3)
			echo "[$(date) | $scope ] Error 3 - User specified an invalid option." | sudo tee -a "$LOGFILE"  > /dev/null
			return 0
		;;
		4)
			echo "[$(date) | $scope ] Error 4 - Error in user-supplied function in pacscript." | sudo tee -a "$LOGFILE"  > /dev/null
			return 0
		;;
		5)
			echo "[$(date) | $scope ] Error 5 - Failed to create a viable package." | sudo tee -a "$LOGFILE"  > /dev/null
			return 0
		;;
		6)
			echo "[$(date) | $scope ] Error 6 - A source or auxiliary file specified in the pacscript is missing." | sudo tee -a "$LOGFILE"  > /dev/null
			return 0
		;;
		7)
			echo "[$(date) | $scope ] Error 7 - The STOWDIR is missing." | sudo tee -a "$LOGFILE"  > /dev/null
			return 0
		;;
		8)
			echo "[$(date) | $scope ] Error 8 - Failed to install dependencies." | sudo tee -a "$LOGFILE"  > /dev/null
			return 0
		;;
		9)
			echo "[$(date) | $scope ] Error 9 - Failed to remove dependencies." | sudo tee -a "$LOGFILE"  > /dev/null
			return 0
		;;
		10)
			echo "[$(date) | $scope ] Error 10 - User attempted to run pacstall as root." | sudo tee -a "$LOGFILE"  > /dev/null
			return 0
		;;
		11)
			echo "[$(date) | $scope ] Error 11 - User lacks permissions to build or install to a given location." | sudo tee -a "$LOGFILE"  > /dev/null
			return 0
		;;
		12)
			echo "[$(date) | $scope ] Error 12 - Error parsing  pacscript." | sudo tee -a "$LOGFILE"  > /dev/null
			return 0
		;;
		13)
			echo "[$(date) | $scope ] Error 13 - A package has already been built." | sudo tee -a "$LOGFILE"  > /dev/null
			return 0
		;;
		14)
			echo "[$(date) | $scope ] Error 14 - The package failed to install." | sudo tee -a "$LOGFILE"  > /dev/null
			return 0
		;;
		15)
			echo "[$(date) | $scope ] Error 15 - Programs necessary to run pacstall are missing." | sudo tee -a "$LOGFILE"  > /dev/null
			return 0
		;;
		16)
			echo "[$(date) | $scope ] Error 16 - Specified hash does not exist or failed to sign package." | sudo tee -a "$LOGFILE"  > /dev/null
			return 0
		;;
	esac
}

export -f error_log

# vim:set ft=sh ts=4 sw=4 noet:
