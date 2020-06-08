#!/bin/bash
mkdir build
cd build
cmake ..
sudo make
paco -lp conky "sudo make install"
