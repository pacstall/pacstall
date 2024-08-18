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

# shellcheck disable=SC2034
{ ignore_stack=false; set -o pipefail; trap stacktrace ERR RETURN; }

source "$METADIR/$PACKAGE" 2> /dev/null || {
    fancy_message error $"$PACKAGE is not installed"
    exit 1
}

if ! dpkg -l "${_gives:-$_name}" &> /dev/null; then
    fancy_message error $"$PACKAGE is not installed"
    exit 1
fi

sudo apt-get remove "${_gives:-$_name}" -y || {
    error_log 1 "remove $PACKAGE"
    exit 1
}

if [[ -n ${_ppa[*]} ]]; then
    for ppa in "${_ppa[@]}"; do
        fancy_message warn $"You may have dangling PPAs on your system. You can remove them using '${UCyan}sudo add-apt-repository --remove ppa:$ppa${NC}'"
    done
fi

sudo rm -f "${METADIR:?}/${_name}"
sudo rm -f "/etc/apt/preferences.d/${_name//./-}-pin"
# vim:set ft=sh ts=4 sw=4 et:
