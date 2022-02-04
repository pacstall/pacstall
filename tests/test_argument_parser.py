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

import sys
from argparse import Namespace
from typing import Callable, List

import pytest

from pacstall.parser import parse_arguments

# TODO: Test `repo` command.

commands = ["install", "remove", "upgrade", "download", "search", "list", "info"]


def test_with_no_arguments_passed() -> None:
    """Test to see if Pacstall errors out as expected when no arguments are supplied."""

    sys.argv = ["pacstall"]
    with pytest.raises(SystemExit) as error:
        parse_arguments()
    assert error.value.code == 1


def test_with_unknown_arguments(random_words: List[str]) -> None:
    """
    Test to see if Pacstall errors out as expected when random arguments are
    supplied.

    Parameters
    ----------
    random_words
        Fixture that generates random words, which are used as unknown arguments.
    """

    sys.argv = ["pacstall", *random_words]
    with pytest.raises(SystemExit) as error:
        parse_arguments()
    assert error.value.code == 2


@pytest.mark.parametrize("command", commands)
def test_with_no_packages_passed_to_commands(command: str) -> None:
    """
    Test behavior with no packages passed to the commands.

    Parameters
    ----------
    command
        The command to test against (parametrized).
    """

    sys.argv = ["pacstall", command]

    expected_namespaces = {
        "upgrade": Namespace(
            command="upgrade", disable_prompts=False, keep=False, packages=[]
        ),
        "list": Namespace(command="list"),
    }

    if command in expected_namespaces:
        assert parse_arguments() == expected_namespaces[command]

    else:
        with pytest.raises(SystemExit) as error:
            parse_arguments()
        assert error.value.code == 2


@pytest.mark.parametrize("command", commands)
def test_with_unknown_flags_passed_to_commands(
    random_flags: Callable[[List[str]], List[str]], command: str
) -> None:
    """
    Test behavior with unknown flags passed to the commands.

    Parameters
    ----------
    random_flags
        Fixture factory to get random/unknown flags.
    command
        The command to test against (parametrized).
    """

    known_flags = {
        "install": ["h", "P", "K"],
        "remove": ["h", "P"],
        "upgrade": ["h", "P", "K"],
        "download": ["h"],
        "search": ["h"],
        "list": ["h"],
        "info": ["h"],
    }

    unknown_flags = random_flags(known_flags[command])
    sys.argv = ["pacstall", command, *unknown_flags]

    with pytest.raises(SystemExit) as error:
        parse_arguments()
    assert error.value.code == 2


@pytest.mark.parametrize("command", commands)
def test_with_packages_passed_to_commands(
    random_words: List[str], command: str
) -> None:
    """
    Test behavior with random packages passed to the commands.

    Parameters
    ----------
    random_words
        Fixture to get random words used as the packages.
    command
        The command to test against (parametrized).
    """
    sys.argv = ["pacstall", command, *random_words]

    expected_namespaces = {
        "install": Namespace(
            command="install",
            disable_prompts=False,
            keep=False,
            packages=random_words,
        ),
        "remove": Namespace(
            command="remove",
            disable_prompts=False,
            packages=random_words,
        ),
        "upgrade": Namespace(
            command="upgrade",
            disable_prompts=False,
            keep=False,
            packages=random_words,
        ),
        "download": Namespace(
            command="download",
            pacscripts=random_words,
        ),
        "search": Namespace(
            command="search",
            packages=random_words,
        ),
        "info": Namespace(command="info", packages=random_words),
    }

    if command == "list":
        with pytest.raises(SystemExit) as error:
            parse_arguments()
        assert error.value.code == 2
    else:
        assert parse_arguments() == expected_namespaces[command]


@pytest.mark.parametrize("command", ["install", "remove", "upgrade"])
def test_commands_with_disable_prompts(random_words: List[str], command: str) -> None:
    """
    Test behavior with disable prompts flag enabled.

    Parameters
    ----------
    random_words
        Fixture to get random words used as the packages.
    command
        The command to test against (parametrized).
    """

    expected_namespaces = {
        "install": Namespace(
            command="install",
            disable_prompts=True,
            keep=False,
            packages=random_words,
        ),
        "remove": Namespace(
            command="remove",
            disable_prompts=True,
            packages=random_words,
        ),
        "upgrade": Namespace(
            command="upgrade",
            disable_prompts=True,
            keep=False,
            packages=random_words,
        ),
    }

    sys.argv = ["pacstall", command, "-P", *random_words]
    assert parse_arguments() == expected_namespaces[command]

    sys.argv = ["pacstall", command, "--disable-prompts", *random_words]
    assert parse_arguments() == expected_namespaces[command]


@pytest.mark.parametrize("command", ["install", "upgrade"])
def test_commands_with_keep(random_words: List[str], command: str) -> None:
    """
    Test behavior with keep flag enabled.

    Parameters
    ----------
    random_words
        Fixture to get random words used as the packages.
    command
        The command to test against (parametrized).
    """

    sys.argv = ["pacstall", command, "-K", *random_words]

    expected_namespaces = {
        "install": Namespace(
            command="install",
            disable_prompts=False,
            keep=True,
            packages=random_words,
        ),
        "upgrade": Namespace(
            command="upgrade",
            disable_prompts=False,
            keep=True,
            packages=random_words,
        ),
    }

    sys.argv = ["pacstall", command, "--keep", *random_words]
    assert parse_arguments() == expected_namespaces[command]
