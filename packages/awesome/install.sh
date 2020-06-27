#!/bin/bash
make -j$(nproc)
cmake
sudo paco -lp "make install"
