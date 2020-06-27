#!/bin/bash
./bootstrap
make -j$(nproc)
sudo porg -lp cmake "make install"
