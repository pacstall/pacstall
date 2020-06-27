#!/bin/bash
./autogen.sh --prefix=/usr
make -j$(nproc)
paco -lp adapta-gtk-theme "make install"
