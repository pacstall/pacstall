#!/bin/bash
make -j$(nproc)
cmake
sudo make install
