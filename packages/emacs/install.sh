#!/bin/bash
wget -O emacs.tar.xz https://mirrors.ocf.berkeley.edu/gnu/emacs/emacs-26.3.tar.xz
tar -xf emacs.tar.xz
cd emacs-26.3
./configure
make -j4
paco -lp emacs "make install"
