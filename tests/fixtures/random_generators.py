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

from random import choice
from string import ascii_letters, ascii_lowercase, digits, punctuation
from typing import Callable, List

import pytest


@pytest.fixture()
def random_words() -> List[str]:
    """
    Fixture to generate random words.

    Returns
    -------
    list of str:
        The random generated words.
    """

    words = []
    for _ in range(max(choice(range(10)), 1)):
        package_name = ""
        for _ in range(choice(range(10))):
            if choice((1, 2, 3)) == 1:
                package_name += choice(ascii_lowercase)
            if choice((1, 2, 3)) == 2:
                package_name += choice(digits)

            # Punctuations should be added after the first letter so as to not
            # interfere with flags.
            if choice((1, 2, 3)) == 3 and len(package_name) > 1:
                package_name += choice(punctuation)

        words.append(package_name)
    return words


@pytest.fixture()
def random_flags() -> Callable[[List[str]], List[str]]:
    """
    Fixture to generate random flags.

    Returns
    -------
    callable of list of str and list of str:
        Callable function to generate unknown flags.
    """

    def _random_flags(known_flags: List[str]) -> List[str]:
        """
        Generate unknown flags.

        Parameters
        ----------
        known_flags
            Known flags to exclude when generate random flags.

        Returns
        -------
        list of str:
            Random unknown flags.
        """

        flags = []
        filtered_ascii_letters = ascii_letters
        for known_flag in known_flags:
            filtered_ascii_letters = filtered_ascii_letters.replace(known_flag, "")

        for _ in range(max(choice(range(10)), 1)):
            flag = choice(("-", "--"))
            for _ in range(max(choice(range(10)), 1)):
                flag += choice(filtered_ascii_letters)

            flags.append(flag)

        return flags

    return _random_flags
