#!/bin/bash
autoreconf -if
./configure
make
sudo porg -lp mocp "make install"
