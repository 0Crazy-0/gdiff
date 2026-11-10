"""Finding, validating and installing the commit-message rule. Never prints or asks."""

import os
import shutil
import sys
from importlib import resources
from pathlib import Path

from gdiff.errors import GdiffError

RESET_HINT = "Please edit the file or run 'gdiff rule reset' to restore the default rule."


def config_dir() -> Path:
    override = os.environ.get("GDIFF_CONFIG_HOME")

    if override:
        return Path(override)

    if sys.platform == "win32":
        base = os.environ.get("APPDATA") or str(Path.home() / ".config")
    else:
        base = os.environ.get("XDG_CONFIG_HOME") or str(Path.home() / ".config")

    return Path(base) / "gdiff"


def user_rule_path() -> Path:
    return config_dir() / "rule.txt"


def existing_user_rule() -> Path | None:
    """The user's own rule (rule.txt wins over rule.md), if there is one."""
    for name in ("rule.txt", "rule.md"):
        candidate = config_dir() / name
        if candidate.is_file():
            return candidate
    return None


def default_rule_path() -> Path:
    # A real file on disk: gdiff is installed as loose files, not as a zipapp
    return Path(str(resources.files("gdiff") / "data" / "rule.txt"))


def resolve_rule(custom: str | None = None) -> Path:
    """--rule file > user rule in the config dir > rule shipped with gdiff."""
    if custom:
        path = Path(custom)
        if not path.is_file():
            raise GdiffError(f"Rule file not found: {custom}")
        return path

    user_rule = existing_user_rule()
    if user_rule:
        return user_rule

    packaged = default_rule_path()
    if packaged.is_file():
        return packaged
    raise GdiffError(
        f"Built-in rule file is missing: {packaged}",
        hint="The installation looks broken. Try reinstalling gdiff.",
    )


def check_rule(path: Path) -> None:
    if path.stat().st_size == 0:
        raise GdiffError(f"Rule file is empty: {path}", hint=RESET_HINT)


def read_rule(path: Path) -> str:
    # Read bytes and decode by hand so CRLF in the rule is kept as written
    try:
        return path.read_bytes().decode("utf-8")
    except (OSError, UnicodeDecodeError) as exc:
        raise GdiffError(f"Cannot read rule file {path}: {exc}") from None


def write_user_rule() -> Path:
    """Copy the built-in rule to the config dir, replacing whatever is there.

    Deciding whether that is acceptable (prompting, refusing) is the caller's job.
    """
    source = default_rule_path()
    if not source.is_file():
        raise GdiffError(f"Built-in rule file is missing: {source}")
    target = user_rule_path()
    try:
        target.parent.mkdir(parents=True, exist_ok=True)
        shutil.copyfile(source, target)
    except OSError as exc:
        raise GdiffError(f"Cannot write {target}: {exc}") from None
    return target
