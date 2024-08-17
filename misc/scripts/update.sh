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

METADIR="/var/lib/pacstall/metadata"
LOGDIR="/var/log/pacstall/error_log"
SCRIPTDIR="/usr/share/pacstall"
PACDIR="/tmp/pacstall"
MAN8DIR="/usr/share/man/man8"
MAN5DIR="/usr/share/man/man5"
PODIR="${SCRIPTDIR}/po"
BASH_COMPLETION_DIR="/usr/share/bash-completion/completions"
FISH_COMPLETION_DIR="/usr/share/fish/vendor_completions.d"
PACSTALL_USER=$(logname 2> /dev/null || echo "${SUDO_USER:-${USER:-$(whoami)}}")

pacstall_deps=(
    "sudo" "wget" "build-essential" "unzip" "git"
    "zstd" "iputils-ping" "aptitude" "bubblewrap"
    "jq" "distro-info-data" "spdx-licenses" "gettext"
)

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

echo -e "[${BGreen}+${NC}] INFO: Updating..."

if [[ -n $GIT_USER ]]; then
    REPO="file://$PWD"
else
    REPO="https://raw.githubusercontent.com/${USERNAME}/pacstall/${BRANCH}"
    if ! curl -s --fail "${REPO}/pacstall" > /dev/null; then
        fancy_message error $"Invalid URL"
        suggested_solution "Confirm that '${UCyan}${REPO}/pacstall${NC}' is valid"
        exit 1
    fi
fi

fancy_message sub $"Fetching translation list"
read -r -a linguas < <(curl -fsSL "${REPO}/misc/po/LINGUAS")

fancy_message sub $"Updating directories"
for i in "${METADIR}" "${LOGDIR}" "${MAN8DIR}" "${MAN5DIR}" "${PODIR}" "${BASH_COMPLETION_DIR}" "${FISH_COMPLETION_DIR}"; do
    sudo mkdir -p "${i}"
done
for lang in "${linguas[@]}"; do
    sudo mkdir -p "misc/locale/${lang}/LC_MESSAGES/"
done

fancy_message sub $"Checking dependencies"
for pkg in "${pacstall_deps[@]}"; do
    if ! dpkg -s "${pkg}" > /dev/null 2>&1; then
        if [[ ${pkg} == "spdx-licenses" ]]; then
            if [[ -z $(apt-cache search --names-only "^${pkg}$") ]]; then
                sudo curl -s "http://ftp.debian.org/debian/pool/main/s/${pkg}/${pkg}_3.8+dfsg-3_all.deb" -o "/tmp/${pkg}.deb" && \
                    sudo apt install "/tmp/${pkg}.deb" -y && sudo rm -f "/tmp/${pkg}.deb" && continue
            fi
        fi
        to_install+=("${pkg}")
    fi
done
if ((${#to_install[@]} != 0)); then
    sudo apt-get install "${to_install[@]}" -y
fi

tabs -4

tty_settings=$(stty -g)
# shellcheck disable=SC2207
old_version=($(pacstall -V))
# shellcheck disable=SC2207
old_info=($(cat "$SCRIPTDIR/repo/update" 2> /dev/null || echo pacstall master))

old_username="${old_info[0]}"
old_branch="${old_info[1]}"

fancy_message sub $"Pulling scripts from GitHub"
pacstall_scripts=(
    "error-log" "add-repo" "search" "dep-tree" "version-constraints"
    "checks" "get-pacscript" "package" "package-base" "fetch-sources"
    "build" "upgrade" "remove" "update" "query-info" "quality-assurance"
    "bwrap" "srcinfo" "manage-repo"
)
for script in "${pacstall_scripts[@]}"; do
    sudo curl -s -o "$SCRIPTDIR/scripts/${script}.sh" "${REPO}/misc/scripts/${script}.sh" &
done
for lang in "${linguas[@]}"; do
    sudo curl -s -o "${PODIR}/${lang}.po" "${REPO}/misc/po/${lang}.po" &
done
# Remove renamed files
for i in {error_log,download,download-local,install-local,build-local}.sh; do
    sudo rm -f "${SCRIPTDIR:?}/scripts/$i"
done
sudo curl -s -o "/usr/bin/pacstall" "${REPO}/pacstall" &
sudo curl -s -o "${MAN8DIR}/pacstall.8" "${REPO}/misc/man/pacstall.8" &
sudo curl -s -o "${MAN5DIR}/pacstall.5" "${REPO}/misc/man/pacstall.5" &
sudo curl -s -o "${BASH_COMPLETION_DIR}/pacstall" "${REPO}/misc/completion/bash" &
sudo curl -s -o "${FISH_COMPLETION_DIR}/pacstall.fish" "${REPO}/misc/completion/fish" &
wait && stty "${tty_settings}"

fancy_message sub $"Rebuilding translations"
for lang in "${linguas[@]}"; do
    sudo msgfmt -o "/usr/share/locale/${lang}/LC_MESSAGES/pacstall.mo" "${PODIR}/${lang}.po"
done

fancy_message sub $"Rebuilding manpages"
sudo gzip --force -9n "${MAN8DIR}/pacstall.8"
sudo gzip --force -9n "${MAN5DIR}/pacstall.5"

fancy_message sub $"Making scripts executable"
sudo chmod +x "/usr/bin/pacstall"
sudo chmod +x "${SCRIPTDIR}/scripts/"*

if [[ -n $GIT_USER ]]; then
    echo "pacstall master" | sudo tee "${SCRIPTDIR}/repo/update" > /dev/null
else
    echo "${USERNAME} ${BRANCH}" | sudo tee "${SCRIPTDIR}/repo/update" > /dev/null
fi

# shellcheck disable=SC2207
new_info=($(cat $SCRIPTDIR/repo/update))
# shellcheck disable=SC2207
new_version=($(pacstall -V))

new_username="${new_info[0]}"
new_branch="${new_info[1]}"

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
fi
exit 0

# vim:set ft=sh ts=4 sw=4 et:
