#!/bin/bash
./configure
make -j$(nproc)
make install
