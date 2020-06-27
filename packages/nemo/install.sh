#!/bin/bash
./configure
make -j$(nproc)
sudo paco -lp nemo "make install"
