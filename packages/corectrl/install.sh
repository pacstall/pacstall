#!/bin/bash
cd corectrl
mkdir build
cd build
cmake -DCMAKE_INSTALL_PREFIX=/usr -DCMAKE_BUILD_TYPE=Release -DBUILD_TESTING=OFF ..
sudo paco -lp corectrl "make -j$(nproc)"
