#!/bin/bash
./configure
make -j$(nproc)
sudo porg -lp glibc "make install"
