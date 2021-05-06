#!/bin/bash
function fancy_message() {
    # $1 = type , $2 = message
    # Message types
    # 0 - info
    # 1 - warning
    # 2 - error
    if [ -z "${1}" ] || [ -z "${2}" ]; then
      return
    fi

    local RED="\e[31m"
    local GREEN="\e[32m"
    local YELLOW="\e[33m"
    local RESET="\e[0m"
    local MESSAGE_TYPE=""
    local MESSAGE=""
    MESSAGE_TYPE="${1}"
    MESSAGE="${2}"
    
    case ${MESSAGE_TYPE} in
      info) echo -e "[${GREEN}+${RESET}] INFO: ${MESSAGE}";;
      warn) echo -e "[${YELLOW}*${RESET}] WARNING: ${MESSAGE}";;
      error) echo -e "[${RED}!${RESET}] ERROR: ${MESSAGE}";;
      *) echo -e "[?] UNKNOWN: ${MESSAGE}";;
    esac
}
banner() {
echo -e "|------------------------|"
echo -e "|---${GREEN}Pacstall Installer${NC}---|"
echo -e "|------------------------|"
echo " "
}
if ! command -v apt &> /dev/null
then
    fancy_message error "apt could not be found"
    exit 1
fi
apt install -y sudo wget
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
printf ' '
while [ -d /proc/$PID ]
do
  sleep 0.1
  printf "\b${sp:i++%${#sp}:1}"
done
if [[ $? -eq 1 ]] ; then
  fancy_message warn "You seem to be offline"
  exit 1
fi
echo ""
fancy_message info "Updating"
sudo apt-get update
fancy_message info "Installing packages"

sudo apt-get install -qq -y {curl,wget,stow,build-essential,unzip,fzf}

unset PACSTALL_DIRECTORY
export PACSTALL_DIRECTORY="/usr/share/pacstall"
fancy_message info "making directories"
sudo mkdir -p $PACSTALL_DIRECTORY
sudo mkdir -p $PACSTALL_DIRECTORY/scripts
sudo mkdir -p $PACSTALL_DIRECTORY/repo
sudo mkdir -p /var/log/pacstall_orphaned
sudo rm $PACSTALL_DIRECTORY/repo/pacstallrepo.txt
sudo touch $PACSTALL_DIRECTORY/repo/pacstallrepo.txt
sudo sh -c "echo 'Henryws/pacstall-programs' > $PACSTALL_DIRECTORY/repo/pacstallrepo.txt"
sudo rm -rf /var/log/pacstall_installed
sudo mkdir /var/log/pacstall_installed
sudo rm -rf /var/cache/pacstall
sudo mkdir -p /var/db/pacstall
fancy_message info "Pulling scripts from GitHub "
for i in {change-repo.sh,search.sh,download.sh,install-local.sh,upgrade.sh}; do 
sudo wget -q --show-progress -N https://raw.githubusercontent.com/Henryws/pacstall/master/misc/scripts/$i -P /usr/share/pacstall/scripts
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
echo ""
fancy_message info "pulling ${BLUE}pacstall${NC} from ${RED}https://raw.githubusercontent.com/Henryws/pacstall/master/pacstall${NC}"
sudo wget -q --show-progress --progress=bar:force -O /bin/pacstall https://raw.githubusercontent.com/Henryws/pacstall/master/pacstall
sudo chmod +x /bin/pacstall
fancy_message info "Installing ${BLUE}Manpage${NC}"
sudo mkdir -p /usr/share/man/man8/
wget -q --show-progress --progress=bar:force -O /usr/share/man/man8/pacstall.8.gz https://raw.githubusercontent.com/Henryws/pacstall/master/misc/pacstall.8.gz
