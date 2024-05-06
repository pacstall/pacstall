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
export BOLD='\033[1m'
export NC='\033[0m'
export UCyan='\033[4;36m'
export BPurple='\033[1;35m'

required_packages=(lsb-release aptitude bubblewrap jq)

function suggested_solution() {
    if [[ -z $PACSTALL_SUPPRESS_SOLUTIONS ]]; then
        local inputs=("${@}")
        if ((${#inputs[@]} > 1)); then
            local text="Suggested solutions are:"
        else
            local text="Suggested solution is:"
        fi
        echo -e "[${BOLD}${BPurple}⠿${NC}] ${text}"
        for i in "${inputs[@]}"; do
            echo -e "    ${BOLD}|${NC} $i"
        done
    fi
}

sudo mkdir -p "/var/lib/pacstall/metadata"
sudo mkdir -p "/var/log/pacstall/error_log"
sudo chown "$PACSTALL_USER" -R /var/log/pacstall/error_log

sudo mkdir -p "/tmp/pacstall"
sudo chown "$PACSTALL_USER" -R /tmp/pacstall

sudo mkdir -p /usr/share/bash-completion/completions

for pkg in "${required_packages[@]}"; do
    if ! dpkg -s "${pkg}" > /dev/null 2>&1; then
        to_install+=("${pkg}")
    fi
done
if ((${#to_install[@]} != 0)); then
    sudo apt-get install "${to_install[@]}" -y
fi

# Pre 4.0.0 metadata dir changes
if [[ -d "/var/log/pacstall/metadata/" ]]; then
    sudo mkdir -p "/var/lib/pacstall/metadata/"
    sudo cp -r "/var/log/pacstall/metadata/" "/var/lib/pacstall/"
    sudo rm -rf "/var/log/pacstall/metadata/"
fi

SCRIPTDIR="/usr/share/pacstall"
tabs -4

tty_settings=$(stty -g)
# shellcheck disable=SC2207
old_version=($(pacstall -V))
# shellcheck disable=SC2207
old_info=($(cat $SCRIPTDIR/repo/update 2> /dev/null || echo pacstall master))

old_username="${old_info[0]}"
old_branch="${old_info[1]}"

if [[ -n $GIT_USER ]]; then
    REPO="file://$PWD"
else
    REPO="https://raw.githubusercontent.com/$USERNAME/pacstall/$BRANCH"
    if ! curl -s --fail "$REPO/pacstall" > /dev/null; then
        fancy_message error "Invalid URL"
        suggested_solution "Confirm that '${UCyan}$REPO/pacstall${NC}' is valid"
        exit 1
    fi
fi
for i in {error-log.sh,add-repo.sh,search.sh,dep-tree.sh,version-constraints.sh,checks.sh,get-pacscript.sh,package.sh,fetch-sources.sh,build.sh,upgrade.sh,remove.sh,update.sh,query-info.sh,quality-assurance.sh,bwrap.sh}; do
    sudo curl -s -o "$SCRIPTDIR/scripts/$i" "$REPO/misc/scripts/$i" &
done
# Remove renamed files
for i in {error_log.sh,download.sh,download-local.sh,install-local.sh,build-local.sh}; do
    sudo rm -f "$SCRIPTDIR/scripts/$i"
done

sudo curl -s -o /bin/pacstall "$REPO/pacstall" &
sudo curl -s -o /usr/share/man/man8/pacstall.8.gz "$REPO/misc/pacstall.8.gz" &
sudo curl -s -o /usr/share/bash-completion/completions/pacstall "$REPO/misc/completion/bash" &

if command -v fish &> /dev/null; then
    sudo curl -s -o /usr/share/fish/vendor_completions.d/pacstall.fish "$REPO/misc/completion/fish" &
fi

wait && stty "$tty_settings"

sudo chmod +x /bin/pacstall
sudo chmod +x /usr/share/pacstall/scripts/*

if [[ -n $GIT_USER ]]; then
    echo "pacstall master" | sudo tee "$SCRIPTDIR/repo/update" > /dev/null
else
    echo "$USERNAME $BRANCH" | sudo tee "$SCRIPTDIR/repo/update" > /dev/null
fi

if [[ -f ${SCRIPTDIR}/repo/pacstallrepo.txt ]]; then
    sudo mv "${SCRIPTDIR}/repo/pacstallrepo.txt" "${SCRIPTDIR}/repo/pacstallrepo"
fi

# shellcheck disable=SC2207
new_info=($(cat $SCRIPTDIR/repo/update))
# shellcheck disable=SC2207
new_version=($(pacstall -V))

new_username="${new_info[0]}"
new_branch="${new_info[1]}"

# TODO: Remove this after a while
if [[ ${old_version[0]} =~ 3\.[0-9]+\.[0-9]+ ]] && [[ ${new_version[0]} =~ 4\.[0-9]+\.[0-9]+ ]]; then
    curl -s https://raw.githubusercontent.com/pacstall/pacstall-4.0.0-scripts/master/convert.sh | bash
fi

# Bling Bling update ascii
if [[ -n ${GIT_USER} || ${new_branch} != "master" ]]; then
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

if [[ -n $GIT_USER ]]; then
    echo -e "[${BGreen}+${NC}] INFO: You have updated to a local branch."
    echo -e "[${BYellow}*${NC}] WARN: Remember that you must update with '${BCyan}pacstall -U .${NC}' to update to this repo again, otherwise run '${BCyan}pacstall -U${NC}'."
elif [[ ${new_branch} != "master" ]]; then
    echo -e "[${BGreen}+${NC}] INFO: You have updated to a development branch."
    echo -e "[${BYellow}*${NC}] WARN: Please remember that bugs may arise, and that this branch may not be as stable as master."
fi

if [[ ${new_username} == "pacstall" ]]; then
    echo -e "Useful links:"
    echo -e "\t${BYellow}Website${NC}: ${BOLD}https://pacstall.dev${NC}"
    echo -e "\t${BPurple}Packages${NC}: ${BOLD}https://pacstall.dev/packages${NC}"
    echo -e "\t${BCyan}GitHub${NC}: ${BOLD}https://github.com/pacstall${NC}"
    echo -e "\t${BRed}Report Bugs${NC}: ${BOLD}https://github.com/${new_username}/pacstall/issues${NC}"
    echo -e "\t${BBlue}Discord${NC}: ${BOLD}https://discord.gg/yzrjXJV6K8${NC}"
    echo -e "\t${BGreen}Matrix${NC}: ${BOLD}https://matrix.to/#/#pacstall:matrix.org${NC}"
fi
exit 0

# vim:set ft=sh ts=4 sw=4 noet:
