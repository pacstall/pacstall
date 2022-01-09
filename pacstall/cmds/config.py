#!/bin/env python3

"""Config command."""

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
from subprocess import call

from api.config_facade import read_config

from pacstall.api.config import PACSTALL_CONFIG_PATH
from pacstall.api.message import fancy

__FALLBACK_EDITOR = "sensible-editor"


def open_editor() -> int:
    """
    Opens the `config.toml` file in the default editor, prioritizing `$PACSTALL_EDITOR > $EDITOR > sensible-editor`, and validates it.

    Returns
    -------
    - Editor's `exit code` if it closes with a non-zero exit code
    - `ReadConfigErrorCode` if the config validation fails
    - `0` if success
    """
    editor = environ.get("PACSTALL_EDITOR", environ.get("EDITOR", __FALLBACK_EDITOR))
    ret_code = call([editor, PACSTALL_CONFIG_PATH])
    if ret_code != 0:
        fancy("error", f"Editor '{editor}' closed with a non-zero exit code")
        return ret_code

    (err, _) = read_config()
    if err is not None:
        assert type(err.value) == int
        return err.value  # Is already `int` but must please the git-hooks gods
    return 0
