import json
import os
import tempfile
from pathlib import Path


def test_utf8_logging_path(tmp_path: Path) -> None:
    """Test reading and writing UTF-8 with pathlib."""

    test_file = tmp_path / "test_utf8.txt"
    data = {"tekst": "ÆØÅ æøå", "emoji": "🤖"}

    with test_file.open("w", encoding="utf-8") as f:
        json.dump(data, f, ensure_ascii=False)

    with test_file.open("r", encoding="utf-8") as f:
        d = json.load(f)

    assert d == data


def test_utf8_logging_tempfile(tmp_path=None) -> None:
    """Test reading and writing UTF-8 using a temporary directory."""

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
