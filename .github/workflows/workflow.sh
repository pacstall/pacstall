#!/bin/bash
apt update -qq
apt install curl sudo git wget bc -y -qq
export PACSTALL_SKIP_NETWORK_CHECK=1
echo "N" | sudo bash -c "$(curl -fsSL https://git.io/JsADh || wget -q https://git.io/JsADh -O -)"
useradd -m -d /home/pacstall pacstall
usermod -a -G sudo pacstall

# chowning
METADIR="/var/log/pacstall/metadata"
LOGDIR="/var/log/pacstall/error_log"
SCRIPTDIR="/usr/share/pacstall"
PACDIR="/tmp/pacstall"
chown pacstall -R "$PACDIR"
chown pacstall -R "$METADIR"
chown pacstall -R "$LOGDIR"
export LOGNAME="pacstall"

echo '%sudo ALL=(ALL) NOPASSWD:ALL' >> /etc/sudoers
sudo -u pacstall bash -c : && RUNAS="sudo -u pacstall"

$RUNAS bash << _
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
