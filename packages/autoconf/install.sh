#!/bin/bash
./configure
make -j$(nproc)
sudo paco -lp autoconf "make install"
