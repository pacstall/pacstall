#!/bin/bash
mkdir build
cd build
cmake ..
sudo make -j4
sudo porg -lp conky "make install"
