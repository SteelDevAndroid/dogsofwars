#!/usr/bin/env python3
"""Builds a scenario map from an illustration (design/art/maps/<id>/): the terrain, the starts, the
nodes, the units, the dormants and the ruin zones are drawn by hand in spec.json (an illustration
cannot tell a mountain from a painted peak by its colour), and the picture gives the map its
colours. The script checks what the game checks and what it does not (every point reachable from the
player's start, with the movement rules of GDD 2), then writes:

  assets/data/maps/<id>.json              the map file (symmetry "none": a scenario)
  assets/art/maps/<id>_colors.png         one pixel per tile: the mean colour of the tile in the picture
  assets/art/maps/art_index.json          which map file each colour image belongs to (by terrain hash)

The game paints the ground of the tiles with these colours (MapArt) and the choice screen's miniature
too; the relief stays the 3D low-poly one. The picture must be square with a 16 x 16 grid of equal
cells (the grid lines are skipped).

  python3 tools/maps/from_illustration.py canyon            # checks and writes
  python3 tools/maps/from_illustration.py --check           # checks every scenario, and that the files on disk
                                                           # are what it writes (the picture is read only if
                                                           # Pillow is installed)
"""
import hashlib
import json
import sys
from collections import deque
from pathlib import Path

ROOT = Path(__file__).resolve().parents[2]
SOURCES = ROOT / "design" / "art" / "maps"
MAPS_OUT = ROOT / "assets" / "data" / "maps"
ART_OUT = ROOT / "assets" / "art" / "maps"
SIZE = 16
CODES = {".": 0, "f": 1, "^": 2, "~": 3}  # TerrainGrid: plain, forest, mountain, water
MIN_NODE_GAP = 4
MIN_START_GAP = 3
GRID_MARGIN = 0.12  # share of a cell skipped on each side (the grid lines)
REACH = {"chasseur": 4, "bastion": 2}  # move + range of the armed Guardians (cover of the dormants)
PACK = ["eclaireur", "assaut", "rempart"]
FACTIONS = ("meute", "gardiens")


def chebyshev(a, b):
    return max(abs(a[0] - b[0]), abs(a[1] - b[1]))


def load_spec(map_id):
    return json.loads((SOURCES / map_id / "spec.json").read_text(encoding="utf-8"))


def check(spec):
    """Every error of the scenario, one message each."""
    errors = []
    rows = spec["terrain"]
    if len(rows) != SIZE or any(len(r) != SIZE for r in rows):
        return ["the terrain must be %d rows of %d tiles" % (SIZE, SIZE)]
    cell = lambda t: rows[t[1]][t[0]]
    for y, row in enumerate(rows):
        for x, glyph in enumerate(row):
            if glyph not in CODES:
                errors.append("unknown glyph %r at %s" % (glyph, (x, y)))
    if errors:
        return errors
    starts = {f: tuple(spec["starts"][f]) for f in FACTIONS}
    nodes = [tuple(n[:2]) for n in spec["nodes"]]
    stands = list(starts.values()) + nodes
    for t in stands:
        if cell(t) != ".":
            errors.append("node or start %s is not on plain" % (t,))
    for i, a in enumerate(stands):
        for b in stands[i + 1:]:
            if chebyshev(a, b) < MIN_NODE_GAP:
                errors.append("%s and %s are closer than %d" % (a, b, MIN_NODE_GAP))
    taken = set(stands)
    dormants = [(d[0], d[1]) for d in spec["dormants"]]
    for t in dormants:
        if cell(t) not in ".f" or t in taken:
            errors.append("dormant %s is not on a free plain or forest" % (t,))
        if any(chebyshev(t, s) < MIN_START_GAP for s in starts.values()):
            errors.append("dormant %s is closer than %d to a start" % (t, MIN_START_GAP))
        if any(chebyshev(t, n) <= 1 for n in stands):
            errors.append("dormant %s is next to a node" % (t,))
        taken.add(t)
    for z, zone in enumerate(spec["ruins"]):
        if zone["draw"] > len(zone["candidates"]):
            errors.append("ruin zone %d draws more than it has candidates" % z)
        for c in map(tuple, zone["candidates"]):
            if cell(c) not in ".f" or c in taken:
                errors.append("ruin candidate %s is not on a free plain or forest" % (c,))
            if any(chebyshev(c, s) < MIN_START_GAP for s in starts.values()):
                errors.append("ruin candidate %s is closer than %d to a start" % (c, MIN_START_GAP))
            taken.add(c)
    guardians = []
    for faction in FACTIONS:
        for kind, x, y in spec["units"][faction]:
            t = (x, y)
            if cell(t) not in ".f" or t in taken:
                errors.append("%s %s at %s is on water, a mountain or a taken tile" % (faction, kind, t))
            taken.add(t)
            if faction == "gardiens":
                guardians.append((kind, t))
    for t in dormants:  # GDD 9 rule 11: a dormant on the AI's half is covered by an armed Guardian
        if chebyshev(t, starts["gardiens"]) <= chebyshev(t, starts["meute"]) \
                and not any(chebyshev(t, g) <= REACH.get(k, 0) for k, g in guardians):
            errors.append("dormant %s on the AI side is not covered by an armed Guardian" % (t,))
    # what the game does not check: every point can be reached from the player's start
    seen = reach(rows, starts["meute"])
    for name, t in [("the Guardians' start", starts["gardiens"])] + [("node %s" % (n,), n) for n in nodes] \
            + [("dormant %s" % (d,), d) for d in dormants]:
        if t not in seen:
            errors.append("%s cannot be reached from the player's start" % name)
    return errors


