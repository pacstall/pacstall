#!/bin/bash
./autogen.sh
./configure
make
sudo porg -lp awf "make install"
