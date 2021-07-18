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
  sudo rm -rf /tmp/pacstall/*
  if [ -f /tmp/pacstall-optdepends ]; then
    sudo rm /tmp/pacstall-optdepends
  fi
  exit 2
}

trap "trap_ctrlc" 2

# run checks to verify script works
function checks() {
  # curl url to check it exists
  if curl --output /dev/null --silent --head --fail "$url" > /dev/null; then
    fancy_message info "URL exists"
  else
      fancy_message error "URL doesn't exist"
      exit 6
  fi

  if [[ -z "$hash" ]]; then
    fancy_message warn "Package does not contain a hash"
  fi
}

function cget() {
  URL="$1"
  BRANCH="$2"
  # If BRANCH was not specified, default to master
  if [[ -n $BRANCH ]]; then
    BRANCH=master
  fi
  git ls-remote "$URL" "$BRANCH" | sed "s/refs\/heads\/.*//"
}

# logging metadata
function loggingMeta() {
# Metadata writing
  echo "_version=\"$version"\" | sudo tee "$LOGDIR"/"$PACKAGE" > /dev/null
  echo "_description=\"$description"\" | sudo tee -a "$LOGDIR"/"$PACKAGE" > /dev/null
  echo "_date=\"$(date)"\" | sudo tee -a "$LOGDIR"/"$PACKAGE" > /dev/null
  echo "_maintainer=\"$maintainer"\" | sudo tee -a "$LOGDIR"/"$PACKAGE" > /dev/null
  if [[ -n $depends ]]; then
    echo "_dependencies=\"$depends"\" | sudo tee -a "$LOGDIR"/"$PACKAGE" > /dev/null
  fi
  if [[ -n $build_depends ]]; then
    echo "_build_dependencies=\"$build_depends"\" | sudo tee -a "$LOGDIR"/"$PACKAGE" > /dev/null
  fi
  if [[ -n $pacdeps ]]; then
    echo "_pacdeps=\"$pacdeps"\" | sudo tee -a "$LOGDIR"/"$PACKAGE" > /dev/null
  fi
  if [[ -n $ppa ]]; then
    echo "_ppa=\"$ppa"\" | sudo tee -a "$LOGDIR"/"$PACKAGE" > /dev/null
  fi
  if test -f /tmp/pacstall-pacdeps-"$PACKAGE"; then
    echo "_pacstall_depends=\"true"\" | sudo tee -a "$LOGDIR"/"$PACKAGE" > /dev/null
  fi
  if [[ $local == 'no' ]]; then
    echo  "_remoterepo=\"$pURL"\" | sudo tee -a "$LOGDIR"/"$PACKAGE" > /dev/null
    if [[ $branch == 'yes' ]]; then
      echo  "_remotebranch=\"$pBRANCH"\" | sudo tee -a "$LOGDIR"/"$PACKAGE" > /dev/null
    fi
  fi
}



function aria2 {
fancy_message info "Downloading the package"
if which aria2c >/dev/null; then
aria2c --download-result=hide -q -o "${url##*/}" "$url"
else
sudo wget -q --show-progress --progress=bar:force "$url" 2>&1
fi
}

if [[ $local == 'no' ]]; then
  if echo "$REPO" | grep "github" > /dev/null ; then
    pURL="${REPO/'raw.githubusercontent.com'/'github.com'}" 
    pURL="${pURL%/*}"
    pBRANCH="${REPO##*/}"
    branch="yes"
  elif echo "$REPO"| grep "gitlab" > /dev/null; then
    pURL="${REPO%/-/raw/*}"
    pBRANCH="${REPO##*/-/raw/}"
    branch="yes"
  else
    pURL=$REPO
    branch="no"
  fi
fi

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
    sensible-editor "$PACKAGE".pacscript
  fi
fi

fancy_message info "Sourcing pacscript"
DIR=$(pwd)
export homedir="/home/$(logname)"
source "$PACKAGE".pacscript > /dev/null
if [[ $? -eq 1 ]]; then
  fancy_message error "Couldn't source pacscript"
  exit 12
fi

if type pkgver > /dev/null 2>&1; then
  version=$(pkgver) > /dev/null
fi

# Run checks function
checks
if [[ $? -eq 1 ]]; then
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
  for i in "${pacdeps[@]}"; do
    fancy_message info "Installing $i"
    # If /tmp/pacstall-pacdeps-"$i" is available, it will trigger the logger to log it as a dependency
    sudo touch /tmp/pacstall-pacdeps-"$i"
    sudo pacstall -P -I "$i"
    sudo rm -f /tmp/pacstall-pacdeps-"$i"
  done
fi

if echo -n "$depends" > /dev/null 2>&1; then
  if [[ -n "$breaks" ]]; then
    if dpkg-query -l "$breaks" > /dev/null 2>&1; then
      # Check if anything in breaks variable is installed already
      fancy_message error "${RED}$name${NC} breaks $breaks, which is currently installed by apt"
      exit 1
    fi
  fi

  if [[ -n "$breaks" ]]; then
    if [[ $(pacstall -L) == *$breaks* ]]; then
      # Same thing, but check if anything is installed with pacstall
      fancy_message error "${RED}$name${NC} breaks $breaks, which is currently installed by pacstall"
      exit 1
    fi
  fi
fi

