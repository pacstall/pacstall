#!/bin/bash
mkdir build
cd build
cmake ..
sudo make -j4
paco -lp conky "make install"
