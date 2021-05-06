<p align="center">
<a href="https://choosealicense.com/licenses/gpl-3.0/"><img src="https://img.shields.io/badge/license-GPL-blue.svg?style=flat-square&logo"></a>
<a href="https://github.com/Henryws/pacstall/releases/latest"><img src="https://img.shields.io/github/v/release/Henryws/pacstall?color=red&style=flat-square"></a>
<a href="https://www.gnu.org/software/bash/"><img src="https://img.shields.io/badge/bash-v5-brightgreen?style=flat-square&logo" alt="Bash v5"></a>
  <a href="https://github.com/Henryws/pacstall/issues"><img src="https://img.shields.io/github/issues/Henryws/pacstall?style=flat-square"></a>
<a href="https://github.com/Henryws/pacstall/actions?query=workflow%3A%22test+install+script%22"><img src="https://img.shields.io/github/workflow/status/Henryws/pacstall/test%20install%20script?style=flat-square"></a>
<a href="https://discord.gg/yzrjXJV6K8"><img src="https://img.shields.io/discord/839818021207801878?style=flat-square"></a>
</p>

<p align="center"><b>PACSTALL</b></p>
<p align="center">
<a href="https://github.com/Henryws/pacstall"><img align="center" src="website-images/pacstall.png" alt="Pacstall Logo"></a>
</p>
<p align="center"><b>The AUR Ubuntu never had</b></p>

<p align="center">Pacstall will attempt to become the AUR Ubuntu wishes it had. It takes the AUR and puts a spin on it, making it easier to install programs without scouring github repos and the likes</p>
</p>

---

### Installing

You can grab the deb file [here](https://github.com/Henryws/pacstall/releases/latest) although they aren't as up to date as running one of the commands below. If that's not your thing you can run this command:
```bash
sudo bash -c "$(curl -fsSL https://git.io/JfHDM)"
```
Or with wget:
```bash
sudo bash -c "$(wget -q https://git.io/JfHDM -O -)"
```
### Info
This is not the repository for pacscripts (PKGBUILD). They are [here](https://github.com/Henryws/pacstall-programs). Even though there are packages here, they are for testing pacstall, so I don't have to jump back and forth between repo's.


---

## Basic Commands

```bash
sudo pacstall -I foo
``` 
This will install foo. Equivalent of apt install

```bash
sudo pacstall -R foo
```
This will remove foo. Equivalent of apt remove

```bash
sudo pacstall -S foo
```
This will search for foo in repositories. Equivalent of apt search

```bash
sudo pacstall -C
```
This will open a window where you can choose a repository

```bash
sudo pacstall -U
```
This will update pacstall's scripts

```bash
sudo pacstall -Up
```

This will update packages. Equivalent of apt upgrade
