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

Currently, a pacscript is sourced by brush and immediately converted into an `SRCINFO` format. A constant goal of this rewrite is to interact with bash as little as possible, and we feel that an `SRCINFO` representation is the most representative and least frictionful format for a pacscript. One happy conclusion from this is that we get an `SRCINFO` generator inside pacstall itself.

Note that not everything can be mapped onto `SRCINFO`, such as functions, but we expect those to not be very annoying to deal with, as we will just be calling them on our own, no parsing needed.

If there is one thing to take away from this section, it should be that you should try to load the bash code into some rust data structure and run as fast as you can away from bash once that's done.

#### Linting/Checking

In bashstall, the checks are located in `misc/scripts/checks.sh`, and in rust they are located in `src/cmds/checks/`, where each check has it's own module where you can go crazy with however many lints you want.

Some lints inside checks may not even be needed in ruststall, because parsing is handled elsewhere. To give an example, `incompatible` and `compatible` elements do not need to be checked for improper formatting, because that is done at the `SRCINFO` conversion stage by [DistroClamp](https://docs.rs/libpacstall/latest/libpacstall/pkg/keys/struct.DistroClamp.html).
