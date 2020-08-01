#!/bin/bash
make -j$(nproc)
cmake
sudo porg -lp "make install"
