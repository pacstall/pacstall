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

export UPGRADE="yes"

# Get the list of the installed packages
list=( $(pacstall -L) )
if [ -f /tmp/pacstall-up-list ]; then
  sudo rm /tmp/pacstall-up-list
fi

if [ -f /tmp/pacstall-up-print ]; then
  sudo rm /tmp/pacstall-up-print
fi

if [ -f /tmp/pacstall-up-urls ]; then
  sudo rm /tmp/pacstall-up-urls
fi

sudo touch /tmp/pacstall-up-list
sudo touch /tmp/pacstall-up-print
sudo touch /tmp/pacstall-up-urls

fancy_message info "Checking for updates"

for i in "${list[@]}"; do
    source "$LOGDIR/$i"

    if [[ -z ${_remoterepo} ]]; then
      continue
    fi
    
    if echo "${_remoterepo}" | grep "github.com" > /dev/null ; then
      remoterepo="${_remoterepo/'github.com'/'raw.githubusercontent.com'}/${_remotebranch}" 
    elif echo "${_remoterepo}"| grep "gitlab.com" > /dev/null; then
      remoterepo="${_remoterepo}/-/raw/${_remotebranch}"
    else
      remoterepo=${_remoterepo}
    fi

    unset _remoterepo
    
    # localver is the version of the package
    localver=$(sed -n -e 's/_version=//p' "$LOGDIR"/"$i" | tr -d \")

    
    source "$STGDIR/scripts/search.sh"
    
    
    IDXMATCH=$(printf "%s\n" "${REPOS[@]}"| grep -n "$remoterepo" | cut -d : -f1| awk '{print $0"-1"}'|bc)
    
    if [[ -z $IDXMATCH ]]; then
      remotever=$(source <(curl -s "$REPO"/packages/"$i"/"$i".pacscript) && type pkgver &>/dev/null && pkgver || echo "$version") >/dev/null
      remoteurl=$REPO
    else
      remotever="0.0.0"
      for REPO in "${REPOS[@]}"; do
        ver=$(source <(curl -s "$REPO"/packages/"$i"/"$i".pacscript) && type pkgver &>/dev/null && pkgver || echo "$version") >/dev/null
        if  dpkg --compare-versions "$remotever" "lt" "$ver" ; then
          remotever=$ver
          remoteurl=$REPO   
        fi
      done
    fi
    if dpkg --compare-versions "$localver" "lt" "$remotever"; then
        echo "$i" |sudo tee -a /tmp/pacstall-up-list >/dev/null
        echo "${GREEN}${i}${CYAN} @ $(parseRepo "${remoteurl}") ${NC}" | sudo tee -a /tmp/pacstall-up-print >/dev/null
        echo "$remoteurl" |sudo tee -a /tmp/pacstall-up-urls >/dev/null
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
  echo -e "Upgradable: $(wc -l /tmp/pacstall-up-print | awk '{ print $1 }')
${BOLD}$(cat /tmp/pacstall-up-print)${NORMAL}"
  echo ""

  if ask "Do you want to continue?" Y; then
    upgrade=()
    while IFS= read -r line; do
      upgrade+=("$line")
    done < /tmp/pacstall-up-list
    
    while IFS= read -r line; do
      remotes+=("$line")
    done < /tmp/pacstall-up-urls
    
    export local='no'
    for i in "${!upgrade[@]}"; do
      PACKAGE=${upgrade[$i]}
      REPO="${remotes[$i]}"
      export URL="$REPO/packages/$PACKAGE/$PACKAGE.pacscript"
      source "$STGDIR/scripts/download.sh"
      source "$STGDIR/scripts/install-local.sh"
    done
  else
    exit 1
  fi
fi


if test -f "/tmp/pacstall-up-list"; then
  sudo rm -f /tmp/pacstall-up-list
fi

if test -f "/tmp/pacstall-up-print"; then
  sudo rm -f /tmp/pacstall-up-print
fi

if test -f "/tmp/pacstall-up-urls"; then
  sudo rm -f /tmp/pacstall-up-urls
fi
