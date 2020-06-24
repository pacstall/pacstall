#!/bin/bash
echo "Pacstall installer"
equals=$(command -v apt)
if [[ $equals = /usr/bin/apt ]]
then
  sudo apt install -y wget dialog porg curl pandoc
  sudo wget -q https://raw.githubusercontent.com/Henryws/pacstall/master/pacstall -O /bin/pacstall
else
  sudo dnf install -y wget porg dialog curl pandoc
  sudo wget -q https://raw.githubusercontent.com/Henryws/pacstall/master/pacstall -O /bin/pacstall
fi
if [[ $? -eq 1 ]] ; then
echo "Distro not supported yet"
exit 1
fi
echo "Henryws" >> /usr/share/pacstall/repo/pacstallrepo.txt
sudo chmod a+x /bin/pacstall
echo "Done"
exit 0
