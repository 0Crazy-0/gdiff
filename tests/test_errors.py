from gdiff.errors import GdiffError


def test_defaults() -> None:
    err = GdiffError("boom")

    assert str(err) == "boom"
    assert err.hint is None
    assert err.label == "Error:"
    assert err.exit_code == 1


def test_custom_attributes() -> None:
    err = GdiffError("boom", hint="  try --help", label="Oops:", exit_code=3)

    assert str(err) == "boom"
    assert err.hint == "  try --help"
    assert err.label == "Oops:"
    assert err.exit_code == 3
