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

http_code="$(curl -o /dev/null -s -w "%{http_code}\n" -- "${URL}")"

case "${http_code}" in
	000)
		fancy_message error "Failed to download file, check your connection"
		error_log 1 "get ${PACKAGE} pacscript"
		exit 1
	;;
	404)
		fancy_message error "The URL ${BIGreen}${URL}${NC} returned a 404"
		exit 1
	;;
	200)
		if [[ "$type" = "install" ]]; then
			mkdir -p "${SRCDIR}"
			if ! cd "${SRCDIR}"; then
				error_log 1 "install ${PACKAGE}"; fancy_message error "Could not enter ${SRCDIR}"; exit 1
			fi
		fi
	;;
	*)
		fancy_message error "Failed with http code ${http_code}"
		exit 1
	;;
esac
case "${URL}" in
	*.pacscript)
		wget -q --show-progress --progress=bar:force -- "${URL}" > /dev/null 2>&1
	;;
	*)
		download -- "${URL}" > /dev/null 2>&1
	;;
esac
return 0
# vim:set ft=sh ts=4 sw=4 noet:
