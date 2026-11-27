from __future__ import annotations

from types import SimpleNamespace

import pytest

from gdiff import git
from gdiff.errors import GdiffError

COMMIT_HASH = "a" * 40

# Not ASCII digits: \d matches them unless the pattern is compiled with re.ASCII
ARABIC_THREE = "\u0663"


# ensure_repo


def test_ensure_repo_asks_git_for_the_git_dir(fake_git: _FakeGit) -> None:
    fake_git.reply(0)

    git.ensure_repo()

    assert fake_git.calls == [("rev-parse", "--git-dir")]


@pytest.mark.parametrize("code", [1, 128])
def test_ensure_repo_fails_outside_a_repository(fake_git: _FakeGit, code: int) -> None:
    fake_git.reply(code)

    with pytest.raises(GdiffError) as excinfo:
        git.ensure_repo()

    assert str(excinfo.value) == "Not inside a git repository."


# has_staged


def test_has_staged_asks_git_quietly_about_the_index(fake_git: _FakeGit) -> None:
    fake_git.reply(0)

    git.has_staged()

    assert fake_git.calls == [("diff", "--cached", "--quiet")]


def test_has_staged_is_false_when_git_exits_0(fake_git: _FakeGit) -> None:
    fake_git.reply(0)

    assert git.has_staged() is False


def test_has_staged_is_true_when_git_exits_1(fake_git: _FakeGit) -> None:
    fake_git.reply(1)

    assert git.has_staged() is True


@pytest.mark.parametrize("code", [2, 128])
def test_has_staged_fails_on_any_other_exit_code(fake_git: _FakeGit, code: int) -> None:
    fake_git.reply(code)

    with pytest.raises(GdiffError) as excinfo:
        git.has_staged()

    assert str(excinfo.value) == "git diff failed."


# staged_diff


def test_staged_diff_returns_stat_and_patch_without_colour(fake_git: _FakeGit) -> None:
    fake_git.reply(0, "the staged diff")

    assert git.staged_diff() == "the staged diff"
    assert fake_git.calls == [("diff", "--cached", "--no-color", "--stat", "--patch")]


# resolve_commit


@pytest.mark.parametrize("target", ["1", "0", "123456"])
def test_resolve_commit_sends_short_digit_strings_to_position(
    monkeypatch: pytest.MonkeyPatch, target: str
) -> None:
    monkeypatch.setattr(git, "_resolve_position", lambda value: f"position:{value}")
    monkeypatch.setattr(git, "_resolve_ref", lambda value: f"ref:{value}")

    assert git.resolve_commit(target) == f"position:{target}"


@pytest.mark.parametrize("target", ["1234567", "abc123", "", ARABIC_THREE])
def test_resolve_commit_sends_everything_else_to_ref(
    monkeypatch: pytest.MonkeyPatch, target: str
) -> None:
    monkeypatch.setattr(git, "_resolve_position", lambda value: f"position:{value}")
    monkeypatch.setattr(git, "_resolve_ref", lambda value: f"ref:{value}")

    assert git.resolve_commit(target) == f"ref:{target}"


# commit_diff


def test_commit_diff_joins_stat_and_patch(fake_git: _FakeGit) -> None:
    fake_git.reply(0, "STAT")
    fake_git.reply(0, "PATCH")

    assert git.commit_diff(COMMIT_HASH) == "STAT\nPATCH"


def test_commit_diff_follows_the_first_parent_of_merges(fake_git: _FakeGit) -> None:
    fake_git.reply(0)
    fake_git.reply(0)

    git.commit_diff(COMMIT_HASH)

    assert fake_git.calls == [
        ("show", "-m", "--first-parent", "--stat", "--format=", COMMIT_HASH),
        ("show", "-m", "--first-parent", "-p", "--format=", COMMIT_HASH),
    ]


# commit_message


