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
from random import choice
from string import ascii_letters, ascii_lowercase, digits, punctuation
from typing import Callable, List

import pytest

from pacstall.parser import parse_arguments


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


@pytest.mark.arg_parser()
def test_with_no_arguments_passed() -> None:
    """Test to see if Pacstall errors out as expected when no arguments are supplied."""

    sys.argv = ["pacstall"]
    try:
        parse_arguments()
    except SystemExit as error:
        assert error.code == 1


@pytest.mark.arg_parser()
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
    try:
        parse_arguments()
    except SystemExit as error:
        assert error.code == 2


@pytest.mark.arg_parser()
class TestInstallParser:
    """
    Tests the install command parser.
    """

    def test_with_no_packages_passed(self) -> None:
        """Test behavior with no packages passed to the command."""

        sys.argv = ["pacstall", "install"]
        try:
            parse_arguments()
        except SystemExit as error:
            assert error.code == 2

    def test_with_unknown_flags(
        self, random_flags: Callable[[List[str]], List[str]]
    ) -> None:
        """
        Test behavior with unknown flags passed to the command.

        Parameters
        ----------
        random_flags
            Fixture factory to get random/unknown flags.
        """

        unknown_flags = random_flags(["h", "P", "K"])
        sys.argv = ["pacstall", "install", *unknown_flags]
        try:
            parse_arguments()
        except SystemExit as error:
            assert error.code == 2

    def test_with_packages_passed(self, random_words: List[str]) -> None:
        """
        Test behavior with random packages passed to the command.

        Parameters
        ----------
        random_words
            Fixture to get random words used as the packages.
        """

        sys.argv = ["pacstall", "install", *random_words]
        assert parse_arguments() == Namespace(
            command="install",
            disable_prompts=False,
            keep=False,
            packages=random_words,
        )

    def test_with_disable_prompts(self, random_words: List[str]) -> None:
        """
        Test behavior with disable prompts flag enabled.

        Parameters
        ----------
        random_words
            Fixture to get random words used as the packages.
        """

        sys.argv = ["pacstall", "install", "-P", *random_words]
        assert parse_arguments() == Namespace(
            command="install",
            disable_prompts=True,
            keep=False,
            packages=random_words,
        )

        sys.argv = ["pacstall", "install", "--disable-prompts", *random_words]
        assert parse_arguments() == Namespace(
            command="install",
            disable_prompts=True,
            keep=False,
            packages=random_words,
        )

    def test_with_keep(self, random_words: List[str]) -> None:
        """
        Test behavior with keep flag enabled.

        Parameters
        ----------
        random_words
            Fixture to get random words used as the packages.
        """

        sys.argv = ["pacstall", "install", "-K", *random_words]
        assert parse_arguments() == Namespace(
            command="install",
            disable_prompts=False,
            keep=True,
            packages=random_words,
        )

        sys.argv = ["pacstall", "install", "--keep", *random_words]
        assert parse_arguments() == Namespace(
            command="install",
            disable_prompts=False,
            keep=True,
            packages=random_words,
        )


@pytest.mark.arg_parser()
class TestRemoveParser:
    """
    Tests the remove command parser.
    """

    def test_with_no_packages_passed(self) -> None:
        """Test behavior with no packages passed to the command."""

        sys.argv = ["pacstall", "remove"]
        try:
            parse_arguments()
        except SystemExit as error:
            assert error.code == 2

    def test_with_unknown_flags(
        self, random_flags: Callable[[List[str]], List[str]]
    ) -> None:
        """
        Test behavior with unknown flags passed to the command.

        Parameters
        ----------
        random_flags
            Fixture factory to get random/unknown flags.
        """

        unknown_flags = random_flags(["h", "P"])
        sys.argv = ["pacstall", "remove", *unknown_flags]
        try:
            parse_arguments()
        except SystemExit as error:
            assert error.code == 2

    def test_with_packages_passed(self, random_words: List[str]) -> None:
        """
        Test behavior with random packages passed to the command.

        Parameters
        ----------
        random_words
            Fixture to get random words used as the packages.
        """

        sys.argv = ["pacstall", "remove", *random_words]
        assert parse_arguments() == Namespace(
            command="remove",
            disable_prompts=False,
            packages=random_words,
        )

    def test_with_disable_prompts(self, random_words: List[str]) -> None:
        """
        Test behavior with disable prompts flag enabled.

        Parameters
        ----------
        random_words
            Fixture to get random words used as the packages.
        """

        sys.argv = ["pacstall", "remove", "-P", *random_words]
        assert parse_arguments() == Namespace(
            command="remove",
            disable_prompts=True,
            packages=random_words,
        )

        sys.argv = ["pacstall", "remove", "--disable-prompts", *random_words]
        assert parse_arguments() == Namespace(
            command="remove",
            disable_prompts=True,
            packages=random_words,
        )


