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

# Get the list of the installed packages
list=( $(pacstall -L) )
if [ -f /tmp/pacstall-up-list ]; then
  sudo rm /tmp/pacstall-up-list
fi

sudo touch /tmp/pacstall-up-list
REPO=$(cat "$STGDIR"/repo/pacstallrepo.txt)
fancy_message info "Checking for updates"

for i in "${list[@]}"; do
    # localver is the version of the package
    localver=$(sed -n -e 's/_version=//p' "$LOGDIR"/"$i" | tr -d \")
    # remotever stuff
    remotever=$(source <(curl -s "$REPO"/packages/"$i"/"$i".pacscript) && type pkgver &>/dev/null && pkgver || echo "$version") >/dev/null
    # if the remotever and localver are different, they are upgradable, EI: 1.4 != 1.2
    if [[ $remotever != $localver ]]; then
      echo "$i" | sudo tee -a /tmp/pacstall-up-list >/dev/null
    fi
done &

PID=$!
i=1
sp=".oO@*"
echo -n ' '
while [ -d /proc/$PID ]; do
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
    upgrade=()
    while IFS= read -r line; do
      upgrade+=("$line")
    done < /tmp/pacstall-up-list

    for i in "${upgrade[@]}"; do
      pacstall -I "$i"
    done
  else
    exit 1
  fi
fi

if test -f "/tmp/pacstall-up-list"; then
  sudo rm -f /tmp/pacstall-up-list
fi
