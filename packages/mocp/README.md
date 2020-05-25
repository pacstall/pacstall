# MOC: Music on Console

  http://moc.daper.net

![Screenshot](https://raw.githubusercontent.com/jonsafari/mocp/master/themes/transparent-background_screenshot_thumb.png?raw=true)



What Is It?
--------------------------------------------------------------------------------

MOC (music on console) is a console audio player for Linux/Unix designed to be
powerful and easy to use.

This is an unofficial mirror, with a few small aesthetic tweaks.  It syncs with 
the subversion upstream every few weeks.
MOC makes it easy to use multimedia keys on your keyboard, which is discussed below.  

Prerequisites
-------------
On Debian/Ubuntu systems, you minimally need the following packages:
```Bash
sudo apt-get install gcc autoconf libtool gettext libdb-dev libpopt-dev libncursesw5-dev
```
I recommend the following packages as well:
```Bash
sudo apt-get install libasound2-dev libcurl4-openssl-dev libogg-dev libvorbis-dev libflac-dev libopus-dev libid3tag0-dev libsndfile1-dev libfaad-dev libavcodec-dev libsamplerate0-dev librcc-dev
```
**Optional**: FFmpeg adds many, many more file formats, including AAC, Opus, MP4, and WMA. You may need to first add www.deb-multimedia.org to your apt-get sources.  Then get FFmpeg:
```Bash
sudo apt-get install libavformat-dev
```

Compilation
-----------
```Bash
autoreconf -if
./configure
make -j 2
sudo make install
```

Keyboard Shortcuts
------------------
For Xfce, go to `Settings -> Keyboard -> Application Shortcuts`, then add shortcuts with
commands like `mocp --next` and others listed in `mocp --help`.  I find that the most
useful keyboard shortcuts are for the following:

* `mocp --toggle-pause` - Play/pause
* `mocp --toggle shuffle` - Enable/disable shuffle
* `mocp --next` - Skip to the next song
* `mocp --previous` - Go to the previous song
* `mocp --seek +5` - Jump 5 seconds forward
* `mocp --seek -5` - Jump 5 seconds back

In Fluxbox you can add the following to your `.fluxbox/keys` file (after using `xev`
to discover key numbers):

```bash
# Play/pause
179 :Exec mocp --toggle-pause
# Skip to next song
225 :Exec mocp --next
# Go to previous song
Mod1 225 :Exec mocp --previous
# Move forward a few seconds: ALT + >
Mod1 60 :Exec mocp --seek +5
# Move backward a few seconds: ALT + <
Mod1 59 :Exec mocp --seek -5
# Go to MOCP tab (should be first tab)
128 :Tab 1
# Toggle shuffle
152 :Exec mocp --toggle shuffle
``` 

Remote Controls
---------------
It's really easy to use a remote control with MOC.  You can use any remote that appears to your computer as a keyboard, like [this one](https://smile.amazon.com/dp/B01MSX306Z) or similar ones.  Then setup keyboard shortcuts as described above for each button you want to use to control MOC.


Original Text
-------------
The rest of the upstream README is as follows:

You just need to select a file from some directory using the menu similar to
Midnight Commander, and MOC will start playing all files in this directory
beginning from the chosen file.  There is no need to create playlists as in
other players.

If you want to combine some files from one or more directories in one playlist,
you can do this.  The playlist will be remembered between runs or you can save
it as an m3u file to load it whenever you want.

Need the console where MOC is running for more important things?  Need to close
the X terminal emulator?  You don't have to stop playing - just press q and the
interface will be detached leaving the server running.  You can attach it later,
or you can attach one interface in the console, and another in the X terminal
emulator, no need to switch just to play another file.

MOC plays smoothly, regardless of system or I/O load because it uses the output
buffer in a separate thread.  The transition between files is gapless, because
the next file to be played is precached while the current file is playing.

Supported file formats are: MP3, Ogg Vorbis, FLAC, Musepack (mpc), Speex, Opus,
WAVE, those supported by FFmpeg/LibAV (e.g., WMA, RealAudio, AAC, MP4), AIFF,
AU, SVX, Sphere Nist WAV, IRCAM SF, Creative VOC, SID, wavpack, MIDI and
modplug.

Other features:

  - Simple mixer
  - Color themes
  - Menu searching (playlist or directory) like M-s in Midnight Commander
  - The way MOC creates titles from tags is configurable
  - Optional character set conversion for file tags using iconv()
  - OSS, ALSA, SNDIO and JACK output
  - User defined keys
  - Cache for files' tags


Documentation and The MOC Forum
--------------------------------------------------------------------------------

This file is only a brief description of MOC, for more information is
available on the home page (http://moc.daper.net/documentation).

You can also find a discussion forum on the MOC home page.


What Software Is Required To Build It?
--------------------------------------------------------------------------------

To build MOC from the distribution tarball you will need:

  - A POSIX.1-2001 compatible UNIX system with POSIX threads
    (e.g., Linux or OSX)
  - A C compiler which is C99 capable and a C++ compiler (MOC is written
    in C, but libtool and some decoder plugins require a C++ compiler)
  - ncurses (probably already installed in your system)
  - POPT (libpopt) (probably already installed in your system)
  - Berkeley DB (libdb) version 4.1 (unless configured with --disable-cache)
  - GnuPG (gpg) if you are going to verify the tarball (and you should)

If you are building from the SVN repository you will also need:

  - Subversion or git-svn (to checkout the source directory tree)
  - Autoconf version 2.64 and the associated Automake and Libtool

You should choose which of the following audio formats you wish to play and
provide the libraries needed to support them:

  - AAC - libfaad2 version 2.7 (http://www.audiocoding.com/), and
    libid3tag (http://www.underbit.com/products/mad/)
  - FLAC - libFLAC version 1.1.3 (http://flac.sourceforge.net/)
  - MIDI - libtimidity version 0.1 (http://timidity.sourceforge.net/)
  - modplug - libmodplug version 0.7 (http://modplug-xmms.sourceforge.net/)
  - MP3 - libmad with libid3tag (ftp://ftp.mars.org/pub/mpeg/)
  - Musepack (mpc)
    - libmpcdec (http://www.musepack.net/), and
    - taglib version 1.3.1 (http://developer.kde.org/~wheeler/taglib.html)
  - Ogg Vorbis
    - libvorbis, libogg and libvorbisfile (all version 1.0) (http://www.xiph.org/ogg/), or
    - libvorbisidec and libogg (both version 1.0) (http://svn.xiph.org/trunk/Tremor)
  - SID - libsidplay2 version 2.1.1 and libsidutils version 1.0.4
    (http://sidplay2.sourceforge.net/)
  - Speex
    - libspeex version 1.0 (http://www.speex.org/), and
    - libogg version 1.0 (http://www.xiph.org/ogg/)
  - WMA, RealAudio (.ra), MP4
    - FFmpeg version 0.7 (http://www.ffmpeg.org/), or
    - LibAV version 0.7 (http://www.libav.org/)
  - WAVE, AU, AIFF, SVX, SPH, IRC, VOC - libsndfile version 1.0 (http://www.mega-nerd.com/libsndfile/)
  - wavpack - libwavpack version 4.31 (http://www.wavpack.com/)

For interfacing to the sound sub-system, you will need libraries for one or
more of the following:

  - ALSA - alsa-lib version 1.0.11 (http://www.alsa-project.org/)
  - OSS - the OSS libraries (http://www.opensound.com/)
  - BSD's SNDIO - SNDIO libraries
  - JACK low-latency audio server - JACK version 0.4 (http://jackit.sourceforge.net/)

For network streams:

  - libcurl version 7.15.1 (http://curl.haxx.se/)

For resampling (playing files with sample rate not supported by your
hardware):

  - libresamplerate version 0.1.2 (http://www.mega-nerd.com/SRC/)

For librcc (fixes encoding in broken mp3 tags):

  - http://rusxmms.sourceforge.net

Note that for Debian-based distributions, you will also require any '-dev'
suffixed versions of the packages above if building from source.

The versions given above are minimum versions and later versions should also
work.  However, MOC may not yet have caught up with the very latest changes
to library interfaces and these may cause problems if they break backwards
compatibility.


On Which Systems Is MOC Running?
--------------------------------------------------------------------------------

MOC is developed and tested on GNU/Linux.

MOC is now C99 and POSIX.1-2001 compliant and so should build and run on
any system which has a C99 capable compiler and is POSIX.1-2001 compatible.
However, there may still be cases where MOC breaks this compliance and any
reports of such breakage are welcome.

There is no intention to support MOC on MS-Windows (so please don't ask).


How Do I Verify the Authenticity of the Tarball?
--------------------------------------------------------------------------------

If you downloaded the official MOC distribution you should have the
following files:

	moc-2.6-alpha2.tar.asc
	moc-2.6-alpha2.tar.md5
	moc-2.6-alpha2.tar.xz

would check the integrity of the download:

	md5sum -c moc-2.6-alpha2.tar.md5

and then verify the tarball thusly:

	xzcat moc-2.6-alpha2.tar.xz | gpg --verify moc-2.6-alpha2.tar.asc -

The signature file (\*.asc) was made against the uncompressed tarball,
so if the tarball you have has been recompressed using a tool other
than XZ then uncompress it using the appropriate tool then verify that:

	gunzip moc-2.6-alpha2.tar.gz
	gpg --verify moc-2.6-alpha2.tar.asc

If the tool can output to stdout (and most can) then you can also verify
verify it in a single step similar to the way in which the XZ tarball
was verified above.

Of course, you'll also need the MOC Release Signing Key:

	gpg --recv-key 0x2885A7AA

for which the fingerprint is:

	5935 9B80 406D 9E73 E805  99BE F312 1E4F 2885 A7AA


How Do I Build and Install It?
--------------------------------------------------------------------------------

Generic installation instruction is included in the INSTALL file.

In short, if you are building from an SVN checkout of MOC (but not if you
are building from a downloaded tarball) then you will first need to run:

	autoreconf -if

and then proceed as shown below for a tarball.  (If you are using the
tarball but have applied additional patches then you may also need to run
autoreconf.)

To build MOC from a downloaded tarball just type:

	./configure
	make

And as root:

	make install

Under FreeBSD and NetBSD (and possibly other systems) it is necessary to
run the configure script this way:

	./configure LDFLAGS=-L/usr/local/lib CPPFLAGS=-I/usr/local/include

In addition to the standard configure options documented in the INSTALL
file, there are some MOC-specific options:

	--enable-cache=[yes|no]

	  Specifying 'no' will disable the tags cache support.  If your
	  intent is to remove the Berkeley DB dependancy (rather than
	  simply removing the on-disk cache) then you should also either
	  build MOC without RCC support or use a librcc built with BDB
	  disabled.

	--enable-debug=[yes|no|gdb]

	  Using 'gdb' will cause MOC to be built with options tailored to
	  use with GDB.  (Note that in release 2.6 this option will be
	  split into separate debugging and logging options.)

	--with-oss=[yes|no|DIR]

	  Where DIR is the location of the OSS include directory (and
	  defaults to '/usr/lib/oss').

	--with-vorbis=[yes|no|tremor]

	  Using 'tremor' will cause MOC to build against the integer-only
	  implementation of the Vorbis library (libvorbisidec).

You can install MOC into its own source directory tree and run it from there
so you do not have to install it permanently on your system.  If you're just
wanting to try it out or test some patches, then this is something you may
wish to do:

	./configure --prefix="$PWD" --without-timidity
	make
	make install
	bin/mocp -M .moc


How Do I Use It?
--------------------------------------------------------------------------------

Run program with the 'mocp' command.  The usage is simple; if you need help,
press 'h' and/or read mocp manpage.  There is no complicated command line or
cryptic commands.  Using MOC is as easy as using basic functions of Midnight
Commander.

You can use a configuration file placed in ~/.moc/config, but it's not required.
See config.example provided with MOC.


Using Themes
--------------------------------------------------------------------------------

Yes, there are themes, because people wanted them. :)

Themes can change all colors and only colors.  An example theme file with a
exhaustive description is included (themes/example_theme) and is the
default MOC appearance.

Theme files should be placed in ~/.moc/themes/ or $(datadir)/moc/themes/
(e.g., /usr/local/share/moc/themes) directory, and can be selected with
the Theme configuration options or the -T command line option (see the
manpage and the example configuration file).

Feel free to share the themes you have created.


Defining Keys
--------------------------------------------------------------------------------

You can redefine standard keys.  See the instructions in the keymap.example file.


How Do I Report A Problem?
--------------------------------------------------------------------------------

Not every release is extensively tested on every system, so the particular
configuration of software, libraries, versions and hardware on your system
might expose a problem.

If you find any problems then you should search the MOC Forum for a solution;
your problem may not be unique.  If you do find an existing topic which
matches your problem but does not offer a solution, or the solution offered
does not work for you and the topic appears still active, then please add your
experience to it; it may be that additional information you can provide will
contain the clue needed to resolve the problem.

If you don't find an answer there and you installed MOC from your Linux
distribution's repository then you should report it via your distribution's
usual reporting channels in the first instance.  If the problem is ultimately
identified as actually being in MOC itself, it should then be reported to the
MOC Maintainer (preferably by the distribution's MOC package maintainer).

If you built MOC from source yourself or you get no resolution from your
distribution then start a new topic on the MOC Forum for your problem or
contact the MOC Maintainer.

Before reporting a problem, you should first read this Forum post:

   Linkname: How to Report Bugs Effectively
        URL: http://moc.daper.net/node/1035

and the essay it references:

   Linkname: How to Report Bugs Effectively
        URL: http://www.chiark.greenend.org.uk/~sgtatham/bugs.html

There are two things you must do if at all possible:

1. Make sure you are using the current stable MOC release or, even better,
   can reproduce it on the latest development release or SVN HEAD, and
2. Make sure you include the version and revision information (which you
   can obtain by running 'mocp --version').

If you do not do those two things (and don't offer a good explanation as to
why you didn't) your problem report is likely to be ignored until such time
as you do.


Hacking
--------------------------------------------------------------------------------

Want to modify MOC?  You're welcome to do so, and patch contributions are
also welcome.

MOC is written in C, so you must at least know this language to make simple
changes.  It is multi-threaded program, but there are places where you don't
need to worry about that (the interface is only a single thread process).  It
uses autoconf, automake and libtool chain to generate configuration/compilation
stuff, so you must know how to use it, for example, if you need to link to an
additional library.

The documentation for some parts of the internal API for creating decoder
plugins (file format support) and sound output drivers can be generated using
Doxygen (http://www.doxygen.org/).  Just run the doxygen command from the MOC
source directory.

Before you change anything it is a good idea to check for the latest development
version (check out from the Subversion repository is the best).  Your changes
might conflict with changes already made to the source or your feature might be
already implemented.  See also the TODO file as it is updated regularly and
contains quite detailed information on future plans.

If you need help, just contact MOC's Maintainer via e-mail.  And if you are
planning anything non-trivial it's a good idea to discuss your intentions
with the MOC Maintainer once you've clarified your ideas but before spending
too much time implementing them; it will be more productive if your work fits
with MOC's future direction.


Who Wrote It?  Where Can I Send Bug Reports, Questions or Comments?
--------------------------------------------------------------------------------

- Original author is Damian Pietras
- Current maintainer is John Fitzgerald
- For comments and questions see the official forum: http://moc.daper.net/forum
- Need to report a bug?  You can reach the maintainer(s) at: <mocmaint@daper.net>
