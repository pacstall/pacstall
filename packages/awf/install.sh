#!/bin/bash
./autogen.sh
./configure
make
paco -lp awf "sudo make install"
