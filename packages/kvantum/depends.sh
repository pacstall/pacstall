#!/bin/bash
if [ command -v apt -eq /usr/bin/apt ]
then
sudo apt install -y qtbase5-dev libqt5svg5-dev libqt5x11extras5-dev
fi
if [ command -v pacman -eq /usr/bin/pacman ]
then
sudo pacman -S qt5-base qt5-svg qt5-x11extras
fi
