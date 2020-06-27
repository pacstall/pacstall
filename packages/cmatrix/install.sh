#!/bin/bash
./configure
make -j$(nproc)
sudo paco -lp cmatrix "make install"
