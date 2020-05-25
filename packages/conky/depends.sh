#!/bin/bash
if [ command -v apt -eq /usr/bin/apt ]
then
    sudo apt-get install -y cmake libimlib2-dev libncurses5-dev libx11-dev libxdamage-dev libxft-dev libxinerama-dev libxml2-dev libxext-dev libcurl4-openssl-dev liblua5.3-dev
else
    echo "Are you running an Arch Linux based system?"
    select yn in "Yes" "No"
    case $yn in
        Yes ) sudo pacman -S glib2 imlib2 libpulse libxdamage libxft libxml2 libxnvctrl lua git;;
        No ) echo "Your system is not supported" && exit;;
    esac
fi
