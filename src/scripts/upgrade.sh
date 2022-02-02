#!/usr/bin/env bash

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

function ver_compare() {
	local first second
	first="${1#${1/[0-9]*/}}"
	second="${2#${2/[0-9]*/}}"
	return $(dpkg --compare-versions "$first" lt "$second")
}

export UPGRADE="yes"

# Get the list of the installed packages
mapfile -t list < <(pacstall -L)

# remove all old temp files
for tmp in /tmp/pacstall-up-{list,print,urls}; {
	[ -f "$tmp" ] && sudo rm -f "$tmp"
}
unset tmp

# create new tmp files
sudo touch /tmp/pacstall-up-{list,print,urls}

fancy_message info "Checking for updates"

for i in "${list[@]}"; do
	source "$LOGDIR/$i"

	# localver is the current version of the package
	localver=$(sed -n -e 's/_version=//p' "$LOGDIR"/"$i" | tr -d \")

	if [ -z "${_remoterepo}" ]; then
		# TODO: upgrade for local pacscripts
		continue
	elif echo "${_remoterepo}" | grep "github.com" > /dev/null ; then
		remoterepo="${_remoterepo/'github.com'/'raw.githubusercontent.com'}/${_remotebranch}"
	elif echo "${_remoterepo}"| grep "gitlab.com" > /dev/null; then
		remoterepo="${_remoterepo}/-/raw/${_remotebranch}"
	else
		remoterepo="${_remoterepo}"
	fi

	unset _remoterepo

	source "$STGDIR/scripts/search.sh"

	IDXMATCH=$(printf "%s\n" "${REPOS[@]}"| grep -n "$remoterepo" | cut -d : -f1| awk '{print $0"-1"}'| bc)

	if [ $IDXMATCH ]; then
		remotever=$(source <(curl -s "$remoterepo"/packages/"$i"/"$i".pacscript) && type pkgver &>/dev/null && pkgver || echo "$version") >/dev/null
		remoteurl="${REPOS[$IDXMATCH]}"
	else
		fancy_message warning "Package ${GREEN}${i}${CYAN} is not on ${CYAN}$(parseRepo "${remoterepo}")${NC} anymore"
		sed -i "/_remote/d" "$LOGDIR/$i"
	fi
	
	[ "$remotever" = "$localver" ] && continue

	if [[ $i != *"-git" ]]; then
		alterver="0.0.0"
		for IDX in "${!REPOS[@]}"; do
			[ $IDX -eq $IDXMATCH ] && continue
		
			ver=$(source <(curl -s "${REPOS[$IDX]}"/packages/"$i"/"$i".pacscript) && type pkgver &>/dev/null && pkgver || echo "$version") >/dev/null
			if ! ver_compare "$alterver" "$ver"; then
				alterver="$ver"
				alterurl="$REPO"
			fi
		done
		if [ "$remotever" ]; then
			if ver_compare "$remotever" "$alterver"; then
				echo -e "${GREEN}${i}${CYAN} has a newer version at ${CYAN}$(parseRepo "${alterurl}")${NC}."
				ask "Keep the package from the current repo?" Y
				if [ "$answer" -eq 0 ]; then
					remoterepo="$alterver"
					remoteurl="$alterurl"
				fi
			fi
		elif [ "$alterver" != "0.0.0" ]; then
			remoterepo="$alterver"
			remoteurl="$alterurl"
		fi
	fi

	if [ "$remotever" ]; then
		if [[ $i == *"-git" ]] || ver_compare "$localver" "$remotever"; then
			echo "$i" | sudo tee -a /tmp/pacstall-up-list >/dev/null
			echo "${GREEN}${i}${CYAN} @ $(parseRepo "${remoteurl}") ${NC}" | sudo tee -a /tmp/pacstall-up-print >/dev/null
			echo "$remoteurl" | sudo tee -a /tmp/pacstall-up-urls >/dev/null
		fi
	fi
done
	# count line number using awk alone 
if [[ $(awk 'END { print NR }' /tmp/pacstall-up-list) -eq 0 ]] ; then
	fancy_message info "Nothing to upgrade"
else
	fancy_message info "Packages can be upgraded"
	echo -e "Upgradable: $(awk 'END { print NR }' /tmp/pacstall-up-list)
	${BOLD}$(cat /tmp/pacstall-up-print)${NORMAL}\n"
	
	# make array with builtin function in bash 
	mapfile -t upgrade < /tmp/pacstall-up-list
	mapfile -t remotes < /tmp/pacstall-up-urls

	export local='no'
	sudo mkdir -p "$SRCDIR"
	sudo chown -R "$USER":"$USER" "$SRCDIR"
	
	if ! cd "$SRCDIR" 2> /dev/null; then
		error_log 1 "upgrade"; fancy_message error "Could not enter ${SRCDIR}"; exit 1
	fi
	
	for i in "${!upgrade[@]}"; do
		PACKAGE=${upgrade[$i]}
		ask "Do you want to upgrade ${GREEN}${PACKAGE}${NC}?" Y
		
		[ "$answer" -eq 0 ] && continue
		
		REPO="${remotes[$i]}"
		export URL="$REPO/packages/$PACKAGE/$PACKAGE.pacscript"
		if ! source "$STGDIR/scripts/download.sh"; then
			fancy_message error "Failed to download the ${GREEN}${PACKAGE}${NC} pacscript"
			continue;
		fi
		source "$STGDIR/scripts/install-local.sh"
	done
fi

# remove tmp files
for tmp in /tmp/pacstall-up-{list,print,urls}; {
	[ -f "$tmp" ] && sudo rm -f "$tmp"
}
unset tmp

# vim:set ft=sh ts=4 sw=4 noet:
