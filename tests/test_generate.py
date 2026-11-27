from __future__ import annotations

import argparse
import sys
from pathlib import Path

import pytest

from gdiff import clipboard, git, rules
from gdiff.commands import generate
from gdiff.errors import GdiffError

STAGED_DIFF = "staged diff\n"
COMMIT_DIFF = "commit diff\n"
COMMIT_HASH = "a" * 40


# add_arguments


def test_flags_have_their_defaults() -> None:
    args = _parse()

    assert args.commit is None
    assert args.print_only is False
    assert args.rule is None
    assert args.diff_only is False


@pytest.mark.parametrize("flag", ["-c", "--commit"])
def test_commit_without_value_means_latest(flag: str) -> None:
    assert _parse(flag).commit == "1"


@pytest.mark.parametrize("flag", ["-c", "--commit"])
def test_commit_accepts_a_value(flag: str) -> None:
    assert _parse(flag, "3").commit == "3"


@pytest.mark.parametrize("flag", ["-p", "--print"])
def test_print_is_a_switch(flag: str) -> None:
    args = _parse(flag)

    assert args.print_only is True
    assert args.diff_only is False


@pytest.mark.parametrize("flag", ["-d", "--diff-only"])
def test_diff_only_is_a_switch(flag: str) -> None:
    args = _parse(flag)

    assert args.diff_only is True
    assert args.print_only is False


@pytest.mark.parametrize("flag", ["-r", "--rule"])
def test_rule_takes_one_value(flag: str) -> None:
    assert _parse(flag, "my-rule.txt").rule == Path("my-rule.txt")


def test_rule_and_diff_only_are_mutually_exclusive() -> None:
    with pytest.raises(SystemExit):
        _parse("-r", "my-rule.txt", "-d")


# passed_flags


def test_passed_flags_is_empty_when_nothing_was_typed() -> None:
    parser = _build_parser()
    args = parser.parse_args([])

    assert generate.passed_flags(args, parser) == []


# In production, a non-empty result makes cli._dispatch reject the command,
# e.g. `gdiff -p rule path` fails with "'rule' cannot be combined with -p."
@pytest.mark.parametrize(
    ("argv", "expected"),
    [
        (["-c"], ["-c"]),
        (["-c", "3"], ["-c"]),
        (["-r", "my-rule.txt"], ["-r"]),
        (["-p"], ["-p"]),
        (["-d"], ["-d"]),
        (["-p", "-c", "2"], ["-c", "-p"]),
    ],
)
def test_passed_flags_lists_only_what_was_typed(argv: list[str], expected: list[str]) -> None:
    parser = _build_parser()
    args = parser.parse_args(argv)

    assert generate.passed_flags(args, parser) == expected


# run: print


def test_print_staged_diff_followed_by_custom_rule(
    env: _Env, monkeypatch: pytest.MonkeyPatch, tmp_path: Path
) -> None:
    stdout = _FakeStdout()
    monkeypatch.setattr(sys, "stdout", stdout)
    rule_file = _write_rule(tmp_path, "Custom rule\n")

    code = generate.run(_args(print_only=True, rule=rule_file))

    assert code == 0
    assert stdout.written == f"{STAGED_DIFF}\n\nCustom rule\n"
    assert env.copied == []


def test_print_diff_only_has_no_rule(env: _Env, monkeypatch: pytest.MonkeyPatch) -> None:
    stdout = _FakeStdout()
    monkeypatch.setattr(sys, "stdout", stdout)

    code = generate.run(_args(print_only=True, diff_only=True))

    assert code == 0
    assert stdout.written == f"{STAGED_DIFF}\n\n"
    assert env.copied == []


def test_print_keeps_line_endings_untranslated(env: _Env, monkeypatch: pytest.MonkeyPatch) -> None:
    stdout = _FakeStdout()
    monkeypatch.setattr(sys, "stdout", stdout)

    generate.run(_args(print_only=True, diff_only=True))

    assert stdout.reconfigure_calls == [{"newline": ""}]


def test_print_works_when_stdout_cannot_be_reconfigured(
    env: _Env, monkeypatch: pytest.MonkeyPatch
) -> None:
    # sys.stdout always has reconfigure() in real runs; a stream without it
    # (e.g. a wrapper installed by another tool) exercises the fallback branch in isolation.
    stdout = _PlainStdout()
    monkeypatch.setattr(sys, "stdout", stdout)

    code = generate.run(_args(print_only=True, diff_only=True))

    assert code == 0
    assert stdout.written == f"{STAGED_DIFF}\n\n"


# run: clipboard


def test_copy_with_default_rule(env: _Env, capsys: pytest.CaptureFixture[str]) -> None:
    default_rule = rules.read_rule(rules.default_rule_path())

    code = generate.run(_args())

    assert code == 0
    assert env.copied == [f"{STAGED_DIFF}\n\n{default_rule}"]
    assert capsys.readouterr().out == "✓ Diff with default rule copied to clipboard\n"


