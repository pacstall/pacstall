<p align="center">
<a href="https://choosealicense.com/licenses/gpl-3.0/"><img src="https://img.shields.io/badge/license-GPL-blue.svg?style=flat-square&logo"></a>
<a href="https://github.com/Henryws/pacstall/releases/latest"><img src="https://img.shields.io/github/v/release/Henryws/pacstall?color=red&style=flat-square"></a>
<a href="https://www.gnu.org/software/bash/"><img src="https://img.shields.io/badge/bash-v5-brightgreen?style=flat-square&logo" alt="Bash v5"></a>
  <a href="https://github.com/Henryws/pacstall/issues"><img src="https://img.shields.io/github/issues/Henryws/pacstall?style=flat-square"></a>
<a href="https://github.com/Henryws/pacstall/actions?query=workflow%3A%22test+install+script%22"><img src="https://img.shields.io/github/workflow/status/Henryws/pacstall/test%20install%20script?style=flat-square"></a>
</p>

<p align="center"><b>PACSTALL</b></p>
<p align="center"><b>The AUR Ubuntu never had</b></p>
<a href="https://github.com/Henryws/pacstall">
  <img src="https://imgur.com/a/NXiSzja" align="right" />
</a>

> Mimics the AUR by installing dependencies from apt and then building the package from source
<p align="center"><b>Mimics the AUR by installing dependencies from package manager and then building package from source</b></p>
</p>

---

### Installing

You can grab the deb file [here](https://github.com/Henryws/pacstall/releases/latest). If that's not your thing you can run this command:

```bash
sudo bash -c "$(curl -fsSL https://git.io/JfHDM)"
```

### Info
This is not the repository for pacscripts (PKGBUILD). They are [here](https://github.com/Henryws/pacstall-programs). Even though there are packages here, they are for testing pacstall, so I don't have to jump back and forth between repo's

---

## Basic Commands

```bash
sudo pacstall -I foo
``` 
This will install foo

```bash
sudo pacstall -R foo
```
This will remove foo

```bash
sudo pacstall -S foo
```
This will search for foo in repositories

```bash
sudo pacstall -C
```
This will open a window where you can choose a repository

```bash
sudo pacstall -U
```
This will update pacstall
