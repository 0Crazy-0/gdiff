import re
import subprocess

from gdiff.errors import GdiffError


def _run(*args: str) -> tuple[int, str]:
    """Run git and return (exit code, stdout).

    Output is decoded by hand instead of using text=True, because text mode
    would turn CRLF into LF and silently alter diffs of Windows files.
    """
    try:
        result = subprocess.run(["git", *args], capture_output=True, check=False)
    except FileNotFoundError:
        raise GdiffError("git is not installed.") from None
    return result.returncode, result.stdout.decode("utf-8", errors="replace")


def _run_checked(*args: str) -> str:
    code, out = _run(*args)
    if code != 0:
        raise GdiffError(f"git {args[0]} failed.")
    return out


def ensure_repo() -> None:
    code, _ = _run("rev-parse", "--git-dir")
    if code != 0:
        raise GdiffError("Not inside a git repository.")


def has_staged() -> bool:
    # `git diff --quiet` exits 0 when there is nothing and 1 when there are changes
    code, _ = _run("diff", "--cached", "--quiet")
    if code not in (0, 1):
        raise GdiffError("git diff failed.")
    return code == 1


def staged_diff() -> str:
    stat = _run_checked("diff", "--cached", "--stat")
    patch = _run_checked("diff", "--cached")
    return f"{stat}\n{patch}"


def resolve_commit(target: str) -> str:
    """Turn a position (1 = latest), hash or ref into a full commit hash."""
    code, _ = _run("rev-parse", "--verify", "HEAD")
    if code != 0:
        raise GdiffError("No commits found in repository.")

    if re.fullmatch(r"[0-9]{1,6}", target):
        # Short all-digit values are positions in git log order, counting from
        # HEAD. Every reachable commit counts, including merge commits and the
        # commits of merged branches.
        if not re.fullmatch(r"[1-9][0-9]*", target):
            raise GdiffError(
                f"Invalid commit position '{target}'. Must be a positive integer (e.g. 1, 2, 3)."
            )
        position = int(target)
        total = int(_run_checked("rev-list", "--count", "HEAD").strip())
        if position > total:
            noun = "commit" if total == 1 else "commits"
            raise GdiffError(
                f"Commit at position {position} does not exist (branch only has {total} {noun})."
            )
        out = _run_checked("rev-list", f"--skip={position - 1}", "--max-count=1", "HEAD")
        commit_hash = out.strip()
        if not commit_hash:
            raise GdiffError(f"Failed to resolve commit at position {target}.")
        return commit_hash

    # Anything else is treated as a hash or ref
    if not target or target.startswith("-"):
        raise GdiffError(
            f"Invalid commit '{target}'. Use a position (e.g. 1, 2, 3) or a commit hash."
        )
    code, out = _run("rev-parse", "--verify", "--quiet", f"{target}^{{commit}}")
    commit_hash = out.strip()
    if code != 0 or not commit_hash:
        raise GdiffError(f"Commit '{target}' not found.")
    return commit_hash


def commit_diff(commit_hash: str) -> str:
    stat = _run_checked("show", "-m", "--first-parent", "--stat", "--format=", commit_hash)
    patch = _run_checked("show", "-m", "--first-parent", "-p", "--format=", commit_hash)
    return f"{stat}\n{patch}"


def commit_message(commit_hash: str, with_info: bool = False) -> str:
    """The message exactly as written; with_info adds hash, author and date first."""
    message = _run_checked("log", "-1", "--format=%B", commit_hash).rstrip("\n")
    if not with_info:
        return f"{message}\n"
    header = _run_checked(
        "log",
        "-1",
        "--date=default",
        "--format=Commit: %H%nShort:  %h%nAuthor: %an <%ae>%nDate:   %ad",
        commit_hash,
    ).rstrip("\n")
    return f"{header}\n\n{message}\n"
