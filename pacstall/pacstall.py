#!/bin/env python3

"""Main Pacstall launcher file."""

#     ____                  __        ____
#    / __ \____ ___________/ /_____ _/ / /
#   / /_/ / __ `/ ___/ ___/ __/ __ `/ / /
#  / ____/ /_/ / /__(__  ) /_/ /_/ / / /
# /_/    \__,_/\___/____/\__/\__,_/_/_/
#
# Copyright (C) 2020-2021
#
# This file is part of Pacstall
#
# Pacstall is free software: you can redistribute it and/or modify
# it under the terms of the GNU General Public License as published by
# the Free Software Foundation, version 3 of the License
#
# Pacstall is distributed in the hope that it will be useful,
# but WITHOUT ANY WARRANTY; without even the implied warranty of
# MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE. See the
# GNU General Public License for more details.
#
# You should have received a copy of the GNU General Public License

import sys
from fcntl import lockf, LOCK_EX, LOCK_NB
from getpass import getuser
from argparse import HelpFormatter, ArgumentParser, Namespace
from time import sleep
from subprocess import call

from rich.traceback import install

from api.color import Foreground
from api import message

from cmds import download

# Copied from https://stackoverflow.com/a/23941599 and modified
class CustomHelpFormatter(HelpFormatter):
    """
    Custom help message formatter for Pacstall.

    Format:
    -s, --long       help message
    """

    def _format_action_invocation(self, action) -> str:
        if not action.option_strings:
            (metavar,) = self._metavar_formatter(action, action.dest)(1)
            return metavar

        parts = []
        # if the Optional doesn't take a value, format is:
        #    -s, --long
        if action.nargs == 0:
            parts.extend(action.option_strings)

        # if the Optional takes a value, format is:
        #    -s ARGS, --long ARGS
        # change to
        #    -s, --long
        else:
            for option_string in action.option_strings:
                parts.append("%s" % option_string)
        return ", ".join(parts)


def parse_arguments() -> Namespace:
    """
    Parses command line arguments passed to Pacstall.

    Prints help and exits if no argument is passed.

    Returns
    -------
    Namespace: Containing all the parsed arguments
    """
    parser = ArgumentParser(prog="pacstall", formatter_class=CustomHelpFormatter)
    commands = parser.add_argument_group("commands").add_mutually_exclusive_group()
    modifiers = parser.add_argument_group("modifiers")

    commands.add_argument(
        "-I", "--install", metavar="package", nargs="+", help="install packages"
    )
    commands.add_argument(
        "-S", "--search", metavar="package", nargs="?", help="search for packages"
    )
    commands.add_argument(
        "-R", "--remove", metavar="package", nargs="?", help="remove packages"
    )
    commands.add_argument(
        "-D", "--download", metavar="package", nargs="?", help="download pacscripts"
    )
    commands.add_argument(
        "-A", "--add-repo", metavar="repo", nargs="?", help="add repos to the repo list"
    )
    commands.add_argument(
        "-V",
        "--version",
        action="version",
        version=f"{Foreground.BIBLUE}Pacstall {Foreground.BIWHITE}2.0 {Foreground.BIYELLOW}Kournikova",
        help="show version",
    )
    commands.add_argument(
        "-L", "--list", action="store_true", help="list installed packages"
    )
    commands.add_argument(
        "-Up", "--upgrade", action="store_true", help="upgrade packages"
    )
    commands.add_argument(
        "-Qi", "--query-info", metavar="package", nargs=1, help="show package info"
    )

    modifiers.add_argument(
        "-P",
        "--disable-prompts",
        dest="disable_prompts",
        action="store_true",
        help="disable prompts for unattended operations",
    )
    modifiers.add_argument(
        "-K",
        "--keep",
        dest="keep",
        action="store_true",
        help="retain build directory after installation",
    )

    if len(sys.argv) == 1:
        parser.print_help()
        sys.exit(1)

    return parser.parse_args()


if __name__ == "__main__":
    install() # --> Install Rich's traceback handler for better looking tracebacks
    if getuser() == "root":
        message.fancy("error", "Pacstall cannot be run as root")
        sys.exit(1)

    args = parse_arguments()

    if args.install or args.remove or args.upgrade:
        lock_file = open("/var/lock/pacstall.lock", "w")
        call(["/usr/bin/sudo", "/usr/bin/chown", "root", "/var/lock/pacstall.lock"])
        while True:
            try:
                lockf(lock_file, LOCK_EX | LOCK_NB)
                break
            except IOError:
                message.fancy("error", "Pacstall is already running another instance")
                sleep(1)

    if args.download:
        exit (download.execute(args.download))
