#!/bin/bash
SEARCH=$2
REPO=$(cat /usr/share/pacstall/repo/pacstallrepo.txt)
wget -q --spider https://github.com/"$REPO"/tree/master/packages/$SEARCH/
if [ $? -eq 0 ]; then
	printf "${GREEN}$SEARCH${NC} is available. Do you want to view the pacscript [y/n] "
	read -r answer
	if [[ $answer = y ]] ; then
		curl -s https://raw.githubusercontent.com/$REPO/master/packages/$SEARCH/$SEARCH.pacscript | less -R
		exit 0
	else
	exit 0
	fi
else
	fancy_message error "$SEARCH doesn't seem to exist"
	exit 1
fi
