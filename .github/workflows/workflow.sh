#!/bin/bash

apt install -y sudo bc wget iputils-ping network-manager
# sudo bash -c "$(curl -fsSL https://git.io/JsADh || wget -q https://git.io/JsADh -O -)"
wget https://github.com/pacstall/pacstall/releases/download/1.6/pacstall-1.6.deb
apt install -y ./pacstall-1.6.deb
useradd -m -d /home/pacstall pacstall
usermod -a -G sudo pacstall
echo '%sudo ALL=(ALL) NOPASSWD:ALL' >> /etc/sudoers
sudo -u pacstall bash -c : && RUNAS="sudo -u pacstall"

$RUNAS bash<<_
export TERM="xterm"
echo "Installing neofetch"
pacstall -PI neofetch
if [[ $? -ne 0 ]]; then
	echo "Something went wrong"
	exit 1
fi
echo "Installing deb package"
pacstall -PI brave-browser-beta-deb
if [[ $? -ne 0 ]]; then
	echo "Something went wrong"
	exit 1
fi
echo "Testing removal"
pacstall -PR neofetch
if [[ $? -ne 0 ]]; then
	echo "Something went wrong"
	exit 1
fi
_
