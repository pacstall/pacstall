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

echo "repo changer"
      cmd=(dialog --separate-output --checklist "Select Repository:" 22 76 16)
      options=(1 "pacstall" on    # any option can be set to default to "on"
               2 "Option 2" off
               3 "Option 3" off
               4 "Option 4" off)
      CHOICE=$("${cmd[@]}" "${options[@]}" 2>&1 >/dev/tty)
      clear
      for choice in $CHOICE
      do
          case $CHOICE in
              1)
                  fancy_message info "${PURPLE}pacstall${NC} repository selected" ; echo -n "https://raw.githubusercontent.com/pacstall/pacstall-programs/master" | sudo tee /usr/share/pacstall/repo/pacstallrepo.txt
                  exit
                  ;;
              2)
                  echo "Second Option"
                  ;;
              3)
                  echo "Third Option"
                  ;;
              4)
                  echo "Fourth Option"
                  ;;
          esac
      done
