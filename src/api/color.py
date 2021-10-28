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

"""
Pacstall's color API

Classes
-------
Style: Modify text styles
Foreground: Modify foreground colors
Background: Modify background colors
"""


class Style:
    """
    Modify text styles
    """

    BOLD = "\033[1m"
    DIM = "\033[2m"
    ITALIC = "\033[3m"
    UNDERLINE = "\033[4m"
    STRIKETHROUGH = "\033[9m"
    BLINK = "\033[5m"
    RESET = "\033[0m"


class Foreground:
    """
    Modify foreground colors

    Sections
    --------
    normal(no prefix): Normal colors
    bold("B" prefix): Bold colors
    underline("U" prefix): Underlined colors
    high intensity("I" prefix): High intensity colors
    bold high intensity("BI" prefix): Bold high intensity colors
    """

    BLACK = "\033[0;30m"
    RED = "\033[0;31m"
    GREEN = "\033[0;32m"
    YELLOW = "\033[0;33m"
    BLUE = "\033[0;34m"
    PURPLE = "\033[0;35m"
    CYAN = "\033[0;36m"
    WHITE = "\033[0;37m"

    # Bold
    BBLACK = "\033[1;30m"
    BRED = "\033[1;31m"
    BGREEN = "\033[1;32m"
    BYELLOW = "\033[1;33m"
    BBLUE = "\033[1;34m"
    BPURPLE = "\033[1;35m"
    BCYAN = "\033[1;36m"
    BWHITE = "\033[1;37m"

    # Underline
    UBLACK = "\033[4;30m"
    URED = "\033[4;31m"
    UGREEN = "\033[4;32m"
    UYELLOW = "\033[4;33m"
    UBLUE = "\033[4;34m"
    UPURPLE = "\033[4;35m"
    UCYAN = "\033[4;36m"
    UWHITE = "\033[4;37m"

    # High Intensity
    IBLACK = "\033[0;90m"
    IRED = "\033[0;91m"
    IGREEN = "\033[0;92m"
    IYELLOW = "\033[0;93m"
    IBLUE = "\033[0;94m"
    IPURPLE = "\033[0;95m"
    ICYAN = "\033[0;96m"
    IWHITE = "\033[0;97m"

    # Bold High Intensity
    BIBLACK = "\033[1;90m"
    BIRED = "\033[1;91m"
    BIGREEN = "\033[1;92m"
    BIYELLOW = "\033[1;93m"
    BIBLUE = "\033[1;94m"
    BIPURPLE = "\033[1;95m"
    BICYAN = "\033[1;96m"
    BIWHITE = "\033[1;97m"


class Background:
    """
    Modify background colors

    Sections
    --------
    normal(no prefix): Normal colors
    high intensity("I" prefix): High intensity colors
    """

    BLACK = "\033[40m"
    RED = "\033[41m"
    GREEN = "\033[42m"
    YELLOW = "\033[43m"
    BLUE = "\033[44m"
    PURPLE = "\033[45m"
    CYAN = "\033[46m"
    WHITE = "\033[47m"

    # High Intensity backgrounds
    IBLACK = "\033[0;100m"
    IRED = "\033[0;101m"
    IGREEN = "\033[0;102m"
    IYELLOW = "\033[0;103m"
    IBLUE = "\033[0;104m"
    IPURPLE = "\033[0;105m"
    ICYAN = "\033[0;106m"
    IWHITE = "\033[0;107m"
