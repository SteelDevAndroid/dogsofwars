#!/usr/bin/env python3
"""Import the generated 58-asset Dogs of Gods pack into this Godot project.

Usage: python tools/import_graphics_pack.py /path/to/dogsofgods_integration_complete_58_assets.zip
Defaults to a non-destructive import. --replace replaces existing assets after backup.
"""
import argparse
import shutil
import sys
import zipfile
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
ALLOWED = ("assets/art/3d/", "assets/art/ui/", "assets/art/illus/",
           "assets/art/icons/", "assets/art/store/")

def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("archive", type=Path)
    parser.add_argument("--replace", action="store_true",
                        help="Replace existing files, backing them up to .asset-backups")
    args = parser.parse_args()
    if not (ROOT / "project.godot").exists():
        parser.error("project.godot not found at repository root")
    if not args.archive.is_file():
        parser.error(f"archive not found: {args.archive}")
    added = skipped = replaced = 0
    with zipfile.ZipFile(args.archive) as archive:
        corrupt = archive.testzip()
        if corrupt:
            parser.error(f"archive CRC error: {corrupt}")
        names = [n for n in archive.namelist()
                 if n.startswith(ALLOWED) and not n.endswith("/")]
        if len(names) != 44 + 14:
            parser.error(f"expected 58 graphical assets, found {len(names)}")
        for name in names:
            rel = Path(name)
            if rel.is_absolute() or ".." in rel.parts:
                parser.error(f"unsafe archive entry: {name}")
            dest = ROOT / rel
            if dest.exists() and not args.replace:
                skipped += 1
                continue
            dest.parent.mkdir(parents=True, exist_ok=True)
            if dest.exists():
                backup = ROOT / ".asset-backups" / rel
                backup.parent.mkdir(parents=True, exist_ok=True)
                shutil.copy2(dest, backup)
                replaced += 1
            else:
                added += 1
            with archive.open(name) as src, dest.open("wb") as dst:
                shutil.copyfileobj(src, dst)
    print(f"Imported {added} assets; replaced {replaced}; skipped {skipped}.")
    print("Import assets in Godot 4.7 and verify scene paths before merging.")

if __name__ == "__main__":
    main()
