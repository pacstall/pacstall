### Proper Packaging

---

Read [Proper Pacscript](https://raw.githubusercontent.com/Henryws/pacstall/master/misc/docs/pacscript.md) first.

#### Terminology

$PACKAGE: Your package, generally relating to the GitHub directory (github.com/name/repo/packages/$PACKAGE)



1: don't add version="master". It doesn't have a version number, and it's lazy. Even though there is a master directory in your $PACKAGE directory, that is for the latest version available, since most people won't bother to look up what the latest version is and install with ```sudo pacstall -I foo@1.1``` or something like that.

2: Proper layout of your $PACKAGE directory. It should be something like this:

![](https://github.com/Henryws/pacstall/raw/1.0.4-Celeste/website-images/pacstall_tree.png)

That is to make falling back to a certain version easy.

3: If your PACSCRIPT contains variables, just as the AUR, add an underscore (_) to the front of the variable in question so there is no confusion.

4: $name and $pkgname are different! $pkgname is the name of the executable to run. $name is generic. The reason behind this is GNOME settings... I'm looking at YOU!
