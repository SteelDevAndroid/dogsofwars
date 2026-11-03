#!/usr/bin/env bash
# Self-test of tools/ci/check-layer-deps.sh on throwaway fixtures (no repo state touched).
# Run: bash tests/unit/ci/test_check_layer_deps.sh   — exits 0 when every case behaves.

set -u
HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
CHECK="$HERE/../../../tools/ci/check-layer-deps.sh"
fails=0

mk() {  # mk <dir> : a Core rule, a presentation class that uses the Core, a clean project
    mkdir -p "$1/src/core/units" "$1/src/presentation/hud" "$1/src/app"
    printf 'class_name UnitsRules\nstatic func hp(s: GameState, i: int) -> int:\n\treturn 0\n' > "$1/src/core/units/units_rules.gd"
    printf 'class_name HudPanel\nextends Control\nfunc show_hp(s: GameState) -> void:\n\tprint(UnitsRules.hp(s, 0))\n' > "$1/src/presentation/hud/hud_panel.gd"
    printf 'class_name Bootstrap\nextends Node\n' > "$1/src/app/bootstrap.gd"
    printf '[application]\nconfig/name="t"\n' > "$1/project.godot"
}

expect() {  # expect <name> <expected exit> <dir>
    (cd "$3" && bash "$CHECK" src project.godot >/dev/null 2>&1)
    got=$?
    if [ "$got" -ne "$2" ]; then
        echo "FAIL $1: expected exit $2, got $got"
        fails=$((fails + 1))
    else
        echo "ok   $1"
    fi
}

t=$(mktemp -d); mk "$t"
expect "presentation may name the Core" 0 "$t"
rm -rf "$t"

t=$(mktemp -d); mk "$t"
printf 'const P = preload("res://src/presentation/hud/hud_panel.gd")\n' >> "$t/src/core/units/units_rules.gd"
expect "Core preloads a presentation script" 1 "$t"
rm -rf "$t"

t=$(mktemp -d); mk "$t"
printf 'static func f(p: HudPanel) -> void:\n\tpass\n' >> "$t/src/core/units/units_rules.gd"
expect "Core names a presentation class" 1 "$t"
rm -rf "$t"

t=$(mktemp -d); mk "$t"
printf 'static func f() -> void:\n\tprint(Bootstrap)\n' >> "$t/src/core/units/units_rules.gd"
expect "Core names an app class" 1 "$t"
rm -rf "$t"

t=$(mktemp -d); mk "$t"
printf 'func f() -> void:\n\tget_node("/root/Game")\n' >> "$t/src/core/units/units_rules.gd"
expect "Core looks a service up in the tree" 1 "$t"
rm -rf "$t"

t=$(mktemp -d); mk "$t"
printf '# HudPanel and get_tree() are named in this comment only\n' >> "$t/src/core/units/units_rules.gd"
expect "comment lines are ignored" 0 "$t"
rm -rf "$t"

t=$(mktemp -d); mk "$t"
printf '[autoload]\nGame="*res://src/app/game.gd"\n' >> "$t/project.godot"
expect "autoload section is refused" 1 "$t"
rm -rf "$t"

t=$(mktemp -d); mk "$t"; mkdir -p "$t/src/presentation/tiles"
printf 'class_name TileSnapshot\nstatic func take(state: GameState) -> TileSnapshot:\n\treturn null\n' > "$t/src/presentation/tiles/tile_snapshot.gd"
printf 'class_name TileRenderer\nfunc show_state(state: GameState, catalog: DataCatalog) -> void:\n\tpass\n' > "$t/src/presentation/tiles/tile_renderer.gd"
expect "the snapshot and show_state may name GameState" 0 "$t"
printf 'func peek(state: GameState) -> int:\n\treturn 0\n' >> "$t/src/presentation/tiles/tile_renderer.gd"
expect "the tile drawing reading GameState is refused" 1 "$t"
rm -rf "$t"

t=$(mktemp -d)
expect "no code root" 0 "$t"
rm -rf "$t"

[ "$fails" -eq 0 ] && echo "all cases ok" || echo "$fails case(s) failed"
exit "$fails"
