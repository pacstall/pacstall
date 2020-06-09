#!/bin/bash
equals=$(command -v apt)
if [[ equals = /usr/bin/apt ]]
then
sudo apt install -y cabal-install
fi
equals=$(command -v dnf)
if [[ $equals = /usr/bin/dnf ]]
then
sudo dnf install -y cabal-install
fi
