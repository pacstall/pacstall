#!/bin/bash
if [ command -v apt -eq /usr/bin/apt ]
then
sudo apt install -y libc6 libncursesw6 libtinfo6
fi
if [ command -v dnf -eq /usr/bin/dnf ]
then
sudo dnf install -y file-libs glibc ncurses-libs
fi
