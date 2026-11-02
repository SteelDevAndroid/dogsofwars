#!/usr/bin/env python3
"""Puts the backup rules of the game into the Android build template (GDD 16 rule 18).

Usage: patch_backup.py <build template dir> [rules dir]

The Godot template declares android:allowBackup="false". This turns it on and points it at two
rule files (before and after Android 12) that keep the profile and leave out the match in
progress. Idempotent. It refuses a template whose manifest no longer looks as expected, so a new
Godot version cannot silently lose the rules.
"""
import pathlib
import shutil
import sys
import xml.etree.ElementTree as ET

OFF = 'android:allowBackup="false"'
ON = ('android:allowBackup="true"\n'
      '        android:fullBackupContent="@xml/backup_rules"\n'
      '        android:dataExtractionRules="@xml/data_extraction_rules"')
RULES = ("backup_rules.xml", "data_extraction_rules.xml")


def patch(template: pathlib.Path, rules: pathlib.Path) -> str:
    manifest = template / "src" / "main" / "AndroidManifest.xml"
    text = manifest.read_text(encoding="utf-8")
    if "@xml/data_extraction_rules" in text:
        status = "already patched"
    else:
        if text.count(OFF) != 1:
            raise SystemExit("the manifest of the template has no single %s: update patch_backup.py" % OFF)
        text = text.replace(OFF, ON)
        ET.fromstring(text)  # still well-formed
        manifest.write_text(text, encoding="utf-8")
        status = "patched"
    target = template / "res" / "xml"
    target.mkdir(parents=True, exist_ok=True)
    for name in RULES:
        shutil.copyfile(rules / name, target / name)
    return status


if __name__ == "__main__":
    if len(sys.argv) not in (2, 3):
        raise SystemExit(__doc__)
    here = pathlib.Path(__file__).resolve().parent
    print(patch(pathlib.Path(sys.argv[1]), pathlib.Path(sys.argv[2]) if len(sys.argv) == 3 else here))
