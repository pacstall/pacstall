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

from requests import get
from requests.exceptions import ConnectionError
from rich.console import Console

from api.message import fancy


def execute(url: str, filepath: str = None) -> int:
    """
    Runs download command.

    Parameters
    ----------
    url (str): URL to download file from.
    filepath=None (str): Where to download the file to. If nothing is provided download in cwd.

    Error codes
    -----------
    0: Everything went fine.
    1: No internet connection detected.
    2: Some problem occurred while downloading.
    3: Unknown error.
    """
    try:
        with get(url) as data:
            if data.status_code != 200:
                fancy("error", f"Error occurred while downloading {url}")
                fancy("error", f"Error code: {data.status_code}")
                return 2  # --> Problem occurred while downloading
            else:
                if not filepath:
                    filepath = url.split("/")[-1]
                with open(filepath, "wb") as file:
                    file.write(data.content)
                return 0  # --> No problems occurred while downloading
    except ConnectionError:
        fancy("error", "No internet connection")
        return 1  # --> No internet connection detected
    except Exception:
        fancy("error", "Unknown exception occured")
        Console().print_exception(show_locals=True, max_frames=1) # --> Print exception in this case
        return 3 # --> Unknown error
