#!/bin/bash
make linux test
sudo porg -lp lua "make install"
