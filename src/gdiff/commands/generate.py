"""The default command: diff (+ rule) to the clipboard or to stdout."""

import argparse
import sys

from gdiff import clipboard, git, rules, ui
from gdiff.errors import GdiffError

DESTS = ("commit", "rule", "print_only", "diff_only")


def add_arguments(parser: argparse.ArgumentParser) -> None:
    parser.add_argument("-c", "--commit", nargs="?", const="1", default=None)
    parser.add_argument("-p", "--print", dest="print_only", action="store_true")

    group = parser.add_mutually_exclusive_group()
    group.add_argument("-r", "--rule")  # takes exactly one value: the rule file
    group.add_argument("-d", "--diff-only", dest="diff_only", action="store_true")


def run(args: argparse.Namespace) -> int:
    # Same order as the bash version: rule problems are reported before git ones
    rule_text = ""
    if not args.diff_only:
        rule_path = rules.resolve_rule(args.rule)
        rules.check_rule(rule_path)
        rule_text = rules.read_rule(rule_path)

    git.ensure_repo()
    if args.commit is None:
        if not git.has_staged():
            raise GdiffError("Use 'git add' to stage your changes first.", label="Nothing staged.")
        diff = git.staged_diff()
    else:
        diff = git.commit_diff(git.resolve_commit(args.commit))

    payload = f"{diff}\n\n{rule_text}"

    if args.print_only:
        sys.stdout.write(payload)
        return 0

    clipboard.copy(payload)
    ui.success("Diff copied to clipboard" if args.diff_only else "Diff + rule copied to clipboard")
    return 0
