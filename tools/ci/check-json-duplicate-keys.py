#!/usr/bin/env python3
"""check-json-duplicate-keys — CI check: no JSON data file repeats a key.

Rule: docs/architecture/adr-0009-donnees-de-jeu.md §8. Godot's JSON parser keeps
the last value of a duplicated key without any error, so the check runs here.

Usage: tools/ci/check-json-duplicate-keys.py [data_dir=assets/data]
Exit 0: every *.json under data_dir parses with unique keys (also when data_dir is absent).
Exit 1: a duplicated key or a syntax error; one line per file, "file: ...".
"""

import json
import pathlib
import sys


class DuplicateKey(ValueError):
    pass


def unique_pairs(pairs):
    seen = {}
    for key, value in pairs:
        if key in seen:
            raise DuplicateKey(f"duplicate key {key!r}")
        seen[key] = value
    return seen


def main(argv):
    root = pathlib.Path(argv[1] if len(argv) > 1 else "assets/data")
    if not root.is_dir():
        print(f"check-json-duplicate-keys: no '{root}' — nothing to check")
        return 0
    failed = 0
    for path in sorted(root.rglob("*.json")):
        try:
            json.loads(path.read_text(encoding="utf-8"), object_pairs_hook=unique_pairs)
        except (DuplicateKey, json.JSONDecodeError, UnicodeDecodeError) as error:
            print(f"{path}: {error}")
            failed = 1
    return failed


if __name__ == "__main__":
    sys.exit(main(sys.argv))
