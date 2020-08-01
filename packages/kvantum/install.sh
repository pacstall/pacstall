#!/bin/bash
mkdir build && cd build
cmake ..
make -j$(nproc)
sudo porg -lp kvantum "make install"
