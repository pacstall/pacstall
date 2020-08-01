#!/bin/bash
./autogen.sh
./configure
make -j$(nproc)
sudo porg -lp awf "make install"