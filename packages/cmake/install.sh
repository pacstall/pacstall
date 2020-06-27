#!/bin/bash
./bootstrap
make -j$(nproc)
sudo porg -lp "make install"
