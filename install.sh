#!/bin/bash
BRANCH="1.0.4-Celeste"
banner() {
echo "|------------------------|"
echo "|---Pacstall installer---|"
echo "|------------------------|"
echo " "
}

# Colors

banner

echo "this will do:
* Check for curl and wget
* Install Pacstall
  -- Create necessary directories
  -- Wget into /bin/pacstall"

echo "checking for curl and wget"

if [[ $(command -v curl) != "/usr/bin/curl" ]] ; then
  echo "You seem to not have curl installed"
  exit 1
fi

if [[ $(command -v wget) != "/usr/bin/wget" ]] ; then
  echo "You seem to not have wget installed"
  exit 1
fi

if [[ $(command -v porg) != "/usr/bin/porg" ]] ; then
  echo "You seem to not have porg installed"
  exit 1
fi

echo "making directories"
mkdir -p /usr/share/pacstall/repo
touch /usr/share/pacstall/repo/pacstallrepo.txt
echo "Henryws/pacstall-programs" > /usr/share/pacstall/repo/pacstallrepo.txt
touch /var/log/pacstall_installed
touch /var/cache/pacstall/
echo "pulling pacstall from https://raw.githubusercontent.com/Henryws/pacstall/$BRANCH/pacstall"
sudo wget -O /bin/pacstall https://raw.githubusercontent.com/Henryws/pacstall/$BRANCH/pacstall
sudo chmod +x /bin/pacstall
