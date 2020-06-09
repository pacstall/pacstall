#!/bin/bash
./configure
make -j4
paco -lp nemo "make install"
