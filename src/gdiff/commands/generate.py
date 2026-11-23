"""The default command: diff (+ rule) to the clipboard or to stdout."""

import argparse
import sys

from gdiff import clipboard, git, rules, ui
from gdiff.errors import GdiffError

FLAGS = {"commit": "-c", "rule": "-r", "print_only": "-p", "diff_only": "-d"}


def add_arguments(parser: argparse.ArgumentParser) -> None:
    parser.add_argument(
        "-c", "--commit", dest="commit", action="store", nargs="?", const="1", default=None
    )
    parser.add_argument(
        "-p",
        "--print",
        dest="print_only",
        action="store_true",
        default=False,
    )

    group = parser.add_mutually_exclusive_group(required=False)
    group.add_argument(
        "-r",
        "--rule",
        dest="rule",
        action="store",  # takes exactly one value: the rule file
        nargs=None,
        default=None,
    )
    group.add_argument(
        "-d",
        "--diff-only",
        dest="diff_only",
        action="store_true",
        default=False,
    )


def passed_flags(args: argparse.Namespace, parser: argparse.ArgumentParser) -> list[str]:
    """Flags of the default command that the user actually typed."""
    return [flag for dest, flag in FLAGS.items() if getattr(args, dest) != parser.get_default(dest)]


def run(args: argparse.Namespace) -> int:
    # Same order as the bash version: rule problems are reported before git ones
    rule_text = ""
    using_default = False

    if not args.diff_only:
        rule_path = rules.resolve_rule(args.rule)
        rules.check_rule(rule_path)
        rule_text = rules.read_rule(rule_path)
        using_default = rule_path == rules.default_rule_path()

    git.ensure_repo()
    if args.commit is None:
        if not git.has_staged():
            raise GdiffError("Use 'git add' to stage your changes first.", label="Nothing staged.")
        diff = git.staged_diff()
    else:
        diff = git.commit_diff(git.resolve_commit(args.commit))

    payload = f"{diff}\n\n{rule_text}"

    if args.print_only:
        # Keep the diff's existing CRLF/LF endings instead of translating them on Windows
        reconfigure = getattr(sys.stdout, "reconfigure", None)
        if reconfigure:
            reconfigure(newline="")
        sys.stdout.write(payload)
        return 0

    clipboard.copy(payload)
    ui.success(_success_message(args.diff_only, using_default))
    return 0


def _success_message(diff_only: bool, using_default: bool) -> str:
    if diff_only:
        return "Diff copied to clipboard"
    if using_default:
        return "Diff with default rule copied to clipboard"
    return "Diff with rule copied to clipboard"
