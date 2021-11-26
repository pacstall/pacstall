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
	if [[ -z ${KEEP+x} ]]; then
		if [[ -f /tmp/pacstall-pacdeps-"$PACKAGE" ]]; then
			sudo rm -rf /tmp/pacstall-pacdeps-"$PACKAGE"
			sudo rm -rf /tmp/pacstall-pacdep
		else
			sudo rm -rf "${SRCDIR:?}"/*
			sudo rm -rf /tmp/pacstall/*
		fi
		if [[ -f /tmp/pacstall-optdepends ]]; then
			sudo rm /tmp/pacstall-optdepends
		fi
	fi
	unset name version url build_depends depends breaks replace description hash removescript optdepends ppa maintainer pacdeps patch PACPATCH NOBUILDDEP optinstall 2>/dev/null
	unset -f pkgver 2>/dev/null
}

function trap_ctrlc () {
	echo ""
	fancy_message warn "Interupted, cleaning up"
	if dpkg-query -W -f='${Status}' "$name" 2> /dev/null | grep -q -E "ok installed|ok unpacked" ; then
		sudo dpkg -r --force-all "$name" > /dev/null
	fi
	cleanup
	exit 1
}

# run checks to verify script works
function checks() {

	if [[ -z "$name" ]]; then
		fancy_message error "Package does not contain name"
		exit 1
	fi
	if [[ -z "$hash" && "$name" != *-git ]]; then
		fancy_message warn "Package does not contain a hash"
	fi
	if [[ -z "$version" ]]; then
		fancy_message error "Package does not contain version"
		exit 1
	fi
	if [[ -z "$url" ]]; then
		fancy_message error "Package does not contain URL"
		exit 1
	fi
	if [[ -z "$maintainer" ]]; then
		fancy_message warn "Package does not have a maintainer"
		fancy_message warn "It maybe no longer maintained. Please be advised."
	fi
	# curl url to check it exists
	if curl --output /dev/null --silent --head --fail "$url" > /dev/null; then
		fancy_message info "URL exists"
	else
		fancy_message error "URL doesn't exist"
		return 1
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

	# Metadata writing
	if [[ -n ${gives} ]]; then
		echo "_gives=\"${gives}"\" | sudo tee "$LOGDIR"/"$PACKAGE" > /dev/null
	fi
	echo "_version=\"$version"\" | sudo tee -a "$LOGDIR"/"$PACKAGE" > /dev/null
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


function makeVirtualDeb {
	# creates empty .deb package (with only the control file) for apt integration
	# implements $(gives) variable
	fancy_message info "Creating dummy package"
	sudo mkdir -p "$SRCDIR/$name-pacstall/DEBIAN"
	printf "Package: %s\n" "$name" | sudo tee "$SRCDIR/$name-pacstall/DEBIAN/control" > /dev/null

	if [[ $version =~ ^[0-9] ]]; then
		printf "Version: %s-1\n" "$version" | sudo tee -a "$SRCDIR/$name-pacstall/DEBIAN/control" > /dev/null
	else
		printf "Version: 0%s-1\n" "$version" | sudo tee -a "$SRCDIR/$name-pacstall/DEBIAN/control" > /dev/null
	fi

	if [[ -n $depends ]]; then
		printf "Depends: %s\n" "${depends//' '/' , '}"| sudo tee -a "$SRCDIR/$name-pacstall/DEBIAN/control" > /dev/null
	fi

	if [[ -n $optdepends ]]; then
		fancy_message info "$name has optional dependencies that can enhance its functionalities"
		echo "Optional dependencies:"
		printf '    %s\n' "${optdepends[@]}"
		ask "Do you want to install them" Y
		if [[ $answer -eq 1 ]]; then
			optinstall='--install-suggests'
		fi

		printf "Suggests:" |sudo tee -a "$SRCDIR/$name-pacstall/DEBIAN/control" > /dev/null
		printf " %s\n" "${optdepends[@]}" | awk -F': ' '{print $1}' | tr '\n' ',' | head -c -2 | sudo tee -a "$SRCDIR/$name-pacstall/DEBIAN/control" > /dev/null
		printf "\n" | sudo tee -a "$SRCDIR/$name-pacstall/DEBIAN/control" > /dev/null
	fi

	printf "Architecture: all
Essential: no
Section: Pacstall
Priority: optional\n" | sudo tee -a "$SRCDIR/$name-pacstall/DEBIAN/control" > /dev/null

	if [[ -n $replace ]]; then
		echo -e "Conflicts: ${replace//' '/', '}
Replace: ${replace//' '/', '}" | sudo tee -a "$SRCDIR/$name-pacstall/DEBIAN/control" > /dev/null
	fi

	printf "Provides: ${gives:-$name}
Maintainer: ${maintainer:-Pacstall <pacstall@pm.me>}
Description: This is a symbolic package used by pacstall, may be removed with apt or dpkg. $description\n" | sudo tee -a "$SRCDIR/$name-pacstall/DEBIAN/control" > /dev/null

	echo '#!/usr/bin/env bash
function ask() {
	local default reply
	if [[ ${2:-} = "Y" ]]; then
		echo -ne "$1 [Y/n] "
		default="Y"
	elif [[ ${2:-} = "N" ]]; then
		echo -ne "$1 [y/N] "
	fi
	default=${2:-}
	read -r reply <&0
	if [[ -z $reply ]]; then
		reply=$default
	fi
	case "$reply" in
		Y*|y*) export answer=1; return 0;;
		N*|n*) export answer=0; return 1;;
	esac
}
if [[ -z $PACSTALL_REMOVE ]] && [[ -z $PACSTALL_INSTALL ]]; then
	export -f ask
	source /var/cache/pacstall/'"$name"'/'"$version"'/'"$name"'.pacscript 2>&1 /dev/null
	sudo mkdir -p '"$STOWDIR"'
	cd '"$STOWDIR"'
	stow --target="/" -D '"$name"' 2> /dev/null
	rm -rf '"$name"' 2> /dev/null
	hash -r
	if declare -F removescript >/dev/null ; then
		removescript
	fi
	rm -f '"$LOGDIR"'/'"$name"'
else unset PACSTALL_REMOVE
fi' | sudo tee "$SRCDIR/$name-pacstall/DEBIAN/postrm" >"/dev/null"

	sudo chmod -x "$SRCDIR/$name-pacstall/DEBIAN/postrm"
	sudo chmod 755 "$SRCDIR/$name-pacstall/DEBIAN/postrm"

	if ! sudo dpkg-deb -b "$SRCDIR/$name-pacstall" > "/dev/null"; then
		fancy_message error "Could not create dummy package"
		error_log 5 "install $PACKAGE"
		fancy_message info "Cleaning up"
		cleanup
		return 1
	fi
	export PACSTALL_INSTALL=1
	sudo rm -rf "$SRCDIR/$name-pacstall"
	sudo --preserve-env=PACSTALL_INSTALL dpkg -i "$SRCDIR/$name-pacstall.deb" 2> "/dev/null"


	fancy_message info "Installing dependencies"
	if ! sudo --preserve-env=PACSTALL_INSTALL apt-get install $optinstall -f -y -qq -o=Dpkg::Use-Pty=0; then
		fancy_message error "Failed to install dependencies"
		error_log 8 "install $PACKAGE"
		sudo dpkg -r --force-all "$name" > /dev/null
		fancy_message info "Cleaning up"
		cleanup
		return 1
	fi
	sudo --preserve-env=PACSTALL_INSTALL dpkg -i "$SRCDIR/$name-pacstall.deb" > "/dev/null"
	sudo rm "$SRCDIR/$name-pacstall.deb"
	unset PACSTALL_INSTALL
	return 0
}

ask "Do you want to view/edit the pacscript" N
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

if [[ $(logname 2>/dev/null) ]]; then
    LOGNAME=$(logname)
fi

fancy_message info "Sourcing pacscript"
DIR=$(pwd)
export homedir="/home/$LOGNAME"
if ! source "$PACKAGE".pacscript > /dev/null; then
	fancy_message error "Could not source pacscript"
	error_log 12 "install $PACKAGE"
	fancy_message info "Cleaning up"
	cleanup
	return 1
fi

if type pkgver > /dev/null 2>&1; then
	version=$(pkgver) > /dev/null
fi

# Run checks function
if ! checks; then
	fancy_message error "There was an error checking the script!"
	error_log 6 "install $PACKAGE"
	fancy_message info "Cleaning up"
	cleanup
	return 1
fi

# Trap Crtl+C just before the point cleanup is first needed
trap "trap_ctrlc" 2

if [[ -n "$ppa" ]]; then
	for i in "${ppa[@]}"; do
		# Add ppa, but ppa bad I guess
		sudo add-apt-repository ppa:"$i"
	done
fi

if [[ -n "$pacdeps" ]]; then
	for i in "${pacdeps[@]}"; do
		fancy_message info "Installing $i"
		# If /tmp/pacstall-pacdeps-"$i" is available, it will trigger the logger to log it as a dependency
		sudo touch /tmp/pacstall-pacdeps-"$i"

		if ! pacstall -P -I "$i"; then
			fancy_message error "Failed to install pacstall dependencies"
			error_log 8 "install $PACKAGE"
			cleanup
			return 1
		fi
	done
fi

if [[ -n "$breaks" ]]; then
	for pkg in $breaks; do
		if dpkg-query -W -f='${Status} ${Section}' "${pkg}" 2> /dev/null | grep "^install ok installed" | grep -v "Pacstall" > /dev/null 2>&1; then
			# Check if anything in breaks variable is installed already
			fancy_message error "${RED}$name${NC} breaks $pkg, which is currently installed by apt"
			error_log 13 "install $PACKAGE"
			fancy_message info "Cleaning up"
			cleanup
			return 1
		fi
		if [[ "${pkg}" != "${name}" ]] && pacstall -L | grep "${pkg}" > /dev/null 2>&1; then
			# Same thing, but check if anything is installed with pacstall
			fancy_message error "${RED}$name${NC} breaks $pkg, which is currently installed by pacstall"
			error_log 13 "install $PACKAGE"
			fancy_message info "Cleaning up"
			cleanup
			return 1
		fi
	done
fi

if [[ -n $replace ]]; then
	# Ask user if they want to replace the program
	if dpkg-query -W -f='${Status}' $replace 2> /dev/null | grep -q "ok installed" ; then
		ask "This script replaces $replace. Do you want to proceed" N
		if [[ $answer -eq 0 ]]; then
			fancy_message info "Cleaning up"
			cleanup
			return 1
		fi
		sudo apt-get remove -y $replace
	fi
fi

# Get all uninstalled build depends
for build_dep in $build_depends; do
	if dpkg-query -W -f='${Status}' "${build_dep}" 2> /dev/null | grep "^install ok installed" > /dev/null 2>&1; then
		build_depends=${build_depends/"${build_dep}"/};
	fi;
done

build_depends=$(echo "$build_depends" | tr -s ' ' | awk '{gsub(/^ +| +$/,"")} {print $0}')

# This echo makes it ignore empty strigs
if [[ -n "$build_depends" ]]; then
	fancy_message info "${BLUE}$name${NC} requires ${CYAN}$(echo -e "$build_depends")${NC} to install"
	ask "Do you want to remove them after installing ${BLUE}$name${NC}" N
	if [[ $answer -eq 0 ]]; then
		NOBUILDDEP=0
	else
		NOBUILDDEP=1
	fi

	if ! sudo apt-get install -y -qq -o=Dpkg::Use-Pty=0 $build_depends; then
		fancy_message error "Failed to install build dependencies"
		error_log 8 "install $PACKAGE"
		fancy_message info "Cleaning up"
		cleanup
		return 1
	fi
fi

if [[ "$url" != *".deb" ]] && ! makeVirtualDeb; then
		return 1
fi

function hashcheck() {
	inputHash=$hash
	# Get hash of file
	fileHash="$(sha256sum "$1" | sed 's/\s.*$//')"

	if [[ "$inputHash" != "$fileHash" ]]; then
		# We bad
		fancy_message error "Hashes don't match"
		error_log 16 "install $PACKAGE"
		if [[ "$url" != *".deb" ]]; then
			sudo dpkg -r "$name" > /dev/null
		fi

		fancy_message info "Cleaning up"
		cleanup
		return 1
	fi
	true
}

fancy_message info "Retrieving packages"
if [[ -f /tmp/pacstall-pacdeps-"$PACKAGE" ]]; then
	mkdir -p "/tmp/pacstall-pacdep"
	if ! cd "/tmp/pacstall-pacdep" 2> /dev/null; then
		error_log 1 "install $PACKAGE"; fancy_message error "Could not enter ${SRCDIR}"; exit 1
	fi
else
	mkdir -p "$SRCDIR"
	if ! cd "$SRCDIR" 2> /dev/null; then
		error_log 1 "install $PACKAGE"; fancy_message error "Could not enter ${SRCDIR}"; exit 1
	fi
fi

sudo mkdir -p "/tmp/pacstall"
sudo chown "$LOGNAME" -R /tmp/pacstall

case "$url" in
	*.git)
		# git clone quietly, with no history, and if submodules are there, download with 10 jobs
		sudo git clone --quiet --depth=1 --jobs=10 "$url"
		# cd into the directory
		cd ./*/ 2> /dev/null || ( error_log 1 "install $PACKAGE"; fancy_message warn "Could not enter into the cloned git repository" )
		# Check the integrity
		git fsck --full
	;;
	*.zip)
		download "$url"
		# hash the file
		if ! hashcheck "${url##*/}"; then
			return 1
		fi
		# unzip file
		sudo unzip -q "${url##*/}" 1>&1 2>/dev/null
		# cd into it
		cd ./*/ 2> /dev/null || ( error_log 1 "install $PACKAGE"; fancy_message warn "Could not enter into the downloaded archive" )
	;;
	*.deb)
		download "$url"
		if ! hashcheck "${url##*/}"; then
			return 1
		fi
		if sudo apt install -y -f ./"${url##*/}" 2>/dev/null; then
			log
			if type -t postinst > /dev/null 2>&1; then
				if ! postinst; then
					error_log 5 "postinst hook"
					fancy_message error "Could not run postinst hook successfully"
					exit 1
				fi
			fi

			fancy_message info "Storing pacscript"
			sudo mkdir -p /var/cache/pacstall/"$PACKAGE"/"$version"
			if ! cd "$DIR" 2> /dev/null; then
				error_log 1 "install $PACKAGE"; fancy_message error "Could not enter into ${DIR}"; exit 1
			fi
			sudo cp -r "$PACKAGE".pacscript /var/cache/pacstall/"$PACKAGE"/"$version"
			sudo chmod o+r /var/cache/pacstall/"$PACKAGE"/"$version"/"$PACKAGE".pacscript
			fancy_message info "Cleaning up"
			cleanup
			return 0

		else
			fancy_message error "Failed to install the package"
			error_log 14 "install $PACKAGE"
			sudo dpkg -r "$name" > /dev/null
			fancy_message info "Cleaning up"
			cleanup
			return 1
		fi
	;;
	*.AppImage)
		download "$url"
		if ! hashcheck "${url##*/}"; then
			return 1
		fi
	;;
	*)
		download "$url"
		# I think you get it by now
		if ! hashcheck "${url##*/}"; then
			return 1
		fi
		sudo tar -xf "${url##*/}" 1>&1 2>/dev/null
		cd ./*/ 2> /dev/null || ( error_log 1 "install $PACKAGE"; fancy_message warn "Could not enter into the downloaded archive" )
	;;
esac

export srcdir="$PWD"
sudo chown -R "$LOGNAME":"$LOGNAME" . 2>/dev/null

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

fancy_message info "Preparing"
if ! prepare; then
	fancy_message error "Could not prepare $PACKAGE properly"
	sudo dpkg -r "$name" > /dev/null
	fancy_message info "Cleaning up"
	cleanup
	exit 1
fi

# Check if build function doesn't exist
if ! type -t build > /dev/null 2>&1; then
	fancy_message error "Something didn't compile right"
	error_log 5 "install $PACKAGE"
	sudo dpkg -r "$name" > /dev/null
	fancy_message info "Cleaning up"
	cleanup
	return 1
fi

fancy_message info "Building"
if ! build; then
	error_log 5 "build $PACKAGE"
	fancy_message error "Could not properly build $PACKAGE"
	sudo dpkg -r "$name" > /dev/null
	fancy_message info "Cleaning up"
	cleanup
	exit 1
fi

# Trap so that we can clean up (hopefully without messing up anything)
trap - SIGINT

fancy_message info "Installing"
if ! install; then
	error_log 14 "install $PACKAGE"
	fancy_message error "Could not install $PACKAGE properly"
	sudo dpkg -r "$name" > /dev/null
	fancy_message info "Cleaning up"
	cleanup
	exit 1
fi

if [[ $NOBUILDDEP -eq 1 ]]; then
	sudo apt-get remove -y "$build_depends"
fi

cd "$HOME" 2> /dev/null || ( error_log 1 "install $PACKAGE"; fancy_message warn "Could not enter into ${HOME}" )

# Metadata writing
log

fancy_message info "Symlinking files"
sudo mkdir -p "$STOWDIR"
if ! cd "$STOWDIR" 2> /dev/null ; then
	error_log 1 "install $PACKAGE";
	fancy_message error "Could not enter into ${STOWDIR}";
	sudo dpkg -r "$name" > /dev/null
	fancy_message info "Cleaning up"
	cleanup
	exit 1
fi

# By default (I think), stow symlinks to the directory behind it (..), but we want to symlink to /, or in other words, symlink files from pkg/usr to /usr
if ! command -v stow > /dev/null; then
	# If stow failed to install, install it
	if ! sudo apt-get install stow -y; then
		fancy_message error "Failed to install the pacstall dependency stow"
		error_log 15 "install $PACKAGE"
		sudo dpkg -r "$name" > /dev/null
		fancy_message info "Cleaning up"
		cleanup
		return 1
	fi
fi

# Magic time. This installs the package to /, so `/usr/src/pacstall/foo/usr/bin/foo` -> `/usr/bin/foo`
# stow will fail to symlink packages if files already exist on the system; this is just an error
if ! sudo stow --target="/" "$PACKAGE"; then
	fancy_message error "Package contains links to files that exist on the system"
	error_log 14 "install $PACKAGE"
	sudo dpkg -r "$name" > /dev/null
	fancy_message info "Cleaning up"
	cleanup
	return 1
fi

# `hash -r` updates PATH database
hash -r
if type -t postinst > /dev/null 2>&1; then
	if ! postinst; then
		error_log 5 "postinst hook"
		fancy_message error "Could not run postinst hook successfully"
		sudo dpkg -r "$name" > /dev/null
		fancy_message info "Cleaning up"
		cleanup
		exit 1
	fi
fi

fancy_message info "Storing pacscript"
sudo mkdir -p /var/cache/pacstall/"$PACKAGE"/"$version"
if ! cd "$DIR" 2> /dev/null; then
	error_log 1 "install $PACKAGE"
	fancy_message error "Could not enter into ${DIR}"
	sudo dpkg -r "$name" > /dev/null
	fancy_message info "Cleaning up"
	cleanup
	exit 1
fi

sudo cp -r "$PACKAGE".pacscript /var/cache/pacstall/"$PACKAGE"/"$version"
sudo chmod o+r /var/cache/pacstall/"$PACKAGE"/"$version"/"$PACKAGE".pacscript

fancy_message info "Cleaning up"
cleanup
return 0

# vim:set ft=sh ts=4 sw=4 noet:
