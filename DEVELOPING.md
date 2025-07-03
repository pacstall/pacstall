## Porting bash to rust for Pacstall

The very first thing I want to note is that this rewrite has been in the works since 2021, and the last thing I want is another messy codebase. When porting functionality, please please **please** make sure you're not writing spaghetti code unless you have a very good reason to or it is self-contained (can be changed later without breaking other parts).

In this document, "systems" refer to parts of pacstall that make up functionality, such as the linting system, the deb builder, the CLI arg parser, etc.

One thing that I have noticed when developing bashstall is that there actually isn't that much of a need for bash itself. The only part that must recognize bash is the sourcing system.

### What ***you*** can do right now

Clone into the repo, `git checkout rs`, and if you have *ripgrep*, run:

```bash
rg 'TODO'
rg 'BUG'
```

or if you have only *grep*:

```bash
grep -rnw --exclude-dir=".git" --exclude-dir="target" -- 'TODO'
grep -rnw --exclude-dir=".git" --exclude-dir="target" -- 'BUG'
```

You can do the same for [libpacstall](https://github.com/Elsie19/libpacstall).

### How pacstall builds a package (a detailed list)

This is probably the most comprehensive and only list of every step that pacstall takes to build a package. Note that this will not include trivial things, like downloading a pacscript or parsing pacstall arguments. Also note that this list may shift between bashstall and ruststall.

When some part is completed, please check the box and add a link to the commit and code section that does this functionality, and if a section is no longer applicable in ruststall, please ~~strike it out~~ with a note explaining your reasoning.

#### `package-base.sh`

The purpose of `package-base.sh` is to be an entry point to normalizing a package with optionally child packages into a list of packages that the user may install. It also sets up the environment beforehand.

- [x] Set `nproc()` and `$NCPU`[^1] ([Done](https://github.com/Elsie19/libpacstall/blob/b140fb72726efe44d3edc5d41e37b817012519a1/src/sys/vars.rs#L52))
- [x] Ask the user to optionally edit the pacscript[^2] ([Done](https://github.com/pacstall/pacstall/blob/354a4965b2080a1779796e6236473ce7cee9122f/src/main.rs#L31))
    - [x] If the user does, the following order is used for editors ([Done](https://github.com/pacstall/pacstall/blob/354a4965b2080a1779796e6236473ce7cee9122f/src/main.rs#L33)):
        - [x] `$PACSTALL_EDITOR`
        - [x] `$EDITOR`
        - [x] `$VISUAL`
        - [x] `sensible-editor`
- [ ] Set `$DIR` and `$homedir`[^3]
    - [ ] Set `$DIR`
    - [x] Set `$homedir` ([Done](https://github.com/Elsie19/libpacstall/blob/b140fb72726efe44d3edc5d41e37b817012519a1/src/sys/vars.rs#L61))
- [ ] Move pacscript into tmp directory[^4]
    - [ ] `a+r` permissions
    - [ ] Set `$pacfile`
- [ ] Set various variables[^5]
    - [ ] Set `$FARCH`
    - [x] Set `$CARCH` ([Done](https://github.com/Elsie19/libpacstall/blob/b140fb72726efe44d3edc5d41e37b817012519a1/src/sys/vars.rs#L53))
        - [x] Normalize `$AARCH` ([Done](https://github.com/Elsie19/libpacstall/blob/b140fb72726efe44d3edc5d41e37b817012519a1/src/sys/vars.rs#L54-L58))
    - [x] Set `$DISTRO` ([Done](https://github.com/Elsie19/libpacstall/blob/b140fb72726efe44d3edc5d41e37b817012519a1/src/sys/vars.rs#L59))
    - [ ] Set `$CDISTRO`
    - [x] Set `$KVER` ([Done](https://github.com/Elsie19/libpacstall/blob/b140fb72726efe44d3edc5d41e37b817012519a1/src/sys/vars.rs#L60))
- [x] Source pacscript[^6] ([Done](https://github.com/pacstall/pacstall/blob/354a4965b2080a1779796e6236473ce7cee9122f/src/main.rs#L36))
- [ ] Prompt user for `pkgbase` install[^7]
- [ ] Run `package_override`[^8] (TODO: Ask Oren what this does, I assume it normalizes some variables)
- [ ] Entry point into packaging[^9]

#### `package.sh`

`package.sh` does most of the work to build a package.

- [ ] Set `$TARCH`[^10]
- [ ] Merge enhanced arrays?[^11]
- [ ] Run "`pre_checks()`"[^12] (This might be combined with just "`checks()`")
- [ ] Get masked packages[^13]
    - [ ] Determine if package can be installed given the masks
- [ ] Run compat checks
    - [ ] Run `is_compatible_arch()`[^14]
    - [ ] Run `get_compatible_releases()`[^15]
    - [ ] Run `get_incompatible_releases()`[^16]
    - [ ] Compare and limit kernel version[^17]
- [ ] Clean build directory[^18]
- [ ] Create deb folder skeleton[^19]
- [ ] Run `checks()`[^20]
- [ ] Deb download check[^21]
    - [ ] Download deb if the user is not installing a package, only building it
- [ ] Guard for `priority == essential`[^22]
- [ ] Reanalyze git version if applicable[^23]
    - [ ] Get git pkgver[^24]
- [ ] Warn user if reinstalling same package
    - [ ] Check if user is installing, as opposed to building[^25]
    - [ ] Check if package is installed[^25]
    - [ ] Make sure versions are the same[^25]
- [ ] Insert an abort handler[^26]
- [ ] Check if package is not installed yet
    - [ ] Handle `$replaces`[^27]
    - [ ] Handle `$*conflicts`[^28]
        - [ ] `$conflicts`
        - [ ] `$makeconflicts`
        - [ ] `$checkconflicts`
    - [ ] Handle `$breaks`[^29]
- [x] ~~Handle `$ppa`~~[^30] (Defunct, breaking version as well)
- [ ] Handle `$pacdeps`[^31] (TODO: Talk to Oren about adding `:pacdep` to packages in other arrays)
- [ ] Do whatever tf this section does[^32] (TODO: Ask Oren what this is)
- [ ] Install builddepends[^33]
    - [Function here](https://github.com/pacstall/pacstall/blob/87ffd2b546785af0acc8441bc12ada338312fab8/misc/scripts/fetch-sources.sh#L722).
- [ ] `prompt_depends`[^34]
- [ ] Go into `srcdir`[^35]
- [ ] Figure out `${PACDIR}-no-download-${pkgbase}`[^36] (I think it's the download loop)
    - [ ] Get `PACSTALL_PAYLOAD`[^37][^38]
    - [ ] Download source[^39]
- [ ] Set `$pacdir`[^40]
- [ ] Set `$pkgdir`[^41]
- [ ] Export `ask()`, `fancy_message()`, `select_options()`[^42]
    - NOTE: I think this might have to be done in bash, or we could inject builtins that we make, but we still need something for the postscripts.
- [ ] Clean logdir[^43]
- [ ] Begin installing
    - [ ] Collect functions
        - [ ] `prepare()`
        - [ ] `build()`
        - [ ] `check()` if `$NOCHECK == false`[^44]
        - [ ] `package()` with specific pkgchild suffix if needed
    - [ ] For each function, run if exists[^45]
- [ ] Reset environment[^46]
- [ ] Begin creating deb[^47]
    - [ ] Deblog `Package`[^48]
    - [ ] Deblog `Version`[^49]
        - If it doesn't begin with a number, add `0` to the beginning[^50]
    - [ ] Deblog `Architecture`[^51]
        - If `$arch` has [`Arch::All`](https://docs.rs/libpacstall/latest/libpacstall/pkg/keys/enum.Arch.html#variant.All), log only that[^52]
        - Else log `$CARCH`[^53]
    - [ ] Deblog `Section` as `Pacstall`[^54]
    - [ ] Deblog `Priority`[^55]
        - [ ] If essential, deblog `Essential` as `yes`[^56]
        - [ ] If `$priority` doesn't exist, deblog as `optional`[^57]
    - [ ] Deblog `Bugs`[^58]
        - [ ] Attempt to figure out bug tracker from installed repo[^59]
    - [ ] Deblog `Vcs-Git` if git package[^60]
        - [ ] If branch or tag is found, log that inside `Vcs-Git`[^61]
    - [ ] Start logging `$makedepends`[^62]
        - [ ] If `check()` and `$checkdepends` exists, deblog `Build-Depends` along with `$makedepends`[^63]
        - [ ] Figure out logging `Build-Depends-Arch`[^64] (TODO: Ask Oren)
    - [ ] Repeat step above but `s/depends/conflicts/`[^65]
    - [ ] Deblog `Provides`[^66]
        - [ ] Log canonical package name into `Provides`[^67]
    - [ ] Deblog `Breaks`[^68]
    - [ ] Deblog `Enhances`[^69]
    - [ ] Deblog `Recommends`[^70]
    - [ ] Deblog `Suggests`[^71]
        - [ ] Deblog `$suggests`[^72]
        - [ ] Deblog `$optdepends`[^72]
    - [ ] Deblog `Replaces`[^73]
    - [ ] Deblog `Conflicts`[^74]
    - [ ] Deblog `Homepage`[^75]
    - [ ] Deblog `License`[^76]
    - [ ] Deblog `$custom_fields`[^77]
    - [ ] Deblog `Maintainer`[^78]
        - [ ] Deblog `Uploaders`[^79]
        - [ ] log `Pacstall <pacstall@pm.me>` if no maintainer[^80]
    - [ ] Deblog `Description`[^81]
    - [ ] Put in post scripts[^82]
    - [ ] Handle `$backup`[^83]
    - [ ] Deblog `Installed-Size`[^84]
    - [ ] Generate changelog[^85] (TODO: Talk with team about how we could possibly add actual changelogs)
    - [ ] Create deb[^86]
        - [ ] Determine compression type based on intuited need[^87]
        - [ ] Set deb file format[^88]
        - [ ] Pack `control.tar`[^89]
        - [ ] Pack `data.tar`[^90]
        - [ ] Compress `control.tar` and `data.tar`[^91]
        - [ ] Create deb file[^92]
        - [ ] Cleanup[^93]
    - [ ] Install deb[^94]
        - [Function here](https://github.com/pacstall/pacstall/blob/87ffd2b546785af0acc8441bc12ada338312fab8/misc/scripts/build.sh#L670-L719)
- [ ] Log metadata[^95] (TODO: Talk with team about switching to a database)
- [ ] Cleanup
    - [ ] Store pacscript[^96]
    - [ ] Store `.SRCINFO`[^97]

### Systems

#### Loading bash code

##### Introduction

Pacstall-rs uses [brush](https://brush.sh) to handle the interop between bash and rust. [@Elsie19](https://github.com/Elsie19) has an active and quick channel where they can talk to the lead developer of brush for any requests, bugs, etc. So far, there are no issues with brush that demand immediate attention, and the entire pacscript repository can be sourced without any issues:

```bash
#!/bin/brush

set -e
for pkg in packages/*/*.pacscript; do
    source "${pkg}"
done
```

Note that *some* bash features are not implemented, but those are on the developer's radar and regardless, are not needed by pacstall.

##### Other

Currently, a pacscript is sourced by brush and immediately converted into an `SRCINFO` format. A constant goal of this rewrite is to interact with bash as little as possible, and we feel that an `SRCINFO` representation is the most representative and least frictionful format for a pacscript. One happy conclusion from this is that we get an `SRCINFO` generator inside pacstall itself that we can use as the canonical generator for everything.

Note that not everything can be mapped onto `SRCINFO`, such as functions, but we expect those to not be very annoying to deal with, as we will just be calling them on our own, no parsing needed.

If there is one thing to take away from this section, it should be that you should try to load the bash code into some rust data structure and run as fast as you can away from bash once that's done.

#### Linting/Checking

In bashstall, the checks are located in `misc/scripts/checks.sh`, and in rust they are located in `src/cmds/checks/`, where each check has it's own module where you can go crazy with however many lints you want.

Some lints inside checks may not even be needed in ruststall, because parsing is handled elsewhere. To give an example, `incompatible` and `compatible` elements do not need to be checked for improper formatting, because that is done at the `SRCINFO` conversion stage by [DistroClamp](https://docs.rs/libpacstall/latest/libpacstall/pkg/keys/struct.DistroClamp.html).

Also, test your lints!!! Even better is to make your lints into functions that can be tested via rust tests.

### What needs to happen now?

This is a list of random ideas that we could implement. I don't care what gets done as long as we do some of them:

- [ ] CI to test random packages and compare with bashstall. Preferably testing selected packages that have various behavior.
- [ ] CI to test that ruststall and bashstall output the same deb, or if that's too hard, verify that the control files are semantically the same, *AND* that the installed files are the exact same between versions.
- [ ] Discuss with team things that were nigh impossible with bash that we can do now.
- [ ] Discuss with team about breaking changes (now is the best time ever).

---

### Sources

[^1]: https://github.com/pacstall/pacstall/blob/87ffd2b546785af0acc8441bc12ada338312fab8/misc/scripts/package-base.sh#L204-L216
[^2]: https://github.com/pacstall/pacstall/blob/87ffd2b546785af0acc8441bc12ada338312fab8/misc/scripts/package-base.sh#L218-L234
[^3]: https://github.com/pacstall/pacstall/blob/87ffd2b546785af0acc8441bc12ada338312fab8/misc/scripts/package-base.sh#L237-L239
[^4]: https://github.com/pacstall/pacstall/blob/87ffd2b546785af0acc8441bc12ada338312fab8/misc/scripts/package-base.sh#L241-L244
[^5]: https://github.com/pacstall/pacstall/blob/87ffd2b546785af0acc8441bc12ada338312fab8/misc/scripts/package-base.sh#L245-L255
[^6]: https://github.com/pacstall/pacstall/blob/87ffd2b546785af0acc8441bc12ada338312fab8/misc/scripts/package-base.sh#L258-L263
[^7]: https://github.com/pacstall/pacstall/blob/87ffd2b546785af0acc8441bc12ada338312fab8/misc/scripts/package-base.sh#L101
[^8]: https://github.com/pacstall/pacstall/blob/87ffd2b546785af0acc8441bc12ada338312fab8/misc/scripts/package-base.sh#L157
[^9]: https://github.com/pacstall/pacstall/blob/87ffd2b546785af0acc8441bc12ada338312fab8/misc/scripts/package-base.sh#L161
[^10]: https://github.com/pacstall/pacstall/blob/87ffd2b546785af0acc8441bc12ada338312fab8/misc/scripts/package.sh#L32-L39
[^11]: https://github.com/pacstall/pacstall/blob/87ffd2b546785af0acc8441bc12ada338312fab8/misc/scripts/package.sh#L41
[^12]: https://github.com/pacstall/pacstall/blob/87ffd2b546785af0acc8441bc12ada338312fab8/misc/scripts/package.sh#L44-L47
[^13]: https://github.com/pacstall/pacstall/blob/87ffd2b546785af0acc8441bc12ada338312fab8/misc/scripts/package.sh#L50
[^14]: https://github.com/pacstall/pacstall/blob/87ffd2b546785af0acc8441bc12ada338312fab8/misc/scripts/package.sh#L65-L70
[^15]: https://github.com/pacstall/pacstall/blob/87ffd2b546785af0acc8441bc12ada338312fab8/misc/scripts/package.sh#L72-L76
[^16]: https://github.com/pacstall/pacstall/blob/87ffd2b546785af0acc8441bc12ada338312fab8/misc/scripts/package.sh#L77-L82
[^17]: https://github.com/pacstall/pacstall/blob/87ffd2b546785af0acc8441bc12ada338312fab8/misc/scripts/package.sh#L84-L89
[^18]: https://github.com/pacstall/pacstall/blob/87ffd2b546785af0acc8441bc12ada338312fab8/misc/scripts/package.sh#L91
[^19]: https://github.com/pacstall/pacstall/blob/87ffd2b546785af0acc8441bc12ada338312fab8/misc/scripts/package.sh#L92-L93
[^20]: https://github.com/pacstall/pacstall/blob/87ffd2b546785af0acc8441bc12ada338312fab8/misc/scripts/package.sh#L96-L99
[^21]: https://github.com/pacstall/pacstall/blob/87ffd2b546785af0acc8441bc12ada338312fab8/misc/scripts/package.sh#L102-L112
[^22]: https://github.com/pacstall/pacstall/blob/87ffd2b546785af0acc8441bc12ada338312fab8/misc/scripts/package.sh#L115-L121
[^23]: https://github.com/pacstall/pacstall/blob/87ffd2b546785af0acc8441bc12ada338312fab8/misc/scripts/package.sh#L124-L132
[^24]: https://github.com/pacstall/pacstall/blob/87ffd2b546785af0acc8441bc12ada338312fab8/misc/scripts/package.sh#L126
[^25]: https://github.com/pacstall/pacstall/blob/87ffd2b546785af0acc8441bc12ada338312fab8/misc/scripts/package.sh#L134
[^26]: https://github.com/pacstall/pacstall/blob/87ffd2b546785af0acc8441bc12ada338312fab8/misc/scripts/package.sh#L139
[^27]: https://github.com/pacstall/pacstall/blob/87ffd2b546785af0acc8441bc12ada338312fab8/misc/scripts/package.sh#L142-L152
[^28]: https://github.com/pacstall/pacstall/blob/87ffd2b546785af0acc8441bc12ada338312fab8/misc/scripts/package.sh#L154-L177
[^29]: https://github.com/pacstall/pacstall/blob/87ffd2b546785af0acc8441bc12ada338312fab8/misc/scripts/package.sh#L178-L198
[^30]: https://github.com/pacstall/pacstall/blob/87ffd2b546785af0acc8441bc12ada338312fab8/misc/scripts/package.sh#L201-L206
[^31]: https://github.com/pacstall/pacstall/blob/87ffd2b546785af0acc8441bc12ada338312fab8/misc/scripts/package.sh#L208-L248
[^32]: https://github.com/pacstall/pacstall/blob/87ffd2b546785af0acc8441bc12ada338312fab8/misc/scripts/package.sh#L250-L279
[^33]: https://github.com/pacstall/pacstall/blob/87ffd2b546785af0acc8441bc12ada338312fab8/misc/scripts/package.sh#L280
[^34]: https://github.com/pacstall/pacstall/blob/87ffd2b546785af0acc8441bc12ada338312fab8/misc/scripts/build.sh#L233
[^35]: https://github.com/pacstall/pacstall/blob/87ffd2b546785af0acc8441bc12ada338312fab8/misc/scripts/package.sh#L286
[^36]: https://github.com/pacstall/pacstall/blob/87ffd2b546785af0acc8441bc12ada338312fab8/misc/scripts/package.sh#L288
[^37]: https://github.com/pacstall/pacstall/blob/87ffd2b546785af0acc8441bc12ada338312fab8/misc/scripts/package.sh#L293
[^38]: https://github.com/pacstall/pacstall/blob/87ffd2b546785af0acc8441bc12ada338312fab8/misc/scripts/package.sh#L299-L305
[^39]: https://github.com/pacstall/pacstall/blob/87ffd2b546785af0acc8441bc12ada338312fab8/misc/scripts/package.sh#L317-L356
[^40]: https://github.com/pacstall/pacstall/blob/87ffd2b546785af0acc8441bc12ada338312fab8/misc/scripts/package.sh#L362
[^41]: https://github.com/pacstall/pacstall/blob/87ffd2b546785af0acc8441bc12ada338312fab8/misc/scripts/package.sh#L365
[^42]: https://github.com/pacstall/pacstall/blob/87ffd2b546785af0acc8441bc12ada338312fab8/misc/scripts/package.sh#L366
[^43]: https://github.com/pacstall/pacstall/blob/87ffd2b546785af0acc8441bc12ada338312fab8/misc/scripts/package.sh#L368
[^44]: https://github.com/pacstall/pacstall/blob/87ffd2b546785af0acc8441bc12ada338312fab8/misc/scripts/package.sh#L374-L375
[^45]: https://github.com/pacstall/pacstall/blob/87ffd2b546785af0acc8441bc12ada338312fab8/misc/scripts/package.sh#L385-L389
[^46]: https://github.com/pacstall/pacstall/blob/87ffd2b546785af0acc8441bc12ada338312fab8/misc/scripts/package.sh#L408
[^47]: https://github.com/pacstall/pacstall/blob/87ffd2b546785af0acc8441bc12ada338312fab8/misc/scripts/package.sh#L409
[^48]: https://github.com/pacstall/pacstall/blob/87ffd2b546785af0acc8441bc12ada338312fab8/misc/scripts/build.sh#L369
[^49]: https://github.com/pacstall/pacstall/blob/87ffd2b546785af0acc8441bc12ada338312fab8/misc/scripts/build.sh#L372
[^50]: https://github.com/pacstall/pacstall/blob/87ffd2b546785af0acc8441bc12ada338312fab8/misc/scripts/build.sh#L375
[^51]: https://github.com/pacstall/pacstall/blob/87ffd2b546785af0acc8441bc12ada338312fab8/misc/scripts/build.sh#L380-L384
[^52]: https://github.com/pacstall/pacstall/blob/87ffd2b546785af0acc8441bc12ada338312fab8/misc/scripts/build.sh#L381
[^53]: https://github.com/pacstall/pacstall/blob/87ffd2b546785af0acc8441bc12ada338312fab8/misc/scripts/build.sh#L383
[^54]: https://github.com/pacstall/pacstall/blob/87ffd2b546785af0acc8441bc12ada338312fab8/misc/scripts/build.sh#L385
[^55]: https://github.com/pacstall/pacstall/blob/87ffd2b546785af0acc8441bc12ada338312fab8/misc/scripts/build.sh#L387-L392
[^56]: https://github.com/pacstall/pacstall/blob/87ffd2b546785af0acc8441bc12ada338312fab8/misc/scripts/build.sh#L389
[^57]: https://github.com/pacstall/pacstall/blob/87ffd2b546785af0acc8441bc12ada338312fab8/misc/scripts/build.sh#L391
[^58]: https://github.com/pacstall/pacstall/blob/87ffd2b546785af0acc8441bc12ada338312fab8/misc/scripts/build.sh#L395
[^59]: https://github.com/pacstall/pacstall/blob/87ffd2b546785af0acc8441bc12ada338312fab8/misc/scripts/build.sh#L399
[^60]: https://github.com/pacstall/pacstall/blob/87ffd2b546785af0acc8441bc12ada338312fab8/misc/scripts/build.sh#L404-L416
[^61]: https://github.com/pacstall/pacstall/blob/87ffd2b546785af0acc8441bc12ada338312fab8/misc/scripts/build.sh#L409-L415
[^62]: https://github.com/pacstall/pacstall/blob/87ffd2b546785af0acc8441bc12ada338312fab8/misc/scripts/build.sh#L418-L429
[^63]: https://github.com/pacstall/pacstall/blob/87ffd2b546785af0acc8441bc12ada338312fab8/misc/scripts/build.sh#L420-L421
[^64]: https://github.com/pacstall/pacstall/blob/87ffd2b546785af0acc8441bc12ada338312fab8/misc/scripts/build.sh#L422-L428
[^65]: https://github.com/pacstall/pacstall/blob/87ffd2b546785af0acc8441bc12ada338312fab8/misc/scripts/build.sh#L431-L442
[^66]: https://github.com/pacstall/pacstall/blob/87ffd2b546785af0acc8441bc12ada338312fab8/misc/scripts/build.sh#L444
[^67]: https://github.com/pacstall/pacstall/blob/87ffd2b546785af0acc8441bc12ada338312fab8/misc/scripts/build.sh#L445
[^68]: https://github.com/pacstall/pacstall/blob/87ffd2b546785af0acc8441bc12ada338312fab8/misc/scripts/build.sh#L449-L451
[^69]: https://github.com/pacstall/pacstall/blob/87ffd2b546785af0acc8441bc12ada338312fab8/misc/scripts/build.sh#L453-L455
[^70]: https://github.com/pacstall/pacstall/blob/87ffd2b546785af0acc8441bc12ada338312fab8/misc/scripts/build.sh#L457-L459
[^71]: https://github.com/pacstall/pacstall/blob/87ffd2b546785af0acc8441bc12ada338312fab8/misc/scripts/build.sh#L461-L465
[^72]: https://github.com/pacstall/pacstall/blob/87ffd2b546785af0acc8441bc12ada338312fab8/misc/scripts/build.sh#L463
[^73]: https://github.com/pacstall/pacstall/blob/87ffd2b546785af0acc8441bc12ada338312fab8/misc/scripts/build.sh#L467-L474
[^74]: https://github.com/pacstall/pacstall/blob/87ffd2b546785af0acc8441bc12ada338312fab8/misc/scripts/build.sh#L476-L478
[^75]: https://github.com/pacstall/pacstall/blob/87ffd2b546785af0acc8441bc12ada338312fab8/misc/scripts/build.sh#L480-L482
[^76]: https://github.com/pacstall/pacstall/blob/87ffd2b546785af0acc8441bc12ada338312fab8/misc/scripts/build.sh#L484-L487
[^77]: https://github.com/pacstall/pacstall/blob/87ffd2b546785af0acc8441bc12ada338312fab8/misc/scripts/build.sh#L489-L496
[^78]: https://github.com/pacstall/pacstall/blob/87ffd2b546785af0acc8441bc12ada338312fab8/misc/scripts/build.sh#L498-L508
[^79]: https://github.com/pacstall/pacstall/blob/87ffd2b546785af0acc8441bc12ada338312fab8/misc/scripts/build.sh#L502-L504
[^80]: https://github.com/pacstall/pacstall/blob/87ffd2b546785af0acc8441bc12ada338312fab8/misc/scripts/build.sh#L507
[^81]: https://github.com/pacstall/pacstall/blob/87ffd2b546785af0acc8441bc12ada338312fab8/misc/scripts/build.sh#L511-L528
[^82]: https://github.com/pacstall/pacstall/blob/87ffd2b546785af0acc8441bc12ada338312fab8/misc/scripts/build.sh#L529-L587
[^83]: https://github.com/pacstall/pacstall/blob/87ffd2b546785af0acc8441bc12ada338312fab8/misc/scripts/build.sh#L590-L617
[^84]: https://github.com/pacstall/pacstall/blob/87ffd2b546785af0acc8441bc12ada338312fab8/misc/scripts/build.sh#L621
[^85]: https://github.com/pacstall/pacstall/blob/87ffd2b546785af0acc8441bc12ada338312fab8/misc/scripts/build.sh#L658
[^86]: https://github.com/pacstall/pacstall/blob/87ffd2b546785af0acc8441bc12ada338312fab8/misc/scripts/build.sh#L666
[^87]: https://github.com/pacstall/pacstall/blob/87ffd2b546785af0acc8441bc12ada338312fab8/misc/scripts/build.sh#L304-L314
[^88]: https://github.com/pacstall/pacstall/blob/87ffd2b546785af0acc8441bc12ada338312fab8/misc/scripts/build.sh#L317
[^89]: https://github.com/pacstall/pacstall/blob/87ffd2b546785af0acc8441bc12ada338312fab8/misc/scripts/build.sh#L318-L329
[^90]: https://github.com/pacstall/pacstall/blob/87ffd2b546785af0acc8441bc12ada338312fab8/misc/scripts/build.sh#L330-L338
[^91]: https://github.com/pacstall/pacstall/blob/87ffd2b546785af0acc8441bc12ada338312fab8/misc/scripts/build.sh#L341
[^92]: https://github.com/pacstall/pacstall/blob/87ffd2b546785af0acc8441bc12ada338312fab8/misc/scripts/build.sh#L342
[^93]: https://github.com/pacstall/pacstall/blob/87ffd2b546785af0acc8441bc12ada338312fab8/misc/scripts/build.sh#L344
[^94]: https://github.com/pacstall/pacstall/blob/87ffd2b546785af0acc8441bc12ada338312fab8/misc/scripts/build.sh#L667
[^95]: https://github.com/pacstall/pacstall/blob/87ffd2b546785af0acc8441bc12ada338312fab8/misc/scripts/package.sh#L412
[^96]: https://github.com/pacstall/pacstall/blob/87ffd2b546785af0acc8441bc12ada338312fab8/misc/scripts/package.sh#L416-L424
[^97]: https://github.com/pacstall/pacstall/blob/87ffd2b546785af0acc8441bc12ada338312fab8/misc/scripts/package.sh#L426-L427
