#!/usr/bin/env python3
"""Writes the 16 x 16 maps of assets/data/maps/ (ADR-0008, GDD 2 rule 15): each map is a hand-drawn
upper half (rows 0 to 7) turned by 180 degrees into the lower half, so the symmetry that
MapDefinition verifies tile by tile is true by construction. Points of interest of the upper half
(nodes, dormants, ruin candidates) are turned the same way. The script also checks what the game
checks (distances, terrain of each point, cover of the dormants on the Guardians' side) and what
it does not (every node reachable from both starts, the share of each terrain, no mountain wall).

  python3 tools/maps/make_maps.py            # checks and writes
  python3 tools/maps/make_maps.py --check    # checks, and that the files on disk are what it writes

plaine.json and marais.json (12 x 12 and 14 x 14) are older and written by hand.
"""
import json
import sys
from collections import deque
from pathlib import Path

SIZE = 16
OUT = Path(__file__).resolve().parents[2] / "assets" / "data" / "maps"
PLAYER_START = (2, 2)  # the Guardians start on its image: (13, 13)
PLAYER_UNITS = [("ouvrier", 1, 1), ("assaut", 1, 0), ("eclaireur", 0, 1), ("rempart", 1, 2), ("eclaireur", 2, 1)]  # offsets from the start
GUARDIANS = ["bastion", "sentinelle", "chasseur", "chasseur", "chasseur", "chasseur"]
PACK = ["eclaireur", "assaut", "rempart"]
# unit stats used for the cover check (move + range): armed Guardians
REACH = {"chasseur": 4, "bastion": 2}

MAPS = {}


def mirror(t):
    return (SIZE - 1 - t[0], SIZE - 1 - t[1])


def chebyshev(a, b):
    return max(abs(a[0] - b[0]), abs(a[1] - b[1]))


def add(name, title, summary, upper, nodes, dormants, ruins):
    """upper: 8 strings of 16 (the drawing). The points of interest are given as anchors, rough
    places of the upper half: the script puts each on the nearest tile that satisfies the rules
    (GDD 2 rules 10 and 11), and turns it by 180 degrees for the other side.
    nodes: anchors of the neutral nodes. dormants: [(x, y, "w" worker | "p" pack)]. ruins: three
    zones of three anchors; the second zone is the image of the first."""
    assert len(upper) == 8 and all(len(r) == SIZE for r in upper), name
    MAPS[name] = dict(title=title, summary=summary, upper=upper, nodes=nodes, dormants=dormants, ruins=ruins)


# ---- the maps -----------------------------------------------------------------------------------
add("cretes", "Les Crêtes",
    "Des crêtes coupent le terrain en couloirs. On s'y bat aux cols, et celui qui tient la hauteur voit loin.",
    ["......^^....f...",
     "...f.........^^.",
     ".....f...f......",
     ".....^^.....f...",
     "f.......^^..f...",
     "..^^.......^^...",
     "....f.......f...",
     ".f........^^...."],
    [(7, 2), (1, 6), (11, 4), (5, 7)],
    [(5, 4, "w"), (8, 4, "p"), (3, 7, "p"), (12, 6, "p")],
    [[(5, 0), (1, 5), (7, 4)], None, [(8, 7), (9, 2), (13, 7)]])

add("foret", "La Forêt",
    "Un bois épais, des clairières. On ne voit presque rien : chaque clairière peut cacher un ennemi.",
    ["...ffff....fff..",
     "...fff......ff..",
     ".....f.....ff...",
     "..........fff...",
     "fff.....ff......",
     "fff....fff..~~..",
     "ff.....ff...~~.f",
     "......fff....ff."],
    [(6, 1), (1, 6), (11, 2), (5, 7)],
    [(5, 4, "w"), (8, 5, "p"), (3, 7, "p"), (12, 4, "p")],
    [[(5, 0), (0, 5), (7, 4)], None, [(8, 7), (9, 3), (12, 7)]])

add("archipel", "L'Archipel",
    "Des îles reliées par des gués. L'eau coupe les routes : on contourne, on attend, on frappe au passage.",
    ["......~~........",
     "....f.~~..f.....",
     "................",
     ".....f.....~~..f",
     "...........~~~..",
     "~~....f..f......",
     "~~~..f.....f..~.",
     "~~~..........~~."],
    [(7, 2), (3, 6), (12, 4), (5, 7)],
    [(5, 4, "w"), (8, 4, "p"), (4, 7, "p"), (13, 6, "p")],
    [[(5, 0), (4, 5), (7, 5)], None, [(8, 7), (9, 3), (14, 6)]])

