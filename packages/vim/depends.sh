#!/bin/bash
if [ command -v apt -eq /usr/bin/apt ]
then
sudo apt install -y libncurses5-dev libgnome2-dev libgnomeui-dev \
  libgtk2.0-dev libatk1.0-dev libbonoboui2-dev \
  libcairo2-dev libx11-dev libxpm-dev libxt-dev
fi
if [ command -v dnf -eq /usr/bin/dnf ]
then
sudo dnf install -y vim-common
fi
