class GdiffError(Exception):
    """A user-facing error. Only cli.main() prints it and picks the exit code."""

    def __init__(
        self,
        message: str,
        *,
        hint: str | None = None,
        label: str = "Error:",
        exit_code: int = 1,
    ) -> None:
        super().__init__(message)
        self.hint = hint
        self.label = label
        self.exit_code = exit_code
