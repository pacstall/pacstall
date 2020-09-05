#!/bin/bash
BRANCH="1.0.4-Celeste"
banner() {
echo -e "|------------------------|"
echo -e "|---${GREEN}Pacstall Installer${NC}---|"
echo -e "|------------------------|"
echo " "
}

# Colors
RED='\033[0;31m'
NC='\033[0m'
GREEN='\033[0;32m'
PURPLE='\033[0;35m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'

banner
printf "Checking for internet access: "

wget -q --tries=10 --timeout=20 --spider https://github.com &
PID=$!
i=1
sp="/-\|"
echo -n ' '
while [ -d /proc/$PID ]
do
  sleep 0.1
  printf "\b${sp:i++%${#sp}:1}"
done
if [[ $? -eq 1 ]] ; then
  echo "You seem to be offline"
  exit 1
fi
echo -e "this will do:
* Check for ${BLUE}curl${NC} and ${BLUE}wget${NC}
* Install ${BLUE}Pacstall${NC}
  -- Create necessary directories
  -- Pull ${BLUE}Pacstall${NC} with ${BLUE}wget${NC} from the ${YELLOW}$BRANCH${NC} branch into ${PURPLE}/bin/pacstall${NC}"
printf "Does this look good: " 
read -r answer
if [[ $answer = n ]] ; then
  exit 1
fi
echo -e "checking for ${BLUE}curl${NC} and ${BLUE}wget${NC}"

if [[ $(command -v curl) != "/usr/bin/curl" ]] ; then
  echo -e "You seem to not have ${BLUE}curl${NC} installed. Do you want to install it now? "
  read -r curl
  if [[ $curl = y ]] ; then
    sudo apt install -y curl
  else
    exit 1
  fi
fi

if [[ $(command -v wget) != "/usr/bin/wget" ]] ; then
  echo -e "You seem to not have ${BLUE}wget${NC} installed. Do you want to install it now? "
  read -r wget
  if [[ $wget = y ]] ; then
    sudo apt install -y wget
  else
    exit 1
  fi
fi

if [[ $(command -v porg) != "/usr/bin/porg" ]] ; then
  echo -e "You seem to not have ${BLUE}porg${NC} installed. Do you want to install it now? "
  read -r porg
  if [[ $porg = y ]] ; then
    sudo apt install -y porg
  else
    exit 1
  fi
fi
unset PACSTALL_DIRECTORY
export PACSTALL_DIRECTORY="/usr/share/pacstall"

echo "making directories"
sudo mkdir -p $PACSTALL_DIRECTORY
sudo mkdir -p $PACSTALL_DIRECTORY/scripts
sudo mkdir -p $PACSTALL_DIRECTORY/repo
sudo rm $PACSTALL_DIRECTORY/repo/pacstallrepo.txt
sudo touch $PACSTALL_DIRECTORY/repo/pacstallrepo.txt
sudo echo "Henryws/pacstall-programs" > $PACSTALL_DIRECTORY/repo/pacstallrepo.txt
sudo rm $PACSTALL_DIRECTORY/config.conf
sudo touch $PACSTALL_DIRECTORY/config.conf
sudo echo "lisence="ANY" > $PACSTALL_DIRECTORY/config.conf"
sudo rm /var/log/pacstall_installed
sudo touch /var/log/pacstall_installed
sudo rm -rf /var/cache/pacstall
sudo touch /var/cache/pacstall/
echo Pulling scripts from GitHub
sudo curl https://raw.githubusercontent.com/Henryws/pacstall/$BRANCH/misc/scripts/change-repo.sh > $PACSTALL_DIRECTORY/scripts/change-repo.sh
sudo curl https://raw.githubusercontent.com/Henryws/pacstall/$BRANCH/misc/scripts/install.sh > $PACSTALL_DIRECTORY/scripts/install.sh
sudo curl https://raw.githubusercontent.com/Henryws/pacstall/$BRANCH/misc/scripts/search.sh > $PACSTALL_DIRECTORY/scripts/search.sh
sudo curl https://raw.githubusercontent.com/Henryws/pacstall/$BRANCH/misc/scripts/download.sh > $PACSTALL_DIRECTORY/scripts/download.sh
echo -e "pulling ${BLUE}pacstall${NC} from ${RED}https://raw.githubusercontent.com/Henryws/pacstall/$BRANCH/pacstall${NC}"
sudo wget -O /bin/pacstall https://raw.githubusercontent.com/Henryws/pacstall/$BRANCH/pacstall
sudo chmod +x /bin/pacstall
