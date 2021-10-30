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

function fn_exists() {
	declare -F "$1" > /dev/null;
}

# Removal starts from here
if ! source "$LOGDIR/$PACKAGE" > /dev/null 2>&1; then
	fancy_message error "$PACKAGE is not installed or not properly symlinked"
	error_log 3 "remove $PACKAGE"
	return 1
fi

if ! source /var/cache/pacstall/"${PACKAGE}"/"${_version}"/"${PACKAGE}".pacscript > /dev/null 2>&1; then
	fancy_message error "$PACKAGE is not installed or not properly symlinked"
	error_log 1 "remove $PACKAGE"
	return 1
fi

case "$url" in
	*.deb)
		if ! sudo apt remove "$gives" 2>/dev/null; then
			fancy_message warn "Failed to remove the package"
			error_log 1 "remove $PACKAGE"
			return 1
		fi
		
		if fn_exists removescript; then
			fancy_message info "Running post removal script"
			removescript
		fi
		sudo rm -f "$LOGDIR/$PACKAGE"
		return 0
	;;

	*)
		sudo mkdir -p "$STOWDIR"
		if ! cd "$STOWDIR" 2> /dev/null; then
			error_log 1 "remove $PACKAGE"; fancy_message error "Could not enter ${STOWDIR}"; exit 1
		fi

		if [[ ! -d "$PACKAGE" ]]; then
			fancy_message error "$PACKAGE is not installed or not properly symlinked"
			error_log 1 "remove $PACKAGE"
			return 1
		fi

		fancy_message info "Removing symlinks"
		sudo stow --target="/" -D "$PACKAGE"

		fancy_message info "Removing package"
		sudo rm -rf "$PACKAGE"
		# Update PATH database
		hash -r

		if fn_exists removescript; then
			fancy_message info "Running post removal script"
			if ! removescript; then
				error_log 2 "removescript $PACKAGE"
				fancy_message "Could not run removescript properly"
				exit 1
			fi
		fi

		if [[ -n "$_dependencies" ]]; then
			fancy_message info "You may want to remove ${BLUE}$_dependencies${NC}"
		fi

		fancy_message info "Removing dummy package"
		export PACSTALL_REMOVE=1

		if ! sudo --preserve-env=PACSTALL_REMOVE dpkg -r "$name" 2> /dev/null; then
			fancy_message error "Failed to remove dummy package"
			error_log 1 "remove $PACKAGE"
			return 1
		fi

		sudo rm -f "$LOGDIR/$PACKAGE"
		fancy_message info "Package removed successfully"
		return 0
	;;
esac

error_log 1 "remove $PACKAGE"
return 1
# vim:set ft=sh ts=4 sw=4 noet:
