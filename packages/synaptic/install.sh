#!/bin/bash
./configure 
make -j$(nproc)
sudo paco -lp synaptic "make install"
