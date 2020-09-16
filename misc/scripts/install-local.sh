#!/bin/bash
checks() {
if curl --output /dev/null --silent --head --fail "$url" ; then
  echo "url exists"
fi
if apt-cache search $build_depends >/dev/null 2>&1 ; then
  echo "build depends exists in repos"
fi
if apt-cache search $depends >/dev/null 2>&1 ; then
  echo "dependencies exist in repos"
fi
}
source PACSCRIPT
echo ":: Installing ${BLUE}$pkgname${NC} version: ${BLUE}$version${NC}"
echo "running checks"
checks
if [[ $? -eq 1 ]] ; then
  echo "! There was an error checking the script!"
  exit 1
fi
echo "${BLUE}$pkgname${NC} requires $(echo $build_depends) to install"
echo "do you want to remove them after installing ${BLUE}$pkgname${NC} [y/n] "
read -r REMOVE_DEPENDS
dpkg-query -l $breaks >/dev/null 2>&1
if [[ $? -eq 1 ]] ; then
  echo "! ${RED}$pkgname${NC} breaks $breaks"
  exit 1
fi
echo ":: Retrieving packages..."
cd /tmp/
if [[ $url = *.git ]] ; then
  git clone $url
else
  wget --progress=bar:force $url
  if [[ $url = *.zip ]] ; then
    unzip -
  else
    tar -xf -
  fi
fi
prepare
build
install
if [[ $REMOVE_DEPENDS = y ]] ; then
  sudo apt remove $build_depends
fi
echo ":: Done installing $name"
