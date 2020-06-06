#!/bin/bash
equals=$(command -v apt)
if [[ $equals = /usr/bin/apt ]]
then
sudo apt install -y build-essential build-dep emacs24
fi
if [[ $equals = /usr/bin/dnf ]]
then
sudo dnf install -y emacs-common liblockfile lobotf Xaw3d libpng-devel libtiff-devel openjpeg-devel gtk2-devel ncurses-devel giflib-devel libX11-devel libXpm-devel libjpeg-devel gnutls-devel
fi
