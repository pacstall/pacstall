#!/bin/bash
./autogen.sh --prefix=/usr
make -j$(nproc)
sudo porg -lp adapta-gtk-theme "make install"
