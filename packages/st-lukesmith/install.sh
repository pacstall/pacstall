#!/bin/bash
export PKG_CONFIG_PATH=/usr/lib/x86_64-linux-gnu/pkgconfig
if sudo checkinstall ; then
    echo "checkinstall succeeded"
else
    echo "checkinstall failed... running make install"
    sudo make install
fi
