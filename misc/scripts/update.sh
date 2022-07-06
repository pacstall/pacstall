#!/bin/bash

#     ____                  __        ____
#    / __ \____ ___________/ /_____ _/ / /
#   / /_/ / __ `/ ___/ ___/ __/ __ `/ / /
#  / ____/ /_/ / /__(__  ) /_/ /_/ / / /
# /_/    \__,_/\___/____/\__/\__,_/_/_/
#
# Copyright (C) 2020-present
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

# Update should be self-contained and should use mutable functions or variables
# Color variables are ok, while "$USERNAME" and "$BRANCH" are needed

sudo mkdir -p "/var/log/pacstall/metadata"
sudo mkdir -p "/var/log/pacstall/error_log"
find /var/log/pacstall/* -maxdepth 1 | grep -v metadata | grep -v error_log | xargs -I{} sudo mv {} /var/log/pacstall/metadata
sudo chown "$PACSTALL_USER" -R /var/log/pacstall/error_log

sudo mkdir -p "/tmp/pacstall"
sudo chown "$PACSTALL_USER" -R /tmp/pacstall

sudo mkdir -p /usr/share/bash-completion/completions

STGDIR="/usr/share/pacstall"
tabs -4

tty_settings=$(stty -g)
old_version=($(pacstall -V))
old_info=($(cat $STGDIR/repo/update 2>/dev/null || echo pacstall master))

old_username="${old_info[0]}"
old_branch="${old_info[1]}"

for i in {error_log.sh,add-repo.sh,search.sh,download.sh,install-local.sh,upgrade.sh,remove.sh,update.sh,query-info.sh}; do
	sudo wget -q -N https://raw.githubusercontent.com/"$USERNAME"/pacstall/"$BRANCH"/misc/scripts/"$i" -P "$STGDIR/scripts" &
done

sudo wget -q -N https://raw.githubusercontent.com/"$USERNAME"/pacstall/"$BRANCH"/pacstall -P /bin &
sudo wget -q -O /usr/share/man/man8/pacstall.8.gz https://raw.githubusercontent.com/"$USERNAME"/pacstall/"$BRANCH"/misc/pacstall.8.gz &
sudo wget -q -O /usr/share/bash-completion/completions/pacstall https://raw.githubusercontent.com/"$USERNAME"/pacstall/"$BRANCH"/misc/completion/bash &

if command -v fish &> /dev/null; then
	sudo wget -q -O /usr/share/fish/vendor_completions.d/pacstall.fish https://raw.githubusercontent.com/"$USERNAME"/pacstall/"$BRANCH"/misc/completion/fish &
fi

wait && stty "$tty_settings"

sudo chmod +x /bin/pacstall
sudo chmod +x /usr/share/pacstall/scripts/*

echo "$USERNAME $BRANCH" | sudo tee "$STGDIR/repo/update" > /dev/null

new_info=($(cat $STGDIR/repo/update))
new_version=($(pacstall -V))

new_username="${new_info[0]}"
new_branch="${new_info[1]}"

# Bling Bling update ascii
if [[ ${new_branch} != "master" ]]; then
	echo '
                                     ∩~-~∩
 _____               _        _ _   ξ ･×･ ξ
|  __ \             | |      | | |  ξ　~　ξ
| |__) |_ _  ___ ___| |_ __ _| | |  ξ　　 ξ
|  ___/ _` |/ __/ __| __/ _` | | |  ξ　　 “～～～〇
| |  | (_| | (__\__ \ || (_| | | |  ξ　　 　　　 ξ
|_|   \__,_|\___|___/\__\__,_|_|_|  ξ_ξ ξ_ξ ξ_ξξ_ξ
'
else
	echo '
    ____                  __        ____
   / __ \____ ___________/ /_____ _/ / /
  / /_/ / __ `/ ___/ ___/ __/ __ `/ / /
 / ____/ /_/ / /__(__  ) /_/ /_/ / / /
/_/    \__,_/\___/____/\__/\__,_/_/_/
'
fi

echo -e "[${BGreen}+${NC}] INFO: Updated from ${BGreen}${old_version}${NC} (${BGreen}${old_username} ${old_branch}${NC}) -> ${BGreen}${new_version}${NC} (${BGreen}${new_username} ${new_branch}${NC})"

if [[ ${new_branch} != "master" ]]; then
	echo -e "[${BGreen}+${NC}] INFO: You have updated to a development branch."
	echo -e "[${BYellow}*${NC}] WARN: Please remember that bugs may arise, and that this branch may not be as stable as master."

fi

if [[ ${new_username} == "pacstall" ]]; then
	echo -e "Useful links:"
	echo -e "\t${BYellow}Website${NC}: ${BOLD}https://pacstall.dev${NORMAL}"
	echo -e "\t${BPurple}Packages${NC}: ${BOLD}https://pacstall.dev/packages${NORMAL}"
	echo -e "\t${BCyan}GitHub${NC}: ${BOLD}https://github.com/pacstall${NORMAL}"
	echo -e "\t${BRed}Report Bugs${NC}: ${BOLD}https://github.com/${new_username}/pacstall/issues${NORMAL}"
	echo -e "\t${BBlue}Discord${NC}: ${BOLD}https://discord.gg/yzrjXJV6K8${NORMAL}"
	echo -e "\t${BGreen}Matrix${NC}: ${BOLD}https://matrix.to/#/#pacstall:matrix.org${NORMAL}"
fi
exit 0

# vim:set ft=sh ts=4 sw=4 noet:
