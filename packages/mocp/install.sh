#!/bin/bash
autoreconf -if
./configure
make
paco -lp mocp "sudo make install"
