#!/bin/bash

# This script searches for packages
SEARCH=$2
if [[ -z "$SEARCH" ]]; then
	fancy_message error "You failed to specify a package"
	exit 1
fi

REPO=$(cat /usr/share/pacstall/repo/pacstallrepo.txt)
SELECTED=$(curl -s https://raw.githubusercontent.com/"$REPO"/master/packagelist | tr ' ' '\n' | fzf -q $SEARCH)
if ask "Do you want to view the pacscript?" Y; then
    curl -s https://raw.githubusercontent.com/$REPO/master/packages/$SELECTED/$SELECTED.pacscript | less -R
    exit
fi
exit
