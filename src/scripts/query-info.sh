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

if [[ -z "$PACKAGE" ]]; then
	fancy_message error "You failed to specify a package"
	exit 1
fi

if [[ ! -f "$LOGDIR/$PACKAGE" ]]; then
	fancy_message error "Package does not exist"
	exit 1
fi

source "$LOGDIR/$PACKAGE"

if [[ "$PACKAGE" == *-deb ]]; then
	size="$(numfmt --to=iec $(apt-cache --no-all-versions show "${_gives}" | grep Installed-Size | cut -d' ' -f 2))"
else
	size="$(du -sh "$STOWDIR"/"$PACKAGE" 2> /dev/null | awk '{print $1}')"
fi

echo -e "${BGreen}name${NORMAL}: $PACKAGE"
echo -e "${BGreen}version${NORMAL}: $_version"
echo -e "${BGreen}size${NORMAL}: $size"
echo -e "${BGreen}description${NORMAL}: ""$_description"""
echo -e "${BGreen}date installed${NORMAL}: ""$_date"""

if [[ -n $_remoterepo ]]; then
	echo -e "${BGreen}remote repo${NORMAL}: ""$_remoterepo"""
fi
if [[ -n $_maintainer ]]; then
	echo -e "${BGreen}maintainer${NORMAL}: ""$_maintainer"""
fi
if [[ -n $_ppa ]]; then
	echo -e "${BGreen}ppa${NORMAL}: ""$_ppa"""
fi
if [[ -n $_pacdeps ]]; then
	echo -e "${BGreen}pacstall dependencies${NORMAL}: ""$_pacdeps"""
fi
if [[ -n $_dependencies ]]; then
	echo -e "${BGreen}dependencies${NORMAL}: ""$_dependencies"""
fi
if [[ -n $_build_dependencies ]]; then
	echo -e "${BGreen}build dependencies${NORMAL}: ""$_build_dependencies"""
fi
if [[ -n $_pacstall_depends ]]; then
	echo -e "${BGreen}install type${NORMAL}: installed as dependency"
else
	echo -e "${BGreen}install type${NORMAL}: explicitly installed"
fi
exit 0
# vim:set ft=sh ts=4 sw=4 noet:
