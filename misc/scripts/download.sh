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


PACKAGE=$2
REPO=$3
URL=https://raw.githubusercontent.com/$REPO/master/packages/$PACKAGE/PACSCRIPT
if wget --spider $URL 2>/dev/null; then
  echo "the file you want to download does not exists"
  exit 1
fi
mkdir -p ~/.cache/pacstall/$PACKAGE
cd ~/.cache/pacstall/$PACKAGE
wget --progress=bar:force $URL 2>&1 | progressfilt
