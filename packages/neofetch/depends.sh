#!/bin/bash
equals=$(command -v apt)
if [ $equals == /usr/bin/apt ] ; then
    sudo apt install -y w3m-img libsixel termpix pixterm catimg jp2a caca-utils libcaca
fi
equals=$(command -v dnf)
if [ $equals == /usr/bin/dnf ] ; then
    sudo dnf install -y w3m-img caca-utils libcaca
fi
