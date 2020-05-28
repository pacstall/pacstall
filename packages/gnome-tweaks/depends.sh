#!/bin/bash
equals=$(command -v apt)
if [ $equals == /usr/bin/apt ] ; then
    sudo apt install -y python3-pip
    pip3 install meson
fi
equals=$(command -v dnf)
if [ $equals == /usr/bin/dnf ] ; then
    sudo dnf install -y python3-pip ninja-build python27 python3-setuptools
    pip3 install meson
fi

