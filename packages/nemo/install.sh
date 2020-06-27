#!/bin/bash
./configure
make -j$(nproc)
sudo porg -lp nemo "make install"
