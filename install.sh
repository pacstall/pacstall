#!/bin/bash

#     ____                  __        ____
#    / __ \____ ___________/ /_____ _/ / /
#   / /_/ / __ `/ ___/ ___/ __/ __ `/ / /
#  / ____/ /_/ / /__(__  ) /_/ /_/ / / /
# /_/	 \__,_/\___/____/\__/\__,_/_/_/
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

export METADIR="/var/lib/pacstall/metadata"
export LOGDIR="/var/log/pacstall/error_log"
export SCRIPTDIR="/usr/share/pacstall"
export PACDIR="/tmp/pacstall"
export MAN8DIR="/usr/share/man/man8"
export MAN5DIR="/usr/share/man/man5"
export PODIR="${SCRIPTDIR}/po"
export BASH_COMPLETION_DIR="/usr/share/bash-completion/completions"
export FISH_COMPLETION_DIR="/usr/share/fish/vendor_completions.d"
export REPO="https://raw.githubusercontent.com/pacstall/pacstall/master"
export PACSTALL_USER=$(logname 2> /dev/null || echo "${SUDO_USER:-${USER:-$(whoami)}}")

function set_colors() {
    # Colors
    export BOLD='\033[1m'
    export NC="\033[0m"

    export BLACK='\033[0;30m'
    export RED='\033[0;31m'
    export GREEN='\033[0;32m'
    export YELLOW='\033[0;33m'
    export BLUE='\033[0;34m'
    export PURPLE='\033[0;35m'
    export CYAN='\033[0;36m'
    export WHITE='\033[0;37m'

    export BRed='\033[1;31m'
    export BGreen='\033[1;32m'
    export BYellow='\033[1;33m'
    export PACCYAN='\e[38;5;30m'
    export PACYELLOW='\e[38;5;214m'
}

function fancy_message() {
    # $1 = type , $2 = message
    # Message types
    # 0 - info
    # 1 - warning
    # 2 - error
    if [[ -z ${1} || -z ${2} ]]; then
        return
    fi

    local MESSAGE_TYPE="${1}"
    local MESSAGE="${2}"

    case ${MESSAGE_TYPE} in
        info) echo -e "[${BGreen}+${NC}] ${BOLD}INFO${NC}: ${MESSAGE}" ;;
        warn) echo >&2 -e "[${BYellow}*${NC}] ${BOLD}WARNING${NC}: ${MESSAGE}" ;;
        error) echo >&2 -e "[${BRed}!${NC}] ${BOLD}ERROR${NC}: ${MESSAGE}" ;;
        *) echo >&2 -e "[${BOLD}?${NC}] ${BOLD}UNKNOWN${NC}: ${MESSAGE}" ;;
    esac
}

