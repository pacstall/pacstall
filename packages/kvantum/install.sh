#!/bin/bash
mkdir build && cd build
cmake ..
make -j4
paco -lp kvantum "make install"
