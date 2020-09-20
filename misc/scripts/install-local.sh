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

checks() {
if curl --output /dev/null --silent --head --fail "$url" ; then
  echo -e "url exists"
fi
if apt-cache search $build_depends >/dev/null 2>&1 ; then
  echo -e "build depends exists in repos"
fi
if apt-cache search $depends >/dev/null 2>&1 ; then
  echo -e "dependencies exist in repos"
fi
}
printf "${CYAN}??${NC} Do you want to view the pacscript first "
read -r READ
if [[ $READ = y ]] ; then
  less $PACKAGE.pacscript
else
  exit 1
fi
source $PACKAGE.pacscript
echo -e "running checks"
checks
if [[ $? -eq 1 ]] ; then
  echo -e "! There was an error checking the script!"
  exit 1
fi
echo -e "${BLUE}$pkgname${NC} requires ${CYAN}$(echo -e $build_depends)${NC} to install"
printf "do you want to remove them after installing ${BLUE}$pkgname${NC} [y/n] "
read -r REMOVE_DEPENDS
dpkg-query -l $breaks >/dev/null 2>&1
if [[ $? -eq 0 ]] ; then
  echo -e "! ${RED}$pkgname${NC} breaks $breaks"
  exit 1
fi
sudo apt install $build_depends
sudo apt install -y $depends
echo -e ":: Retrieving packages..."
cd /tmp/
if [[ $url = *.git ]] ; then
  git clone $url
else
  wget --progress=bar:force $url 2>&1 | progressfilt
  if [[ $url = *.zip ]] ; then
    unzip $(echo ${url##*/})
  else
    tar -xf $(echo ${url##*/})
  fi
fi
prepare
build
install
if [[ $REMOVE_DEPENDS = y ]] ; then
  sudo apt remove $build_depends
fi
echo -e ":: Done installing $name"
cd /tmp/ && mv $PACKAGE.pacscript /var/log/pacstall_installed
