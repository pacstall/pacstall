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

{ ignore_stack=false; set -o pipefail; trap stacktrace ERR RETURN; }

function parse_pr() {
    { ignore_stack=false; set -o pipefail; trap stacktrace ERR RETURN; }
    IFS=':' read -ra ADDR <<< "$1"
    local provider user repo pr
    provider="${ADDR[0]}"
    user=$(echo "${ADDR[1]}" | cut -d'/' -f1)
    repo=$(echo "${ADDR[1]}" | cut -d'/' -f2)
    pr="$2"
    echo "$provider" "$user" "$repo" "$pr"
}

function parse_link() {
    { ignore_stack=false; set -o pipefail; trap stacktrace ERR RETURN; }
    unset login
    local provider="$1" user="$2" repo="$3" pr="$4"
    if [[ $provider == "github" ]]; then
        gh_provides=$(curl -s "https://api.github.com/repos/$user/$repo/pulls/$pr")
        head_repo_full_name=$(echo "$gh_provides" | jq -r '.head.repo.full_name')
        head_sha=$(echo "$gh_provides" | jq -r '.head.sha')
        login=$(echo "$gh_provides" | jq -r '.head.user.login')
        echo "https://raw.githubusercontent.com/$head_repo_full_name/$head_sha" "$login"
    else
        fancy_message error $"${CYAN}$provider${NC} is not a valid provider!"
        fancy_message sub $"available providers are: 'github'"
        exit 1
    fi
}

function cleanup_qa() {
    # shellcheck disable=SC2034
    { ignore_stack=false; set -o pipefail; trap stacktrace ERR RETURN; }
    if [[ -f "$SCRIPTDIR/repo/pacstallrepo.pacstall-qa.bak" ]]; then
        fancy_message info $"Returning ${CYAN}$SCRIPTDIR/repo/pacstallrepo${NC} backup"
        sudo rm -f "${SCRIPTDIR:?}/repo/pacstallrepo"
        sudo mv "$SCRIPTDIR/repo/pacstallrepo.pacstall-qa.bak" "$SCRIPTDIR/repo/pacstallrepo"
    fi
}

trap cleanup_qa EXIT INT
metalink="${METAURL:-github:pacstall/pacstall-programs}" number="$PRNUM" inst="$PACKAGE"
if [[ -z $number || -z $inst ]]; then
    fancy_message error $"'number' and 'package' cannot be empty!"
    fancy_message sub $"use the syntax: -Qa ${GREEN}package${BYellow}#${YELLOW}NUM${NC}(${BPurple}@${PURPLE}metalink${NC})"
    exit 1
fi
read -r provider user repo pr <<< "$(parse_pr "$metalink" "$number")"
read -r provider_url login <<< "$(parse_link "$provider" "$user" "$repo" "$pr")"
fancy_message info $"Backing up ${CYAN}$SCRIPTDIR/repo/pacstallrepo${NC}"
sudo mv "$SCRIPTDIR/repo/pacstallrepo" "$SCRIPTDIR/repo/pacstallrepo.pacstall-qa.bak"
echo "$provider_url" | sudo tee "$SCRIPTDIR/repo/pacstallrepo" > /dev/null
fancy_message info $"Installing ${GREEN}$inst${NC}(${PURPLE}$login${NC}:${RED}$pr${NC})"
cmd="-I"
[[ ${GITHUB_ACTIONS} == "true" ]] && cmd+="P"
[[ $KEEP ]] && cmd+="K"
((PACSTALL_INSTALL == 0)) && cmd+="B"
[[ $NOSANDBOX ]] && cmd+="Ns"
pacstall $cmd "$inst" || exit 1