if [[ -n $replace ]]; then
  # Ask user if they want to replace the program
  if dpkg-query -W -f='${Status}' $replace 2> /dev/null | grep -q "ok installed" ; then
    if ask "This script replaces $replace. Do you want to proceed" N; then
      sudo apt-get remove -y $replace
    else
      exit 1
    fi
  fi
fi

if [[ -n "$ppa" ]]; then
  for i in "${ppa[@]}"; do
    # Add ppa, but ppa bad I guess
    sudo add-apt-repository ppa:"$i"
  done
fi

if [[ $NOBUILDDEP -eq 0 ]]; then
  if ! sudo apt-get install -y -qq -o=Dpkg::Use-Pty=0 $build_depends; then
    fancy_message error "Failed to install build dependencies"
    exit 8
  fi
fi

function hashcheck() {
  inputHash=$hash
  # Get hash of file
  fileHash=($(sha256sum "$1" | sed 's/\s.*$//'))

  if [ "$inputHash" = "$fileHash" ]; then
    # If hash equals hash, we good
    true
  else
    # We bad
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
mkdir -p "$SRCDIR"
cd "$SRCDIR"

case "$url" in
    *.git)
        # git clone quietly, with no history, and if submodules are there, download with 10 jobs
          sudo git clone --quiet --depth=1 --jobs=10 "$url"
        # cd into the directory
        cd ./*/
        # The srcdir is /tmp/pacstall/foo
        export srcdir="/tmp/pacstall/$PWD"
        # Make the directory available for users
        sudo chown -R "$(logname)":"$(logname)" . 2>/dev/null
        # Check the integrity
        git fsck --full
        ;;
    *.zip)
        aria2
        # hash the file
        hashcheck "${url##*/}"
        # unzip file
        sudo unzip -q "${url##*/}" 1>&1 2>/dev/null
        # cd into it
        cd ./*/
        # export srcdir
        export srcdir="/tmp/pacstall/$PWD"
        # Make the directory available for users
        sudo chown -R "$(logname)":"$(logname)" . 2>/dev/null
        ;;
    *.deb)
        aria2
        hashcheck "${url##*/}"    
        sudo apt install -y -f ./"${url##*/}" 2>/dev/null
        if [[ $? -eq 0 ]]; then
            loggingMeta
            exit 0
        else
            fancy_message error "Failed to install the package"
            exit 1
        fi
        ;;
    *)
        aria2
        # I think you get it by now
        hashcheck "${url##*/}"
        sudo tar -xf "${url##*/}" 1>&1 2>/dev/null
        cd ./*/ 2>/dev/null
        export srcdir="/tmp/pacstall/$PWD"
        sudo chown -R "$(logname)":"$(logname)" . 2>/dev/null
        ;;
esac

if [[ -n $patch ]]; then
  for i in "${patch[@]}"; do
    fancy_message info "Downloading patches"
    mkdir -p PACSTALL_patchesdir
    wget -q "$i" -P PACSTALL_patchesdir
  done

  export PACPATCH=$(pwd)/PACSTALL_patchesdir
fi

export pkgdir="/usr/src/pacstall/$name"
prepare

# Check if build function exists
if type -t build > /dev/null 2>&1; then
  build
else
  fancy_message error "Something didn't compile right"
  exit 5
fi
trap - SIGINT

fancy_message info "Installing"
install

if [[ $REMOVE_DEPENDS = y ]]; then
  sudo apt-get remove $build_depends
fi

sudo rm -rf "${SRCDIR:?}"/*
cd "$HOME"

# Metadata writing
loggingMeta

# If optdepends exists do this
if [[ -n $optdepends ]]; then
  sudo rm -f /tmp/pacstall-optdepends

  fancy_message info "$name has optional dependencies that can enhance its functionalities"
  echo "Optional dependencies:"
  printf '    %s\n' "${optdepends[@]}"
  if ask "Do you want to install them" Y; then
    for items in "${optdepends[*]}"; do
        # output the name of the apt thing without the description, EI: `foo: not bar` -> `foo`
        printf "%s\n" "${optdepends[@]}" | cut -f1 -d":" | tr '\n' ' ' >> /tmp/pacstall-optdepends
        # Install
        sudo apt-get install -y -qq $(cat /tmp/pacstall-optdepends)
    done
  fi
fi

fancy_message info "Symlinking files"
cd /usr/src/pacstall/ || sudo mkdir -p /usr/src/pacstall && cd /usr/src/pacstall
# By default (I think), stow symlinks to the directory behind it (..), but we want to symlink to /, or in other words, symlink files from pkg/usr to /usr
if ! command -v stow > /dev/null; then
  # If stow failed to install, install it
  sudo apt-get install stow -y
fi

# Magic time. This installs the package to /, so `/usr/src/pacstall/foo/usr/bin/foo` -> `/usr/bin/foo`
sudo stow --target="/" "$PACKAGE"
# stow will fail to symlink packages if files already exist on the system; this is just an error
if [[ $? -eq 1 ]]; then
  fancy_message error "Package contains links to files that exist on the system"
  exit 14
fi

# `hash -r` updates PATH database
hash -r
type -t postinst > /dev/null 2>&1
if [[ $? -eq 0 ]]; then
  postinst
fi

fancy_message info "Storing pacscript"
sudo mkdir -p /var/cache/pacstall/"$PACKAGE"/"$version"
cd "$DIR"
sudo cp -r "$PACKAGE".pacscript /var/cache/pacstall/"$PACKAGE"/"$version"
