#!/bin/bash
banner() {
echo -e "|------------------------|"
echo -e "|---${GREEN}Pacstall Installer${NC}---|"
echo -e "|------------------------|"
echo " "
}
apt -qq install -y sudo
sudo apt install -y wget
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
echo ""
echo -e "this will do:
* Check for ${BLUE}curl${NC}, and ${BLUE}wget${NC}
* Install ${BLUE}Pacstall${NC}
  -- Create necessary directories
  -- Pull ${BLUE}Pacstall${NC} with ${BLUE}wget${NC} from the ${YELLOW}Master${NC} branch into ${PURPLE}/bin/pacstall${NC}"
echo -e "checking for ${BLUE}curl${NC} and ${BLUE}wget${NC}"
sudo apt install -y curl
sudo apt install -y porg
unset PACSTALL_DIRECTORY
export PACSTALL_DIRECTORY="/usr/share/pacstall"

echo "making directories"
sudo mkdir -p $PACSTALL_DIRECTORY
sudo mkdir -p $PACSTALL_DIRECTORY/scripts
sudo mkdir -p $PACSTALL_DIRECTORY/repo
sudo mkdir -p /var/log/pacstall_orphaned
sudo rm $PACSTALL_DIRECTORY/repo/pacstallrepo.txt
sudo touch $PACSTALL_DIRECTORY/repo/pacstallrepo.txt
sudo echo "Henryws/pacstall-programs" > $PACSTALL_DIRECTORY/repo/pacstallrepo.txt
sudo curl -s https://raw.githubusercontent.com/Henryws/pacstall/master/misc/config.toml > /usr/share/pacstall/config.toml
sudo rm /var/log/pacstall_installed
sudo mkdir /var/log/pacstall_installed
sudo rm -rf /var/cache/pacstall
sudo touch /var/cache/pacstall/
echo "Pulling scripts from GitHub "
for i in {change-repo.sh,search.sh,download.sh,install-local.sh}; do 
sudo wget -q -N https://raw.githubusercontent.com/Henryws/pacstall/master/misc/scripts/$i -P /usr/share/pacstall/scripts
done &
PID=$!
i=1
sp="/-\|"
echo -n ' '
while [ -d /proc/$PID ]
do
  sleep 0.1
  printf "\b${sp:i++%${#sp}:1}"
done
echo -e "pulling ${BLUE}pacstall${NC} from ${RED}https://raw.githubusercontent.com/Henryws/pacstall/master/pacstall${NC}"
sudo wget -O /bin/pacstall https://raw.githubusercontent.com/Henryws/pacstall/master/pacstall
sudo chmod +x /bin/pacstall
