#!/bin/bash
./configure
make -j$(nproc)
sudo porg -lp autoconf "make install"
