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

"""Module for completion generation for commands."""

from typing import Generator

from httpx import Client, HTTPStatusError, RequestError


def package_completer() -> Generator[str, None, None]:
    """
    Auto completion function for packages.

    Return
    ------
    Generator[str, None, None]
        A generator of package names.
    """

    with Client() as client:
        try:
            response = client.get(
                "https://raw.githubusercontent.com/pacstall/pacstall-programs/master/packagelist"
            )
            response.raise_for_status()
        except (HTTPStatusError, RequestError):
            ...
        else:
            yield from response.text.splitlines()
