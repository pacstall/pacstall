#!/bin/bash
SEARCH=$2
REPO=$(cat /usr/share/pacstall/repo/pacstallrepo.txt)
wget -q --spider https://github.com/"$REPO"/tree/master/packages/$SEARCH/
if [ $? -eq 0 ]; then
	read -p "${GREEN}$SEARCH${NC} is available in the ${PURPLE}$REPO${NC} repository. Do you want to view the pacscript? " answer
	if [[ $answer = y ]] ; then
		curl https://raw.githubusercontent.com/$REPO/master/packages/$PACKAGE/$PACKAGE.pacscript | less -R
		exit 0
	else
	exit 0
	fi
else
	fancy_message error "$SEARCH is not available. Add another repo or check your spelling"
	exit 1
fi
