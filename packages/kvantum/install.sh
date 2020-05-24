sudo apt install -y qtbase5-dev libqt5svg5-dev libqt5x11extras5-dev libkf5windowsystem-dev
mkdir build && cd build
cmake ..
make
sudo make install
