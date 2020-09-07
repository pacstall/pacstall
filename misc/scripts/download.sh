#!/bin/bash
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
mkdir -p ~/.cache/pacstall/
cd ~/.cache/pacstall/
mkdir -p $PACKAGE
cd $PACKAGE
wget --progress=bar:force $URL 2>&1 | progressfilt
}

INPUT=$1
VERSION=$
REPO=$(cat /usr/share/pacstall/repo/pacstallrepo.txt)
URL="https://raw.githubusercontent.com/$REPO/1.0.4-Celeste/packages/$PACKAGE/PACSCRIPT"
if curl --output /dev/null --silent --head --fail "$URL" ; then
  download
else
  echo "the file you want to download does not exists"
  exit 1
fi
