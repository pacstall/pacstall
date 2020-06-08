#!/bin/bash
./configure
cpu=$(grep -c ^prcessor /proc/cpuinfo)
make -j$cpu
sudo make install
