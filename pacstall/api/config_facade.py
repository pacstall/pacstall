#!/bin/env python3

"""A facade for the `config.toml` file."""

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

from dataclasses import dataclass
from enum import Enum, IntEnum
from typing import Dict, List, NoReturn, Optional, Tuple, TypeVar

import tomli
from api.config import PACSTALL_CONFIG_PATH
from api.message import fancy
from requests import get


@dataclass
class RepositoryConfig:
    """
    Representation of a repository entry from `config.toml`
    """

    name: str
    url: str
    branch: str


class SupportedGitProviderLinks(str, Enum):
    """
    String enum that contains the links of the officially supported git platforms
    """

    GITLAB_URL = "https://gitlab.com"
    GITHUB_URL = "https://github.com"
    BITBUCKET_URL = "https://bitbucket.org"


def is_repo_valid(repo_root_url: str) -> bool:
    """
    Checks if the the `repo_root_url` is valid.

    Parameters
    ----------
    repo_root_url (str): URL to the root of the repository.

    Returns
    -------
    `True` if the repository respects the file structure, otherwise `False`.
    """
    try:
        # Choose branch by checking if the `packagelist` file exists
        with get(f"{repo_root_url}/packagelist") as result:
            result.raise_for_status()
            return True
    except Exception:
        return False


def __parse_github_url(url: str) -> Optional[str]:
    """
    Parses GitHub url and returns a url to the root of the files.

    Returns
    -------
    Url to the root of the files or `None` if error.
    """

    GITHUB_RAW_URL = "https://raw.githubusercontent.com"

    # If does not follow format `https://github.com/account/repository`
    if url.split(SupportedGitProviderLinks.GITHUB_URL)[1].count("/") != 2:
        return None

    return url.replace(SupportedGitProviderLinks.GITHUB_URL, GITHUB_RAW_URL)


def __parse_gitlab_url(url: str) -> Optional[str]:
    """
    Parses GitLab url and returns a url to the root of the files.

    Returns
    -------
    Url to the root of the files or `None` if error.
    """

    GITLAB_RAW_SUFFIX = "/-/raw"

    # If does not follow format `https://gitlab.com/account/repository`
    if url.split(SupportedGitProviderLinks.GITLAB_URL)[1].count("/") != 2:
        return None

    return url + GITLAB_RAW_SUFFIX


def __parse_bitbucket_url(url: str) -> Optional[str]:
    """
    Parses Bitbucket url and returns a url to the root of the files.

    Returns
    -------
    Url to the root of the files or `None` if error.
    """

    BITBUCKET_RAW_SUFFIX = "/raw"

    # If does not follow format `https://bitbucket.org/account/repository`
    if url.split(SupportedGitProviderLinks.BITBUCKET_URL)[1].count("/") != 2:
        return None

    return url + BITBUCKET_RAW_SUFFIX


def parse_url(url: str) -> Optional[str]:
    """
    Tries to transform the given URL to a URL to the root of the raw git repository.

    Supported Git Providers
    -----------------------
    `GitHub`, `GitLab` and `BitBucket`

    Other Git Providers
    -------------------
    If the Git provider is not part of the list above, the URL is returned as-is.

    Returns
    -------
    The transformed URL if success, otherwise `None`
    """

    parsed_url: Optional[str] = url[:-1] if url.endswith("/") else url
    if url.startswith(SupportedGitProviderLinks.GITHUB_URL):
        parsed_url = __parse_github_url(url)
    elif url.startswith(SupportedGitProviderLinks.GITLAB_URL):
        parsed_url = __parse_gitlab_url(url)
    elif url.startswith(SupportedGitProviderLinks.BITBUCKET_URL):
        parsed_url = __parse_bitbucket_url(url)

    return parsed_url


def __validate_attribute(
    repo_name: str, conf: Dict[str, Optional[str]], attribute_name: str, type: type
) -> bool:
    """
    Checks if the given `attribute_name` is part of `conf` and has the type `type`.

    Returns
    -------
    If any of the conditions fail, an error message is printed and returns `False`, otherwise returns `True`.
    """

    if attribute_name not in conf:
        fancy(
            "error",
            f"Repository '{repo_name}' is missing required attribute '{attribute_name}'",
        )
        return False
    if type(conf[attribute_name]) is not type:
        fancy(
            "error",
            f"Repository '{repo_name}' attribute '{attribute_name}' must be of type '{type}'",
        )
        return False
    return True


def __raise_unreachable() -> NoReturn:
    """
    Small hack to help the type checker in complex cases.
    """
    raise Exception("Unreachable code. This will never be raised.")


class ReadConfigErrorCode(IntEnum):
    """
    Possible error codes returned when reading and validating `config.toml`
    """

    ERR_NO_FILE_OR_INVALID_PERM = 0
    ERR_INVALID_REPOSITORY = 1
    ERR_INVALID_OR_MISSING_ATTR = 2
    ERR_UNKNOWN = 3


def read_config() -> Tuple[
    Optional[ReadConfigErrorCode], Optional[List[RepositoryConfig]]
]:
    """
    Reads and parses the repository list.

    Returns
    -------
    A tuple consisting of the error code, and the repository list.
    If the error code is `None` then the repository list will *not* be `None` and vice-versa.
    """
    try:
        config_dict: Optional[Dict[str, Dict[str, Dict[str, Optional[str]]]]] = None
        try:
            with open(PACSTALL_CONFIG_PATH) as file:
                config_dict = tomli.load(file)  # type: ignore[arg-type]
        except OSError as error:
            fancy(
                "error",
                f"Could not read repositories from file '{PACSTALL_CONFIG_PATH}'.\n{error}",
            )

            return (ReadConfigErrorCode.ERR_NO_FILE_OR_INVALID_PERM, None)

        parsed_repo_list: List[RepositoryConfig] = []
        for (repo_name, conf) in config_dict["repository"].items():
            if not __validate_attribute(
                repo_name, conf, attribute_name="url", type=str
            ) or not __validate_attribute(
                repo_name, conf, attribute_name="branch", type=str
            ):
                return (ReadConfigErrorCode.ERR_INVALID_OR_MISSING_ATTR, None)

            # Help type checker recognize `[conf["url"]` is not None
            url = conf["url"] if conf["url"] is not None else __raise_unreachable()
            parsed_url: Optional[str] = parse_url(url)
            if parsed_url is None:
                fancy(
                    "error",
                    f"Repository '{repo_name}' has invalid attribute 'url': {url}",
                )
                return (ReadConfigErrorCode.ERR_INVALID_OR_MISSING_ATTR, None)

            # Help type checker recognize `[conf["branch"]` is not None
            branch = (
                conf["branch"] if conf["branch"] is not None else __raise_unreachable()
            )
            repo_entry = RepositoryConfig(repo_name, parsed_url, branch)

            if not is_repo_valid(f"{repo_entry.url}/{repo_entry.branch}"):
                fancy(
                    "error",
                    f"File 'packagelist' not found in the '{repo_name}' repository root.",
                )
                return (ReadConfigErrorCode.ERR_INVALID_REPOSITORY, None)

            parsed_repo_list.append(repo_entry)

        return (None, parsed_repo_list)
    except Exception as error:
        fancy(
            "error", f"Unknown exception occurred while parsing config file.\n{error}"
        )
        return (ReadConfigErrorCode.ERR_UNKNOWN, None)
