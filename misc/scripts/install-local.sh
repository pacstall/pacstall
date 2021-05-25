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

function trap_ctrlc () {
    echo ""
    fancy_message warn "Interupted, cleaning up"
    rm -rf /tmp/pacstall/*
    if [ -f /tmp/pacstall-optdepends ]; then
        rm /tmp/pacstall-optdepends
    fi
    exit 2
}

trap "trap_ctrlc" 2

# run checks to verify script works
checks() {
# curl url to check it exists
if curl --output /dev/null --silent --head --fail "$url" >/dev/null; then
    fancy_message info "URL exists"
else
	fancy_message error "URL doesn't exist"
	exit 6
fi
if [[ -z "$hash" ]]; then
    fancy_message warn "Package does not contain a hash"
fi
}

cget() {
    URL="$1"
    BRANCH="$2"
    # If BRANCH was not specified, default to master
    if [[ -n $BRANCH ]]; then
        BRANCH=master
    fi
    git ls-remote "$URL" "$BRANCH" | sed "s/refs\/heads\/.*//"
}

if ask "Do you want to view the pacscript first" N; then
    less "$PACKAGE".pacscript
fi
if ask "Do you want to edit the pacscript" N; then
    if [[ -n $PACSTALL_EDITOR ]]; then
        $PACSTALL_EDITOR "$PACKAGE".pacscript
    elif [[ -n $EDITOR ]]; then
        $EDITOR "$PACKAGE".pacscript
    elif [[ -n $VISUAL ]]; then
        $VISUAL "$PACKAGE".pacscript
    else
        nano "$PACKAGE".pacscript
    fi
fi
fancy_message info "Sourcing pacscript"
DIR=$(pwd)
source "$PACKAGE".pacscript >/dev/null
if [[ $? -eq 1 ]]; then
    fancy_message error "Couldn't parse pacscript"
    exit 12
fi

if type pkgver >/dev/null 2>&1; then
    version=$(pkgver) >/dev/null
fi

fancy_message info "Running checks"
checks
if [[ $? -eq 1 ]] ; then
    fancy_message error "There was an error checking the script!"
    exit 1
fi

if [[ -n "$build_depends" ]]; then
    fancy_message info "${BLUE}$name${NC} requires ${CYAN}$(echo -e "$build_depends")${NC} to install"
    if ask "Do you want to remove them after installing ${BLUE}$name${NC}" N; then
        NOBUILDDEP=0
	fi
    else
        NOBUILDDEP=1
    fi

if [[ -n "$pacdeps" ]]; then
    for i in "${pacdeps[@]}"
    do
        fancy_message info "Installing $i"
        sudo pacstall -P -I "$i"
    done
fi

if echo -n "$depends" > /dev/null 2>&1; then
    if [[ -n "$breaks" ]]; then
        if dpkg-query -l "$breaks" >/dev/null 2>&1; then
            fancy_message error "${RED}$name${NC} breaks $breaks, which is currently installed by apt"
            exit 1
        fi
    fi
    if [[ -n "$breaks" ]] ; then
        if [[ $(pacstall -L) == *$breaks* ]] ; then
            fancy_message error "${RED}$name${NC} breaks $breaks, which is currently installed by pacstall"
            exit 1
        fi
    fi
fi
if ! [[ -z $replace ]] ; then
    dpkg-query -W -f='${Status}' $replace 2>/dev/null | grep -q "ok installed"
    if [[ $? -eq 1 ]] ; then
        if ask "This script replaces $replace. Do you want to proceed" N; then
            sudo apt-get remove -y $replace
        else
            exit 1
        fi
    fi
fi

if [[ -n "$ppa" ]]; then
  for i in "${ppa[@]}"; do
      sudo add-apt-repository ppa:"$i"
  done
fi

if [[ $NOBUILDDEP -eq 0 ]] ; then
    if ! sudo apt-get install -y -qq -o=Dpkg::Use-Pty=0 $build_depends; then
        fancy_message error "Failed to install build dependencies"
        exit 8
    fi
fi
hashcheck() {
    inputHash=$hash
    fileHash=($(sha256sum "$1" | sed 's/\s.*$//'))

    if [ "$inputHash" = "$fileHash" ]; then
        true
    else
        fancy_message error "Hashes don't match"
        exit 1
    fi
}
fancy_message info "Installing dependencies"
sudo apt-get install -y -qq -o=Dpkg::Use-Pty=0 $depends
if [[ $? -eq 1 ]]; then
    fancy_message error "Failed to install dependencies"
    exit 8
