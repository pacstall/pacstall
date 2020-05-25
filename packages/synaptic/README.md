Synaptic
========

Synaptic is a graphical package management program for apt. It
provides the same features as the apt-get command-line utility with a
GUI front-end based on GTK+ or WINGs.

Synaptic was developed by Alfredo K. Kojima <kojima@conectiva.com.br>
from Connectiva. His last offical released was 0.16. I took over his
CVS version, where he added a nearly complete port to GTK+. I
completed the port and add some new features. See the NEWS file for
the user visible changes from that point on. Connectiva is still
supporting the development of synaptic. Gustavo Niemeyer
<niemeyer@conectiva.com> is a active developer of synaptic.

If you want to use synaptic from the GNOME menu, you should use pkexec
(default) to obtain root privileges. 

Synaptic can display a "Pkg Help" button on Debian systems. If you have 
installed and configured dwww, a help will be display and if you click 
on it, a browser is opened. 

It is also possible on Debian systems to reconfigure debconf packages.
This is done with the help of libgnome2-perl that needs to be installed.

On a Debian system, you can have more than one "release" in your
sources.list file. You can choose which one to use in the "expert" tab
in the preferences dialog. 

All development is done at https://github.com/mvo5/synaptic

Tutorial:
---------
Synaptic is used very much like apt-get. Usually you do a 
"update" which will update the package list from the servers in your
sources.list file. Note that no packages are updated in this step,
only information about the packages. Now you can view what packages
are "upgradeable". To do this, just click on the filter "Upgradeable".
The main list will change and you will see only those packages where
a new version is available on the server. You can now upgrade
inidiviual packages by selecting them and then clicking on the small
"upgrade" button on the left (or double click in the gtk-version) or
thos to upgrade all packages by clicking on the big "Upgrade" button
on the top. No packages will downloaded/upgraded yet, they are only
marked as to be upgraded. You may want to change the filter again to
"Expected Changes" to see what will happen if you continue. If you
like what you see, click "Proceed!" and synaptic will download the
packages and install them. 


Filters:
--------
Synaptic display the main package list according to the filter you
selected. The most simple filter is of course "All packages". But
there are much more filters than that :) You can view the predefiend
filters and make your own filters by clicking on "Filters" above the
main package list. 

Keybindings:
------------
From version 0.20 on, the GTK has some global keybings:
* Alt-K  keep
* Alt-I  install
* Alt-R  remove
* Alt-U  Update individual package
* Alt-L  Update Package List
* Alt-G  upgrade
* Alt-D  DistUpgrade
* Alt-P  proceed
* Ctrl-F find

Command line options:
---------------------
From version 0.25 on, synaptic supports the following command-line options:
 '-f <filename>' or "--filter-file <filename>" = give a alternative filter file
 '-i <int>' or "--initial-filter <int>" = start with filter nr. <int>
 '-r' = open repository screen on startup
 '-o <option>' or "--option <option>" = set a synaptic/apt option (expert only)
 '--set-selections' = feed packages inside synaptic (format is like
                      dpkg --get-selections)
 '--non-interactive' = non-interactive mode (this will also prevent saving 
                       of configuration options)

Selecting Multiple Packages
----------------------------
From 0.25 on, you can select more than one package at a time. You have to
use Shift or Ctrl to select multiple packages. If you click on a action 
(install/upgrade/remove) for multiple packages, the action will be performed
for each package (as you probably already guessed (: ).


Contacting me
-------------
If you have any questions, suggestions or bugreports, send a email
to synaptic-devel@mail.freesoftware.fsf.org or directly to me (mvo@debian.org).


Have fun with synaptic,
 Michael Vogt
