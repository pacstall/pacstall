#!/bin/bash
function version_gt() { 
    test "$(printf '%s\n' "$@" | sort -V | head -n 1)" != "$1"; 
}

list=( $(pacstall -L) )
sudo truncate -s 0 /tmp/pacstall-up-list
touch /tmp/pacstall-up-list
for i in "${list[@]}"; do
    localver=$(pdb-grab $i metadata /var/db/pacstall.pdb | sed -n -e 's/version=//p' | tr -d \")
    remotever=$(curl -s https://raw.githubusercontent.com/Henryws/pacstall-programs/master/packages/$i/$i.pacscript | sed -n -e 's/version=//p' | tr -d \")
    if version_gt "$remotever" "$localver" ; then
        echo $i >> /tmp/pacstall-up-list
    fi
done
for i in `sed ':a;N;$!ba;s/\n/,/g' /tmp/pacstall-up-list` ; do
    sudo pacstall -I $i
done
