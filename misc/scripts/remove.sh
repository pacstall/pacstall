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

function fn_exists() {
	declare -F "$1" > /dev/null
}

# Removal starts from here
if ! dpkg -l "$PACKAGE" &>/dev/null; then
	fancy_message error "$PACKAGE is not installed or not properly symlinked"
	error_log 3 "remove $PACKAGE"
	exit 1
fi

sudo apt-get remove "$PACKAGE" -y && exit 0

error_log 1 "remove $PACKAGE"
exit 1
# vim:set ft=sh ts=4 sw=4 noet:
