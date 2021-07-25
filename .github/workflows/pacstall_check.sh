#!/bin/bash
function banner() {
  MESSAGE="${1}"
  echo "====================================
  $MESSAGE
  ===================================="
}

banner "Installing neofetch"
pacstall -P -I neofetch
if [[ $? -ne 0 ]]; then
	echo "Something went wrong"
    exit 1
fi
banner "Installing deb package"
pacstall -P -I brave-browser-beta
if [[ $? -ne 0 ]]; then
	echo "Something went wrong"
	exit 1
fi
banner "Testing removal"
pacstall -P -R neofetch
if [[ $? -ne 0 ]]; then
	echo "Something went wrong"
	exit 1
fi
pacstall -P -R brave-browser-beta
if [[ $? -ne 0 ]]; then
	echo "Something went wrong"
	exit 1
fi
