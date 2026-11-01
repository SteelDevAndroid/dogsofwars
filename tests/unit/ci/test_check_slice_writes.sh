#!/usr/bin/env bash
# Self-test of tools/ci/check-slice-writes.sh on throwaway fixtures (no repo state touched).
# Run: bash tests/unit/ci/test_check_slice_writes.sh   — exits 0 when every case behaves.

set -u
HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
CHECK="$HERE/../../../tools/ci/check-slice-writes.sh"
fails=0

mk() {  # mk <dir> : a slice owned by src/core/units/, a legal writer, no violator yet
    mkdir -p "$1/src/core/state" "$1/src/core/units" "$1/src/core/combat" "$1/tests"
    cat > "$1/src/core/state/units_slice.gd" <<'EOF'
# owner: src/core/units/ src/core/state/
class_name UnitsSlice
extends RefCounted
var _hp: PackedInt32Array
var _pos: PackedInt32Array
EOF
    cat > "$1/src/core/units/units_rules.gd" <<'EOF'
class_name UnitsRules
static func damage(s: UnitsSlice, i: int, d: int) -> void:
	s._hp[i] -= d
EOF
}

expect() {  # expect <name> <expected exit> <dir>
    (cd "$3" && bash "$CHECK" src tests >/dev/null 2>&1)
    got=$?
    if [ "$got" -ne "$2" ]; then
        echo "FAIL $1: expected exit $2, got $got"
        fails=$((fails + 1))
    else
        echo "ok   $1"
    fi
}

t=$(mktemp -d); mk "$t"
expect "owner writes its own slice" 0 "$t"

cat > "$t/src/core/combat/cheat.gd" <<'EOF'
class_name Cheat
static func heal(s: UnitsSlice) -> void:
	s._hp[0] = 99
EOF
expect "another system writes a private field" 1 "$t"
rm -rf "$t"

t=$(mktemp -d); mk "$t"
printf 'extends GutTest\nfunc test_x(): assert_eq(UnitsSlice.new()._hp.size(), 0)\n' > "$t/tests/test_units.gd"
expect "tests may read private fields" 0 "$t"
rm -rf "$t"

t=$(mktemp -d); mk "$t"
sed -i '1d' "$t/src/core/state/units_slice.gd"
expect "slice without an owner line is refused" 2 "$t"
rm -rf "$t"

t=$(mktemp -d); mk "$t"
printf 'extends GutTest\nfunc test_x(): UnitsSlice.new()._hp[0] = 5\n' > "$t/tests/test_write.gd"
expect "tests may not write private fields" 1 "$t"
rm -rf "$t"

t=$(mktemp -d); mk "$t"
printf 'class_name Dyn\nstatic func f(s: UnitsSlice) -> void:\n\ts.set("_hp", PackedInt32Array())\n' > "$t/src/core/combat/dyn.gd"
expect "dynamic set of a private field is refused" 1 "$t"
rm -rf "$t"

t=$(mktemp -d); mk "$t"
printf '# owner: src/core/nodes/ src/core/state/\nclass_name NodesSlice\nextends RefCounted\nvar _hp: PackedInt32Array\n' > "$t/src/core/state/nodes_slice.gd"
expect "same private name in two slices is refused" 2 "$t"
rm -rf "$t"

t=$(mktemp -d)
expect "no code root" 0 "$t"
rm -rf "$t"

[ "$fails" -eq 0 ] && echo "all cases ok" || echo "$fails case(s) failed"
exit "$fails"
