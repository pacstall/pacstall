#!/bin/bash

#     ____                  __        ____
#    / __ \____ ___________/ /_____ _/ / /
#   / /_/ / __ `/ ___/ ___/ __/ __ `/ / /
#  / ____/ /_/ / /__(__  ) /_/ /_/ / / /
# /_/    \__,_/\___/____/\__/\__,_/_/_/
#
# Copyright (C) 2020-2021
#
# This file is part of Pacstall
#
# Pacstall is free software: you can redistribute it and/or modify
# it under the terms of the GNU General Public License as published by
# the Free Software Foundation, version 3 of the License
#
# Pacstall is distributed in the hope that it will be useful,
# but WITHOUT ANY WARRANTY; without even the implied warranty of
# MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE. See the
# GNU General Public License for more details.
#
# You should have received a copy of the GNU General Public License
# along with Pacstall. If not, see <https://www.gnu.org/licenses/>.

function version_gt() { 
    test "$(printf '%s\n' "$@" | sort -V | head -n 1)" != "$1"; 
}

list=( $(pacstall -L) )
if [ -f /tmp/pacstall-up-list ]; then
    rm /tmp/pacstall-up-list
fi
touch /tmp/pacstall-up-list
REPO=$(cat /usr/share/pacstall/repo/pacstallrepo.txt)
fancy_message info "Checking for updates"
for i in "${list[@]}"; do
    localver=$(sed -n -e 's/version=//p' /var/log/pacstall_installed/"$i" | tr -d \")
    remotever=$(source <(curl -s "$REPO"/packages/"$i"/"$i".pacscript) && type pkgver &>/dev/null && pkgver || echo $version) >/dev/null
    if [[ $remotever != $localver ]]; then
        echo "$i" >> /tmp/pacstall-up-list
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
${BOLD}$(tr '\n' ' ' < /tmp/pacstall-up-list)${NORMAL}"
    echo ""
    if ask "Do you want to continue?" Y; then
        for i in $(sed ':a;N;$!ba;s/\n/,/g' /tmp/pacstall-up-list); do
            sudo pacstall -I "$i"
        done
    else
        exit 1
    fi
fi
if test -f "/tmp/pacstall-up-list"; then
    rm -f /tmp/pacstall-up-list
fi
