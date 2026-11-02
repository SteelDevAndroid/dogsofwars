#!/usr/bin/env bash
# Self-test of tools/ci/check-json-duplicate-keys.py on throwaway fixtures (no repo state touched).
# Run: bash tests/unit/ci/test_check_json_duplicate_keys.sh   — exits 0 when every case behaves.

set -u
HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
CHECK="$HERE/../../../tools/ci/check-json-duplicate-keys.py"
fails=0

expect() {  # expect <name> <expected exit> <dir>
    (cd "$3" && python3 -I "$CHECK" assets/data >/dev/null 2>&1)
    got=$?
    if [ "$got" -ne "$2" ]; then
        echo "FAIL $1: expected exit $2, got $got"
        fails=$((fails + 1))
    else
        echo "ok   $1"
    fi
}

mk() {  # mk <dir> : one valid data file and one map file
    mkdir -p "$1/assets/data/cartes"
    printf '{"schema_version": 1, "units": [{"id": 1, "hp": 10}]}\n' > "$1/assets/data/units.json"
    printf '{"schema_version": 1, "w": 12, "h": 12}\n' > "$1/assets/data/cartes/plaine.json"
}

t=$(mktemp -d); mk "$t"
expect "unique keys pass" 0 "$t"
rm -rf "$t"

t=$(mktemp -d); mk "$t"
printf '{"schema_version": 1, "a": 1, "a": 2}\n' > "$t/assets/data/ai.json"
expect "duplicated top-level key is refused" 1 "$t"
rm -rf "$t"

t=$(mktemp -d); mk "$t"
printf '{"schema_version": 1, "w": 12, "h": 12, "spawn": {"x": 1, "x": 2}}\n' > "$t/assets/data/cartes/plaine.json"
expect "duplicated nested key in a subfolder is refused" 1 "$t"
rm -rf "$t"

t=$(mktemp -d); mk "$t"
printf '{"schema_version": 1,}\n' > "$t/assets/data/hud.json"
expect "syntax error is refused" 1 "$t"
rm -rf "$t"

t=$(mktemp -d)
expect "no data dir" 0 "$t"
rm -rf "$t"

[ "$fails" -eq 0 ] && echo "all cases ok" || echo "$fails case(s) failed"
exit "$fails"