function stacktrace() {
    local catch=$?
    if ((catch==1)) && ! ${ignore_stack}; then
        local i stack_size=${#FUNCNAME[@]} func linen src trace content stack_color color_idx \
            colors=(196 197 198 199 200 201 165 129 93 57 21 27 33 39 45 51 50 49 48 47 46 82 118 154 190 226 220 214 208 202)
        echo -e "[${BRed}!${NC}] ${BOLD}ERROR${NC}: Stacktrace (most recent call last)" >&2
        for ((i = stack_size - 1; i >= 1; i--)); do
            color_idx=$(( (stack_size - 1 - i) % ${#colors[@]} ))
            stack_color="\033[38;5;${colors[color_idx]}m"
            ((i != stack_size - 1)) && func="${FUNCNAME[i - 1]}"
            [[ -z ${func} ]] && func='MAIN'
            [[ ${func} == "stacktrace" ]] && { unset func; trace="${RED}TRACEBACK${NC}"; }
            linen="${BASH_LINENO[i - 1]}"
            src="${BASH_SOURCE[i]}"
            [[ -z ${src} ]] && src=non_file_source
            echo -e " ${stack_color}${func:+├}${trace:+╰}─➤${GREEN}${func}${NC}${trace}${NC}${func:+()}${trace:+:} ${src%/*}/${PURPLE}${src##*/}${NC}:${YELLOW}${linen}${NC}" >&2
            # shellcheck disable=SC2027
            echo -e " ${stack_color}${func:+│}${trace:+ }${NC}  ${CYAN}╰───➤${NC} \033[38;5;242m"$(tail -n +"${linen}" "${src}" | head -n1)"${NC}" >&2
        done
        fancy_message error "Installation failed"
        exit 1
    else
        export ignore_stack=false
        return "${catch}"
    fi
}
{ export ignore_stack=false; set -o pipefail; trap stacktrace ERR RETURN; }

function pre_check() {
    { ignore_stack=false; set -o pipefail; trap stacktrace ERR RETURN; }

    if [[ ! -t 0 ]]; then
        NON_INTERACTIVE=true
        fancy_message warn "Reading input from pipe"
    fi

    if ! command -v apt &> /dev/null; then
        fancy_message error "apt could not be found"
        return 1
    fi

    if ! command -v curl &> /dev/null; then
        apt-get install -y -qq curl iputils-ping || return 1
    fi

    if ! command -v wget &> /dev/null; then
        apt-get install -y -qq wget ca-certificates || return 1
    fi
}

function pre_update() {
    { ignore_stack=false; set -o pipefail; trap stacktrace ERR RETURN; }
    eval "$(apt-config shell State Dir::State)" || return 1
    eval "$(apt-config shell List Dir::State::Lists)" || return 1
    if [[ -z "$(find -H "/${State}/${List}" -maxdepth 0 -mtime -7)" ]]; then
        fancy_message info "Updating"
        case "${GITHUB_ACTIONS}" in
            true) apt-get update -qq || return 1 ;;
            *) apt-get update || return 1 ;;
        esac
    fi
}

function install_deps() {
    { ignore_stack=false; set -o pipefail; trap stacktrace ERR RETURN; }
    fancy_message info "Installing packages"
    pacstall_deps=(
        "sudo" "wget" "build-essential" "unzip" "git"
        "zstd" "iputils-ping" "aptitude" "bubblewrap"
        "jq" "distro-info-data" "spdx-licenses" "gettext"
        "curl" "iputils-ping" "ca-certificates"
    )
    echo -ne "Do you want to install axel (faster downloads)? [${BGreen}Y${NC}/${RED}n${NC}] "
    read -r reply <&0
    case "$reply" in
        N* | n*) ;;
        *)
            pacstall_deps+=("axel")
            ;;
    esac

    for pkg in "${pacstall_deps[@]}"; do
        if ! dpkg -s "${pkg}" > /dev/null 2>&1; then
            if [[ ${pkg} == "spdx-licenses" ]]; then
                if [[ -z $(apt-cache search --names-only "^${pkg}$") ]]; then
                    {
                        wget -q -O "/tmp/${pkg}.deb" "https://ftp.debian.org/debian/pool/main/s/${pkg}/${pkg}_3.27.0+ds-1_all.deb" && \
                        sudo apt install "/tmp/${pkg}.deb" -y && \
                        sudo rm -f "/tmp/${pkg}.deb" && continue
                    } || return 1
                fi
            fi
            to_install+=("${pkg}")
        fi
    done
    if ((${#to_install[@]} != 0)); then
        if [[ ${GITHUB_ACTIONS} == "true" ]]; then
            apt-get install -qq -y "${to_install[@]}" || return 1
        else
            apt-get install -y "${to_install[@]}" || return 1
        fi
    fi
}

function fetch_i18n() {
    { ignore_stack=false; set -o pipefail; trap stacktrace ERR RETURN; }
    fancy_message info "Fetching translation list"
    mapfile -t linguas < <(wget -qO- "${REPO}/misc/po/LINGUAS") || return 1
}

function build_dirs() {
    { ignore_stack=false; set -o pipefail; trap stacktrace ERR RETURN; }
    fancy_message info "Making directories"
    mkdir -p "${SCRIPTDIR}/scripts" "${SCRIPTDIR}/repo" "${PACDIR}" "${METADIR}" "${LOGDIR}" "${MAN8DIR}" "${MAN5DIR}" "${PODIR}" "${BASH_COMPLETION_DIR}" "${FISH_COMPLETION_DIR}" || return 1
    chown "${PACSTALL_USER}" -cR "${PACDIR}" "${LOGDIR}" || return 1
    for lang in "${linguas[@]}"; do
        mkdir -p "/usr/share/locale/${lang}/LC_MESSAGES/" || return 1
    done
}

function fetch_scripts() {
    { ignore_stack=false; set -o pipefail; trap stacktrace ERR RETURN; }
    fancy_message info "Pulling scripts from GitHub"
    pacstall_scripts=(
        "error-log" "add-repo" "search" "dep-tree" "version-constraints"
        "checks" "get-pacscript" "package" "package-base" "fetch-sources"
        "build" "upgrade" "remove" "update" "query-info" "quality-assurance"
        "bwrap" "srcinfo" "manage-repo"
    )
    rm -f "${SCRIPTDIR}/repo/pacstallrepo" > /dev/null
    echo "${REPO/pacstall\/pacstall/pacstall\/pacstall-programs}" > "${SCRIPTDIR}/repo/pacstallrepo"
    for script in "${pacstall_scripts[@]}"; do
        wget -q --show-progress -N "${REPO}/misc/scripts/${script}.sh" -P "${SCRIPTDIR}/scripts" &
    done
    for lang in "${linguas[@]}"; do
        wget -q --show-progress -N "${REPO}/misc/po/${lang}.po" -P "${PODIR}" &
    done
    wget -q --show-progress --progress=bar:force -O "/usr/bin/pacstall" "${REPO}/pacstall" &
    wget -q --show-progress --progress=bar:force -O "${MAN8DIR}/pacstall.8" "${REPO}/misc/man/pacstall.8" &
    wget -q --show-progress --progress=bar:force -O "${MAN5DIR}/pacstall.5" "${REPO}/misc/man/pacstall.5" &
    wget -q --show-progress --progress=bar:force -O "${BASH_COMPLETION_DIR}/pacstall" "${REPO}/misc/completion/bash" &
    wget -q --show-progress --progress=bar:force -O "${FISH_COMPLETION_DIR}/pacstall.fish" "${REPO}/misc/completion/fish" &
    wait
}

function build_i18n() {
    { ignore_stack=false; set -o pipefail; trap stacktrace ERR RETURN; }
    fancy_message info "Building translations"
    for lang in "${linguas[@]}"; do
        msgfmt -o "/usr/share/locale/${lang}/LC_MESSAGES/pacstall.mo" "${PODIR}/${lang}.po" || return 1
    done
}

function build_man() {
    { ignore_stack=false; set -o pipefail; trap stacktrace ERR RETURN; }
    fancy_message info "Building manpages"
    gzip --force -9n "${MAN8DIR}/pacstall.8" || return 1
    gzip --force -9n "${MAN5DIR}/pacstall.5" || return 1
}

function set_exec() {
    { ignore_stack=false; set -o pipefail; trap stacktrace ERR RETURN; }
    fancy_message info "Making scripts executable"
    chmod +x "/usr/bin/pacstall" || return 1
    chmod +x "${SCRIPTDIR}/scripts/"* || return 1
}

set_colors
((EUID != 0)) && { fancy_message error "Must be root to install Pacstall!"; ignore_stack=true; exit 1; }
pre_check
echo -e "${PACYELLOW}┌────────────────────────┐\n│   ${PACCYAN}Pacstall Installer${PACYELLOW}   │\n└────────────────────────┘${NC}\n"
pre_update
install_deps
fetch_i18n
build_dirs
fetch_scripts
build_i18n
build_man
set_exec
fancy_message info "Installation complete"
# vim:set ft=sh ts=4 sw=4 et:
