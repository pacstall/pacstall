#!/bin/bash
wget -O emacs.tar.xz https://mirrors.ocf.berkeley.edu/gnu/emacs/emacs-26.3.tar.xz
tar -xf emacs.tar.xz
cd emacs-26.3
./configure
make
if sudo checkinstall ; then
    echo "checkinstall succeeded"
else
    echo "checkinstall failed... running make install"
    sudo make install
fi