fi

fancy_message info "Retrieving packages"
mkdir -p /tmp/pacstall
cd /tmp/pacstall

# Detects if url ends in .git (in that case git clone it), or ends in .zip, or just assume that the url can be uncompressed with tar. Then cd into them
if [[ $url = *.git ]] ; then
  git clone --quiet --depth=1 --jobs=10 "$url"
  cd $(/bin/ls -d -- */|head -n 1)
  git fsck --full
else
  wget -q --show-progress --progress=bar:force "$url" 2>&1
  if [[ $url = *.zip ]] ; then
    hashcheck "${url##*/}"
    unzip -q "${url##*/}" 1>&1
    cd $(/bin/ls -d -- */|head -n 1)
  else
    hashcheck "${url##*/}"
    tar -xf "${url##*/}" 1>&1
    cd $(/bin/ls -d -- */|head -n 1)
  fi
fi

if [[ -n $patch ]] ; then
  for i in "${patch[@]}"; do
    fancy_message info "Downloading patches"
    mkdir -p PACSTALL_patchesdir
    wget -q "$i" -P PACSTALL_patchesdir
  done
export PACPATCH=$(pwd)/PACSTALL_patchesdir
fi

prepare
# Check if build function exists
if type -t build >/dev/null 2>&1; then
  build
else
  fancy_message error "Something didn't compile right"
  exit 5
fi
trap - SIGINT
fancy_message info "Installing"
install
if [[ $REMOVE_DEPENDS = y ]] ; then
  sudo apt-get remove $build_depends
fi
sudo rm -rf /tmp/pacstall/*
cd "$HOME"

# Metadata writing
echo "version=\"$version"\" | sudo tee /var/log/pacstall_installed/"$PACKAGE" >/dev/null
echo "description=\"$description"\" | sudo tee -a /var/log/pacstall_installed/"$PACKAGE" >/dev/null
echo "date=\"$(date)"\" | sudo tee -a /var/log/pacstall_installed/"$PACKAGE" >/dev/null
if [[ $removescript == "yes" ]] ; then
   echo "removescript=\"yes"\" | sudo tee -a /var/log/pacstall_installed/"$PACKAGE" >/dev/null
fi
echo "maintainer=\"$maintainer"\" | sudo tee -a /var/log/pacstall_installed/"$PACKAGE" >/dev/null
echo "dependencies=\"$depends"\" | sudo tee -a /var/log/pacstall_installed/"$PACKAGE" >/dev/null

# If optdepends exists do this
if [[ -n $optdepends ]] ; then
    sudo rm -f /tmp/pacstall-optdepends
    fancy_message info "Package has some optional dependencies that can enhance it's functionalities"
    echo "Optional dependencies:"
    printf '    %s\n' "${optdepends[@]}"
    if ask "Do you want to install them" Y; then
        for items in "${optdepends[*]}"; do
            printf "%s\n" "$items" | cut -d: -f1 | tr '\n' ' ' | cut -d% -f1 >> /tmp/pacstall-optdepends
            sudo apt-get install -y -qq -o=Dpkg::Use-Pty=0 $(cat /tmp/pacstall-optdepends)
        done
    fi
fi
fancy_message info "Symlinking files"
cd /usr/src/pacstall/ || sudo mkdir -p /usr/src/pacstall && cd /usr/src/pacstall
# By default (I think), stow symlinks to the directory behind it (..), but we want to symlink to /, or in other words, symlink files from pkg/usr to /usr
sudo stow --target="/" "$PACKAGE"
# stow will fail to symlink packages if files already exist on the system; this is just an error
if [[ $? -eq 1 ]]; then
    fancy_message error "Package contains links to files that exist on the system"
    exit 14
fi
hash -r
type -t postinst >/dev/null 2>&1
if [[ $? -eq 0 ]] ; then
   postinst
fi
fancy_message info "Storing pacscript"
sudo mkdir -p /var/cache/pacstall/$PACKAGE/$version
cd $DIR
sudo cp -r "$PACKAGE".pacscript /var/cache/pacstall/$PACKAGE/$version