add("mesas", "Les Mesas",
    "De grands plateaux de roche, des canyons entre eux. Les routes sont droites, les embuscades aussi.",
    [".....^^.........",
     ".....^^.f....^^.",
     ".......f.....^^.",
     "...............f",
     ".....f....^^....",
     ".^^...f...^^..^^",
     ".^^.......f...^^",
     "..........f....."],
    [(9, 2), (4, 6), (13, 4), (7, 7)],
    [(5, 4, "w"), (8, 5, "p"), (3, 7, "p"), (12, 3, "p")],
    [[(7, 0), (4, 3), (8, 6)], None, [(9, 7), (12, 2), (10, 3)]])

add("landes", "Les Landes",
    "Un grand terrain ouvert, presque nu. Rien pour se cacher : tout se joue à la vitesse et au nombre.",
    ["................",
     "......f.........",
     "..........f.....",
     "................",
     "....f.....^.....",
     "...........f...~",
     ".^........f.....",
     "......~........."],
    [(7, 2), (2, 6), (12, 4), (6, 7)],
    [(5, 4, "w"), (8, 4, "p"), (3, 7, "p"), (13, 6, "p")],
    [[(5, 0), (0, 5), (8, 5)], None, [(9, 7), (10, 2), (14, 7)]])


# ---- building and checking ----------------------------------------------------------------------
def build(name, spec):
    upper = spec["upper"]
    rows = list(upper) + [r[::-1] for r in reversed(upper)]
    cell = lambda t: rows[t[1]][t[0]]
    start_p, start_a = PLAYER_START, mirror(PLAYER_START)
    errors = []

    def need(ok, message):
        if not ok:
            errors.append("%s: %s" % (name, message))

    upper_tiles = [(x, y) for y in range(8) for x in range(SIZE)]

    def snap(anchor, ok):
        """The valid tile of the upper half nearest to `anchor`."""
        best = None
        for t in sorted(upper_tiles, key=lambda t: ((t[0] - anchor[0]) ** 2 + (t[1] - anchor[1]) ** 2, t[1], t[0])):
            if ok(t):
                best = t
                break
        need(best is not None, "no valid tile near %s" % (anchor,))
        return best

    need(cell(start_p) == ".", "the start %s is not on plain" % (start_p,))
    stands = [start_p, start_a]
    nodes = []
    for anchor in spec["nodes"]:
        def node_ok(t):
            both = [t, mirror(t)]
            return cell(t) == "." and all(chebyshev(u, o) >= 4 for u in both for o in stands) and chebyshev(t, mirror(t)) >= 4
        t = snap(anchor, node_ok)
        if t is not None:
            stands += [t, mirror(t)]
            nodes += [t, mirror(t)]
    for s in (start_p, start_a):
        for dx in range(-2, 3):
            for dy in range(-2, 3):
                t = (s[0] + dx, s[1] + dy)
                if 0 <= t[0] < SIZE and 0 <= t[1] < SIZE:
                    need(cell(t) in ".f", "mountain or water within 2 of start %s at %s" % (s, t))

    taken = set(stands)
    far_from_starts = lambda t, gap: all(chebyshev(t, s) >= gap for s in (start_p, start_a))
    dormants = []
    for anchor_x, anchor_y, kind in spec["dormants"]:
        def dormant_ok(t):
            both = [t, mirror(t)]
            return (cell(t) in ".f" and not any(u in taken for u in both) and chebyshev(t, mirror(t)) > 1
                    and all(far_from_starts(u, 3) and all(chebyshev(u, n) > 1 for n in stands) for u in both))
        t = snap((anchor_x, anchor_y), dormant_ok)
        if t is not None:
            taken.update([t, mirror(t)])
            dormants.append((t, kind))
    # the list the file wants: every upper dormant, then its image naming it (same_as)
    types = lambda kind: ["ouvrier"] if kind == "w" else PACK
    entries = [dict(x=t[0], y=t[1], types=types(k), same_as=-1) for t, k in dormants]
    entries += [dict(x=mirror(t)[0], y=mirror(t)[1], types=types(k), same_as=i) for i, (t, k) in enumerate(dormants)]
    dormants = entries

    zones = []
    first = []
    for anchor in spec["ruins"][0]:
        def ruin_ok(t):
            both = [t, mirror(t)]
            return cell(t) in ".f" and not any(u in taken for u in both) and all(far_from_starts(u, 3) for u in both)
        t = snap(anchor, ruin_ok)
        if t is not None:
            taken.update([t, mirror(t)])
            first.append(t)
    third = []
    for anchor in spec["ruins"][2]:
        def ruin_ok_mid(t):
            return cell(t) in ".f" and t not in taken and far_from_starts(t, 3)
        t = snap(anchor, ruin_ok_mid)
        if t is not None:
            taken.add(t)
            third.append(t)
    zones = [first, [mirror(t) for t in first], third]

    units = []
    for kind, dx, dy in PLAYER_UNITS:
        t = (start_p[0] + dx, start_p[1] + dy)
        need(cell(t) in ".f" and t not in taken, "unit %s at %s is on water, a mountain or taken" % (kind, t))
        taken.add(t)
        units.append((kind, "meute", t))
    guard = []
    # the Guardians: the first two near the start, the chasseurs placed to cover the dormants of their side
    free = lambda t: 0 <= t[0] < SIZE and 0 <= t[1] < SIZE and cell(t) in ".f" and t not in taken
    near = sorted((chebyshev((x, y), start_a), (x, y)) for x in range(SIZE) for y in range(SIZE) if free((x, y)))
    near = [t for _, t in near]
    ai_side = [(d["x"], d["y"]) for d in dormants if chebyshev((d["x"], d["y"]), start_a) <= chebyshev((d["x"], d["y"]), start_p)]
    for kind in GUARDIANS:
        spot = None
        if kind == "chasseur":
            uncovered = [d for d in ai_side if not any(chebyshev(d, g[1]) <= REACH.get(g[0], 0) for g in guard)]
            if uncovered:
                target = uncovered[0]
                spot = next((t for t in near if chebyshev(t, target) <= 3 and free(t)), None)  # 3: leaves room to move
        if spot is None:
            spot = next(t for t in near if free(t))
        taken.add(spot)
        guard.append((kind, spot))
        units.append((kind, "gardiens", spot))
    for d in ai_side:
        need(any(chebyshev(d, g[1]) <= REACH.get(g[0], 0) for g in guard), "dormant %s is not covered by a Guardian" % (d,))

    # what the game does not check
    passable = lambda t: cell(t) != "~"
    seen, queue = {start_p}, deque([start_p])
    while queue:
        t = queue.popleft()
        for dx, dy in ((1, 0), (-1, 0), (0, 1), (0, -1), (1, 1), (-1, -1), (1, -1), (-1, 1)):
            n = (t[0] + dx, t[1] + dy)
            if 0 <= n[0] < SIZE and 0 <= n[1] < SIZE and n not in seen and passable(n):
                seen.add(n)
                queue.append(n)
    for t in stands + [(d["x"], d["y"]) for d in dormants]:
        need(t in seen, "%s cannot be reached from the player's start" % (t,))
    return rows, nodes, dormants, zones, units, errors


