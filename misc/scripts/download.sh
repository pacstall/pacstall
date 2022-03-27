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

# This script downloads pacscripts from the interwebs

if check_url "${URL}"; then
	if [[ "$type" = "install" ]]; then
		mkdir -p "$SRCDIR"
		if ! cd "$SRCDIR" ; then
			error_log 1 "install $PACKAGE"; fancy_message error "Could not enter ${SRCDIR}"; exit 1
		fi
	fi
	
	case "$URL" in
		*.pacscript)
			if ! wget -q --show-progress --progress=bar:force -- "$URL" > /dev/null 2>&1; then
				error_log 1 "download $PACKAGE"; fancy_message error "Could not download ${URL}"; exit 1
			fi
		;;
		*)
			if ! download -- "$URL" > /dev/null 2>&1; then
				error_log 1 "download $PACKAGE"; fancy_message error "Could not download ${URL}"; exit 1
			fi
		;;
	esac
	return 0
else
	error_log 1 "get $PACKAGE pacscript"
	return 1
fi
# vim:set ft=sh ts=4 sw=4 noet:
