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

function ver_compare() {
	local first="$(echo ${1} | sed 's/^[^0-9]*//')"
	local second="$(echo ${1} | sed 's/^[^0-9]*//')"
	return $(dpkg --compare-versions $first "lt" $second)
}

export UPGRADE="yes"

# Get the list of the installed packages
list=( $(pacstall -L) )
if [ -f /tmp/pacstall-up-list ]; then
	sudo rm /tmp/pacstall-up-list
fi

if [ -f /tmp/pacstall-up-print ]; then
	sudo rm /tmp/pacstall-up-print
fi

if [ -f /tmp/pacstall-up-urls ]; then
	sudo rm /tmp/pacstall-up-urls
fi

sudo touch /tmp/pacstall-up-list
sudo touch /tmp/pacstall-up-print
sudo touch /tmp/pacstall-up-urls

fancy_message info "Checking for updates"

for i in "${list[@]}"; do
	source "$LOGDIR/$i"

	# localver is the current version of the package
	localver=$(sed -n -e 's/_version=//p' "$LOGDIR"/"$i" | tr -d \")

	if [[ -z ${_remoterepo} ]]; then
		#TODO upgrade for local pacscripts
		continue
	elif echo "${_remoterepo}" | grep "github.com" > /dev/null ; then
		remoterepo="${_remoterepo/'github.com'/'raw.githubusercontent.com'}/${_remotebranch}"
	elif echo "${_remoterepo}"| grep "gitlab.com" > /dev/null; then
		remoterepo="${_remoterepo}/-/raw/${_remotebranch}"
	else
		remoterepo=${_remoterepo}
	fi

	unset _remoterepo

	source "$STGDIR/scripts/search.sh"

	IDXMATCH=$(printf "%s\n" "${REPOS[@]}"| grep -n "$remoterepo" | cut -d : -f1| awk '{print $0"-1"}'|bc)

	if [[ -n $IDXMATCH ]]; then
		remotever=$(source <(curl -s "$remoterepo"/packages/"$i"/"$i".pacscript) && type pkgver &>/dev/null && pkgver || echo "$version") >/dev/null
		remoteurl=${REPOS[$IDXMATCH]}
	else
		fancy_message warning "Package ${GREEN}${i}${CYAN} is not on ${CYAN}$(parseRepo "${remoterepo}")${NC} anymore"
		sed -i "/_remote/d"  $LOGDIR/$i
	fi

	if [[ $i != *"-git" ]]; then
		alterver="0.0.0"
		for IDX in ${!REPOS[@]}; do
			if [[ $IDX -eq $IDXMATCH ]]; then
				continue
			else
				ver=$(source <(curl -s "${REPOS[$IDX]}"/packages/"$i"/"$i".pacscript) && type pkgver &>/dev/null && pkgver || echo "$version") >/dev/null
				ver_compare $alterver $ver
				if  [[ $? -ne 0 ]]; then
					alterver=$ver
					alterurl=$REPO
				fi
			fi
		done
		if [[ -n $remotever ]]; then
			ver_compare $remotever $alterver
			if  [[ $? -eq 0 ]]; then
				echo -e "${GREEN}${i}${CYAN} has a newer version at ${CYAN}$(parseRepo "${alterurl}")${NC}."
				ask "Keep the package from the current repo?" Y
				if [[ $answer -eq 0 ]]; then
					remoterepo=$alterver
					remoteurl=$alterurl
				fi
			fi
		elif [[ $alterver != "0.0.0" ]]; then
			remoterepo=$alterver
			remoteurl=$alterurl
		fi
	elif [[ $remotever == $localver ]]; then
		continue
	fi

	if [[ -n $remotever ]]; then
		ver_compare $localver $remotever
		up=$?
		if [[ $i == *"-git" ]] || [[ up -eq 0 ]]; then
			echo "$i" |sudo tee -a /tmp/pacstall-up-list >/dev/null
			echo "${GREEN}${i}${CYAN} @ $(parseRepo "${remoteurl}") ${NC}" | sudo tee -a /tmp/pacstall-up-print >/dev/null
			echo "$remoteurl" |sudo tee -a /tmp/pacstall-up-urls >/dev/null
		fi
	fi
done

if [[ $(wc -l /tmp/pacstall-up-list | awk '{ print $1 }') -eq 0 ]] ; then
	fancy_message info "Nothing to upgrade"
else
	fancy_message info "Packages can be upgraded"
	echo -e "Upgradable: $(wc -l /tmp/pacstall-up-print | awk '{ print $1 }')
	${BOLD}$(cat /tmp/pacstall-up-print)${NORMAL}"
	echo ""

	upgrade=()
	while IFS= read -r line; do
		upgrade+=("$line")
	done < /tmp/pacstall-up-list

	while IFS= read -r line; do
		remotes+=("$line")
	done < /tmp/pacstall-up-urls

	export local='no'
	for i in "${!upgrade[@]}"; do
		PACKAGE=${upgrade[$i]}
		ask "Do you want to upgrade ${GREEN}${PACKAGE}${NC}?" Y
		if [[ $answer -eq 0 ]]; then
			continue
		fi
		REPO="${remotes[$i]}"
		export URL="$REPO/packages/$PACKAGE/$PACKAGE.pacscript"
		source "$STGDIR/scripts/download.sh"
		if [[ $? -ne 0 ]]; then
			fancy_message error "Failed to download the ${GREEN}${PACKAGE}${NC} pacscript"
			continue;
		fi
		source "$STGDIR/scripts/install-local.sh"
	done
fi

if test -f "/tmp/pacstall-up-list"; then
	sudo rm -f /tmp/pacstall-up-list
fi

if test -f "/tmp/pacstall-up-print"; then
	sudo rm -f /tmp/pacstall-up-print
fi

if test -f "/tmp/pacstall-up-urls"; then
	sudo rm -f /tmp/pacstall-up-urls
fi
# vim:set ft=sh ts=4 sw=4 noet:
