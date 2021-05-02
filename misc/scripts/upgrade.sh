#!/bin/bash
function version_gt() { 
    test "$(printf '%s\n' "$@" | sort -V | head -n 1)" != "$1"; 
}

list=( $(pacstall -L) )
rm /tmp/pacstall-up-list
touch /tmp/pacstall-up-list
REPO=$(cat /usr/share/pacstall/repo/pacstallrepo.txt)
fancy_message info "Getting local/remote versions, this may take a while"
for i in "${list[@]}"; do
    localver=$(cat /var/log/pacstall_installed/$i | sed -n -e 's/version=//p' | tr -d \")
    remotever=$(curl -s https://raw.githubusercontent.com/"$REPO"/master/packages/$i/$i.pacscript | sed -n -e 's/version=//p' | tr -d \")
    if version_gt "$remotever" "$localver" ; then
        echo $i >> /tmp/pacstall-up-list
    fi
done &

PID=$!
i=1
sp=".oO@*"
echo -n ' '
while [ -d /proc/$PID ]
do
  sleep 0.2
  printf "\b${sp:i++%${#sp}:1}"
done
echo ""
if [[ $(wc -l /tmp/pacstall-up-list | awk '{ print $1 }') -eq 0 ]] ; then
    fancy_message info "Nothing to upgrade"
else
    fancy_message info "Packages can be upgraded"
    echo -e "Upgradable: $(wc -l /tmp/pacstall-up-list | awk '{ print $1 }')
${BOLD}$(cat /tmp/pacstall-up-list | tr '\n' ' ')${NORMAL}"
    echo ""
    if ask "Do you want to continue?" Y; then
        for i in `sed ':a;N;$!ba;s/\n/,/g' /tmp/pacstall-up-list` ; do
            sudo pacstall -I $i
        done
    else
        exit 1
    fi
fi
rm /tmp/pacstall-up-list
