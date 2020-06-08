#!/bin/bash
./autogen.sh
./configure
make
paco -lp awf "make install"
