import json
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
