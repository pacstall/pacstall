#!/bin/bash
wget https://mirror.us-midwest-1.nexcess.net/gnu/emacs/emacs-26.3.tar.xz
tar -xf emacs-26.3.tar.xz
cd emacs-26.3
./configure
make -j$(nproc)
sudo porg -lp emacs "make install"
sudo mv foo /bin/foo
