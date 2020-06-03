#!/bin/bash
wget -O emacs.tar.xz https://mirrors.ocf.berkeley.edu/gnu/emacs/emacs-26.3.tar.xz
tar xvfz emacs.tar.xz
cd emacs
./configure
make
if sudo checkinstall ; then
    echo "checkinstall succeeded"
else
    echo "checkinstall failed... running make install"
    sudo make install
fi
