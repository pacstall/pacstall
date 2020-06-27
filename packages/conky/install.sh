#!/bin/bash
mkdir build
cd build
cmake ..
sudo make -j$(nproc)
sudo paco -lp conky "make install"
