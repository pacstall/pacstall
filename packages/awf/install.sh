#!/bin/bash
./autogen.sh
./configure
make -j$(nproc)
sudo paco -lp awf "make install"
