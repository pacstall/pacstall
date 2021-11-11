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

Functions
---------
res: Reset text styles and colors
sty: Set text style
fg: Set foreground colors
bg: Set background colors
color: Set text style and colors
"""


class Style:
    """ Modify text styles """

    RESET = "\x1b[0m"
    BOLD = "\x1b[1m"
    DIM = "\x1b[2m"
    ITALIC = "\x1b[3m"
    UNDERLINE = "\x1b[4m"
    BLINK = "\x1b[5m"
    HIDE = "\x1b[8m"
    STRIKETHROUGH = "\x1b[9m"





class Foreground:
    """
    Modify foreground colors

    Sections
    --------
    normal(no prefix): Normal colors
    high intensity("I" prefix): High intensity colors
    """

    BLACK  = "\x1b[38;5;0m"
    RED    = "\x1b[38;5;1m"
    GREEN  = "\x1b[38;5;2m"
    YELLOW = "\x1b[38;5;3m"
    BLUE   = "\x1b[38;5;4m"
    PURPLE = "\x1b[38;5;5m"
    CYAN   = "\x1b[38;5;6m"
    WHITE  = "\x1b[38;5;7m"

    # High Intensity backgrounds
    IBLACK  = "\x1b[38;5;08m"
    IRED    = "\x1b[38;5;09m"
    IGREEN  = "\x1b[38;5;10m"
    IYELLOW = "\x1b[38;5;11m"
    IBLUE   = "\x1b[38;5;12m"
    IPURPLE = "\x1b[38;5;13m"
    ICYAN   = "\x1b[38;5;14m"
    IWHITE  = "\x1b[38;5;15m"


class Background:
    """
    Modify background colors

    Sections
    --------
    normal(no prefix): Normal colors
    high intensity("I" prefix): High intensity colors
    """

    BLACK  = "\x1b[48;5;0m"
    RED    = "\x1b[48;5;1m"
    GREEN  = "\x1b[48;5;2m"
    YELLOW = "\x1b[48;5;3m"
    BLUE   = "\x1b[48;5;4m"
    PURPLE = "\x1b[48;5;5m"
    CYAN   = "\x1b[48;5;6m"
    WHITE  = "\x1b[48;5;7m"

    # High Intensity backgrounds
    IBLACK  = "\x1b[48;5;08m"
    IRED    = "\x1b[48;5;09m"
    IGREEN  = "\x1b[48;5;10m"
    IYELLOW = "\x1b[48;5;11m"
    IBLUE   = "\x1b[48;5;12m"
    IPURPLE = "\x1b[48;5;13m"
    ICYAN   = "\x1b[48;5;14m"
    IWHITE  = "\x1b[48;5;15m"


def res():
    """ Reset text styles and colors """
    return Style.RESET


def set_sty(style=None):
    """ Set text style """
    if isinstance(style,int):
        return f"\x1b[{str(style)}m"
    elif isinstance(style,str):
        style_dict = {  "reset"         : Style.RESET,
                        "bold"          : Style.BOLD,
                        "dim"           : Style.DIM,
                        "italic"        : Style.ITALIC,
                        "underline"     : Style.UNDERLINE,
                        "blink"         : Style.BLINK,
                        "hide"          : Style.HIDE,
                        "strikethrough" : Style.STRIKETHROUGH
                    }
        return style_dict[style]
    return ""


def set_fg(color=None):
    """ Set foreground colors """
    if isinstance(color,int) and 0<=color<=255:
        return f"\x1b[38;5;{str(color)}m"
    elif isinstance(color,str):
        bg_dict = { "black"     : Foreground.BLACK,
                    "red"       : Foreground.RED,
                    "green"     : Foreground.GREEN,
                    "yellow"    : Foreground.YELLOW,
                    "blue"      : Foreground.BLUE,
                    "purple"    : Foreground.PURPLE,
                    "cyan"      : Foreground.CYAN,
                    "white"     : Foreground.WHITE,
                    "Iblack"    : Foreground.IBLACK,
                    "Ired"      : Foreground.IRED,
                    "Igreen"    : Foreground.IGREEN,
                    "Iyellow"   : Foreground.IYELLOW,
                    "Iblue"     : Foreground.IBLUE,
                    "Ipurple"   : Foreground.IPURPLE,
                    "Icyan"     : Foreground.ICYAN,
                    "Iwhite"    : Foreground.IWHITE,
                }
        return bg_dict[color]
    return "\x1b[39m"


def set_bg(color=None):
    """ Set background colors """
    if isinstance(color,int) and 0<=color<=255:
        return f"\x1b[48;5;{str(color)}m"
    elif isinstance(color,str):
        bg_dict = { "black"     : Background.BLACK,
                    "red"       : Background.RED,
                    "green"     : Background.GREEN,
                    "yellow"    : Background.YELLOW,
                    "blue"      : Background.BLUE,
                    "purple"    : Background.PURPLE,
                    "cyan"      : Background.CYAN,
                    "white"     : Background.WHITE,
                    "Iblack"    : Background.IBLACK,
                    "Ired"      : Background.IRED,
                    "Igreen"    : Background.IGREEN,
                    "Iyellow"   : Background.IYELLOW,
                    "Iblue"     : Background.IBLUE,
                    "Ipurple"   : Background.IPURPLE,
                    "Icyan"     : Background.ICYAN,
                    "Iwhite"    : Background.IWHITE,
                }
        return bg_dict[color]
    return "\x1b[49m"

def color(fg=None,bg=None,sty=None):
    """ Set text style and colors """
    s = set_sty(sty)
    f = set_fg(fg)
    b = set_bg(bg)

    return s + f + b