#!/bin/env python3

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

from api.color import Foreground as fg
from api.color import Style as st
from os import environ


def fancy(message_type: str, message: str) -> None:
    """
    Print fancy messages

    Parameters
    ----------
    message_type (str): Type of message - "info" or "warn" or "error".
    message (str): Message.
    """

    # message_types: prompt
    message_types = {
        "info": f"[{fg.BGREEN}+{st.RESET}] INFO:",
        "warn": f"[{fg.BYELLOW}*{st.RESET}] WARNING:",
        "error": f"[{fg.BRED}!{st.RESET}] ERROR:",
    }
    prompt = message_types.get(message_type, f"[{st.BOLD}?{st.RESET}] UNKNOWN:")
    print(f"{prompt} {message}")


def ask(question: str, default: str = "nothing") -> str:
    """
    Ask Y/N questions

    Parameters
    ----------
    question (str): Question.
    default="nothing" (str): Default option - "Y" or "N" or nothing.

    Returns
    -------
    str: Returns the user's reply

    """
    # default: prompt
    defaults = {
        "Y": f"[{fg.BIGREEN}Y{st.RESET}/{fg.RED}n{st.RESET}]",
        "N": f"[{fg.GREEN}y{st.RESET}/{fg.BIRED}N{st.RESET}]",
    }

    prompt = defaults.get(default, f"[{fg.GREEN}y{st.RESET}/{fg.RED}n{st.RESET}]")
    if not environ.get("PACSTALL_DISABLE_PROMPTS"):
        reply = input(f"{question} {prompt} ").upper()

        if not reply:
            reply = default
    else:
        reply = default

        if reply != "nothing":
            print(f"{question} {prompt} {reply}")
    while True:
        if reply in ["Y", "N"]:
            return reply
        else:
            reply = input(f"{question} {prompt} ").upper()
