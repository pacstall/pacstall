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

if [[ ! -d ${LOGDIR} ]]; then
    sudo mkdir -p "${LOGDIR}"
fi

# Used with permission by zakariaGatter
declare -r -A ErrMsg=([1]="Unknown cause of failure."
    [2]="Error in configuration file."
    [3]="User specified an invalid option."
    [4]="Error in user-supplied function in pacscript."
    [5]="Failed to create a viable package."
    [6]="A source or auxiliary file specified in the pacscript is missing."
    [7]="The STAGEDIR is missing."
    [8]="Failed to install dependencies."
    [9]="Failed to remove dependencies."
    [10]="User attempted to run pacstall as root."
    [11]="User lacks permissions to build or install to a given location."
    [12]="Error parsing pacscript."
    [13]="A package has already been built."
    [14]="The package failed to install."
    [15]="Programs necessary to run pacstall are missing."
    [16]="Specified hash does not exist or failed to sign package.")

function error_log() {
    # shellcheck disable=SC2034
    { ignore_stack=false; set -o pipefail; trap stacktrace ERR RETURN; }
    local code="${1}"
    local scope="${2}"
    local time

    if [[ ! -d ${LOGDIR} ]]; then
        sudo mkdir -p "${LOGDIR}"
    fi

    if [[ ! -f $LOGFILE ]]; then
        sudo touch "$LOGFILE"
        sudo find "${LOGDIR:-/var/log/pacstall/error_log/}" -type f -ctime +14 -delete
    fi

    printf -v time '%(%a %b %_d %r %Z %Y)T'
    echo -e "[ ${time} | ${scope} ] Error ${code} - ${ErrMsg[${code}]}" | sudo tee -a "$LOGFILE" > /dev/null
    return 0
}

export -f error_log

# vim:set ft=sh ts=4 sw=4 et:
