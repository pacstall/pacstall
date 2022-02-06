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
# along with Pacstall. If not, see <https://www.gnu.org/licenses/>.

import sys
from asyncio import run
from fcntl import LOCK_EX, LOCK_NB, lockf
from getpass import getuser
from logging import getLogger
from time import sleep

from rich import print as rprint
from rich.traceback import install

from pacstall.api import logger
from pacstall.api.error_codes import ErrorCodes
from pacstall.cmds import download
from pacstall.parser import parse_arguments


def main() -> int:
    """Main Pacstall function."""
    install(
        show_locals=True
    )  # --> Install Rich's traceback handler for better looking tracebackes

    args = parse_arguments()
    if args.command in ["install", "remove", "upgrade", "repo"] and getuser() != "root":
        rprint(
            f"[[bold red]![/bold red]] [bold]ERROR[/bold]: Pacstall needs root privileges to run the {args.command} command",
            file=sys.stderr,
        )
        rprint(
            f"[[bold green]+[/bold green]] [bold]INFO[/bold]: Try running [code]sudo pacstall {' '.join(sys.argv[1:])}[/code] instead",
            file=sys.stderr,
        )
        sys.exit(ErrorCodes.USAGE_ERROR)  # --> command line usage error

    logger.setup_logger()
    log = getLogger()

    log.debug(f"{args = }")

    if args.command in ["install", "remove", "upgrade", "repo"]:
        lock_file = open("/var/lock/pacstall.lock", "w")
        while True:
            try:
                lockf(lock_file, LOCK_EX | LOCK_NB)
                log.debug("Lock acquired")
                break
            except OSError:
                log.warn("Pacstall is already running another instance")
                sleep(1)

    if args.command == "download":
        sys.exit(run(download.execute(args.pacscripts)))

    sys.exit(0)


if __name__ == "__main__":
    sys.exit(main())
