"""Copy text to the system clipboard using whatever tool the machine has."""

import os
import shutil
import subprocess

from gdiff.errors import GdiffError


def detect() -> tuple[list[str], str] | None:
    if shutil.which("wl-copy") and os.environ.get("WAYLAND_DISPLAY"):
        return ["wl-copy"], "utf-8"
    if shutil.which("xclip") and os.environ.get("DISPLAY"):
        return ["xclip", "-selection", "clipboard"], "utf-8"
    if shutil.which("xsel") and os.environ.get("DISPLAY"):
        return ["xsel", "--clipboard", "--input"], "utf-8"
    if shutil.which("pbcopy"):
        return ["pbcopy"], "utf-8"
    if shutil.which("clip.exe"):
        return ["clip.exe"], "utf-16le"
    return None


def copy(text: str) -> None:
    tool = detect()
    if tool is None:
        raise GdiffError(
            "No clipboard tool found (wl-copy, xclip, xsel, pbcopy, clip.exe).",
            hint="Use --print to output to stdout instead.",
        )
    command, encoding = tool
    try:
        # stdout must not be captured: wl-copy and xclip fork a child that keeps
        # the pipe open, so waiting for it to close would hang forever.
        result = subprocess.run(
            command,
            input=text.encode(encoding),
            stdout=subprocess.DEVNULL,
            check=False,
        )
    except OSError:
        raise GdiffError("Failed to copy to clipboard.") from None
    if result.returncode != 0:
        raise GdiffError("Failed to copy to clipboard.")
