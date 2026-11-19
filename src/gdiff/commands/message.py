"""gdiff message [REF] [-i]: print a commit message to the terminal."""

import argparse
import sys

from gdiff import git, ui

SUMMARY = "Print a commit message (position, hash or ref; default: 1 = latest)"


def add_arguments(parser: argparse.ArgumentParser) -> None:
    parser.add_argument("ref", nargs="?", default="1")
    parser.add_argument("-i", "--info", action="store_true")


def build_help() -> str:
    return "\n".join(
        [
            ui.bold("DESCRIPTION"),
            "  Print a commit message to the terminal, exactly as written.",
            "",
            ui.bold("USAGE"),
            "  gdiff message [REF] [-i]",
            "",
            ui.bold("ARGUMENTS"),
            "  REF           Commit position, hash or ref (default: 1 = latest)",
            "",
            ui.bold("FLAGS"),
            "  -i, --info    Prepend a header with the commit hash, short hash, author and date",
            "",
            ui.bold("GLOBAL FLAGS"),
            "  -h, --help    Show help information",
        ]
    )


def run(args: argparse.Namespace) -> int:
    git.ensure_repo()
    commit_hash = git.resolve_commit(args.ref)
    sys.stdout.write(git.commit_message(commit_hash, args.info))
    return 0
