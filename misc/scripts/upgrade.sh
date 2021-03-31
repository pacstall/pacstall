#!/bin/bash
vercmpe() {
    [ “$1” = “`echo -e “$1\n$2” | sort -V | head -n1`”]
}

vercmp() {
    [“$1”=“$2”] && return 1 || vercmpe $1 $2
}

function version_gt() { 
    test "$(printf '%s\n' "$@" | sort -V | head -n 1)" != "$1"; 
}

list=$(pacstall -L | sed ':a;N;$!ba;s/\n/,/g')
for i in {"$list"}; do
    Local=$(pdb-grab $i metadata /var/db/pacstall.pdb | sed -n -e 's/description=//p')
    Curl=$(curl -s https://raw.githubusercontent.com/Henryws/pacstall-programs/master/packages/$i/$i.pacscript | sed -n -e 's/version=//p')
    if version_gt "$Curl" "$Local" ; then
        echo "Upgradable"
    fi
    if [[ $? == "Upgradable" ]] ; then
        echo $i >> /tmp/pacstall-up-list
    fi

for i in "$(cat /tmp/pacstall-up-list | sed ':a;N;$!ba;s/\n/,/g')" ; do
    sudo pacstall -I $i
done
