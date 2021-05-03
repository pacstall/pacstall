#!/bin/bash

# This script downloads pacscripts from the interwebs

download() {
mkdir -p $HOME/.cache/pacstall/
cd $HOME/.cache/pacstall/
mkdir -p $PACKAGE
cd $PACKAGE
wget -q --show-progress --progress=bar:force $URL -O $PACKAGE.pacscript 2>&1
if [[ $INSTALLING -eq 1 ]] ; then
    source /usr/share/pacstall/scripts/install-local.sh
    exit
fi
fancy_message info "Your script is in ${GREEN}$HOME/.cache/pacstall/$PACKAGE${NC}"
fancy_message info "cd into it and run sudo pacstall -Il <pkg> to install it"
}
URL=https://raw.githubusercontent.com/$REPO/master/packages/$PACKAGE/$PACKAGE.pacscript
wget -q --tries=10 --timeout=20 --spider https://github.com 
if [[ $? -eq 1 ]]; then
    fancy_message error "Not connected to internet"
    exit 1
fi
if curl --output /dev/null --silent --head --fail "$URL" ; then
  download
else
  fancy_message warn "The file you want to download does not exist"
  exit 1
fi
