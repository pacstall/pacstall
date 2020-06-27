#!/bin/bash
make -j$(nproc)
sudo porg -lp vim "make install"
