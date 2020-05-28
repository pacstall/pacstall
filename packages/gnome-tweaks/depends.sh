#!/bin/bash
equals=$(command -v apt)
if [ $equals == /usr/bin/apt ] ; then
    sudo apt install -y python3-pip
fi
equals=$(command -v dnf)
if [ $equals == /usr/bin/dnf ] ; then
    sudo dnf install -y python3-pip ninja-build python27 python3-setuptools
fi
pip3 install --user meson
