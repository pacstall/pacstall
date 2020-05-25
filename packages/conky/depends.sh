#!/bin/bash

if [ command -v apt -eq /usr/bin/apt ]
then
    sudo apt-get install -y cmake libimlib2-dev libncurses5-dev libx11-dev libxdamage-dev libxft-dev libxinerama-dev libxml2-dev libxext-dev libcurl4-openssl-dev liblua5.3-dev
fi
