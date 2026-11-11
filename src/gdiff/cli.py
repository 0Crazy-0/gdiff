import argparse
import os
import sys
from collections.abc import Sequence
from typing import NoReturn, TextIO

from gdiff import __version__, ui
from gdiff.commands import generate, message, rule
from gdiff.errors import GdiffError

# Subcommands must be the first argument; anything else goes to `generate`.
COMMANDS = {"message": message, "rule": rule}


class _Parser(argparse.ArgumentParser):
    """argparse that raises GdiffError and prints gdiff's own help."""

    help_text = ""

    def error(self, message: str) -> NoReturn:
        raise GdiffError(message, hint="  Run 'gdiff --help' for usage.")

    def print_help(self, file: TextIO | None = None) -> None:
        print(self.help_text, file=file or sys.stdout)


def _build_main_help() -> str:
    commands: list[str] = [f"  {name:<10}{module.SUMMARY}" for name, module in COMMANDS.items()]
    return "\n".join(
        [
            ui.bold("DESCRIPTION"),
            "  Copy your git diff plus a commit-message rule to the clipboard.",
            "",
            ui.bold("USAGE"),
            "  gdiff [flags]",
            "  gdiff <command> [args]",
            "",
            ui.bold("COMMANDS"),
            *commands,
            "",
            ui.bold("FLAGS"),
            "  -c, --commit [REF]    Diff of a commit: position, hash or ref (default: 1 = latest)",
            "  -r, --rule <file>     Use a custom rule file (.txt or .md)",
            "  -p, --print           Print the output instead of copying to clipboard",
            "  -d, --diff-only       Copy only the diff, without the rule",
            "",
            ui.bold("GLOBAL FLAGS"),
            "  -h, --help            Show help information",
            "  -v, --version         Show version information",
        ]
    )


def _build_parser() -> argparse.ArgumentParser:
    parser = _Parser(prog="gdiff", allow_abbrev=False)

    parser.help_text = _build_main_help()

    parser.add_argument("-v", "--version", action="version", version=f"gdiff v{__version__}")

    generate.add_arguments(parser)

    sub = parser.add_subparsers(dest="command")

    for name, module in COMMANDS.items():
        sub_parser = sub.add_parser(name, allow_abbrev=False)
        sub_parser.help_text = module.build_help()
        module.add_arguments(sub_parser)

    return parser


def _dispatch(argv: list[str]) -> int:
    if argv and not argv[0].startswith("-") and argv[0] not in COMMANDS:
        raise GdiffError(
            f"'{argv[0]}'",
            label="Unknown command:",
            hint="  Run 'gdiff --help' for a list of valid commands.",
        )

    parser = _build_parser()
    args = parser.parse_args(argv)

    if args.command is None:
        return generate.run(args)

    used = [d for d in generate.DESTS if getattr(args, d) != parser.get_default(d)]

    if used:
        parser.error(f"'{args.command}' cannot be combined with -c, -r, -p or -d.")

    return COMMANDS[args.command].run(args)


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
