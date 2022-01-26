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

from logging import getLogger
from typing import Optional

from pacstall.api.color import Foreground as fg
from pacstall.api.color import Style as st
from pacstall.api.config_facade import read_config
from pacstall.api.error_codes import ErrorCodes, PacstallError


def list_repos() -> int:
    """
    Prints the existing repositories.

    Returns
    -------
    `int` exit code
    """

    log = getLogger()

    try:
        conf = read_config()

        for repo in conf.repositories:
            log.info(
                f"{fg.GREEN}{repo.name}{st.RESET} ({repo.branch}) - {repo.original_url}",
            )

        return 0
    except PacstallError as error:
        return error.code
    except Exception as error:
        log.exception(f"Unknown error has occurred. {error}")
        return ErrorCodes.SOFTWARE_ERROR
