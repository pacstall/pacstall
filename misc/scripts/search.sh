#!/bin/bash

# This script searches for packages
SEARCH=$2
if [[ -z "$SEARCH" ]]; then
	fancy_message error "You failed to specify a package"
	exit 1
fi

REPO=$(cat /usr/share/pacstall/repo/pacstallrepo.txt)
logthis wget -q --spider https://github.com/"$REPO"/tree/master/packages/$SEARCH/
if [ $? -eq 0 ]; then
	if ask "${GREEN}$SEARCH${NC} is available. Do you want to view the pacscript" Y; then
        curl -s https://raw.githubusercontent.com/$REPO/master/packages/$SEARCH/$SEARCH.pacscript | pygmentize -l bash | less -R
		exit 0
	else
	exit 0
	fi
else
	fancy_message error "$SEARCH doesn't seem to exist"
	exit 1
fi
