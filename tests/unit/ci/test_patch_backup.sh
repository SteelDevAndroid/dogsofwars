#!/usr/bin/env bash
# Self-test of tools/android/patch_backup.py on a copy of the real Godot 4.7.2 template manifest.
# Run: bash tests/unit/ci/test_patch_backup.sh — exits 0 when every case behaves.

set -u
HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PATCH="$HERE/../../../tools/android/patch_backup.py"
FIXTURE="$HERE/../../fixtures/android/AndroidManifest.template.xml"
fails=0

ok() { echo "ok   $1"; }
bad() { echo "FAIL $1"; fails=$((fails + 1)); }

mk() { mkdir -p "$1/src/main"; cp "$FIXTURE" "$1/src/main/AndroidManifest.xml"; }

t=$(mktemp -d); mk "$t"
out=$(python3 -I "$PATCH" "$t") && [ "$out" = "patched" ] && ok "first run patches" || bad "first run patches ($out)"
m="$t/src/main/AndroidManifest.xml"
grep -q 'android:allowBackup="true"' "$m" && ok "backup is on" || bad "backup is on"
grep -q 'android:allowBackup="false"' "$m" && bad "no leftover off switch" || ok "no leftover off switch"
grep -q 'fullBackupContent="@xml/backup_rules"' "$m" && grep -q 'dataExtractionRules="@xml/data_extraction_rules"' "$m" && ok "both rule files are named" || bad "both rule files are named"
python3 -I -c "import sys,xml.etree.ElementTree as E; E.parse(sys.argv[1])" "$m" && ok "the manifest is still well-formed XML" || bad "the manifest is still well-formed XML"
for f in backup_rules.xml data_extraction_rules.xml; do
    [ -s "$t/res/xml/$f" ] && ok "$f copied" || bad "$f copied"
done
grep -q 'profile.sav' "$t/res/xml/backup_rules.xml" && ! grep -q 'path="match' "$t/res/xml/backup_rules.xml" \
    && ! grep -q 'path="match' "$t/res/xml/data_extraction_rules.xml" && grep -q 'profile.sav' "$t/res/xml/data_extraction_rules.xml" \
    && ok "the rules carry the profile and never the match" || bad "the rules carry the profile and never the match"
out=$(python3 -I "$PATCH" "$t") && [ "$out" = "already patched" ] && ok "second run changes nothing" || bad "second run changes nothing ($out)"
[ "$(grep -c 'allowBackup' "$m")" -eq 1 ] && ok "one allowBackup attribute after two runs" || bad "one allowBackup attribute after two runs"

t2=$(mktemp -d); mk "$t2"
sed -i 's/android:allowBackup="false"/android:allowBackup="auto"/' "$t2/src/main/AndroidManifest.xml"
python3 -I "$PATCH" "$t2" >/dev/null 2>&1 && bad "refuses a template it does not know" || ok "refuses a template it does not know"
rm -rf "$t" "$t2"
exit $fails
