#!/bin/bash
./configure
make -j4
paco -lp cmatrix "make install"
