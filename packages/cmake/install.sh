#!/bin/bash
./bootstrap
make -j$(nproc)
sudo paco -lp "make install"
