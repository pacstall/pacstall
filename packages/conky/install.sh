#!/bin/bash
mkdir build
cd build
cmake ..
sudo make -j$(nproc)
sudo porg -lp conky "make install"
