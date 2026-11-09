"""Colours and the few messages shared by every command."""

import os
import sys
from typing import TextIO

_RED = "\033[0;31m"
_GREEN = "\033[0;32m"
_BOLD = "\033[1m"
_RESET = "\033[0m"


def _paint(text: str, code: str, stream: TextIO) -> str:
    if os.environ.get("NO_COLOR") or not stream.isatty():
        return text
    return f"{code}{text}{_RESET}"


def red(text: str, stream: TextIO | None = None) -> str:
    return _paint(text, _RED, stream or sys.stderr)


def green(text: str, stream: TextIO | None = None) -> str:
    return _paint(text, _GREEN, stream or sys.stdout)


def bold(text: str, stream: TextIO | None = None) -> str:
    return _paint(text, _BOLD, stream or sys.stdout)


def error(label: str, message: str, hint: str | None = None) -> None:
    print(f"{red(label)} {message}", file=sys.stderr)
    if hint:
        print(hint, file=sys.stderr)


def success(message: str) -> None:
    print(f"{green('✓')} {message}")


def confirm(message: str) -> bool:
    """Ask a y/N question on stdout. Anything but y/yes (or EOF) means no."""
    sys.stdout.write(f"{red('Warning:', sys.stdout)} {message} (y/N): ")
    sys.stdout.flush()
    answer = sys.stdin.readline().strip().lower()
    return answer in ("y", "yes")
