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
mkdir -p $HOMEDIR/.cache/pacstall/
cd $HOMEDIR/.cache/pacstall/
mkdir -p $PACKAGE
cd $PACKAGE
wget --progress=bar:force $URL -O $PACKAGE.pacscript 2>&1 | progressfilt
if [[ $INSTALLING -eq 1 ]] ; then
    source /usr/share/pacstall/scripts/install-local.sh
fi
}
if curl --output /dev/null --silent --head --fail "$URL" ; then
  download
else
  echo $URL
  echo "! the file you want to download does not exist"
  if [ -f "/var/log/pacstall_installed/$PACKAGE" ]; then
    echo ":: It seems you have a copy of $PACKAGE on your system but no longer exists in the repos"
    sudo touch /var/log/pacstall_orphaned/$PACKAGE
    printf "do you want to uninstall $PACKAGE "
    if [[ $? = y ]] ; then
        sudo pacstall -R $PACKAGE
    fi
  fi
  exit 1
fi
