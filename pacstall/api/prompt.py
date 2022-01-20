#!/bin/env python3

"""Pacstall Prompting API."""

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

from os import environ

from pacstall.api.color import Foreground as Fg
from pacstall.api.color import Style as St


def confirm(question: str, default: bool = True) -> bool:
    """
    Ask the user for confirmation.

    Parameters
    ----------
    question : str
        The question to ask the user.
    default : bool
        Default value. Defaults to ``True``.

    Returns
    -------
    bool
        ``True`` if the default matches with the user's reply.
        ``False`` if it doesn't.
    """

    if environ.get("PACSTALL_DISABLE_PROMPTS"):
        return default

    choices = (
        f"[{Fg.BIGREEN}Y{St.RESET}/{Fg.RED}n{St.RESET}]"
        if default
        else f"[{Fg.GREEN}y{St.RESET}/{Fg.BIRED}N{St.RESET}]"
    )

    reply_bool_converter = {"Y": True, "N": False, "": default}
    while True:
        try:
            return (
                reply_bool_converter[
                    input(
                        f"[{Fg.BBLUE}?{St.RESET}] {St.BOLD}CONFIRM{St.RESET}: {St.ITALIC}{question}{St.RESET} {choices} "
                    ).upper()
                ]
                == default
            )
        except KeyError:
            continue
