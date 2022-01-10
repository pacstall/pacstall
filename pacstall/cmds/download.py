#!/bin/env python3

"""Download command."""

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

from requests import exceptions, get

from pacstall.api.message import fancy


def execute(url: str, file_path: str = "") -> int:
    """
    Runs download command.

    Parameters
    ----------
    url (str): URL to download file from.
    file_path="" (str): Where to download the file to. If nothing is provided download in cwd.

    Error codes
    -----------
    0: Everything went fine.
    1: Connection problems.
    2: Downloading problems.
    3: Unknown error.
    """

    REQUEST_ERROR_MESSAGES = {
        exceptions.HTTPError: "A HTTP error occurred while connecting to the URL",
        exceptions.ConnectionError: "No internet connection detected",
        exceptions.Timeout: "Connection timed out. Check your internet connection",
        exceptions.TooManyRedirects: "Too many redirections. Possibly bad URL",
    }

    try:
        with get(url) as data:
            data.raise_for_status()
            file_path = file_path or url.split("/")[-1]

            try:
                with open(file_path, "wb") as file:
                    file.write(data.content)
            except OSError:
                fancy("error", "Could not write downloaded contents to file")
                return 2  # --> Writing data failed
            return 0  # --> No problems occurred while downloading

    except (
        exceptions.HTTPError,
        exceptions.ConnectionError,
        exceptions.Timeout,
        exceptions.TooManyRedirects,
    ) as error:
        fancy("error", REQUEST_ERROR_MESSAGES[type(error)])
        return 1  # --> Connection problems

    except Exception:
        fancy("error", "Unknown exception occurred")
        return 3  # --> Unknown error
