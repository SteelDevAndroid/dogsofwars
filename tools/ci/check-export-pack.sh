#!/usr/bin/env bash
# Exports the game data pack of the Android preset and runs the game from it, headless
# (ADR-0008 §1): the pack must hold every data file and none of the test or design files, and
# the game must reach its menu from the pack alone (a data error is printed as "data error:").
# Needs GODOT (path of the editor binary) and a project already imported.
set -euo pipefail
: "${GODOT:?set GODOT to the Godot 4.7.2 binary}"
root="$(cd "$(dirname "$0")/../.." && pwd)"
work="$(mktemp -d)"
trap 'rm -rf "$work"' EXIT
cd "$root"
"$GODOT" --headless --export-pack "Android" "$work/game.pck" 2>&1 | sed 's/\x1b\[[0-9;]*m//g' > "$work/export.log"
grep -q "DONE" "$work/export.log" || { cat "$work/export.log"; echo "export-pack failed"; exit 1; }
stored="$(grep -o 'Storing File: .*' "$work/export.log" | sed 's/Storing File: //')"
fail=0
for file in assets/data/*.json assets/data/maps/*.json assets/audio/*.wav.import; do
  grep -qx "res://$file" <<<"$stored" || { echo "missing from the pack: $file"; fail=1; }
done
# an imported sound travels as its .import record plus a compiled .sample under .godot/imported
for wav in assets/audio/*.wav; do
  grep -q "^res://.godot/imported/$(basename "$wav")-.*\.sample$" <<<"$stored" || { echo "sound not imported in the pack: $wav"; fail=1; }
done
# the delivered textures (terrain, nodes, ruins, units, effects) travel as compiled .ctex under .godot/imported
for png in assets/art/*/*.png assets/art/*/*.svg; do
  case "$png" in *_mask.png) continue ;; esac  # the faction masks equal the silhouettes: not shipped
  grep -q "^res://.godot/imported/$(basename "$png")-.*\.ctex$" <<<"$stored" || { echo "texture not imported in the pack: $png"; fail=1; }
done
if grep -E '_mask\.png' <<<"$stored"; then
  echo "faction masks are in the pack"; fail=1
fi
if grep -E '^res://(tests|addons|docs|design|tools|reports)/' <<<"$stored"; then
  echo "files that must not ship are in the pack"; fail=1
fi
(cd "$work" && timeout 60 "$GODOT" --headless --main-pack "$work/game.pck" --quit-after 120 > run.log 2>&1) || true
if grep -qE 'data error:|ERROR|SCRIPT ERROR' "$work/run.log"; then
  cat "$work/run.log"; echo "the game printed errors when run from the pack"; fail=1
fi
[ "$fail" -eq 0 ] && echo "check-export-pack: ok ($(wc -l <<<"$stored") files)"
exit "$fail"
