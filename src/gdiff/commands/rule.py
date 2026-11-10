"""gdiff rule <path|init|reset>: look at and manage the rule file."""

import argparse
import sys
from collections.abc import Callable

from gdiff import rules, ui
from gdiff.errors import GdiffError

SUMMARY = "Show which rule file is used and manage it"


def add_arguments(parser: argparse.ArgumentParser) -> None:
    parser.add_argument("action", nargs="?")


def build_help() -> str:
    config = rules.config_dir()
    return "\n".join(
        [
            ui.bold("DESCRIPTION"),
            "  Show which rule file is used and manage it.",
            "",
            ui.bold("USAGE"),
            "  gdiff rule <path|init|reset>",
            "",
            ui.bold("RULE ACTIONS"),
            "  path     Show which rule file is being used",
            f"  init     Create an editable copy of the default rule in {config}",
            "  reset    Overwrite your rule with the default one",
            "",
            ui.bold("LOOKUP ORDER"),
            "  1. gdiff -r <file>    (highest)",
            f"  2. {config / 'rule.txt'} (or rule.md)",
            "  3. built-in default rule",
            "",
            ui.bold("GLOBAL FLAGS"),
            "  -h, --help    Show help information",
        ]
    )


def run_path() -> int:
    path = rules.resolve_rule()
    print(path)
    if path == rules.default_rule_path():
        print(
            "Using the built-in default rule. Run 'gdiff rule init' to create an editable copy.",
            file=sys.stderr,
        )
    return 0


def run_init() -> int:
    existing = rules.existing_user_rule()
    if existing:
        print(f"A rule file already exists at {existing} (left untouched).")
        return 0
    target = rules.write_user_rule()
    ui.success(f"Created an editable rule at {target}")
    return 0


def run_reset() -> int:
    existing = rules.existing_user_rule()
    if existing and not ui.confirm(f"A rule file already exists at {existing}. Overwrite?"):
        print("Operation cancelled.")
        return 0
    target = rules.write_user_rule()
    ui.success(f"Reset the rule to the built-in default at {target}")
    return 0


_ACTIONS: dict[str, Callable[[], int]] = {
    "path": run_path,
    "init": run_init,
    "reset": run_reset,
}


def run(args: argparse.Namespace) -> int:
    names = list(_ACTIONS)
    valid = f"{', '.join(names[:-1])} or {names[-1]}"
    if args.action is None:
        raise GdiffError(f"Command 'rule' requires an action: {valid}.")
    handler = _ACTIONS.get(args.action)
    if handler is None:
        raise GdiffError(f"Unknown rule action: '{args.action}'. Valid actions: {valid}.")
    return handler()
