#!/bin/bash
cd corectrl
mkdir build
cd build
cmake -DCMAKE_INSTALL_PREFIX=/usr -DCMAKE_BUILD_TYPE=Release -DBUILD_TESTING=OFF ..
paco -lp corectrl "make"
