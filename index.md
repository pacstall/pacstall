# Welcome to Pacstall!
![Code](https://img.shields.io/github/languages/top/Henryws/pacstall?color=Red) ![GitHub last commit (branch)](https://img.shields.io/github/last-commit/Henryws/pacstall/master)

This is my attempt at making a universal package manager without having them in containers like snap, flathub and appimage. How I can make it universal is by compiling from source. Your first question is probably, wait, what about dependencies? Well, pacstall is very modular. How I made it modular is by making the process of installing packages convoluted. There's an install.sh file. There's a depends.sh file. There's an alerts.sh file. You get the point, it's modular.
Currently, most bigger sized packages only have apt install in their respective depends.sh file, but I hope to add more support for rpm distro's. I don't plan on adding much support for Arch because it has the AUR.

[<img src="https://github.com/Henryws/pacstall/blob/master/website-images/button.png">](https://github.com/Henryws/pacstall/releases)
