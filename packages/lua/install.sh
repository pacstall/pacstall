#!/bin/bash
make linux test
sudo paco -lp lua "make install"
