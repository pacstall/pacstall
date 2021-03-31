#!/bin/bash
vercmpe() {
    [ “$1” = “`echo -e “$1\n$2” | sort -V | head -n1`”]
}

vercmp() {
    [“$1”=“$2”] && return 1 || vercmpe $1 $2
}

list=$(pacstall -L | sed ':a;N;$!ba;s/\n/,/g')
for i in {"$list"}; do
    Local=$(pdb-grab $i metadata /var/db/pacstall.pdb | sed -n -e 's/description=//p')
    Curl=$(curl -s https://raw.githubusercontent.com/Henryws/pacstall-programs/master/packages/$i/$i.pacscript | sed -n -e 's/version=//p')
    verdiff=$(vercmp $Local $Curl && echo “upgradable” || echo “no”)
    if [[ $? -eq 0 ]] ; then
        echo $i >> /tmp/pacstall-up-list
    fi
done

for i in "$(cat /tmp/pacstall-up-list | sed ':a;N;$!ba;s/\n/,/g')" ; do
    sudo pacstall -I $i
done
