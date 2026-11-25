"""Finding, validating and installing the commit-message rule. Never prints or asks."""

import os
import shutil
import sys
from importlib import resources
from pathlib import Path

from gdiff.errors import GdiffError

ALLOWED_SUFFIXES = (".txt",)
RULE_FILENAME = "rule.txt"


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
    return config_dir() / RULE_FILENAME


def existing_user_rule() -> Path | None:
    """The user's own rule, if there is one."""
    candidate = config_dir() / RULE_FILENAME
    return candidate if candidate.is_file() else None


def default_rule_path() -> Path:
    # A real file on disk: gdiff is installed as loose files, not as a zipapp
    return Path(str(resources.files("gdiff") / "data" / RULE_FILENAME))


def resolve_rule(custom: Path | None = None) -> Path:
    """--rule file > user rule in the config dir > rule shipped with gdiff."""
    if custom is not None:
        if custom.suffix.lower() not in ALLOWED_SUFFIXES:
            raise GdiffError(f"Rule file must have a .txt extension: {custom}")

        if not custom.is_file():
            raise GdiffError(f"Rule file not found: {custom}")

        return custom

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
    try:
        size = path.stat().st_size
    except OSError as exc:
        raise GdiffError(f"Cannot read rule file {path}: {exc}") from None
    if size == 0:
        raise GdiffError(
            f"Rule file is empty: {path}",
            hint="Please edit the file or run 'gdiff rule reset' to restore the default rule.",
        )


def read_rule(path: Path) -> str:
    # Read bytes and decode by hand so CRLF in the rule is kept as written
    try:
        return path.read_bytes().decode("utf-8")
    except (OSError, UnicodeDecodeError) as exc:
        raise GdiffError(f"Cannot read rule file {path}: {exc}") from None


def write_user_rule(*, overwrite: bool = True) -> Path:
    """Copy the built-in rule to the config dir.

    With overwrite=False the target is created exclusively and
    FileExistsError is raised if it already exists.
    """
    source = default_rule_path()
    if not source.is_file():
        raise GdiffError(f"Built-in rule file is missing: {source}")
    target = user_rule_path()

    # Directory problems are always a GdiffError, never FileExistsError
    try:
        target.parent.mkdir(parents=True, exist_ok=True)
    except OSError as exc:
        raise GdiffError(f"Cannot write {target}: {exc}") from None

    if overwrite:
        try:
            shutil.copyfile(source, target)
        except OSError as exc:
            raise GdiffError(f"Cannot write {target}: {exc}") from None
        return target

    created = False
    try:
        with source.open("rb") as src, target.open("xb") as dst:
            created = True
            shutil.copyfileobj(src, dst)
    except OSError as exc:
        if created:
            target.unlink(missing_ok=True)
        elif isinstance(exc, FileExistsError):
            raise  # "xb" rejected an existing target: the caller decides
        raise GdiffError(f"Cannot write {target}: {exc}") from None
    return target
