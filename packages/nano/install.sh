#!/bin/bash
./configure
make -j$(nproc)
sudo porg -lp nano "make install"
