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
else
	fancy_message error "URL doesn't exist"
	exit 1
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

if [[ -n "$build_depends" ]]; then
    fancy_message info "${BLUE}$pkgname${NC} requires ${CYAN}$(echo -e $build_depends)${NC} to install"
	if ask "Do you want to remove them after installing ${BLUE}$pkgname${NC}" N; then
    	NOBUILDDEP=0
	fi
else
    NOBUILDDEP=1
fi
echo -n $depends > /dev/null 2>&1
if [[ $? -eq 0 ]] ; then
    dpkg-query -l $breaks >/dev/null 2>&1
    if [[ $? -eq 0 ]] ; then
      echo -e "! ${RED}$pkgname${NC} breaks $breaks"
      exit 1
    fi
fi
if [[ $NOBUILDDEP -eq 0 ]] ; then
    sudo apt-get install -y -qq $build_depends
fi
fancy_message info "Installing dependencies"
sudo apt-get install -y -qq $depends
fancy_message info "Retrieving packages"
mkdir -p /tmp/pacstall
cd /tmp/pacstall
if [[ $url = *.git ]] ; then
  git clone --depth=1 $url
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
description="$description"
version="$version"" > /tmp/pacstall-$name-data
data="/tmp/pacstall-$name-data"
trap - SIGINT
fancy_message info "Installing"
install
if [[ $REMOVE_DEPENDS = y ]] ; then
  sudo apt remove $build_depends
fi
sudo rm -rf /tmp/pacstall/*
cd $HOME
echo $(date) | sudo tee /var/log/pacstall_installed/$PACKAGE_$version >/dev/null
# Check if package has binaries
if [[ -v bindir ]] ; then
    fancy_message info "Symlinking files to ${GREEN}/usr/local/bin${NC}"
    sudo ln -sf "$destdir"/"$bindir"/* /usr/local/bin
else
    fancy_message warn "$PACKAGE does not have binaries available (This may be because it is a theme, or just configuration files, etc)"
fi
