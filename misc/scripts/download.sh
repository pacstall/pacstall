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

# This script downloads pacscripts from the interwebs

download() {
mkdir -p "$HOME"/.cache/pacstall/
cd "$HOME"/.cache/pacstall/
mkdir -p "$PACKAGE"
cd "$PACKAGE"
wget -q --show-progress --progress=bar:force "$URL" -O "$PACKAGE".pacscript 2>&1
if [[ $INSTALLING -eq 1 ]] ; then
    source /usr/share/pacstall/scripts/install-local.sh
    exit
fi
fancy_message info "Your script is in ${GREEN}$HOME/.cache/pacstall/$PACKAGE${NC}"
fancy_message info "cd into it and run sudo pacstall -Il <pkg> to install it"
}
URL="$REPO/packages/$PACKAGE/$PACKAGE.pacscript"
wget -q --tries=10 --timeout=20 --spider https://github.com 
if [[ $? -eq 1 ]]; then
    fancy_message error "Not connected to internet"
    exit 6
fi
if curl --output /dev/null --silent --head --fail "$URL" ; then
  download
else
  fancy_message warn "The file you want to download does not exist"
  exit 6
fi
