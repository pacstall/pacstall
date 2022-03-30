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

"""Install command."""

from logging import getLogger
from textwrap import dedent
from typing import List, Optional

from typer import Abort, Argument, Option

from pacstall.api.color import Foreground, Style
from pacstall.api.error_codes import ErrorCodes
from pacstall.cmds import app
from pacstall.cmds.completers import package_completer
from pacstall.cmds.validators import root_validator


def show_easter_egg(packages: List[str], please_flag: bool) -> None:
    """
    Shows Pacstall's Easter egg.

    Parameters
    ----------
    packages
        List of packages to install.
    please_flag
        If True, then allow the installation to continue.
    """

    if "makedeb" in packages and not please_flag:
        print(
            dedent(
                rf"""
        ╭───────────────────────────────────────────────────────────╮
        │ Oh, you thought it was {Style.BOLD}Makedeb{Style.RESET} but it was me, {Style.BOLD}Pacstall{Style.RESET}!1! │
        ╰───────────────────────────────────────────────────────────╯
               \   ∩~-~∩
                \ ξ {Foreground.BIRED}•{Style.RESET}×{Foreground.BIRED}•{Style.RESET} ξ
                  ξ　~　ξ
                  ξ　　 ξ
                  ξ　　 “～～～〇
                  ξ　　 　　　 ξ
                  ξ  ξ  ξ~～~ξ ξ
                  ξ_ξ ξ_ξ ξ_ξξ_ξ

                  if you really want to install makedeb, say --please
                  """
            ).strip()
        )

        Abort(ErrorCodes.USAGE_ERROR)


@app.command()
def install(
    packages: List[str] = Argument(
        ...,
        autocompletion=package_completer,
        callback=lambda packages: root_validator(packages, "install"),
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
    repo_flag: Optional[str] = Option(
        None,
        "-r",
        "--repo",
        help="Install from the specified repository.",
        metavar="REPOSITORY",
    ),
    please_flag: bool = Option(
        False, "--please", help="It's always good to be polite."
    ),
) -> None:
    """
    Install packages.

    Builds and install packages from local or remote pacscripts.
    In case of remote packages, it searches in all of your repos unless
    specified otherwise.
    """

    show_easter_egg(packages, please_flag)

    log = getLogger()

    log.debug(f"{packages = }")
    log.debug(f"{disable_prompts_flag = }")
    log.debug(f"{keep_flag = }")
