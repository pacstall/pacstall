#!/bin/bash
make
if sudo checkinstall ; then
    echo "checkinstall succeeded"
else
    echo "checkinstall failed... running make install"
    sudo make install
fi
