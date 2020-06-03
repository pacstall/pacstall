#!/bin/bash
if [ command -v apt -eq /usr/bin/apt ]
then
sudo apt install -y build-essential build-dep emacs24
fi
if [ command -v dnf -eq /usr/bin/dnf ]
then
sudo dnf install -y emacs-common liblockfile lobotf
fi
