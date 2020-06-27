#!/bin/bash
autoreconf -if
./configure
make -j$(nproc)
sudo porg -lp mocp "make install"
