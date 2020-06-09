#!/bin/bash
mkdir build && cd build
cmake ..
make -j4
sudo porg -lp kvantum "make install"