@pytest.mark.arg_parser()
class TestUpgradeParser:
    """
    Tests the upgrade command parser.
    """

    def test_with_no_packages_passed(self) -> None:
        """Test behavior with no packages passed to the command."""

        sys.argv = ["pacstall", "upgrade"]
        try:
            parse_arguments()
        except SystemExit as error:
            assert error.code == 2

    def test_with_unknown_flags(
        self, random_flags: Callable[[List[str]], List[str]]
    ) -> None:
        """
        Test behavior with unknown flags passed to the command.

        Parameters
        ----------
        random_flags
            Fixture factory to get random/unknown flags.
        """

        unknown_flags = random_flags(["h", "P", "K"])
        sys.argv = ["pacstall", "upgrade", *unknown_flags]
        try:
            parse_arguments()
        except SystemExit as error:
            assert error.code == 2

    def test_with_packages_passed(self, random_words: List[str]) -> None:
        """
        Test behavior with random packages passed to the command.

        Parameters
        ----------
        random_words
            Fixture to get random words used as the packages.
        """

        sys.argv = ["pacstall", "upgrade", *random_words]
        assert parse_arguments() == Namespace(
            command="upgrade",
            disable_prompts=False,
            keep=False,
            packages=random_words,
        )

    def test_with_disable_prompts(self, random_words: List[str]) -> None:
        """
        Test behavior with disable prompts flag enabled.

        Parameters
        ----------
        random_words
            Fixture to get random words used as the packages.
        """

        sys.argv = ["pacstall", "upgrade", "-P", *random_words]
        assert parse_arguments() == Namespace(
            command="upgrade",
            disable_prompts=True,
            keep=False,
            packages=random_words,
        )

        sys.argv = ["pacstall", "upgrade", "--disable-prompts", *random_words]
        assert parse_arguments() == Namespace(
            command="upgrade",
            disable_prompts=True,
            keep=False,
            packages=random_words,
        )

    def test_with_keep(self, random_words: List[str]) -> None:
        """
        Test behavior with keep flag enabled.

        Parameters
        ----------
        random_words
            Fixture to get random words used as the packages.
        """

        sys.argv = ["pacstall", "upgrade", "-K", *random_words]
        assert parse_arguments() == Namespace(
            command="upgrade",
            disable_prompts=False,
            keep=True,
            packages=random_words,
        )

        sys.argv = ["pacstall", "upgrade", "--keep", *random_words]
        assert parse_arguments() == Namespace(
            command="upgrade",
            disable_prompts=False,
            keep=True,
            packages=random_words,
        )


@pytest.mark.arg_parser()
class TestDownloadParser:
    """
    Tests the download command parser.
    """

    def test_with_no_packages_passed(self) -> None:
        """Test behavior with no packages passed to the command."""

        sys.argv = ["pacstall", "download"]
        try:
            parse_arguments()
        except SystemExit as error:
            assert error.code == 2

    def test_with_unknown_flags(
        self, random_flags: Callable[[List[str]], List[str]]
    ) -> None:
        """
        Test behavior with unknown flags passed to the command.

        Parameters
        ----------
        random_flags
            Fixture factory to get random/unknown flags.
        """

        unknown_flags = random_flags(["h"])
        sys.argv = ["pacstall", "download", *unknown_flags]
        try:
            parse_arguments()
        except SystemExit as error:
            assert error.code == 2

    def test_with_packages_passed(self, random_words: List[str]) -> None:
        """
        Test behavior with random packages passed to the command.

        Parameters
        ----------
        random_words
            Fixture to get random words used as the packages.
        """

        sys.argv = ["pacstall", "download", *random_words]
        assert parse_arguments() == Namespace(
            command="download",
            pacscripts=random_words,
        )


