#!/bin/env python3

"""List repositories command."""

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

from typing import Optional

from pacstall.api.color import Foreground as fg
from pacstall.api.color import Style as st
from pacstall.api.config_facade import read_config
from pacstall.api.error_codes import ErrorCodes
from pacstall.api.message import fancy


def list_repos() -> Optional[ErrorCodes]:
    """
    Prints the existing repositories.

    Returns
    -------
    `ReadConfigErrorCode` if an error has occurred, otherwise `None`.
    """

    (err, repos) = read_config()
    if err is not None:
        return err

    if repos is not None:
        for repo in repos:
            fancy(
                "info",
                f"{fg.GREEN}{repo.name}{st.RESET} ({repo.branch}) - {repo.original_url}",
            )

    return None
