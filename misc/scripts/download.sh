#!/bin/bash

# Minimalistic progress bar wget
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
wget --progress=bar:force $URL -O $PACKAGE.pacscript 2>&1 | progressfilt
if [[ $INSTALLING -eq 1 ]] ; then
    source /usr/share/pacstall/scripts/install-local.sh
fi
fancy_message info "Your script is in ${GREEN}$HOME/.cache/pacstall/$PACKAGE${NC}"
}
URL=https://raw.githubusercontent.com/$REPO/master/packages/$PACKAGE/$PACKAGE.pacscript
if curl --output /dev/null --silent --head --fail "$URL" ; then
  download
else
  echo $URL
  fancy_message warn "The file you want to download does not exist"
  if [ -f "/var/log/pacstall_installed/$PACKAGE" ]; then
    fancy_message warn "It seems you have a copy of $PACKAGE on your system but no longer exists in the repos"
    sudo touch /var/log/pacstall_orphaned/$PACKAGE
    printf "do you want to uninstall $PACKAGE "
    if [[ $? = y ]] ; then
        sudo pacstall -R $PACKAGE
    fi
  fi
  exit 1
fi
