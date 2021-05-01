#!/bin/bash

# This script downloads pacscripts from the interwebs
progressfilt ()
{
    local flag=false c count cr=$'\r' nl=$'\n'
    while IFS='' read -d '' -rn 1 c
    do
        if $flag
        then
            printf '%s' "$c"
        else
            if [[ $c != $cr && $c != $nl ]]
            then
                count=0
            else
                ((count++))
                if ((count > 1))
                then
                    flag=true
                fi
            fi
        fi
    done
}

download() {
mkdir -p $HOME/.cache/pacstall/
cd $HOME/.cache/pacstall/
mkdir -p $PACKAGE
cd $PACKAGE
logthis wget --progress=bar:force $URL -O $PACKAGE.pacscript 2>&1 | progressfilt
if [[ $INSTALLING -eq 1 ]] ; then
    source /usr/share/pacstall/scripts/install-local.sh
    exit
fi
fancy_message info "Your script is in ${GREEN}$HOME/.cache/pacstall/$PACKAGE${NC}"
}
URL=https://raw.githubusercontent.com/$REPO/master/packages/$PACKAGE/$PACKAGE.pacscript
logthis wget -q --tries=10 --timeout=20 --spider https://github.com 
if [[ $? -eq 1 ]]; then
    fancy_message error "Not connected to internet"
    exit 1
fi
if curl --output /dev/null --silent --head --fail "$URL" ; then
  logthis download
else
  fancy_message warn "The file you want to download does not exist"
  exit 1
fi
