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

"""Upgrade command."""

from logging import getLogger
from typing import List, Optional

from typer import Argument, BadParameter, Context, Option

from pacstall.cmds import app
from pacstall.cmds.validators import root_validator

log = getLogger()


def upgrade_validator(ctx: Context, packages: Optional[List[str]]) -> List[str]:
    """
    Validate the upgrade command.

    Parameters
    ----------
    ctx
        The context of the command.
    packages
        The packages to upgrade.

    Raises
    ------
    BadParameter
        If the parameters are not valid.

    Returns
    -------
    List[str]
        The validated packages to upgrade.
    """

    if ctx.params.get("all_flag") and packages:
        raise BadParameter("Cannot use --all and specify packages at the same time")

    elif not packages:
        raise BadParameter("No packages specified")

    root_validator(packages, "upgrade")

    return packages


@app.command()
def upgrade(
    packages: Optional[List[str]] = Argument(
        None, callback=upgrade_validator, help="Optional when --all flag is used."
    ),
    disable_prompts_flag: bool = Option(
        False,
        "-p",
        "--disable-prompts",
        help="Disables prompts for unattended installation.",
    ),
    keep_flag: bool = Option(
        False, "-k", "--keep", help="Retain the build directory after installation."
    ),
    all_flag: bool = Option(
        False, "-a", "--all", help="Updates all packages interactively."
    ),
) -> None:
    """Upgrade packages."""

    log.debug(f"{packages = }")
    log.debug(f"{disable_prompts_flag = }")
    log.debug(f"{keep_flag = }")
    log.debug(f"{all_flag = }")