def test_commit_message_reads_the_raw_body(fake_git: _FakeGit) -> None:
    fake_git.reply(0, "feat: add X\n")

    git.commit_message(COMMIT_HASH)

    assert fake_git.calls == [("log", "-1", "--encoding=UTF-8", "--format=%B", COMMIT_HASH)]


def test_commit_message_has_no_header_by_default(fake_git: _FakeGit) -> None:
    fake_git.reply(0, "subject\n")

    assert git.commit_message(COMMIT_HASH) == "subject\n"
    assert len(fake_git.calls) == 1


@pytest.mark.parametrize(
    ("raw", "expected"),
    [
        ("subject\n", "subject\n"),
        ("subject\n\n\n", "subject\n"),  # only trailing newlines go
        ("subject  \n", "subject  \n"),  # trailing spaces are part of the message
        ("ends with X\n", "ends with X\n"),  # and so is any other trailing character
        ("\n\nsubject\n", "\n\nsubject\n"),  # leading newlines too
        ("subject\n\nbody line\n", "subject\n\nbody line\n"),
        ("", "\n"),
    ],
)
def test_commit_message_only_trims_trailing_newlines(
    fake_git: _FakeGit, raw: str, expected: str
) -> None:
    fake_git.reply(0, raw)

    assert git.commit_message(COMMIT_HASH) == expected


def test_commit_message_with_info_reads_message_then_header(fake_git: _FakeGit) -> None:
    fake_git.reply(0, "subject\n")
    fake_git.reply(0, "HEADER\n")

    git.commit_message(COMMIT_HASH, with_info=True)

    assert fake_git.calls == [
        ("log", "-1", "--encoding=UTF-8", "--format=%B", COMMIT_HASH),
        (
            "log",
            "-1",
            "--encoding=UTF-8",
            "--date=default",
            "--format=Commit: %H%nShort:  %h%nAuthor: %an <%ae>%nDate:   %ad",
            COMMIT_HASH,
        ),
    ]


def test_commit_message_with_info_puts_header_first(fake_git: _FakeGit) -> None:
    fake_git.reply(0, "subject\n")
    fake_git.reply(0, "HEADER\n")

    assert git.commit_message(COMMIT_HASH, with_info=True) == "HEADER\n\nsubject\n"


@pytest.mark.parametrize(
    ("raw_header", "expected_header"),
    [
        ("HEADER\n", "HEADER"),
        ("HEADER\n\n\n", "HEADER"),  # only trailing newlines go
        ("HEADER \n", "HEADER "),
        ("HEADERX\n", "HEADERX"),
        ("\nHEADER\n", "\nHEADER"),
    ],
)
def test_commit_message_with_info_only_trims_trailing_newlines_of_the_header(
    fake_git: _FakeGit, raw_header: str, expected_header: str
) -> None:
    fake_git.reply(0, "subject\n")
    fake_git.reply(0, raw_header)

    result = git.commit_message(COMMIT_HASH, with_info=True)

    assert result == f"{expected_header}\n\nsubject\n"


# _run


def test_run_calls_git_with_the_given_arguments(fake_subprocess: _FakeSubprocess) -> None:
    git._run("rev-parse", "--git-dir")

    assert fake_subprocess.commands == [["git", "rev-parse", "--git-dir"]]


def test_run_captures_output_and_does_not_raise_on_failure(
    fake_subprocess: _FakeSubprocess,
) -> None:
    git._run("status")

    assert fake_subprocess.kwargs == [{"capture_output": True, "check": False}]


def test_run_returns_exit_code_and_stdout(fake_subprocess: _FakeSubprocess) -> None:
    fake_subprocess.result = SimpleNamespace(returncode=3, stdout=b"hello\n")

    assert git._run("status") == (3, "hello\n")


def test_run_keeps_crlf_untouched(fake_subprocess: _FakeSubprocess) -> None:
    fake_subprocess.result = SimpleNamespace(returncode=0, stdout=b"a\r\nb\r\n")

    assert git._run("show") == (0, "a\r\nb\r\n")


