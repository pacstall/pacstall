#!/bin/bash
mkdir build
cd build
cmake ..
make
if sudo checkinstall ; then
    echo "checkinstall succeeded"
else
    echo "checkinstall failed... running make install"
    make install
fi
