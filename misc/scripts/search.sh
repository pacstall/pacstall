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

# This script searches for packages

export LC_ALL=C
SEARCH=$2
if [[ -z "$SEARCH" ]]; then
	fancy_message error "You failed to specify a package"
	exit 3
fi

PACKAGELIST=()
URLLIST=()
while IFS= read -r  URL; do
  PARTIALLIST=($(curl -s "$URL"/packagelist))
  PACKAGELIST+=(${PARTIALLIST[*]})
  PACKAGELIST[-1]+=' '
  URLLIST+=("${PARTIALLIST[@]/*/$URL}")
done < "$STGDIR/repo/pacstallrepo.txt"

IDXSEARCH=$(echo ${PACKAGELIST[*]} | tr ' ' '\n' | grep -n "$SEARCH" | cut -d : -f1| awk '{print $0"-1"}'|bc)
LEN=($IDXSEARCH)
LEN=${#LEN[@]}

function parseRepo() {
  local REPO="${1}"
  SPLIT=($(echo $REPO | tr "/" "\n"))
  
  if command echo $REPO |grep "github" &> /dev/null;then
    echo -e "\e]8;;https://github.com/${SPLIT[-3]}/${SPLIT[-2]}\a${SPLIT[-3]}\e]8;;\a"
    
  elif command echo $REPO |grep "gitlab" &> /dev/null;then
    echo -e "\e]8;;https://gitlab.com/${SPLIT[-4]}/${SPLIT[-3]}\a${SPLIT[-4]}\e]8;;\a"
  
  else
    echo "\e]8;;$REPO\a$REPO\e]8;;\a" 
  fi
}

if [ $LEN -eq 0 ];then
  fancy_message warn "There is no package with the name $IRed$SEARCH$NC"
  
elif [[ -z "$PACKAGE" ]];then
  fancy_message info "There are $LEN package(s) with $IGreen$SEARCH$NC in their name:"
  for IDX in $IDXSEARCH ; do
    echo -e "$GREEN${PACKAGELIST[$IDX]}$CYAN @ $(parseRepo ${URLLIST[$IDX]}) $NC"
  done
  
else
  if [ $LEN -eq 1 ];then
    REPO=${URLLIST[0]}
  else
    echo "There are $LEN package(s) with $GREEN$SEARCH$NC in their name."
    
    if ask "Do you want to continue?" N;then
      for IDX in $IDXSEARCH ; do
        if ask "\e[1A\e[KDo you want to install $GREEN${PACKAGELIST[$IDX]}$NC from the repo $CYAN$(parseRepo ${URLLIST[$IDX]})$NC?" N;then
          REPO=${URLLIST[$IDX]}
          break
        fi
      done  
    else
      exit 1
    fi
  fi
fi


