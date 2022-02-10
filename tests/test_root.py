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
from pathlib import Path
from subprocess import CalledProcessError, run
from textwrap import dedent

import pytest

from pacstall.api.error_codes import ErrorCodes


@pytest.mark.slow()
class TestWithoutRoot:
    """Test behavior without root privileges."""

    def test_launch(self) -> None:
        """Test behavior when pacstall is launched without any arguments."""

        with pytest.raises(CalledProcessError) as error:
            run(
                [f"{Path(environ['HOME']) / '.local/bin/poetry'}", "run", "pacstall"],
                check=True,
            )

        assert error.value.returncode == 1

    def test_with_help_flag(self) -> None:
        """Test behavior when pacstall is launched as root."""

        assert (
            run(
                [
                    f"{Path(environ['HOME']) / '.local/bin/poetry'}",
                    "run",
                    "pacstall",
                    "-h",
                ],
                check=True,
            ).returncode
            == 0
        )

    @pytest.mark.parametrize(
        "command",
        ["install", "remove", "upgrade", "download", "search", "list", "info"],
    )
    def test_commands(
        self, command: str, capfd: pytest.CaptureFixture  # type:ignore[type-arg]
    ) -> None:
        """
        Test behavior when commands are issued without root.

        Parameters
        ----------
        command
            Parameterized commands to test against.
        capfd
            Fixture to capture stderr output.
        """

        if command == "list":
            assert (
                run(
                    [
                        f"{Path(environ['HOME']) / '.local/bin/poetry'}",
                        "run",
                        "pacstall",
                        command,
                    ],
                    check=True,
                ).returncode
                == 0
            )

        elif command in ["info", "search"]:
            assert (
                run(
                    [
                        f"{Path(environ['HOME']) / '.local/bin/poetry'}",
                        "run",
                        "pacstall",
                        command,
                        "foo",
                    ],
                    check=True,
                ).returncode
                == 0
            )

        elif command == "download":
            with pytest.raises(CalledProcessError) as error:
                run(
                    [
                        f"{Path(environ['HOME']) / '.local/bin/poetry'}",
                        "run",
                        "pacstall",
                        command,
                        "foo",
                    ],
                    check=True,
                )

            assert (
                error.value.returncode == ErrorCodes.UNAVAILABLE_ERROR
            )  # Not ErrorCodes.USAGE_ERROR

        else:
            with pytest.raises(CalledProcessError) as error:
                run(
                    [
                        f"{Path(environ['HOME']) / '.local/bin/poetry'}",
                        "run",
                        "pacstall",
                        command,
                        "foo",
                    ],
                    check=True,
                )

            assert error.value.returncode == ErrorCodes.USAGE_ERROR
            assert capfd.readouterr().err == dedent(
                f"""\
                [!] ERROR: Pacstall needs root privileges to run the {command} command
                [+] INFO: Try running sudo pacstall {command} foo instead
                """
            )


@pytest.mark.slow()
class TestWithRoot:
    """Test behavior with root privileges."""

    def test_launch(self) -> None:
        """Test behavior when pacstall is launched without any arguments."""

        with pytest.raises(CalledProcessError) as error:
            run(
                [
                    "sudo",
                    "-E",
                    f"{Path(environ['HOME']) / '.local/bin/poetry'}",
                    "run",
                    "pacstall",
                ],
                check=True,
            )

        assert error.value.returncode == 1

    def test_with_help_flag(self) -> None:
        """Test behavior when pacstall is launched as root."""

        assert (
            run(
                [
                    "sudo",
                    "-E",
                    f"{Path(environ['HOME']) / '.local/bin/poetry'}",
                    "run",
                    "pacstall",
                    "-h",
                ],
                check=True,
            ).returncode
            == 0
        )

    @pytest.mark.parametrize(
        "command",
        ["install", "remove", "upgrade", "download", "search", "list", "info"],
    )
    def test_commands(self, command: str) -> None:
        """
        Test behavior when commands are issued with root.

        Parameters
        ----------
        command
            Parameterized commands to test against.
        """

        if command == "list":
            assert (
                run(
                    [
                        "sudo",
                        "-E",
                        f"{Path(environ['HOME']) / '.local/bin/poetry'}",
                        "run",
                        "pacstall",
                        command,
                    ],
                    check=True,
                ).returncode
                == 0
            )

        elif command == "download":
            with pytest.raises(CalledProcessError) as error:
                run(
                    [
                        "sudo",
                        "-E",
                        f"{Path(environ['HOME']) / '.local/bin/poetry'}",
                        "run",
                        "pacstall",
                        command,
                        "foo",
                    ],
                    check=True,
                )

            assert (
                error.value.returncode == ErrorCodes.UNAVAILABLE_ERROR
            )  # Not ErrorCodes.USAGE_ERROR

        else:
            assert (
                run(
                    [
                        "sudo",
                        "-E",
                        f"{Path(environ['HOME']) / '.local/bin/poetry'}",
                        "run",
                        "pacstall",
                        command,
                        "foo",
                    ],
                    check=True,
                ).returncode
                == 0
            )
