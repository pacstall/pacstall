#!/bin/bash
function trap_ctrlc ()
      {
          echo "! cleaning up"
          rm -rf /tmp/pacstall/*
	  echo "installation interrupted, removed files"
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

if echo $build_depends; then
    echo -e "${BLUE}$pkgname${NC} requires ${CYAN}$(echo -e $build_depends)${NC} to install"
    printf "do you want to remove them after installing ${BLUE}$pkgname${NC} [y/n] "
    read -r REMOVE_DEPENDS
    NOBUILDDEP=0
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
echo -e ":: Retrieving packages..."
mkdir -p /tmp/pacstall
cd /tmp/pacstall
if [[ $url = *.git ]] ; then
  git clone $url
  cd *
else
  wget --progress=bar:force $url 2>&1 | progressfilt
  if [[ $url = *.zip ]] ; then
    unzip $(echo ${url##*/})
    cd *
  else
    tar -xf $(echo ${url##*/})
    cd *
  fi
fi
prepare
# Check if build function exists
type -t build > /dev/null 2>&1
if [[ $? -eq 0 ]] ; then
  build
fi

trap - SIGINT
echo ":: Installing"
install 1> /dev/null
if [[ $REMOVE_DEPENDS = y ]] ; then
  sudo apt remove $build_depends
fi
echo -e ":: Done installing $name"
sudo touch /var/log/pacstall_installed/$PACKAGE
