#!/bin/bash
function trap_ctrlc ()
      {
          fancy_message warn "Cleaning up"
          rm -rf /tmp/pacstall/*
	  fancy_message info "installation interrupted, removed files"
          exit 2
      }
trap "trap_ctrlc" 2
# Minimalistic progress bar for wget
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

# run checks to verify script works
checks() {
if curl --output /dev/null --silent --head --fail "$url" ; then
  fancy_message info "URL exists"
fi
if apt-cache search $build_depends &> /dev/null ; then
  fancy_message info "Build depends exists in repos"
fi
if apt-cache search $depends &> /dev/null ; then
  fancy_message info "Dependencies exist in repos"
fi
}
if ask "Do you want to view the pacscript first" Y; then
  less $PACKAGE.pacscript
fi
fancy_message info "Sourcing pacscript"
source $PACKAGE.pacscript
fancy_message info "Running checks"
checks
if [[ $? -eq 1 ]] ; then
  fancy_message error "There was an error checking the script!"
  exit 1
fi

if echo $build_depends; then
    fancy_message info "${BLUE}$pkgname${NC} requires ${CYAN}$(echo -e $build_depends)${NC} to install"
    if ask "Do you want to remove them after installing ${BLUE}$pkgname${NC}" N;
    	NOBUILDDEP=0
	fi
else
    NOBUILDDEP=1
fi
echo $depends > /dev/null 2>&1
if [[ $? -eq 0 ]] ; then
    dpkg-query -l $breaks >/dev/null 2>&1
    if [[ $? -eq 0 ]] ; then
      echo -e "! ${RED}$pkgname${NC} breaks $breaks"
      exit 1
    fi
fi
if [[ $NOBUILDDEP -eq 0 ]] ; then
    sudo apt install -y $build_depends
fi
sudo apt install -y $depends
fancy_message info "Retrieving packages"
mkdir -p /tmp/pacstall
cd /tmp/pacstall
if [[ $url = *.git ]] ; then
  git clone $url
  cd $(/bin/ls -d */|head -n 1)
else
  wget --progress=bar:force $url 2>&1 | progressfilt
  if [[ $url = *.zip ]] ; then
    unzip -q $(echo ${url##*/}) 1>&1
    cd $(/bin/ls -d */|head -n 1)
  else
    tar -xf $(echo ${url##*/}) 1>&1
    cd $(/bin/ls -d */|head -n 1)
  fi
fi
prepare
# Check if build function exists
type -t build > /dev/null 2>&1
if [[ $? -eq 0 ]] ; then
  build
fi

echo "url="$url"
license="$license"
description="$description"" > /tmp/pacstall-$name-data
data="/tmp/pacstall-$name-data"
trap - SIGINT
fancy_message info "Installing"
install
if [[ $REMOVE_DEPENDS = y ]] ; then
  sudo apt remove $build_depends
fi
fancy_message info "Done installing $name"
sudo rm -rf /tmp/pacstall/*
fancy_message info "Recording to database"
pdb-remove $pkgname metadata /var/db/pacstall.pdb
pdb-remove $pkgname files /var/db/pacstall.pdb
pdb-add $pkgname metadata "`cat $data`" /var/db/pacstall.pdb
pdb-add $pkgname files "`cat /var/lib/porg/$pkgname`" /var/db/pacstall.pdb
