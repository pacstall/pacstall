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

from glob import glob
from pathlib import Path
from shutil import rmtree
from typing import List
from unittest.mock import AsyncMock, patch

import pytest
from httpx import HTTPStatusError, RequestError, Response

from pacstall.api.error_codes import ErrorCodes
from pacstall.cmds.download import execute


@pytest.mark.slow()
@pytest.mark.anyio()
async def test_normal_payload(
    monkeypatch: pytest.MonkeyPatch, pacscript_list: List[str]
) -> None:
    """
    Test normal download behavior.

    Parameters
    ----------
    monkeypatch
        Fixture to temporarily change directory to a test directory.
    pacscript_list
        Fixture to generate a random `list` of pacscripts to download.
    """
    with monkeypatch.context() as monkey:
        tmp_download_dir = Path("_test/")
        tmp_download_dir.mkdir(exist_ok=True)
        monkey.chdir(tmp_download_dir)

        # Send all the pacscript stems to the download command
        assert (
            await execute(
                [pacscript.split(".pacscript")[0] for pacscript in pacscript_list]
            )
            == 0
        )

    # Check if every pacscript in pacscript_list is present in the downloaded_pacscripts list
    downloaded_pacscripts = [pacscript.name for pacscript in tmp_download_dir.iterdir()]
    assert all(pacscript in downloaded_pacscripts for pacscript in pacscript_list)

    rmtree(tmp_download_dir)


class TestErrors:
    """
    Test errors.
    """

    @pytest.mark.anyio()
    async def test_with_unknown_packages(self, random_words: List[str]) -> None:
        """
        Test the command with unknown packages.

        Parameters
        ----------
        random_words
            Fixture to generate random words to test the command with.
        """

        assert await execute(random_words) == ErrorCodes.UNAVAILABLE_ERROR

        # Check if no files got downloaded as expected.
        assert glob("*.pacscript") == []

    @pytest.mark.parametrize("exception", [HTTPStatusError, RequestError, OSError])
    @pytest.mark.anyio()
    @patch("httpx.AsyncClient.get")
    async def test_exception_catching(
        self,
        mock_async_client_get: AsyncMock,
        pacscript_list: List[str],
        exception: type,
    ) -> None:
        """
        Test the command's exception catching.

        Parameters
        ----------
        mock_async_client_get
            Mocked ``httpx.AsyncClient.get`` for testing.
        pacscript_list
            Fixture to generate a random `list` of pacscript to download
            (but it shouldn't download anything.)
        exception
            The exception to test the download command against (parametrized).
        """

        downloads = [pacscript.split(".pacscript")[0] for pacscript in pacscript_list]

        if exception is HTTPStatusError:
            mock_async_client_get.side_effect = exception(
                message="Mocked Message",
                request="Mocked Request",
                response=Response(status_code=9000),
            )
            assert await execute(downloads) == ErrorCodes.UNAVAILABLE_ERROR

        elif exception is RequestError:
            mock_async_client_get.side_effect = exception(
                message="Mocked Message",
            )
            assert await execute(downloads) == ErrorCodes.UNAVAILABLE_ERROR

        elif exception is OSError:
            mock_async_client_get.side_effect = exception()
            assert await execute(downloads) == ErrorCodes.IO_ERROR

        # Check if no files got downloaded as expected.
        assert glob("*.pacscript") == []
