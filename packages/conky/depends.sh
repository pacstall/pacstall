#!/bin/bash
equals=$(command -v apt)
if [[ $equals = /usr/bin/apt ]] ; then
    sudo apt-get install -y cmake libimlib2-dev libncurses5-dev libx11-dev libxdamage-dev libxft-dev libxinerama-dev libxml2-dev libxext-dev libcurl4-openssl-dev liblua5.3-dev
fi
equals=$(command -v dnf)
if [[ $equals = /usr/bin/dnf ]] ; then
    sudo dnf install -y cmake imlib2 libcurl libX11 libXdamage glibc cairo libcurl libgcc lua-libs g++ ncurses-devel libx11-devel libXdamage-devel libXft-devel libXinerama-devel libcurl-devel lua-devel imlib2-devel
fi
