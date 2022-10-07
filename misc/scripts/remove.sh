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

source "$LOGDIR/$PACKAGE" || {
	fancy_message error "$PACKAGE is not installed"
	error_log 3 "remove $PACKAGE"
	exit 1
}

if ! dpkg -l "${_gives:-$_name}" &>/dev/null; then
	fancy_message error "$PACKAGE is not installed"
	error_log 3 "remove $PACKAGE"
	exit 1
fi

sudo apt-get purge "${_gives:-$_name}" -y || {
	error_log 1 "remove $PACKAGE"
	exit 1
}

if [[ -n "${_pacdeps[*]}" ]]; then
	for i in "${_pacdeps[@]}"; do
		(
		source "$LOGDIR/$i"
		sudo apt-get purge "${_gives:-$_name}" -y
		)
	done
fi
# vim:set ft=sh ts=4 sw=4 noet:
