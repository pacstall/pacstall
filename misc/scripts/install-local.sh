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

function cleanup () {
	sudo rm -rf "${SRCDIR:?}"/*
	sudo rm -rf /tmp/pacstall/*
	if [ -f /tmp/pacstall-optdepends ]; then
		sudo rm /tmp/pacstall-optdepends
	fi
}

function trap_ctrlc () {
	echo ""
	fancy_message warn "Interupted, cleaning up"
	cleanup
	exit 1
}

# run checks to verify script works
function checks() {
	# curl url to check it exists
	if curl --output /dev/null --silent --head --fail "$url" > /dev/null; then
		fancy_message info "URL exists"
	else
		fancy_message error "URL doesn't exist"
		return 1
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

# Logging metadata
function log() {

	# Origin repo info parsing
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

	echo "]===== This is what pacstall logged =====[" | tee -a "$LOGFILE" > /dev/null
	# Metadata writing
	echo "_version=\"$version"\" | sudo tee "$LOGDIR"/"$PACKAGE" "$LOGFILE" > /dev/null
	echo "_description=\"$description"\" | sudo tee -a "$LOGDIR"/"$PACKAGE" "$LOGFILE" > /dev/null
	echo "_date=\"$(date)"\" | sudo tee -a "$LOGDIR"/"$PACKAGE" "$LOGFILE" > /dev/null
	echo "_maintainer=\"$maintainer"\" | sudo tee -a "$LOGDIR"/"$PACKAGE" "$LOGFILE" > /dev/null
	if [[ -n $depends ]]; then
		echo "_dependencies=\"$depends"\" | sudo tee -a "$LOGDIR"/"$PACKAGE" "$LOGFILE" > /dev/null
	fi
	if [[ -n $build_depends ]]; then
		echo "_build_dependencies=\"$build_depends"\" | sudo tee -a "$LOGDIR"/"$PACKAGE" "$LOGFILE" > /dev/null
	fi
	if [[ -n $pacdeps ]]; then
		echo "_pacdeps=\"$pacdeps"\" | sudo tee -a "$LOGDIR"/"$PACKAGE" "$LOGFILE" > /dev/null
	fi
	if [[ -n $ppa ]]; then
		echo "_ppa=\"$ppa"\" | sudo tee -a "$LOGDIR"/"$PACKAGE" "$LOGFILE" > /dev/null
	fi
	if test -f /tmp/pacstall-pacdeps-"$PACKAGE"; then
		echo "_pacstall_depends=\"true"\" | sudo tee -a "$LOGDIR"/"$PACKAGE" "$LOGFILE" > /dev/null
	fi
	if [[ $local == 'no' ]]; then
		echo  "_remoterepo=\"$pURL"\" | sudo tee -a "$LOGDIR"/"$PACKAGE" "$LOGFILE" > /dev/null
		if [[ $branch == 'yes' ]]; then
			echo  "_remotebranch=\"$pBRANCH"\" | sudo tee -a "$LOGDIR"/"$PACKAGE" "$LOGFILE" > /dev/null
		fi
	fi
}

ask "Do you want to view the pacscript first" N
if [[ $answer -eq 1 ]]; then
	less "$PACKAGE".pacscript
fi

ask "Do you want to edit the pacscript" N
if [[ $answer -eq 1 ]]; then
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
if [[ $? -ne 0 ]]; then
	fancy_message error "Couldn't source pacscript"
	error_log 12 "install $PACKAGE"
	return 1
fi

# export all variables from pacscript (fakeroot), and redirect to /dev/null in case of errors (because obviously no pacscript will contain every single available option)
export {name,version,url,build_depends,depends,replace,description,hash,maintainer,optdepends,ppa,pacdeps,patch} > /dev/null 2>&1
# Do the same for functions
export -f {prepare,build,install,postinst,removescript} > /dev/null 2>&1

if type pkgver > /dev/null 2>&1; then
	version=$(pkgver) > /dev/null
fi

# Run checks function
checks
if [[ $? -ne 0 ]]; then
	fancy_message error "There was an error checking the script!"
	error_log 6 "install $PACKAGE"
	return 1
fi

if [[ -n "$build_depends" ]]; then
	fancy_message info "${BLUE}$name${NC} requires ${CYAN}$(echo -e "$build_depends")${NC} to install"
	ask "Do you want to remove them after installing ${BLUE}$name${NC}" N
	if [[ $answer -eq 1 ]]; then
		NOBUILDDEP=0
	fi
else
	NOBUILDDEP=1
fi

# Trap Crtl+C just before the point cleanup is first needed
trap "trap_ctrlc" 2


if [[ -n "$pacdeps" ]]; then
	for i in "${pacdeps[@]}"; do
		fancy_message info "Installing $i"
		# If /tmp/pacstall-pacdeps-"$i" is available, it will trigger the logger to log it as a dependency
		sudo touch /tmp/pacstall-pacdeps-"$i"
		pacstall -P -I "$i"
	done
fi

if echo -n "$depends" > /dev/null 2>&1; then
	if [[ -n "$breaks" ]]; then
		if dpkg-query -l "$breaks" > /dev/null 2>&1; then
			# Check if anything in breaks variable is installed already
			fancy_message error "${RED}$name${NC} breaks $breaks, which is currently installed by apt"
			error_log 13 "install $PACKAGE"
			return 1
		fi
		if [[ $(pacstall -L) == *$breaks* ]]; then
			# Same thing, but check if anything is installed with pacstall
			fancy_message error "${RED}$name${NC} breaks $breaks, which is currently installed by pacstall"
			error_log 13 "install $PACKAGE"
			return 1
		fi
	fi
fi

if [[ -n $replace ]]; then
	# Ask user if they want to replace the program
	if dpkg-query -W -f='${Status}' $replace 2> /dev/null | grep -q "ok installed" ; then
		ask "This script replaces $replace. Do you want to proceed" N
		if [[ $answer -eq 0 ]]; then
			return 1
		fi
		sudo apt-get remove -y $replace
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
		error_log 8 "install $PACKAGE"
		return 1
	fi
fi

function hashcheck() {
	inputHash=$hash
	# Get hash of file
	fileHash=($(sha256sum "$1" | sed 's/\s.*$//'))

	if [[ "$inputHash" != "$fileHash" ]]; then
		# We bad
		fancy_message error "Hashes don't match"
		error_log 16 "install $PACKAGE"
		return 1
	fi
	true
}

fancy_message info "Installing dependencies"
sudo apt-get install -y -qq -o=Dpkg::Use-Pty=0 $depends 2>&1 | tee -a "$LOGFILE"
if [[ $? -ne 0 ]]; then
	fancy_message error "Failed to install dependencies"
	error_log 8 "install $PACKAGE"
	return 1
fi

# If optdepends exists do this
if [[ -n $optdepends ]]; then
	sudo rm -f /tmp/pacstall-optdepends

	fancy_message info "$name has optional dependencies that can enhance its functionalities"
	echo "Optional dependencies:"
	printf '    %s\n' "${optdepends[@]}"
	ask "Do you want to install them" Y
	if [[ $answer -eq 1 ]]; then
		for items in "${optdepends[*]}"; do
			# output the name of the apt thing without the description, EI: `foo: not bar` -> `foo`
			printf "%s\n" "${optdepends[@]}" | awk -F': ' '{print $1}' | tr '\n' ' ' >> /tmp/pacstall-optdepends
			# Install
			sudo apt-get install -y -qq $(cat /tmp/pacstall-optdepends)
		done
	fi
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
		sudo chown -R "$LOGNAME":"$LOGNAME" . 2>/dev/null
		# Check the integrity
		git fsck --full
	;;
	*.zip)
		download "$url"
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
		download "$url"
		hashcheck "${url##*/}"
		sudo apt install -y -f ./"${url##*/}" 2>/dev/null
		if [[ $? -eq 0 ]]; then
			log

			fancy_message info "Storing pacscript"
			sudo mkdir -p /var/cache/pacstall/"$PACKAGE"/"$version"
			cd "$DIR"
			sudo cp -r "$PACKAGE".pacscript /var/cache/pacstall/"$PACKAGE"/"$version"

			cleanup
			return 0

		else
			fancy_message error "Failed to install the package"
			error_log 14 "install $PACKAGE"
			return 1
		fi
	;;
	*)
		download "$url"
		# I think you get it by now
		hashcheck "${url##*/}"
		sudo tar -xf "${url##*/}" 1>&1 2>/dev/null
		cd ./*/ 2>/dev/null
		export srcdir="/tmp/pacstall/$PWD"
		sudo chown -R "$(logname)":"$(logname)" . 2>/dev/null
	;;
esac

if [[ -n $patch ]]; then
		fancy_message info "Downloading patches"
		mkdir -p PACSTALL_patchesdir
	for i in "${patch[@]}"; do
		wget -q "$i" -P PACSTALL_patchesdir &
	done
	wait
	export PACPATCH=$(pwd)/PACSTALL_patchesdir
fi

export pkgdir="/usr/src/pacstall/$name"

# fakeroot is weird but this method works
# create tmp variable that is the output of what prepare function is (it prints out function)
if ! command -v fakeroot > /dev/null; then
	sudo apt-get install fakeroot -y
fi
tmp_prepare=$(declare -f prepare)
# We run fakeroot, BUT, we don't actually pass any variables through to fakeroot. In other words, bash works with the tmp_prepare, instead of fakeroot
fancy_message info "Running prepare in fakeroot. Do not enter password if prompted"
echo "]===== running prepare function =====[" | tee -a "$LOGFILE" > /dev/null
fakeroot -- bash -c "$tmp_prepare; prepare" 2>&1 | tee -a "$LOGFILE"
# Unset because it's a tmp variable
unset tmp_prepare

# Check if build function doesn't exist
if ! type -t build > /dev/null 2>&1; then
	fancy_message error "Something didn't compile right"
	error_log 5 "install $PACKAGE"
	return 1
fi

if ! command -v fakeroot > /dev/null; then
	sudo apt-get install fakeroot -y
fi
tmp_build=$(declare -f build)
fancy_message info "Running build in fakeroot. Do not enter password if prompted"
echo "]===== running build function =====[" | tee -a "$LOGFILE" > /dev/null
fakeroot -- bash -c "$tmp_build; build" 2>&1 | tee -a "$LOGFILE"
unset tmp_build

# Trap so that we can clean up (hopefully without messing up anything)
trap - SIGINT

fancy_message info "Installing"
echo "]===== running install function =====[" | tee -a "$LOGFILE" > /dev/null
install 2>&1 | tee -a "$LOGFILE"

if [[ $REMOVE_DEPENDS = y ]]; then
	sudo apt-get remove $build_depends
fi

sudo rm -rf "${SRCDIR:?}"/*
cd "$HOME"

# Metadata writing
log

fancy_message info "Symlinking files"
cd /usr/src/pacstall/ || sudo mkdir -p /usr/src/pacstall && cd /usr/src/pacstall
# By default (I think), stow symlinks to the directory behind it (..), but we want to symlink to /, or in other words, symlink files from pkg/usr to /usr
if ! command -v stow > /dev/null; then
	# If stow failed to install, install it
	sudo apt-get install stow -y
fi

# Magic time. This installs the package to /, so `/usr/src/pacstall/foo/usr/bin/foo` -> `/usr/bin/foo`
echo "]===== stowing =====[" | tee -a "$LOGFILE" > /dev/null
sudo stow --target="/" "$PACKAGE" 2>&1 | tee -a "$LOGFILE"
# stow will fail to symlink packages if files already exist on the system; this is just an error
if [[ $? -ne 0	 ]]; then
	fancy_message error "Package contains links to files that exist on the system"
	error_log 14 "install $PACKAGE"
	return 1
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

fancy_message info "Cleaning up"
echo "]===== cleaning up =====[" | tee -a "$LOGFILE" > /dev/null
cleanup 2>&1 | tee -a "$LOGFILE"

return 0

# vim:set ft=sh ts=4 sw=4 noet:
