#!/bin/bash
./configure 
make 
if sudo checkinstall ; then
    echo "checkinstall succeded"
else
    echo "checkinstall failed... running make install"
    sudo make install
fi
