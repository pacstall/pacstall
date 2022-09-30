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

if [[ -z $PACKAGE ]]; then
	fancy_message error "You failed to specify a package"
	exit 1
fi

if [[ ! -f "$LOGDIR/$PACKAGE" ]]; then
	fancy_message error "Package does not exist"
	exit 1
fi

source "$LOGDIR/$PACKAGE"

function get_field() {
	# input 1: package
	# input 2: field
	local output="$(dpkg -s "$1" | grep --color=never "^$2: " | sed "s/$2: //")"
	if [[ -z $output ]]; then
		echo "Unknown/None"
	else
		echo $output
	fi
}

echo -e "${BGreen}name${NORMAL}: $(get_field $PACKAGE Package)"
echo -e "${BGreen}version${NORMAL}: $(get_field $PACKAGE Version)"
if [[ -n ${size} ]]; then
	echo -e "${BGreen}size${NORMAL}: $(get_field $PACKAGE Installed-Size | cut -d' ' -f 2 | numfmt --to=iec)"
fi
echo -e "${BGreen}description${NORMAL}: $(get_field $PACKAGE Description)"
echo -e "${BGreen}date installed${NORMAL}: $_date"

if [[ -n $_remoterepo ]]; then
	echo -e "${BGreen}remote repo${NORMAL}: $_remoterepo"
fi
echo -e "${BGreen}maintainer${NORMAL}: $(get_field $PACKAGE Maintainer)"
if [[ -n $_ppa ]]; then
	echo -e "${BGreen}ppa${NORMAL}: $_ppa"
fi
if [[ -n $_pacdeps ]]; then
	echo -e "${BGreen}pacstall dependencies${NORMAL}: $_pacdeps"
fi
echo -e "${BGreen}dependencies${NORMAL}: $(get_field $PACKAGE Depends | tr -d ',')"
if [[ -n $_pacstall_depends ]]; then
	echo -e "${BGreen}install type${NORMAL}: installed as dependency"
else
	echo -e "${BGreen}install type${NORMAL}: explicitly installed"
fi
exit 0
# vim:set ft=sh ts=4 sw=4 noet:
