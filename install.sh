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
progressfilt() {
    local flag=false c count cr=$'\r' nl=$'\n'
    while IFS='' read -d '' -rn 1 c
    do
        if $flag
        then
            printf '%s' "$c"
        else
            if [[ $c != $cr && $c != $nl ]]
            then
                count=0
            else
                ((count++))
                if ((count > 1))
                then
                    flag=true
                fi
            fi
        fi
    done
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
echo -n ' '
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
echo -e "this will do:
* Check for ${BLUE}curl${NC}, and ${BLUE}wget${NC}
* Install ${BLUE}Pacstall${NC}
  -- Create necessary directories
  -- Install pdb (Pacstall DataBase)
  -- Pull ${BLUE}Pacstall${NC} with ${BLUE}wget${NC} from the ${YELLOW}Master${NC} branch into ${PURPLE}/bin/pacstall${NC}"
echo ""
fancy_message info "checking for ${BLUE}curl${NC} and ${BLUE}wget${NC}"
fancy_message info "Installing curl" &
sudo apt -qq install -y curl 1>&1
echo "Installing porg" &
sudo apt -qq install -y porg 1>&1
unset PACSTALL_DIRECTORY
export PACSTALL_DIRECTORY="/usr/share/pacstall"
fancy_message info "making directories"
sudo mkdir -p $PACSTALL_DIRECTORY
sudo mkdir -p $PACSTALL_DIRECTORY/scripts
sudo mkdir -p $PACSTALL_DIRECTORY/repo
sudo mkdir -p /var/log/pacstall_orphaned
sudo rm $PACSTALL_DIRECTORY/repo/pacstallrepo.txt
sudo touch $PACSTALL_DIRECTORY/repo/pacstallrepo.txt
sudo echo "Henryws/pacstall-programs" > $PACSTALL_DIRECTORY/repo/pacstallrepo.txt
sudo rm -rf /var/log/pacstall_installed
sudo mkdir /var/log/pacstall_installed
sudo rm -rf /var/cache/pacstall
sudo mkdir -p /var/db/pacstall
fancy_message info "Pulling scripts from GitHub "
for i in {change-repo.sh,search.sh,download.sh,install-local.sh,upgrade.sh}; do 
sudo wget -q -N https://raw.githubusercontent.com/Henryws/pacstall/master/misc/scripts/$i -P /usr/share/pacstall/scripts 2>/dev/null | progressfilt
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
sudo wget --progress=bar:force -O /bin/pacstall https://raw.githubusercontent.com/Henryws/pacstall/master/pacstall 2>&1 | progressfilt
sudo chmod +x /bin/pacstall
fancy_message info "Installing ${BLUE}Manpage${NC}"
wget --progress=bar:force -O /usr/share/man/man8/pacstall.8.gz https://raw.githubusercontent.com/Henryws/pacstall/master/misc/pacstall.8.gz 2>&1 | progressfilt
for i in {add,grab,remove}; do
    sudo wget --progress=bar:force -O /bin/pdb-$i https://raw.githubusercontent.com/Henryws/pdb/master/tools/pdb-$i 2>/dev/null | progressfilt
    sudo chmod +x /bin/$i 
done
fancy_message info "Setting up a database"
echo "[pacstall-db]
id="$(date +%s | sha1sum | tr '-' ' ' |cut -c1-16)"" | sudo tee /var/db/pacstall.pdb
