#!/bin/bash
if [[ command -v pacman = /usr/bin/pacman ]]
then
sudo pacman -S dmenu freetype2 st libxinerama
fi
if [[ command -v apt = /usr/bin/apt ]]
then
sudo apt install -y dmenu freetype2 libxinerama
fi


