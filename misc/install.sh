#!/bin/bash
if [[ command -v apt = /usr/bin/apt ]] ; then
    sudo apt install -qq dialog porg curl wget
else
    sudo dnf install dialog porg curl wget
fi
echo "retrieving pacstall"
sudo wget -q https://raw.githubusercontent.com/Henryws/pacstall/master/pacstall -O /bin/pacstall
sudo chmod a+x /bin/pacstall
echo "retrieving default config file"

sudo echo "Henryws" >> /usr/share/pacstall/repo/pacstallrepo.txt