def test_copy_with_custom_rule(
    env: _Env, capsys: pytest.CaptureFixture[str], tmp_path: Path
) -> None:
    rule_file = _write_rule(tmp_path, "Custom rule\n")

    code = generate.run(_args(rule=rule_file))

    assert code == 0
    assert env.copied == [f"{STAGED_DIFF}\n\nCustom rule\n"]
    assert capsys.readouterr().out == "✓ Diff with rule copied to clipboard\n"


def test_copy_diff_only(env: _Env, capsys: pytest.CaptureFixture[str]) -> None:
    code = generate.run(_args(diff_only=True))

    assert code == 0
    assert env.copied == [f"{STAGED_DIFF}\n\n"]
    assert capsys.readouterr().out == "✓ Diff copied to clipboard\n"


# run: which diff


def test_nothing_staged_raises(env: _Env) -> None:
    env.has_staged = False

    with pytest.raises(GdiffError) as excinfo:
        generate.run(_args(diff_only=True))

    assert str(excinfo.value) == "Use 'git add' to stage your changes first."
    assert excinfo.value.label == "Nothing staged."
    assert env.copied == []


def test_commit_diff_is_used_when_a_commit_is_given(
    env: _Env, monkeypatch: pytest.MonkeyPatch
) -> None:
    stdout = _FakeStdout()
    monkeypatch.setattr(sys, "stdout", stdout)

    generate.run(_args(commit="3", print_only=True, diff_only=True))

    assert env.resolved == ["3"]
    assert env.commit_diffs == [COMMIT_HASH]
    assert stdout.written == f"{COMMIT_DIFF}\n\n"
    assert env.copied == []


# _success_message


def test_success_message_when_only_the_diff_is_copied() -> None:
    message = generate._success_message(diff_only=True, using_default=False)

    assert message == "Diff copied to clipboard"


def test_success_message_diff_only_wins_over_default_rule() -> None:
    # run() never produces this pair, since --diff-only skips resolving the rule;
    # it checks in isolation that diff_only takes priority over using_default.
    message = generate._success_message(diff_only=True, using_default=True)

    assert message == "Diff copied to clipboard"


def test_success_message_mentions_the_default_rule() -> None:
    message = generate._success_message(diff_only=False, using_default=True)

    assert message == "Diff with default rule copied to clipboard"


def test_success_message_for_a_custom_rule() -> None:
    message = generate._success_message(diff_only=False, using_default=False)

    assert message == "Diff with rule copied to clipboard"


class _Env:
    """What the fake git and clipboard saw and what they should answer."""

    def __init__(self) -> None:
        self.has_staged = True
        self.copied: list[str] = []
        self.resolved: list[str] = []
        self.commit_diffs: list[str] = []


class _PlainStdout:
    def __init__(self) -> None:
        self.written: str = ""

    def write(self, text: str) -> int:
        self.written += text
        return len(text)


class _FakeStdout(_PlainStdout):
    def __init__(self) -> None:
        super().__init__()
        self.reconfigure_calls: list[dict[str, object]] = []

    def reconfigure(self, **kwargs: object) -> None:
        self.reconfigure_calls.append(kwargs)


@pytest.fixture
def env(monkeypatch: pytest.MonkeyPatch, tmp_path: Path) -> _Env:
    fake = _Env()

    def resolve_commit(target: str) -> str:
        fake.resolved.append(target)
        return COMMIT_HASH

    def commit_diff(commit_hash: str) -> str:
        fake.commit_diffs.append(commit_hash)
        return COMMIT_DIFF

    # No user rule on disk, so the built-in one is the default
    monkeypatch.setenv("GDIFF_CONFIG_HOME", str(tmp_path / "config"))
    monkeypatch.setattr(git, "ensure_repo", lambda: None)
    monkeypatch.setattr(git, "has_staged", lambda: fake.has_staged)
    monkeypatch.setattr(git, "staged_diff", lambda: STAGED_DIFF)
    monkeypatch.setattr(git, "resolve_commit", resolve_commit)
    monkeypatch.setattr(git, "commit_diff", commit_diff)
    monkeypatch.setattr(clipboard, "copy", fake.copied.append)
    return fake


def _build_parser() -> argparse.ArgumentParser:
    parser = argparse.ArgumentParser(allow_abbrev=False)
    generate.add_arguments(parser)
    return parser


def _parse(*argv: str) -> argparse.Namespace:
    return _build_parser().parse_args(list(argv))


def _args(**overrides: object) -> argparse.Namespace:
    values: dict[str, object] = {
        "commit": None,
        "rule": None,
        "print_only": False,
        "diff_only": False,
    }
    values.update(overrides)
    return argparse.Namespace(**values)


def _write_rule(tmp_path: Path, text: str) -> Path:
    path = tmp_path / "rule.txt"
    path.write_text(text, encoding="utf-8", newline="")
    return path
