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

from logging import DEBUG
from typing import Optional

import typer
from rich import traceback

from pacstall.api import logger
from pacstall.api.color import Foreground
from pacstall.cmds import app


@app.callback(invoke_without_command=True)
def version_callback(
    version: Optional[bool] = typer.Option(
        None, "-v", "--version", help="Show version and exit.", is_eager=True
    ),
    debug: Optional[bool] = typer.Option(
        None, "-d", "--debug", help="Turn on debugging info.", is_eager=True
    ),
) -> None:
    """
    Show version and exit.

    Parameters
    ----------
    version
        Show version and exit.
    debug
        Turn on debugging info.

    Raises
    ------
    typer.Exit
        Exit with code 0.
    """
    if debug:
        logger.setup_logger(console_logger_level=DEBUG)
    else:
        logger.setup_logger()

    if version:
        print(
            f"{Foreground.BIBLUE}Pacstall {Foreground.BIWHITE}2.0.0 {Foreground.BIYELLOW}Kournikova"
        )
        raise typer.Exit()


def main() -> None:
    """Main Pacstall function."""

    # Install Rich's traceback handler for better looking tracebackes.
    traceback.install(show_locals=True)

    app()


if __name__ == "__main__":
    main()
