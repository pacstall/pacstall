#!/bin/bash
make -j$(nproc)
sudo paco -lp vim "make install"
