from os import environ
from subprocess import run
from pathlib import Path


def test_launch_as_root():
    # Run the help command as root
    process = run(
        [
            "sudo",
            "-E",
            f"{Path(environ['HOME']) / '.local/bin/poetry'}",
            "run",
            "pacstall",
            "-h",
        ]
    )
    assert process.returncode == 0


def test_launch_as_normal_user():
    # Run the help command as normal user
    process = run(["poetry", "run", "pacstall", "-h"])
    assert process.returncode == 1
