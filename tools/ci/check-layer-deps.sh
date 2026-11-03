#!/usr/bin/env bash
# check-layer-deps.sh — CI check: the Core never depends on the Presentation or
# on the composition root, and the project declares no autoload.
#
# Rule: docs/architecture/adr-0008-racine-de-composition.md (§1, §7), registry
# forbidden patterns `core_references_presentation` and
# `autoload_or_service_locator`.
#
# In <src>/presentation/tiles/*.gd: GameState outside tile_snapshot.gd and the signature of
# show_state (ADR-0012, the renderer reads the snapshot only).
# In <src>/core/**/*.gd (comment lines ignored), reported:
#   - a path to <src>/presentation/ or <src>/app/ (preload, load, any string);
#   - a class_name declared under <src>/presentation/ or <src>/app/;
#   - get_tree( / get_node( / "/root/" (service lookup in the scene tree).
# In <project.godot>: an [autoload] section.
#
# Usage: tools/ci/check-layer-deps.sh [src=src] [project=project.godot]
# Exit 0: nothing found (also when there is no <src>/core yet).
# Exit 1: at least one violation; one line per hit, "file:line: ...".

set -u
SRC="${1:-src}"
PROJECT="${2:-project.godot}"
found=0

report() { echo "$1"; found=1; }

if [ -f "$PROJECT" ] && grep -qE '^\[autoload\]' "$PROJECT"; then
    report "$PROJECT: [autoload] section found (ADR-0008 §1: no autoload)"
fi

CORE="$SRC/core"
if [ ! -d "$CORE" ]; then
    echo "check-layer-deps: no '$CORE' — nothing to check"
    exit "$found"
fi

# Code lines only: "file:line:text" with comment-only lines dropped.
code_lines() {
    grep -rnE --include='*.gd' "$1" "$CORE" 2>/dev/null | grep -vE '^[^:]+:[0-9]+:[[:space:]]*#'
}

while IFS= read -r hit; do
    [ -n "$hit" ] && report "$hit: path into presentation/app (ADR-0008 §7)"
done < <(code_lines "res://$SRC/(presentation|app)/")

while IFS= read -r hit; do
    [ -n "$hit" ] && report "$hit: scene-tree lookup in Core (ADR-0008, guideline: no get_tree/get_node)"
done < <(code_lines '(get_tree|get_node)[[:space:]]*\(|"/root/')

outer_classes=$(grep -rhoE --include='*.gd' '^class_name[[:space:]]+[A-Za-z0-9_]+' \
    "$SRC/presentation" "$SRC/app" 2>/dev/null | awk '{print $2}' | sort -u)
for cls in $outer_classes; do
    while IFS= read -r hit; do
        [ -n "$hit" ] && report "$hit: uses $cls, declared outside Core (ADR-0008 §7)"
    done < <(code_lines "(^|[^A-Za-z0-9_])${cls}([^A-Za-z0-9_]|$)")
done

# ADR-0012, registry pattern renderer_reads_real_state: the tile drawing reads the TileSnapshot
# only. GameState may appear in tile_snapshot.gd (TileSnapshot.take) and in the signature of
# TileRenderer.show_state, nowhere else under <src>/presentation/tiles/.
TILES="$SRC/presentation/tiles"
if [ -d "$TILES" ]; then
    while IFS= read -r hit; do
        [ -n "$hit" ] && report "$hit: tile drawing reads GameState outside TileSnapshot.take (ADR-0012)"
    done < <(grep -rnE --include='*.gd' '(^|[^A-Za-z0-9_])GameState([^A-Za-z0-9_]|$)' "$TILES" 2>/dev/null \
        | grep -vE '^[^:]+:[0-9]+:[[:space:]]*#' | grep -v '/tile_snapshot\.gd:' | grep -vE ':[0-9]+:func show_state\(')
fi

exit "$found"
