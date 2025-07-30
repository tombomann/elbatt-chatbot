import json

from pathlib import Path


def test_utf8_logging(tmp_path: Path) -> None:
    """Test that UTF-8 characters are written and read correctly."""

    test_file = tmp_path / "test_utf8.txt"
    data = {"tekst": "ÆØÅ æøå", "emoji": "🤖"}

    # Write to file
    with test_file.open("w", encoding="utf-8") as f:
        json.dump(data, f, ensure_ascii=False)

    # Read from file
    with test_file.open("r", encoding="utf-8") as f:
        d = json.load(f)

    assert d["tekst"] == "ÆØÅ æøå"
    assert d["emoji"] == "🤖"

    # Clean up
    test_file.unlink()
    assert not test_file.exists()

    print("UTF-8 test OK!")
=======
import os
import tempfile


def test_utf8_logging(tmp_path=None):
    data = {"tekst": "ÆØÅ æøå", "emoji": "🤖"}
    tmp_dir = tmp_path if tmp_path is not None else tempfile.gettempdir()
    test_file = os.path.join(tmp_dir, "test_utf8.txt")
    try:
        with open(test_file, "w", encoding="utf-8") as f:
            json.dump(data, f, ensure_ascii=False)
        with open(test_file, "r", encoding="utf-8") as f:
            d = json.load(f)
        assert d == data
    finally:
        if os.path.exists(test_file):
            os.remove(test_file)
