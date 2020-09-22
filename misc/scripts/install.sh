#!/bin/bash
#DEPRECATED
function trap_ctrlc ()
      {
          echo "cleaning up"
          rm -rf /tmp/pacstall/*
	  echo "installation interrupted, removed files"
          exit 2
      }
trap "trap_ctrlc" 2
      
if [ "$EUID" -ne 0 ] ; then
	echo "Please run as root"
	exit 1
fi

PACPREFIX="apt install -y"
DOWNLOAD() {
if [[ $url == *.git ]]; then
	echo "detected git"
	cd $BUILDDIR
	git clone $url
fi
if [[ $url == *.tar.xz ]] ; then
	echo "detected tar.xz"
	cd $BUILDDIR
	wget -q --show-progress --progress=bar:force:noscroll $url
	tar -xf $pkgname.tar.xz
fi
if [[ $url == *.zip ]]; then
	echo "detected zip"
	cd $BUILDDIR
	wget -q --show-progress --progress=bar:force:noscroll $url
	unzip $pkgname.zip
fi
}
PACKAGE=$2
if [[ ! -e /usr/share/pacstall/repo/ ]]; then
	mkdir -p /usr/share/pacstall/repo
	touch /usr/share/pacstall/repo/pacstallrepo.txt
	sudo pacstall -C
fi
REPO=$(cat /usr/share/pacstall/repo/pacstallrepo.txt)
RED='\033[0;31m'
CYAN='\033[0;36m'
NC='\033[0m'
GREEN='\033[0;32m'
PURPLE='\033[0;35m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
BUILDDIR=/tmp/pacstall
if [ ! -d $BUILDDIR ]; then
	mkdir -p $BUILDDIR;
fi

sudo rm -rf $BUILDDIR
sudo mkdir $BUILDDIR
cd $BUILDDIR || exit
sudo rm -rf "$PACKAGE"
URL=https://raw.githubusercontent.com/$REPO/master/packages/$PACKAGE/PACSCRIPT

if wget -q "$URL" >/dev/null 2>&1 ; then

	cd /tmp/
	wget -q https://raw.githubusercontent.com/$REPO/master/packages/$PACKAGE/PACSCRIPT
	source PACSCRIPT
	# LICENSE CHECKER HERE
	source /usr/share/pacstall/config.conf
	if [[ $mylicense != $license ]]; then
		if [[ $mylicense = ANY ]]; then
			echo " "
		else
			echo "$name breaks your chosen license! Exiting..."
			exit 1
		fi
	fi
echo "checking for conflicting packages"
if grep -q $breaks "/var/log/pacstall_installed"; then
	echo -e "$name breaks ${RED}$breaks${NC}"
	exit 1
fi
DOWNLOAD
$PACPREFIX $depends
cd $pkgname*
prepare
if [[ $? -eq 1 ]]; then
	echo "preparing the package failed"
	exit 1
fi
build
if [[ $? -eq 1 ]]; then
	echo "building the package failed"
	exit 1
fi
install
if [[ $? -eq 1 ]]; then
	echo "installing the package failed"
	exit 1
fi
fi
echo " "
rm -rf /tmp/installlist
exit 0