def reach(rows, start):
    """Tiles reachable from `start`, with the movement of GDD 2: eight neighbours, water and
    mountains impassable, no diagonal between two impassable orthogonal tiles."""
    passable = lambda t: rows[t[1]][t[0]] in ".f"
    seen, queue = {start}, deque([start])
    while queue:
        x, y = queue.popleft()
        for dx in (-1, 0, 1):
            for dy in (-1, 0, 1):
                n = (x + dx, y + dy)
                if (dx or dy) and 0 <= n[0] < SIZE and 0 <= n[1] < SIZE and n not in seen and passable(n):
                    if dx and dy and not (passable((x + dx, y)) or passable((x, y + dy))):
                        continue
                    seen.add(n)
                    queue.append(n)
    return seen


def document(spec):
    return {
        "schema_version": 1, "id": spec["id"], "title": spec["title"], "summary": spec["summary"],
        "width": SIZE, "height": SIZE, "terrain": spec["terrain"], "symmetry": "none", "memory_faction": "meute",
        "starts": [dict(faction=f, x=spec["starts"][f][0], y=spec["starts"][f][1]) for f in FACTIONS],
        "nodes": [dict(x=n[0], y=n[1], level=n[2]) for n in spec["nodes"]],
        "units": [dict(type=k, faction=f, x=x, y=y, post_x=-1, post_y=-1) for f in FACTIONS for k, x, y in spec["units"][f]],
        "dormants": [dict(x=d[0], y=d[1], types=["ouvrier"] if d[2] == "w" else PACK, same_as=-1) for d in spec["dormants"]],
        "ruin_zones": [dict(draw=z["draw"], candidates=[dict(x=c[0], y=c[1]) for c in z["candidates"]]) for z in spec["ruins"]],
    }


def terrain_hash(rows):
    """What MapArt computes in the game: SHA-256 of the terrain codes, row by row."""
    return hashlib.sha256(bytes(CODES[g] for row in rows for g in row)).hexdigest()


def colors_image(map_id):
    """The 16 x 16 image of the mean colour of each tile of the picture."""
    from PIL import Image  # only here: the check mode needs no picture library
    picture = Image.open(SOURCES / map_id / ("%s.png" % map_id)).convert("RGB")
    if picture.width != picture.height:
        raise SystemExit("%s: the picture must be square" % map_id)
    side = picture.width
    out = Image.new("RGB", (SIZE, SIZE))
    for y in range(SIZE):
        for x in range(SIZE):
            x0, x1 = round(x * side / SIZE), round((x + 1) * side / SIZE)
            y0, y1 = round(y * side / SIZE), round((y + 1) * side / SIZE)
            m = round((x1 - x0) * GRID_MARGIN)
            tile = picture.crop((x0 + m, y0 + m, x1 - m, y1 - m)).resize((1, 1), Image.BOX)
            out.putpixel((x, y), tile.getpixel((0, 0)))
    return out


def index_text(entries):
    return json.dumps({"maps": entries}, indent=1, sort_keys=True) + "\n"


def scenarios():
    return sorted(p.name for p in SOURCES.iterdir() if (p / "spec.json").exists())


def main():
    check_only = "--check" in sys.argv
    wanted = [a for a in sys.argv[1:] if not a.startswith("--")] or scenarios()
    try:
        import PIL  # noqa: F401
        have_pillow = True
    except ImportError:
        have_pillow = False
    failed = False
    entries = {}
    index_path = ART_OUT / "art_index.json"
    if index_path.exists():
        entries = json.loads(index_path.read_text(encoding="utf-8"))["maps"]
    for map_id in wanted:
        spec = load_spec(map_id)
        errors = check(spec)
        for e in errors:
            print("  !", map_id + ":", e)
        if errors:
            failed = True
            continue
        text = json.dumps(document(spec), ensure_ascii=False, indent=1) + "\n"
        entries[map_id] = {"colors": "%s_colors.png" % map_id, "sha256": terrain_hash(spec["terrain"])}
        path = MAPS_OUT / ("%s.json" % map_id)
        png = ART_OUT / entries[map_id]["colors"]
        if check_only:
            if not path.exists() or path.read_text(encoding="utf-8") != text:
                print("  ! %s is not what from_illustration.py writes: run it and commit the result" % path.name)
                failed = True
            if have_pillow:
                from PIL import Image
                if not png.exists() or Image.open(png).convert("RGB").tobytes() != colors_image(map_id).tobytes():
                    print("  ! %s is not what from_illustration.py writes" % png.name)
                    failed = True
            elif not png.exists():
                print("  ! %s is missing" % png.name)
                failed = True
        else:
            ART_OUT.mkdir(parents=True, exist_ok=True)
            path.write_text(text, encoding="utf-8")
            colors_image(map_id).save(png)
            print("%s: written (%s, %s)" % (map_id, path.relative_to(ROOT), png.relative_to(ROOT)))
    if check_only:
        if not index_path.exists() or index_path.read_text(encoding="utf-8") != index_text(entries):
            print("  ! art_index.json is not what from_illustration.py writes")
            failed = True
    elif not failed:
        ART_OUT.mkdir(parents=True, exist_ok=True)
        index_path.write_text(index_text(entries), encoding="utf-8")
    sys.exit(1 if failed else 0)


if __name__ == "__main__":
    main()
