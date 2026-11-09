import argparse
import os
import sys
from collections.abc import Sequence
from typing import NoReturn

from gdiff import __version__, rules, ui
from gdiff.commands import generate, message, rule
from gdiff.errors import GdiffError

# Subcommands must be the first argument; anything else goes to `generate`.
COMMANDS = {"message": message, "rule": rule}


class _Parser(argparse.ArgumentParser):
    """argparse that raises GdiffError instead of printing usage and exiting with 2."""

    def error(self, message: str) -> NoReturn:
        raise GdiffError(message, hint="  Run 'gdiff --help' for usage.")


def _help_text() -> str:
    config = rules.config_dir()
    return "\n".join(
        [
            ui.bold("USAGE"),
            "  gdiff [OPTIONS]",
            "  gdiff message [REF] [-i]",
            "  gdiff rule <path|init|reset>",
            "",
            ui.bold("COMMANDS"),
            "  message [REF]       Print the commit message: position, hash or ref (default: 1 = latest)",
            "  rule path           Show which rule file is being used",
            f"  rule init           Create an editable copy of the default rule in {config}",
            "  rule reset          Overwrite your rule with the default one",
            "",
            ui.bold("OPTIONS"),
            "  -c, --commit [REF]  Diff of a commit: position, hash or ref (default: 1 = latest)",
            "  -i, --info          With 'message': add a header with hash, author and date",
            "  -r, --rule <file>   Use a custom rule file (.txt or .md)",
            "  -p, --print         Print the output instead of copying to clipboard",
            "  -d, --diff-only     Copy only the diff, without the rule",
            "  -v, --version       Show version",
            "  -h, --help          Show this help",
            "",
            ui.bold("NOTES"),
            "  'message' prints to the terminal, does not use a rule, and cannot be",
            "  combined with -c, -r, -p or -d.",
            "",
            ui.bold("RULE PRECEDENCE"),
            "  1. --rule <file>                 (highest)",
            f"  2. {config / 'rule.txt'}  (or rule.md)",
            "  3. built-in default rule",
        ]
    )


def _dispatch(argv: list[str]) -> int:
    command = None
    rest = argv
    if argv and not argv[0].startswith("-"):
        command, rest = argv[0], argv[1:]
        if command not in COMMANDS:
            raise GdiffError(
                f"'{command}'",
                label="Unknown command:",
                hint="  Run 'gdiff --help' for a list of valid commands.",
            )

    for arg in rest:
        if arg in ("-h", "--help"):
            print(_help_text())
            return 0
        if arg in ("-v", "--version"):
            print(f"gdiff v{__version__}")
            return 0

    module = generate if command is None else COMMANDS[command]
    parser = _Parser(add_help=False, allow_abbrev=False)
    module.add_arguments(parser)
    return module.run(parser.parse_args(rest))


def _configure_streams() -> None:
    # The ✓ and non-ASCII diffs break on Windows consoles that default to cp1252
    for stream in (sys.stdout, sys.stderr):
        reconfigure = getattr(stream, "reconfigure", None)
        if reconfigure:
            reconfigure(encoding="utf-8", errors="replace")


def main(argv: Sequence[str] | None = None) -> int:
    _configure_streams()
    args = list(sys.argv[1:] if argv is None else argv)
    try:
        code = _dispatch(args)
        sys.stdout.flush()
        return code
    except GdiffError as err:
        ui.error(err.label, str(err), err.hint)
        return err.exit_code
    except KeyboardInterrupt:
        return 130
    except BrokenPipeError:
        # e.g. `gdiff -p | head`: silence the second error Python raises at exit
        os.dup2(os.open(os.devnull, os.O_WRONLY), sys.stdout.fileno())
        return 1
