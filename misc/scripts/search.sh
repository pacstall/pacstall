#!/bin/bash

# This script searches for packages
SEARCH=$2
if [[ -z "$SEARCH" ]]; then
	fancy_message error "You failed to specify a package"
	exit 1
fi

REPO=$(cat /usr/share/pacstall/repo/pacstallrepo.txt)
FZF_DEFAULT_OPTS=$FZF_DEFAULT_OPTS'
--color=dark
--color=fg:-1,bg:-1,hl:#5fff87,fg+:-1,bg+:-1,hl+:#ffaf5f
--color=info:#af87ff,prompt:#5fff87,pointer:#ff87d7,marker:#ff87d7,spinner:#ff87d7
'
SELECTED=$(curl -s "$REPO"/packagelist | tr ' ' '\n' | fzf -q "$SEARCH")
if ask "Do you want to view the pacscript?" N; then
    curl -s "$REPO"/packages/$SELECTED/$SELECTED.pacscript | less -R
    exit
fi
unset FZF_DEFAULT_OPTS
exit