def test_run_decodes_utf8(fake_subprocess: _FakeSubprocess) -> None:
    fake_subprocess.result = SimpleNamespace(returncode=0, stdout="ñandú ✓".encode())

    assert git._run("show") == (0, "ñandú ✓")


def test_run_replaces_bytes_that_are_not_utf8(fake_subprocess: _FakeSubprocess) -> None:
    fake_subprocess.result = SimpleNamespace(returncode=0, stdout=b"ok \xff\xfe end")

    assert git._run("show") == (0, "ok \ufffd\ufffd end")


def test_run_reports_a_missing_git(fake_subprocess: _FakeSubprocess) -> None:
    fake_subprocess.error = FileNotFoundError("git")

    with pytest.raises(GdiffError) as excinfo:
        git._run("status")

    assert str(excinfo.value) == "git is not installed."
    assert excinfo.value.__cause__ is None
    assert excinfo.value.__suppress_context__ is True


# _run_checked


def test_run_checked_returns_stdout_on_success(fake_git: _FakeGit) -> None:
    fake_git.reply(0, "output")

    assert git._run_checked("log", "-1") == "output"


def test_run_checked_forwards_every_argument(fake_git: _FakeGit) -> None:
    fake_git.reply(0)

    git._run_checked("log", "-1", "abc")

    assert fake_git.calls == [("log", "-1", "abc")]


@pytest.mark.parametrize("code", [1, 128])
def test_run_checked_names_the_failed_subcommand(fake_git: _FakeGit, code: int) -> None:
    fake_git.reply(code, "ignored")

    with pytest.raises(GdiffError) as excinfo:
        git._run_checked("show", "-m", COMMIT_HASH)

    assert str(excinfo.value) == "git show failed."


def test_run_checked_failure_with_a_single_argument(fake_git: _FakeGit) -> None:
    fake_git.reply(1)

    with pytest.raises(GdiffError) as excinfo:
        git._run_checked("diff")

    assert str(excinfo.value) == "git diff failed."


# _resolve_position


@pytest.mark.parametrize(
    ("position", "total", "skip"),
    [
        ("1", "1", "--skip=0"),
        ("3", "3", "--skip=2"),  # the oldest commit is still valid
        ("3", "5\n", "--skip=2"),
    ],
)
def test_position_counts_back_from_head(
    fake_git: _FakeGit, position: str, total: str, skip: str
) -> None:
    fake_git.reply(0, "HEAD-HASH\n")
    fake_git.reply(0, total)
    fake_git.reply(0, f"{COMMIT_HASH}\n")

    assert git._resolve_position(position) == COMMIT_HASH
    assert fake_git.calls == [
        ("rev-parse", "--verify", "HEAD"),
        ("rev-list", "--count", "HEAD"),
        ("rev-list", skip, "--max-count=1", "HEAD"),
    ]


@pytest.mark.parametrize(
    "target",
    ["0", "007", "-1", "1.5", "abc", "", "1 ", f"1{ARABIC_THREE}"],
)
def test_position_must_be_a_positive_ascii_integer(fake_git: _FakeGit, target: str) -> None:
    with pytest.raises(GdiffError) as excinfo:
        git._resolve_position(target)

    assert str(excinfo.value) == (
        f"Invalid commit position '{target}'. Must be a positive integer (e.g. 1, 2, 3)."
    )
    assert fake_git.calls == []


@pytest.mark.parametrize("code", [1, 128])
def test_position_fails_when_there_are_no_commits(fake_git: _FakeGit, code: int) -> None:
    fake_git.reply(code)

    with pytest.raises(GdiffError) as excinfo:
        git._resolve_position("1")

    assert str(excinfo.value) == "No commits found in repository."
    assert fake_git.calls == [("rev-parse", "--verify", "HEAD")]