@pytest.mark.arg_parser()
class TestSearchParser:
    """
    Tests the download command parser.
    """

    def test_with_no_packages_passed(self) -> None:
        """Test behavior with no packages passed to the command."""

        sys.argv = ["pacstall", "search"]
        try:
            parse_arguments()
        except SystemExit as error:
            assert error.code == 2

    def test_with_unknown_flags(
        self, random_flags: Callable[[List[str]], List[str]]
    ) -> None:
        """
        Test behavior with unknown flags passed to the command.

        Parameters
        ----------
        random_flags
            Fixture factory to get random/unknown flags.
        """

        unknown_flags = random_flags(["h"])
        sys.argv = ["pacstall", "search", *unknown_flags]
        try:
            parse_arguments()
        except SystemExit as error:
            assert error.code == 2

    def test_with_packages_passed(self, random_words: List[str]) -> None:
        """
        Test behavior with random packages passed to the command.

        Parameters
        ----------
        random_words
            Fixture to get random words used as the packages.
        """

        sys.argv = ["pacstall", "search", *random_words]
        assert parse_arguments() == Namespace(
            command="search",
            packages=random_words,
        )


@pytest.mark.arg_parser()
class TestListParser:
    """
    Tests the list command parser.
    """

    def test_with_no_packages_passed(self) -> None:
        """Test behavior with no packages passed to the command."""

        sys.argv = ["pacstall", "list"]
        assert parse_arguments() == Namespace(command="list")

    def test_with_unknown_flags(
        self, random_flags: Callable[[List[str]], List[str]]
    ) -> None:
        """
        Test behavior with unknown flags passed to the command.

        Parameters
        ----------
        random_flags
            Fixture factory to get random/unknown flags.
        """

        unknown_flags = random_flags(["h"])
        sys.argv = ["pacstall", "list", *unknown_flags]
        try:
            parse_arguments()
        except SystemExit as error:
            assert error.code == 2

    def test_with_packages_passed(self, random_words: List[str]) -> None:
        """
        Test behavior with random packages passed to the command.

        Parameters
        ----------
        random_words
            Fixture to get random words used as the packages.
        """

        sys.argv = ["pacstall", "list", *random_words]
        try:
            parse_arguments()
        except SystemExit as error:
            assert error.code == 2


@pytest.mark.arg_parser()
class TestInfoParser:
    """
    Tests the info command parser.
    """

    def test_with_no_packages_passed(self) -> None:
        """Test behavior with no packages passed to the command."""

        sys.argv = ["pacstall", "info"]
        try:
            parse_arguments()
        except SystemExit as error:
            assert error.code == 2

    def test_with_unknown_flags(
        self, random_flags: Callable[[List[str]], List[str]]
    ) -> None:
        """
        Test behavior with unknown flags passed to the command.

        Parameters
        ----------
        random_flags
            Fixture factory to get random/unknown flags.
        """

        unknown_flags = random_flags(["h"])
        sys.argv = ["pacstall", "info", *unknown_flags]
        try:
            parse_arguments()
        except SystemExit as error:
            assert error.code == 2

    def test_with_packages_passed(self, random_words: List[str]) -> None:
        """
        Test behavior with random packages passed to the command.

        Parameters
        ----------
        random_words
            Fixture to get random words used as the packages.
        """

        sys.argv = ["pacstall", "info", *random_words]
        assert parse_arguments() == Namespace(command="info", packages=random_words)
