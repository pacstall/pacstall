#!/usr/bin/env python3

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

import sys
from argparse import ArgumentParser, HelpFormatter, Namespace

from pacstall.api.color import Foreground


class CustomHelpFormatter(HelpFormatter):
    """Custom Help Formatter class for Pacstall"""

    def _format_action_invocation(self, action) -> str:  # type: ignore[no-untyped-def]
        """
        Define Pacstall help menu format

        Format:
        -s, --long       help message
        """
        if not action.option_strings:
            (metavar,) = self._metavar_formatter(action, action.dest)(1)
            return metavar

        parts = []
        # if the Optional doesn't take a value, format is:
        #    -s, --long
        if action.nargs == 0:
            parts.extend(action.option_strings)

        # if the Optional takes a value, format is:
        #    -s ARGS, --long ARGS
        # change to
        #    -s, --long
        else:
            for option_string in action.option_strings:
                parts.append("%s" % option_string)
        return ", ".join(parts)


def parse_arguments() -> Namespace:
    """Parses command line arguments passed to Pacstall.

    Prints help and exits if no argument is passed.

    Namespace Attributes
    --------------------
        - Globally
            - command : ``str``
                The command passed to pacstall.

        - For install command
            - packages : ``List[str]``
                Packages to install.
            - disable_prompts : ``boolean``
                Whether to disable prompts.
            - keep : ``boolean``
                Signifying whether to keep the build directory after installation.

        - For remove command
            - packages : ``List[str]``
                Packages to remove.
            - disable_prompts : ``boolean``
                Signifying whether to disable prompts.

        - For upgrade command
            - packages : ``List[str] | None``
                Packages to upgrade.

                If ``None``, signifies interactive upgrades of all packages installed.
            - disable_prompts : ``boolean``
                Whether to disable prompts.
            - keep : ``boolean``
                Whether to keep the build directory after upgrades.

        - For download command
            - pacscripts : ``List[str]``
                Pacscripts to download.

        - For search command
            - packages : ``List[str]``
                Packages to search for.

        - For list command : `command`

        - For info command
            - packages : ``List[str]``
                Packages to show the info of.

        - For repo command
            - subcommand: ``str``
                The subcommand passed to a pacstall command.
                Ex: `repo add` (`add` is the `subcommand`).

                - For list subcommand
                    `command` and `subcommand`.

                - For add subcommand
                    - repositories : ``List[str]``
                        Repositories to add to package sources.

                - For remove subcommand
                    - repositories : ``List[str]``
                        Repositories to remove from package sources.
    Returns
    -------
    parsed arguments : Namespace
    """

    # Define our main argument parser
    parser = ArgumentParser(prog="pacstall", formatter_class=CustomHelpFormatter)
    parser.add_argument(
        "-V",
        "--version",
        action="version",
        version=f"{Foreground.BIBLUE}Pacstall {Foreground.BIWHITE}2.0.0 {Foreground.BIYELLOW}Kournikova",
        help="Print pacstall version",
    )
    # Define our command subparsers
    subparsers = parser.add_subparsers(dest="command")

    # HACK: The titles couldn't be modified in any Pythonic way.
    #       Please make a PR if you have a better way to do this.
    parser._positionals.title = "commands"
    parser._optionals.title = "options"

    # Define parser for the `install` command
    install_parser = subparsers.add_parser(
        "install",
        help="Install packages",
    )
    install_parser.add_argument(
        "packages",
        metavar="packages",
        nargs="+",
        help="Packages/pacscripts to install",
    )
    install_parser.add_argument(
        "-P",
        "--disable-prompts",
        dest="disable_prompts",
        action="store_true",
        help="Disable prompts for unattended operations",
    )
    install_parser.add_argument(
        "-K",
        "--keep",
        dest="keep",
        action="store_true",
        help="Retain build directory after installation",
    )
    # HACK: The titles couldn't be modified in any Pythonic way.
    #       Please make a PR if you have a better way to do this.
    install_parser._positionals.title = "arguments"
    install_parser._optionals.title = "options"

    # Define parser for the `remove` command
    remove_parser = subparsers.add_parser("remove", help="Remove packages")
    remove_parser.add_argument("packages", nargs="+", help="Packages to remove")
    remove_parser.add_argument(
        "-P",
        "--disable-prompts",
        dest="disable_prompts",
        action="store_true",
        help="Disable prompts for unattended operations",
    )
    # HACK: The titles couldn't be modified in any Pythonic way.
    #       Please make a PR if you have a better way to do this.
    remove_parser._positionals.title = "arguments"
    remove_parser._optionals.title = "options"

    # Define parser for the `upgrade` command
    upgrade_parser = subparsers.add_parser(
        "upgrade",
        help="Upgrade packages",
        epilog="Leave argument blank to upgrade all packages interactively",
    )
    upgrade_parser.add_argument("packages", nargs="?", help="Packages to upgrade")
    upgrade_parser.add_argument(
        "-P",
        "--disable-prompts",
        dest="disable_prompts",
        action="store_true",
        help="Disable prompts for unattended operations",
    )
    upgrade_parser.add_argument(
        "-K",
        "--keep",
        dest="keep",
        action="store_true",
        help="Retain build directory after upgrades",
    )
    # HACK: The titles couldn't be modified in any Pythonic way.
    #       Please make a PR if you have a better way to do this.
    upgrade_parser._positionals.title = "arguments"
    upgrade_parser._optionals.title = "options"

    # Define parser for the `download` command
    download_parser = subparsers.add_parser("download", help="Download pacscripts")
    download_parser.add_argument("pacscripts", nargs="+", help="Pacscripts to download")
    # HACK: The titles couldn't be modified in any Pythonic way.
    #       Please make a PR if you have a better way to do this.
    download_parser._positionals.title = "arguments"
    download_parser._optionals.title = "options"

    # Define parser for the `search` command
    search_parser = subparsers.add_parser("search", help="Search for packages")
    search_parser.add_argument("packages", nargs="+", help="Packages to search for")
    # HACK: The titles couldn't be modified in any Pythonic way.
    #       Please make a PR if you have a better way to do this.
    search_parser._positionals.title = "arguments"
    search_parser._optionals.title = "options"

    # Define parser for the `list` command
    list_parser = subparsers.add_parser("list", help="List installed packages")
    # HACK: The titles couldn't be modified in any Pythonic way.
    #       Please make a PR if you have a better way to do this.
    list_parser._positionals.title = "arguments"
    list_parser._optionals.title = "options"

    # Define parser for the `info` command
    info_parser = subparsers.add_parser("info", help="Show package info")
    info_parser.add_argument(
        "packages", nargs="+", help="Packages to show the infos of"
    )
    # HACK: The titles couldn't be modified in any Pythonic way.
    #       Please make a PR if you have a better way to do this.
    info_parser._positionals.title = "arguments"
    info_parser._optionals.title = "options"

    # Define parser for the `repo` command
    repo_parser = subparsers.add_parser(
        "repo",
        help="Modify package sources",
        formatter_class=CustomHelpFormatter,
    )
    # HACK: The titles couldn't be modified in any Pythonic way.
    #       Please make a PR if you have a better way to do this.
    repo_parser._positionals.title = "commands"
    repo_parser._optionals.title = "options"

    # Define subparsers for the `repo` command's subcommands: `list`, `add` & `remove`
    repo_subcommand_subparsers = repo_parser.add_subparsers(dest="subcommand")

    # Define parser for `repo list` subcommand
    repo_list_parser = repo_subcommand_subparsers.add_parser(
        "list", help="List currently installed package sources"
    )
    # HACK: The titles couldn't be modified in any Pythonic way.
    #       Please make a PR if you have a better way to do this.
    repo_list_parser._positionals.title = "arguments"
    repo_list_parser._optionals.title = "options"

    # Define parser for `repo add` subcommand
    repo_add_parser = repo_subcommand_subparsers.add_parser(
        "add", help="Add repositories to package sources"
    )
    repo_add_parser.add_argument(
        "repositories", nargs="+", help="Repositories to add to package sources"
    )
    # HACK: The titles couldn't be modified in any Pythonic way.
    #       Please make a PR if you have a better way to do this.
    repo_add_parser._positionals.title = "arguments"
    repo_add_parser._optionals.title = "options"

    # Define parser for `repo remove` subcommand
    repo_remove_parser = repo_subcommand_subparsers.add_parser(
        "remove", help="Remove repositories from package sources"
    )
    repo_remove_parser.add_argument(
        "repositories", nargs="+", help="Repositories to remove from package sources"
    )
    # HACK: The titles couldn't be modified in any Pythonic way.
    #       Please make a PR if you have a better way to do this.
    repo_remove_parser._positionals.title = "arguments"
    repo_remove_parser._optionals.title = "options"

    # If no arguments are provided, print help and exit
    if len(sys.argv) == 1:
        parser.print_help()
        sys.exit(1)

    # Return the Namespace consisting of parsed arguments
    return parser.parse_args()
