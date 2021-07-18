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

if [[ -z "$UPGRADE" ]]; then
  SEARCH=$2
  if [[ -z "$SEARCH" ]]; then
	fancy_message error "You failed to specify a package"
	exit 3
  fi
else
  PACKAGE=$i
fi

# Makes array of packages and array
# of their respective URL's
PACKAGELIST=()
URLLIST=()
while IFS= read -r URL; do
  PARTIALLIST=($(curl -s "$URL"/packagelist))
  URLLIST+=("${PARTIALLIST[@]/*/$URL}")
  PACKAGELIST+=(${PARTIALLIST[*]})
  PACKAGELIST[-1]+=' ' # Broke while testing
                       # Added space so that
                       # the last word didn't merge
                       # with the first in the
                       # following loop
done < "$STGDIR/repo/pacstallrepo.txt"

# Gets index of packages that the search returns
if [[ -z "$PACKAGE" ]]; then
  IDXSEARCH=$(printf "%s\n" "${PACKAGELIST[@]}" | grep -n "${SEARCH}" | cut -d : -f1| awk '{print $0"-1"}'|bc)
else
  IDXSEARCH=$(printf "%s\n" "${PACKAGELIST[@]}" | grep -n "^${PACKAGE}$" | cut -d : -f1| awk '{print $0"-1"}'|bc)
fi
LEN=($IDXSEARCH)
LEN=${#LEN[@]}

# Parses github and gitlab URL's
# url -> maintaner/repo 
# Also adds hyperlink for the
# terminals that support them
function parseRepo() {
  local REPO="${1}"
  SPLIT=($(echo "$REPO" | tr "/" "\n"))
  
  if command echo "$REPO" |grep "github" &> /dev/null; then
    echo -e "\e]8;;https://github.com/${SPLIT[-3]}/${SPLIT[-2]}\a${SPLIT[-3]}\e]8;;\a"
    
  elif command echo "$REPO" |grep "gitlab" &> /dev/null; then
    echo -e "\e]8;;https://gitlab.com/${SPLIT[-4]}/${SPLIT[-3]}\a${SPLIT[-4]}\e]8;;\a"
  
  else
    echo "\e]8;;$REPO\a$REPO\e]8;;\a"
  fi
}


#Check if there are results
if [[ "$LEN" -eq 0 ]]; then
  fancy_message warn "There is no package with the name $IRed$SEARCH$NC"
  exit 1
# Check if it's upgrading packages
elif [[ ! -z "$UPGRADE" ]]; then
  REPOS=()
  for IDX in $IDXSEARCH ; do
    REPOS+=(${URLLIST[$IDX]})
  done

# Check if its being used for search or intall 
elif [[ -z "$PACKAGE" ]]; then
  # Search
  for IDX in $IDXSEARCH ; do
    echo -e "$GREEN${PACKAGELIST[$IDX]}$CYAN @ $(parseRepo "${URLLIST[$IDX]}") $NC"
  done
  exit 1
else
  # Install
  # If there is only one result, proceed
  if [[ "$LEN" -eq 1 ]]; then
    export PACKAGE=${PACKAGELIST[$IDXSEARCH]}
    export REPO=${URLLIST[$IDXSEARCH]}
  # If there are multiple results, ask
  else
    echo -e "There are $LEN package(s) with the name $GREEN$SEARCH$NC." 
    
    if ask "Do you want to continue?" Y; then
      # Pacstall repo first
      for IDX in $IDXSEARCH ; do
        if [[ "${URLLIST[$IDX]}" == 'https://raw.githubusercontent.com/pacstall/pacstall-programs/master' ]]; then
          PACSTALLREPO=$IDX
          break
        fi
      done
      if [[ ! -z "$PACSTALLREPO" ]]; then
        if ask "\e[1A\e[KDo you want to $type $GREEN${PACKAGELIST[$IDX]}$NC from the repo $CYAN$(parseRepo "${URLLIST[$IDX]}")$NC?" Y;then
          export PACKAGE=${PACKAGELIST[$PACSTALLREPO]}
          export REPO=${URLLIST[$PACSTALLREPO]}
          DEFAULT='yes'
        else
          DEFAULT='no'
        fi
      fi
      if [[ "$DEFAULT" == "no" ]] || [[ -z "$PACSTALLREPO" ]]; then
        for IDX in $IDXSEARCH ; do
          if [[ "$IDX" == "$PACSTALLREPO" ]]; then
            continue
          fi
          # Overwrite last question
          if ask "\e[1A\e[KDo you want to $type $GREEN${PACKAGELIST[$IDX]}$NC from the repo $CYAN$(parseRepo "${URLLIST[$IDX]}")$NC?" Y;then
            export PACKAGE=${PACKAGELIST[$IDX]}
            export REPO=${URLLIST[$IDX]}
            break
          fi
        done
      fi
    else
      exit 1
    fi
  fi
fi


