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

echo -e "this will do:
* Check for ${BLUE}curl${NC} and ${BLUE}wget${NC}
* Install ${BLUE}Pacstall${NC}
  -- Create necessary directories
  -- Pull ${BLUE}Pacstall${NC} with ${BLUE}wget${NC} from the ${YELLOW}$BRANCH${NC} branch into ${PURPLE}/bin/pacstall${NC}"

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
sudo mkdir -p /usr/share/pacstall/repo
sudo touch /usr/share/pacstall/repo/pacstallrepo.txt
sudo echo "Henryws/pacstall-programs" > /usr/share/pacstall/repo/pacstallrepo.txt
sudo touch /var/log/pacstall_installed
sudo touch /var/cache/pacstall/
echo -e "pulling ${BLUE}pacstall${NC} from ${RED}https://raw.githubusercontent.com/Henryws/pacstall/$BRANCH/pacstall${NC}"
sudo wget -O /bin/pacstall https://raw.githubusercontent.com/Henryws/pacstall/$BRANCH/pacstall
sudo chmod +x /bin/pacstall
