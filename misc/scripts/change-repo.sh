#!/bin/bash
echo "repo changer"
      cmd=(dialog --separate-output --checklist "Select Repository:" 22 76 16)
      options=(1 "Henryws" on    # any option can be set to default to "on"
               2 "Option 2" off
               3 "Option 3" off
               4 "Option 4" off)
      CHOICE=$("${cmd[@]}" "${options[@]}" 2>&1 >/dev/tty)
      clear
      for choice in $CHOICE
      do
          case $CHOICE in
              1)
                  echo -e "${PURPLE}Henryws${NC} repository selected" ; echo -n "Henryws/pacstall-programs" | sudo tee /usr/share/pacstall/repo/pacstallrepo.txt
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
