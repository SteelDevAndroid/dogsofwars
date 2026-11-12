#!/usr/bin/env python3
"""Verify that every shipped Dogs of Gods art asset is present and readable.

Only standard-library dependencies; suitable for CI without running Godot.
The check covers packaged 3D terrain/units, the UI and off-map artwork.
"""
from __future__ import annotations

import json
from pathlib import Path
import struct
import sys

ROOT = Path(__file__).resolve().parents[2]
ART = ROOT / "assets" / "art"

TERRAINS = [
    f"terrain_{kind}_{variant:02d}.glb"
    for kind in ("plaine", "foret", "montagne", "eau")
    for variant in range(1, 4)
]
UNIT_TYPES = ("eclaireur", "assaut", "rempart", "ouvrier", "sentinelle", "chasseur", "bastion")
UNITS = [
    f"unit_{kind}{suffix}.glb"
    for kind in UNIT_TYPES
    for suffix in ("", "_endormi")
]
ICONS = [
    "attaque", "chronique", "defense", "energie", "menace",
    "montee_niveau", "mouvement", "noeud", "pause", "perte",
    "recentrer", "recherche", "reglages", "retour", "reveil",
    "ruine", "tour", "vitesse", "vue", "zoom_moins", "zoom_plus",
]

ASSETS = (
    [ART / "3d" / name for name in TERRAINS + UNITS]
    + [ART / "ui" / f"ui_icon_{name}.svg" for name in ICONS]
    + [ART / "ui" / "ui_panneau.png"]
    + [ROOT / "assets" / "ui" / name for name in (
        "splash.png", "splash_landscape.png",
        "icon_192.png", "icon_512.png",
        "icon_adaptive_background_432.png",
        "icon_adaptive_foreground_432.png",
        "icon_adaptive_monochrome_432.png",
    )]
    + [ROOT / "design" / "art" / "illustrations" / f"chronique_{name}.webp"
       for name in ("introduction", "briefing", "revelation")]
    + [ROOT / "design" / "art" / "store" / "graphique_presentation_1024x500.png"]
)

def validate(path: Path) -> str | None:
    if not path.is_file():
        return "missing"
    data = path.read_bytes()
    if not data:
        return "empty"
    if path.suffix == ".glb":
        if len(data) < 20 or data[:4] != b"glTF":
            return "invalid GLB header"
        version, length = struct.unpack_from("<II", data, 4)
        if version != 2 or length != len(data):
            return "invalid GLB version/length"
        chunk_length, chunk_type = struct.unpack_from("<II", data, 12)
        if chunk_type != 0x4E4F534A or chunk_length + 20 > len(data):
            return "invalid GLB JSON chunk"
        try:
            doc = json.loads(data[20:20 + chunk_length])
        except (ValueError, UnicodeDecodeError):
            return "unreadable GLB JSON"
        if not doc.get("meshes"):
            return "GLB has no meshes"
    elif path.suffix == ".png":
        if not data.startswith(b"\x89PNG\r\n\x1a\n") or len(data) < 24:
            return "invalid PNG"
    elif path.suffix == ".webp":
        if len(data) < 12 or data[:4] != b"RIFF" or data[8:12] != b"WEBP":
            return "invalid WebP"
    elif path.suffix == ".svg":
        import xml.etree.ElementTree as ET
        try:
            root = ET.fromstring(data)
        except ET.ParseError:
            return "invalid SVG XML"
        if not root.tag.endswith("svg"):
            return "invalid SVG root"
    return None

def main() -> int:
    failures = []
    for path in ASSETS:
        problem = validate(path)
        if problem is not None:
            failures.append(f"{path.relative_to(ROOT)}: {problem}")
    if failures:
        for problem in failures:
            print(f"ERROR {problem}", file=sys.stderr)
        print(f"{len(failures)} / {len(ASSETS)} assets invalid", file=sys.stderr)
        return 1
    print(f"OK: {len(ASSETS)} art assets checked (12 terrain, 14 units, "
          "21 SVG, panel, splash, Android icons, chronicle, Play Store).")
    return 0

if __name__ == "__main__":
    raise SystemExit(main())
