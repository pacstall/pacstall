# CoreCtrl

[![CoreCtrl 1.0 overview video](https://gitlab.com/corectrl/corectrl/wikis/img/overview-1.0.png)](https://www.youtube.com/watch?v=6uchS6OiwiU)

**CoreCtrl** is a Free and Open Source GNU/Linux application that allows you to control with ease your computer hardware using application profiles. It aims to be flexible, comfortable and accessible to regular users.

There are already others GNU/Linux applications that allow you to control your hardware. *Some* of them are pretty good. *Most* of them are not built with regular users in mind and/or are focused on some specific hardware or features, so usually you end up with multiple control programs installed and running at the same time, each of them having its own specific configuration. Also, most of them do not respond to external events other that the hardware events they control so, if you want to change the behavior of the system for a given period of time, let's say, during one specific program execution, you have to manually interact with each control program in order to change its behavior, before and after that specific program execution.

All of this is perceived by regular users as a big burden or even a barrier that impedes them to migrate to GNU/Linux for some specific tasks (as gaming).

**CoreCtrl** aims to be a game changer in this particular field. You can use it to automatically configure your system when a program is launched (works for Windows applications too). It doesn't matter what the program is, a game, a 3D modeling application, a video editor or... even a compiler! It offers you full hardware control per application.

The actual version of **CoreCtrl** automatically apply profiles for native and Windows applications, has basic CPU controls and full AMD GPUs controls (for both old and new models). The goal is to support as much hardware as possible, even from other vendors. Please, see [Future work](https://gitlab.com/corectrl/corectrl/wikis/home#future-work) for more details.

## Installation

### Distribution packages

This list may contain unofficial distribution packages. For security reasons, always be extra careful on what you install on your system. I you are suspicious about them, you can wait until you distribution packages CoreCtrl officially or you can install it from the [source code](https://gitlab.com/corectrl/corectrl/wikis/Installation). If you find something wrong or malicious on any of them, please open an issue so the list can be updated.

#### Arch Linux

Install [corectrl](https://aur.archlinux.org/packages/corectrl/) from the AUR.

With `yay`, run:

    yay -Sy corectrl

#### Fedora

    sudo dnf install corectrl

#### Gentoo

Add the [farmboy0](https://github.com/farmboy0/portage-overlay) overlay.

Then run:

    emerge --ask --verbose kde-misc/corectrl

#### openSUSE

Install the [corectrl](https://software.opensuse.org/download.html?project=home%3ADead_Mozay&package=corectrl) package from OBS.

#### Ubuntu

Add the [`Ernst ppa-mesarc`](https://launchpad.net/~ernstp/+archive/ubuntu/mesarc) PPA.

Then run:

    sudo apt install corectrl

#### Others

For other installation methods and setup instructions, please go to the [project wiki](https://gitlab.com/corectrl/corectrl/wikis/home).
