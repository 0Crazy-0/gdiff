"""gdiff message [REF] [-i]: print a commit message to the terminal."""

import argparse
import sys

from gdiff import git


def add_arguments(parser: argparse.ArgumentParser) -> None:
    parser.add_argument("ref", nargs="?", default="1", metavar="REF")
    parser.add_argument("-i", "--info", action="store_true")


def run(args: argparse.Namespace) -> int:
    git.ensure_repo()
    commit_hash = git.resolve_commit(args.ref)
    sys.stdout.write(git.commit_message(commit_hash, args.info))
    return 0
