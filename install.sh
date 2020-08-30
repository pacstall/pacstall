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
CYAN='\033[0;36m'
NC='\033[0m'
GREEN='\033[0;32m'
PURPLE='\033[0;35m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'

banner
echo -e "Checking for internet access"

wget -q --tries=10 --timeout=20 --spider http://github.com
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
  echo -e "You seem to not have ${BLUE}curl${NC} installed"
  exit 1
fi

if [[ $(command -v wget) != "/usr/bin/wget" ]] ; then
  echo -e "You seem to not have ${BLUE}wget${NC} installed"
  exit 1
fi

if [[ $(command -v porg) != "/usr/bin/porg" ]] ; then
  echo -e "You seem to not have ${BLUE}porg${NC} installed"
  exit 1
fi

echo "making directories"
sudo mkdir -p /usr/share/pacstall
sudo mkdir -p /usr/share/pacstall/scripts
sudo mkdir -p /usr/share/pacstall/repo
sudo touch /usr/share/pacstall/repo/pacstallrepo.txt
sudo echo "Henryws/pacstall-programs" > /usr/share/pacstall/repo/pacstallrepo.txt
sudo touch /var/log/pacstall_installed
sudo touch /var/cache/pacstall/
echo -e "Pulling scripts from GitHub"
sudo curl https://raw.githubusercontent.com/Henryws/pacstall/$BRANCH/misc/scripts/change-repo.sh > /usr/share/pacstall/scripts/change-repo.sh
sudo curl https://raw.githubusercontent.com/Henryws/pacstall/$BRANCH/misc/scripts/install.sh > /usr/share/pacstall/scripts/install.sh
sudo curl https://raw.githubusercontent.com/Henryws/pacstall/$BRANCH/misc/scripts/search.sh > /usr/share/pacstall/scripts/search.sh
echo -e "pulling ${BLUE}pacstall${NC} from ${RED}https://raw.githubusercontent.com/Henryws/pacstall/$BRANCH/pacstall${NC}"
sudo wget -O /bin/pacstall https://raw.githubusercontent.com/Henryws/pacstall/$BRANCH/pacstall
sudo chmod +x /bin/pacstall
