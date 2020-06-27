#!/bin/bash
./configure
make -j$(nproc)
sudo paco -lp nano "make install"
