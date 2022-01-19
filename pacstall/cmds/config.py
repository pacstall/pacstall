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
from subprocess import run

from pacstall.api.config import PACSTALL_CONFIG_PATH
from pacstall.api.config_facade import read_config
from pacstall.api.error_codes import ErrorCodes, PacstallError
from pacstall.api.message import fancy

__FALLBACK_EDITOR = "sensible-editor"


def open_editor() -> int:
    """
    Opens the `config.toml` file in the default editor, and validates it.

    Prioritization order: `PacstallConfig.settings.preferred_editor` > `$PACSTALL_EDITOR` > `$EDITOR` > `sensible-editor`.

    Returns
    -------
    - Editor's `exit code` if it closes with a non-zero exit code
    - `ErrorCodes` if the config validation fails
    - `0` if success
    """

    try:
        conf = read_config()
        editor = (
            conf.settings.preferred_editor
            if conf.settings.preferred_editor is not None
            else environ.get(
                "PACSTALL_EDITOR", environ.get("EDITOR", __FALLBACK_EDITOR)
            )
        )

    except PacstallError as error:
        return error.code
    except Exception as error:
        fancy("error", f"Unknown error has occurred. {error}")
        return ErrorCodes.SOFTWARE_ERROR

    ret_code = run(["sudo", editor, PACSTALL_CONFIG_PATH]).returncode
    if ret_code != 0:
        fancy("error", f"Editor '{editor}' closed with a non-zero exit code {ret_code}")
        return ret_code

    return 0