@pytest.mark.parametrize(
    ("position", "total", "message"),
    [
        ("2", "1", "Commit at position 2 does not exist (branch only has 1 commit)."),
        ("3", "2", "Commit at position 3 does not exist (branch only has 2 commits)."),
        ("4", "3", "Commit at position 4 does not exist (branch only has 3 commits)."),
    ],
)
def test_position_beyond_the_history_is_rejected(
    fake_git: _FakeGit, position: str, total: str, message: str
) -> None:
    fake_git.reply(0)
    fake_git.reply(0, total)

    with pytest.raises(GdiffError) as excinfo:
        git._resolve_position(position)

    assert str(excinfo.value) == message
    assert len(fake_git.calls) == 2


def test_position_fails_when_git_returns_no_hash(fake_git: _FakeGit) -> None:
    fake_git.reply(0)
    fake_git.reply(0, "5")
    fake_git.reply(0, "\n")

    with pytest.raises(GdiffError) as excinfo:
        git._resolve_position("2")

    assert str(excinfo.value) == "Failed to resolve commit at position 2."


# _resolve_ref


def test_ref_is_verified_as_a_commit(fake_git: _FakeGit) -> None:
    fake_git.reply(0, f"{COMMIT_HASH}\n")

    assert git._resolve_ref("v1.0") == COMMIT_HASH
    assert fake_git.calls == [("rev-parse", "--verify", "--quiet", "v1.0^{commit}")]


@pytest.mark.parametrize("target", ["", "-x", "--all", "-"])
def test_ref_rejects_empty_values_and_option_lookalikes(fake_git: _FakeGit, target: str) -> None:
    with pytest.raises(GdiffError) as excinfo:
        git._resolve_ref(target)

    assert str(excinfo.value) == (
        f"Invalid commit '{target}'. Use a position (e.g. 1, 2, 3) or a commit hash."
    )
    assert fake_git.calls == []


@pytest.mark.parametrize(
    ("code", "out"),
    [
        (1, ""),
        (1, f"{COMMIT_HASH}\n"),  # a failing exit code wins over any output
        (128, ""),
        (0, ""),  # a clean exit with no hash is still "not found"
        (0, "\n"),
    ],
)
def test_ref_not_found(fake_git: _FakeGit, code: int, out: str) -> None:
    fake_git.reply(code, out)

    with pytest.raises(GdiffError) as excinfo:
        git._resolve_ref("nope")

    assert str(excinfo.value) == "Commit 'nope' not found."


def test_ref_accepts_a_dash_that_is_not_leading(fake_git: _FakeGit) -> None:
    fake_git.reply(0, f"{COMMIT_HASH}\n")

    assert git._resolve_ref("feature-x") == COMMIT_HASH


class _FakeGit:
    """Stands in for git._run: records each call and answers from a queue."""

    def __init__(self) -> None:
        self.calls: list[tuple[object, ...]] = []
        self.replies: list[tuple[int, str]] = []

    def reply(self, code: int, out: str = "") -> None:
        self.replies.append((code, out))

    def __call__(self, *args: object) -> tuple[int, str]:
        self.calls.append(args)
        if not self.replies:
            raise AssertionError(f"unexpected git call: {args}")
        return self.replies.pop(0)


class _FakeSubprocess:
    """Stands in for subprocess.run inside gdiff.git."""

    def __init__(self) -> None:
        self.commands: list[object] = []
        self.kwargs: list[dict[str, object]] = []
        self.result = SimpleNamespace(returncode=0, stdout=b"")
        self.error: Exception | None = None

    def __call__(self, command: object, **kwargs: object) -> SimpleNamespace:
        self.commands.append(command)
        self.kwargs.append(kwargs)
        if self.error is not None:
            raise self.error
        return self.result


@pytest.fixture
def fake_git(monkeypatch: pytest.MonkeyPatch) -> _FakeGit:
    fake = _FakeGit()
    monkeypatch.setattr(git, "_run", fake)
    return fake


@pytest.fixture
def fake_subprocess(monkeypatch: pytest.MonkeyPatch) -> _FakeSubprocess:
    fake = _FakeSubprocess()
    monkeypatch.setattr(git.subprocess, "run", fake)
    return fake
