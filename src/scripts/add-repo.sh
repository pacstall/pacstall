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

REPO="${2%/}"

if echo "$REPO" | grep "github.com" > /dev/null ; then
	REPO="${REPO/'github.com'/'raw.githubusercontent.com'}"
	if  ! echo "$REPO" | grep  "/tree/" > /dev/null ; then
		REPO="$REPO/master"
		fancy_message warn "Assuming that git branch is ${GREEN}master${NC}"
	else
		REPO="${URL/'/tree/'/'/'}"
	fi
elif echo "$REPO"| grep "gitlab.com" > /dev/null; then
	if  ! echo "$REPO" | grep  "/tree/" > /dev/null ; then
		REPO="$REPO/-/raw/master"
		fancy_message warn "Assuming that git branch is ${GREEN}master${NC}"
	else
		REPO="${REPO/"/tree/"/"/raw/"}"
	fi
else
	fancy_message warn "The repo link must be the root to the raw files"
	fancy_message warn "Make sure the repo contains a package list"

	ask "Do you want to add \"$REPO\" to the repo list?" N
	if [[ $answer -eq 0 ]]; then
		exit 3
	fi
fi


if ! wget -q --spider "$REPO/packagelist"; then
	fancy_message warn "If the URL is a private repo, edit ${CYAN}\e]8;;file://$STGDIR/repo/pacstallrepo.txt\a$STGDIR/repo/pacstallrepo.txt\e]8;;\a${NC}"
	fancy_message error "packagelist file not found"
	exit 3
fi
REPOLIST=()
while IFS= read -r REPOURL; do
	REPOLIST+=("${REPOURL} ")
done < "$STGDIR/repo/pacstallrepo.txt"
REPOLIST+=("$REPO")

echo "${REPOLIST[@]}"|tr -s ' ' '\n'| sort -u | sudo tee "$STGDIR/repo/pacstallrepo.txt" > /dev/null
# vim:set ft=sh ts=4 sw=4 noet:
