#!/bin/bash
autoreconf -if
./configure
make -j$(nproc)
sudo paco -lp mocp "make install"
