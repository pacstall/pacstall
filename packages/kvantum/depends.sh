#!/bin/bash
value=$( command -v apt )
if [ $value -eq /usr/bin/apt ]
then
  echo "Debian based system recognized, installing dependencies"
  sudo apt install -y qtbase5-dev libqt5svg5-dev libqt5x11extras5-dev libkf5windowsystem-dev
else
  echo "Debian based system not recognized... Trying Arch based"
  value=$( command -v pacman )
  if [ $value -eq /usr/bin/pacman ]
  then
    echo "Arch based system recognized, installing dependencies"
    sudo pacman -S qtbase5-dev libqt5svg5-dev libqt5x11extras5-dev libkf5windowsystem-dev
  fi
fi
