#!/bin/bash
echo "Pacstall installer"
sudo wget -q https://raw.githubusercontent.com/Henryws/pacstall/master/pacstall -O /bin/pacstall
equals=$(command -v apt)
if [[ $equals = /usr/bin/apt ]]
then
  sudo apt install -y wget dialog porg curl pandoc
else
  sudo dnf install -y wget porg dialog curl pandoc
  else
  echo "Distro not supported yet"
  fi
fi
echo "Henryws" >> /usr/share/pacstall/repo/pacstallrepo.txt
echo "Done"
exit 0
