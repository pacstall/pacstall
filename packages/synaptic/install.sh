#!/bin/bash
./configure 
make -j$(nproc)
sudo porg -lp synaptic "make install"
