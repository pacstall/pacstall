#!/bin/bash
equals=$(command -v apt)
if [ $equals = /usr/bin/apt ] ; then
    sudo apt-get install -y cmake libimlib2-dev libncurses5-dev libx11-dev libxdamage-dev libxft-dev libxinerama-dev libxml2-dev libxext-dev libcurl4-openssl-dev liblua5.3-dev
fi
equals=$(command -v dnf)
if [ $equals = /usr/bin/dnf ] ; then
    sudo dnf install -y cmake imlib2 libcurl libX11 libXdamage glibc cairo libcurl libgcc lua-libs g++ ncurses-devel libx11-devel libXdamage-devel libXft-devel libXinerama-devel libcurl-devel lua-devel imlib2-devel
fi
#Makes dependencylist variable which should print when asked if the user wishes to install program
equals=$(command -v apt)
if [ $equals = /usr/bin/apt ] ; then
    dependencylist="cmake\nlibimlib2-dev\nlibncurses5-dev\nlibx11-dev\nlibxdamage-dev\nlibxft-dev\nlibxinerama-dev\nlibxml2-dev\nlibxext-dev\nlibcurl4-openssl-dev\nliblua5.3-dev\n"
fi
equals=$(command -v dnf)
if [ $equals = /usr/bin/dnf ] ; then
    dependencylist="cmake\nimlib2\nlibcurl\nlibX11\nlibXdamage\nglibc\ncairo\nlibcurl\nlibgcc\nlua-libs\ng++\nncurses-devel\nlibx11-devel\nlibXdamage-devel\nlibXft-devel\nlibXinerama-devel\nlibcurl-devel\nlua-devel\nimlib2-devel\n"
fi
