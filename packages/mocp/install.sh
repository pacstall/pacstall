#!/bin/bash
autoreconf -if
./configure
make
paco -lp mocp "make install"
