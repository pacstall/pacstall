#!/bin/bash
./configure
make -j$(nproc)
sudo porg -lp cmatrix "make install"
