#!/bin/bash
mkdir build && cd build
cmake ..
make
paco -lp kvantum "sudo make install"
