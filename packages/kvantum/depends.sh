#!/bin/bash
if [ command -v apt == /usr/bin/apt ]
then
sudo apt install -y qtbase5-dev libqt5svg5-dev libqt5x11extras5-dev
fi
if [ command -v dnf == /usr/bin/dnf ]
then
sudo dnf install -y gcc-c++ libX11-devel libXext-devel qt5-qtx11extras-devel qt5-qtbase-devel qt5-qtsvg-devel qt5-qttools-devel kf5-kwindowsystem-devel
fi
