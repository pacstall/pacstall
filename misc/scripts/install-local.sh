#!/bin/bash
function trap_ctrlc () {
    echo ""
    fancy_message warn "Interupted, cleaning up"
    rm -rf /tmp/pacstall/*
    exit 2
}

trap "trap_ctrlc" 2

# run checks to verify script works
checks() {
# curl url to check it exists
if curl --output /dev/null --silent --head --fail "$url" ; then
    fancy_message info "URL exists"
else
	fancy_message error "URL doesn't exist"
	exit 1
fi
if [[ -z "$hash" ]]; then
    fancy_message warn "Package does not contain a hash"
fi
}

if ask "Do you want to view the pacscript first" Y; then
    less $PACKAGE.pacscript
fi
fancy_message info "Sourcing pacscript"
source $PACKAGE.pacscript
fancy_message info "Running checks"
checks
if [[ $? -eq 1 ]] ; then
    fancy_message error "There was an error checking the script!"
    exit 1
fi

if [[ -n "$build_depends" ]]; then
    fancy_message info "${BLUE}$pkgname${NC} requires ${CYAN}$(echo -e $build_depends)${NC} to install"
	if ask "Do you want to remove them after installing ${BLUE}$pkgname${NC}" N; then
    	NOBUILDDEP=0
	fi
else
    NOBUILDDEP=1
fi

echo -n $depends > /dev/null 2>&1
if [[ $? -eq 0 ]] ; then
    if [[ -n "$breaks" ]]; then
    dpkg-query -l $breaks >/dev/null 2>&1
    if [[ $? -eq 0 ]] ; then
      fancy_message error "${RED}$pkgname${NC} breaks $breaks"
      exit 1
    fi
    fi
fi
if [[ -z $replace ]] ; then
    dpkg-query -W -f='${Status}' $replace 2>/dev/null | grep -c "ok installed"
    if [[ $? -eq 1 ]] ; then
        if ask "This script replaces $replace. Do you want to procide?" N; then
            sudo apt-get remove -y $replace 
        else
            exit 1
        fi
    fi
fi
if [[ $NOBUILDDEP -eq 0 ]] ; then
    sudo apt-get install -y -qq $build_depends
fi

hashcheck() {
    inputHash=$hash
    fileHash=($(sha256sum $1 | sed 's/\s.*$//'))

    if [ $inputHash = $fileHash ]; then
        true
    else
        fancy_message error "Hashes don't match"
        exit 1
    fi
}
fancy_message info "Installing dependencies"
sudo apt-get install -y -qq $depends
fancy_message info "Retrieving packages"
mkdir -p /tmp/pacstall
cd /tmp/pacstall

# Detects if url ends in .git (in that case git clone it), or ends in .zip, or just assume that the url can be uncompressed with tar. Then cd into them
if [[ $url = *.git ]] ; then
  git clone --quiet --depth=1 --jobs=10 $url
  cd $(/bin/ls -d */|head -n 1)
else
  wget -q --show-progress --progress=bar:force $url 2>&1
  if [[ $url = *.zip ]] ; then
    hashcheck $(echo ${url##*/}) 
    unzip -q $(echo ${url##*/}) 1>&1
    cd $(/bin/ls -d */|head -n 1)
else
    hashcheck $(echo ${url##*/})
    tar -xf $(echo ${url##*/}) 1>&1
    cd $(/bin/ls -d */|head -n 1)
  fi
fi
prepare
# Check if build function exists
type -t build > /dev/null 2>&1
if [[ $? -eq 0 ]] ; then
  build
fi
if [[ $? -eq 1 ]] ; then
  fancy_message error "Something didn't compile right"
  exit 1
fi
trap - SIGINT
fancy_message info "Installing"
install
if [[ $REMOVE_DEPENDS = y ]] ; then
  sudo apt remove $build_depends
fi
sudo rm -rf /tmp/pacstall/*
cd $HOME
echo "version=\"$version"\" | sudo tee /var/log/pacstall_installed/$PACKAGE >/dev/null
echo "description=\"$description"\" | sudo tee -a /var/log/pacstall_installed/$PACKAGE >/dev/null
echo "date=\"$(date)"\" | sudo tee -a /var/log/pacstall_installed/$PACKAGE >/dev/null
if [[ $removescript == "yes" ]] ; then
   echo "removescript=\"yes"\" | sudo tee -a /var/log/pacstall_installed/$PACKAGE >/dev/null
fi
# If optdepends exists do this
if [[ -n $optdepends ]] ; then
    fancy_message info "Package has some optional dependencies that can enhance it's functionalities"
    echo "Optional dependencies:"
    echo "$optdepends"
    if ask "Do you want to install them?" Y; then
        sudo apt-get install -y $optdepends
    fi
fi
fancy_message info "Symlinking files"
cd /usr/src/pacstall/
# By default (I think), stow symlinks to the directory behind it (..), but we want to symlink to /, or in other words, symlink files from pkg/usr to /usr
sudo stow --target="/" "$PACKAGE"
# stow will fail to symlink packages if files already exist on the system; this is just an error
if [[ $? -eq 1 ]]; then
    fancy_message error "Package contains links to files that exist on the system"
    exit 1
fi
hash -r
type -t postinst > /dev/null 2>&1
if [[ $? -eq 0 ]] ; then
   postinst
fi
