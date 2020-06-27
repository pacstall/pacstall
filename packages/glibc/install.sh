#!/bin/bash
./configure
make -j$(nproc)
sudo paco -lp glibc "make install"
