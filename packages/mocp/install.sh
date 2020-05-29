#!/bin/bash
autoreconf -if
./configure
make -j 2
if sudo checkinstall ; then
    echo "checkinstall succeded"
else
    echo "checkinstall failed... running make install"
    sudo make install
fi