def report(name, rows):
    flat = "".join(rows)
    share = {g: flat.count(g) * 100.0 / len(flat) for g in ".f^~"}
    # a mountain group: tiles joined by a side or a corner
    group_max, seen = 0, set()
    for y in range(SIZE):
        for x in range(SIZE):
            if rows[y][x] == "^" and (x, y) not in seen:
                size, stack = 0, [(x, y)]
                seen.add((x, y))
                while stack:
                    cx, cy = stack.pop()
                    size += 1
                    for dx in (-1, 0, 1):
                        for dy in (-1, 0, 1):
                            n = (cx + dx, cy + dy)
                            if 0 <= n[0] < SIZE and 0 <= n[1] < SIZE and n not in seen and rows[n[1]][n[0]] == "^":
                                seen.add(n)
                                stack.append(n)
                group_max = max(group_max, size)
    print("%-9s plain %4.1f%%  forest %4.1f%%  mountain %4.1f%%  water %4.1f%%  largest ridge %d" % (
        name, share["."], share["f"], share["^"], share["~"], group_max))


def document(name, spec, rows, nodes, dormants, zones, units):
    return {
        "schema_version": 1, "id": name, "title": spec["title"], "summary": spec["summary"],
        "width": SIZE, "height": SIZE, "terrain": rows, "symmetry": "rotation180", "memory_faction": "meute",
        "starts": [dict(faction="meute", x=PLAYER_START[0], y=PLAYER_START[1]),
                   dict(faction="gardiens", x=mirror(PLAYER_START)[0], y=mirror(PLAYER_START)[1])],
        "nodes": [dict(x=t[0], y=t[1], level=1) for t in nodes],
        "units": [dict(type=k, faction=f, x=t[0], y=t[1], post_x=-1, post_y=-1) for k, f, t in units],
        "dormants": dormants,
        "ruin_zones": [dict(draw=1, candidates=[dict(x=t[0], y=t[1]) for t in z]) for z in zones],
    }


def main():
    check_only = "--check" in sys.argv
    failed = False
    for name, spec in MAPS.items():
        rows, nodes, dormants, zones, units, errors = build(name, spec)
        report(name, rows)
        for e in errors:
            print("  !", e)
            failed = True
        if errors:
            continue
        text = json.dumps(document(name, spec, rows, nodes, dormants, zones, units), ensure_ascii=False, indent=1) + "\n"
        path = OUT / ("%s.json" % name)
        if not check_only:
            path.write_text(text, encoding="utf-8")
        elif not path.exists() or path.read_text(encoding="utf-8") != text:
            print("  ! %s is not what make_maps.py writes: run it and commit the result" % path.name)
            failed = True
    sys.exit(1 if failed else 0)


if __name__ == "__main__":
    main()
