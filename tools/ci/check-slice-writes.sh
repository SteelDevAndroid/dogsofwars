#!/usr/bin/env bash
# check-slice-writes.sh — CI check: a game-state slice's private fields (`_name`)
# are touched only by the files of the system that owns the slice.
#
# Rule: docs/architecture/adr-0003-etat-de-partie.md ("Contrôle d'accès"),
# design/gdd/modele-etat-partie.md rule 2 (one writer per field), registry
# forbidden pattern `direct_cross_system_state_write`.
#
# Convention read from the code itself (no separate table to keep in sync):
#   a slice file declares `class_name <Something>Slice` and, in its first lines,
#       # owner: src/core/units/ src/core/state/
#   listing the directories (or files) allowed to access its `_` fields.
#   Every `var _field` declared in that file is private to those paths.
#
# Usage: tools/ci/check-slice-writes.sh [code_root=src] [extra_allowed=tests]
# Exit 0: no access found outside the owners (also when the code root has no slice yet).
# Exit 1: at least one access found; one line per access, "file:line: ...".
# Exit 2: a slice file has no `# owner:` line, or two slices declare the same
#         `_field` name (the check cannot tell whose field `.name` is: field names
#         must be unique across slices, ADR-0003).
#
# Also caught: dynamic access (get/set/get_indexed/set_indexed of "_f", or ["_f"])
# outside the owners. The extra dir (tests) may READ private fields but not write
# them: an assignment (=, +=, ...) to `.name` there is reported.

set -u
ROOT="${1:-src}"
ALLOWED_EXTRA="${2:-tests}"

if [ ! -d "$ROOT" ]; then
    echo "check-slice-writes: no code root '$ROOT' — nothing to check"
    exit 0
fi

slices=$(grep -rlE --include='*.gd' '^class_name[[:space:]]+[A-Za-z0-9_]*Slice\b' "$ROOT" 2>/dev/null | sort)
if [ -z "$slices" ]; then
    echo "check-slice-writes: no slice class under '$ROOT' — nothing to check"
    exit 0
fi

violations=0
missing_owner=0

# field names must be unique across slices
dups=$(for sf in $slices; do grep -E '^[[:space:]]*(@export[[:space:]]+)?var[[:space:]]+_[A-Za-z0-9_]+' "$sf" \
        | sed -E 's/^[[:space:]]*(@export[[:space:]]+)?var[[:space:]]+(_[A-Za-z0-9_]+).*/\2/' | sort -u; done | sort | uniq -d)
if [ -n "$dups" ]; then
    for d in $dups; do echo "$ROOT: private field $d is declared by more than one slice (names must be unique)"; done
    missing_owner=1
fi

for slice_file in $slices; do
    slice_name=$(grep -E '^class_name[[:space:]]+' "$slice_file" | head -1 | sed -E 's/^class_name[[:space:]]+([A-Za-z0-9_]+).*/\1/')
    owners=$(grep -E '^#[[:space:]]*owner:' "$slice_file" | head -1 | sed -E 's/^#[[:space:]]*owner:[[:space:]]*//')
    if [ -z "$owners" ]; then
        echo "$slice_file:1: slice $slice_name has no '# owner:' line"
        missing_owner=1
        continue
    fi

    # private fields declared in the slice: `var _name`, with or without type/default
    fields=$(grep -E '^[[:space:]]*(@export[[:space:]]+)?var[[:space:]]+_[A-Za-z0-9_]+' "$slice_file" \
             | sed -E 's/^[[:space:]]*(@export[[:space:]]+)?var[[:space:]]+(_[A-Za-z0-9_]+).*/\2/' | sort -u)
    [ -z "$fields" ] && continue

    for field in $fields; do
        # `.field` access (read or write) anywhere in the code root or the extra dir
        while IFS=: read -r file line rest; do
            [ -z "$file" ] && continue
            [ "$file" = "$slice_file" ] && continue
            allowed=0
            for o in $owners; do
                case "$file" in
                    "$o"*|./"$o"*) allowed=1; break ;;
                esac
            done
            extra=0
            case "$file" in "$ALLOWED_EXTRA"*|./"$ALLOWED_EXTRA"*) extra=1 ;; esac
            if [ "$allowed" -eq 0 ] && [ "$extra" -eq 1 ]; then
                # tests may read, not write
                if printf '%s\n' "$rest" | grep -qE "\.${field}(\[[^]]*\])?[[:space:]]*([-+*/|&^]|<<|>>)?=[^=]"; then
                    echo "$file:$line: write to private field $field of $slice_name from $ALLOWED_EXTRA"
                    violations=$((violations + 1))
                fi
                continue
            fi
            if [ "$allowed" -eq 0 ]; then
                echo "$file:$line: access to private field $field of $slice_name (owners: $owners)"
                violations=$((violations + 1))
            fi
        done < <(grep -rnE --include='*.gd' "\.${field}([^A-Za-z0-9_]|$)" "$ROOT" $( [ -d "$ALLOWED_EXTRA" ] && echo "$ALLOWED_EXTRA" ) 2>/dev/null)

        # dynamic access: get("_f"), set("_f", ...), get_indexed/set_indexed, ["_f"]
        while IFS=: read -r file line rest; do
            [ -z "$file" ] && continue
            [ "$file" = "$slice_file" ] && continue
            allowed=0
            for o in $owners; do
                case "$file" in "$o"*|./"$o"*) allowed=1; break ;; esac
            done
            if [ "$allowed" -eq 0 ]; then
                echo "$file:$line: dynamic access to private field $field of $slice_name"
                violations=$((violations + 1))
            fi
        done < <(grep -rnE --include='*.gd' "(get|set|get_indexed|set_indexed)\([[:space:]]*[\"']${field}[\"']|\[[[:space:]]*[\"']${field}[\"'][[:space:]]*\]" "$ROOT" $( [ -d "$ALLOWED_EXTRA" ] && echo "$ALLOWED_EXTRA" ) 2>/dev/null)
    done
done

if [ "$missing_owner" -ne 0 ]; then
    exit 2
fi
if [ "$violations" -ne 0 ]; then
    echo "check-slice-writes: $violations access(es) outside the owning system"
    exit 1
fi
echo "check-slice-writes: ok"
exit 0
