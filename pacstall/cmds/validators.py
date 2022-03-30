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

"""Module for validation of command parameters."""

from fcntl import LOCK_EX, LOCK_NB, lockf
from getpass import getuser
from logging import getLogger
from os import getpid
from pathlib import Path
from sys import argv, stderr
from time import sleep
from typing import List

from rich import print as rprint
from typer import Abort

from pacstall.api.error_codes import ErrorCodes

log = getLogger()

lock_file = None


def root_validator(packages: List[str], command_name: str) -> List[str]:
    """
    Validate that the command is not being run as root. If so, then setup the
    locking mechanism.

    Parameters
    ----------
    packages
        The list of packages to return. Typer needs this to be returned.
    command_name
        The name of the command being run.

    Raises
    ------
    Abort
        If the command is not being run as root.

    Returns
    -------
    List[str]
        The list of packages to return. Typer needs this to be returned.
    """

    if getuser() != "root":
        rprint(
            f"[[bold red]![/bold red]] [bold]ERROR[/bold]: Pacstall needs root privileges to run the [code]{command_name}[/code] command",
            file=stderr,
        )
        rprint(
            f"[[bold green]+[/bold green]] [bold]INFO[/bold]: Try running [code]sudo pacstall {' '.join(argv[1:])}[/code] instead"
        )

        raise Abort(ErrorCodes.USAGE_ERROR)

    Path("/var/lock/pacstall.lock").touch(exist_ok=True)

    global lock_file
    lock_file = open("/var/lock/pacstall.lock", "r+")

    current_pid = getpid()
    another_instance_pid = lock_file.read()

    log.debug(f"{current_pid = }")
    log.debug(f"{another_instance_pid = }")
    last_pid_read = another_instance_pid
    first_time = True

    while True:
        try:
            lockf(lock_file, LOCK_EX | LOCK_NB)

            log.debug("Lock acquired")
            log.debug("Writing PID to lock file")
            lock_file.seek(0)
            lock_file.write(f"{current_pid}")
            lock_file.truncate()

            break
        except OSError:
            if first_time or (last_pid_read != another_instance_pid):
                log.warn(
                    f"Pacstall is already running another instance ({last_pid_read})"
                )
                first_time = False
                another_instance_pid = last_pid_read

            lock_file.seek(0)
            last_pid_read = lock_file.read()
            log.debug(f"{last_pid_read = }")
            log.debug(f"{another_instance_pid = }")

            sleep(1)

    return packages
