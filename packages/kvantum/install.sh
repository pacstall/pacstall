#!/bin/bash
mkdir build && cd build
cmake ..
make -j$(nproc)
sudo paco -lp kvantum "make install"
