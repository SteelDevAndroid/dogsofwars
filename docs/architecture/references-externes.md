# Références externes au dépôt

Les ADR citent, dans **References Consulted** et ailleurs, des sources qui ne sont **pas versionnées** dans ce dépôt : elles vivent dans l'outillage local du studio. Ce fichier dit lesquelles, et où leur contenu normatif est recopié pour que les ADR se suffisent à eux-mêmes (revue d'architecture du 2026-11-01, section 4).

**Règle** : un ADR ne tire jamais une contrainte normative d'une source externe sans la recopier. Une citation externe documente la provenance d'une vérification ; elle n'est pas une exigence.

| Source externe | Citée par | Contenu normatif recopié dans |
|---|---|---|
| `docs/engine-reference/godot/` (`VERSION.md`, `breaking-changes.md`, `deprecated-apis.md`, `current-best-practices.md`, `modules/rendering.md`) | ADR-0001 à ADR-0011 | Chaque ADR : sections **Engine Compatibility** et **Last Verified** (version 4.7.2, API vérifiées et méthode de vérification). Les points NOT SOURCEABLE y sont nommés |
| `.claude/docs/coding-standards.md` | ADR-0008, ADR-0011 | ADR-0011 : commande de test (§2), nommage `[système]_[fonction]_test.gd` / `test_[scénario]_[résultat]` (Constraints), arrange / act / assert (§3) ; ADR-0009 : valeurs de jeu jamais codées en dur |
| `.claude/rules/test-standards.md` | ADR-0011 | ADR-0011 : codes de sortie 0 / 100 / 101 (§2, mesurés le 2026-11-01), règles de déterminisme et de doublures (Implementation Guidelines) |
| `.claude/docs/run-and-observe.md` | ADR-0011 | ADR-0011 §6 : preuve visuelle par capture retenue (`--write-movie`, fenêtré, jamais `--headless`) dans `production/qa/evidence/` |
| `.claude/scripts/registry.sh` | `docs/registry/architecture.yaml` (en-tête) | En-tête du registre : forme exacte lue par le script (section `LAYOUT`) |

## Outillage promis par les ADR

| Élément | ADR | État |
|---|---|---|
| `tools/ci/check-slice-writes.sh` | ADR-0003 | Fait, workflow `slice-writes` |
| `tools/ci/check-layer-deps.sh` | ADR-0008 §7 | Fait, workflow `tests` |
| `tools/ci/check-json-duplicate-keys.py` | ADR-0009 §8 | Fait, workflow `tests` |
| `.gitattributes` (`assets/data/*.json text eol=lf`) | ADR-0009 §7 | Fait |
| Workflow `tests` (auto-tests shell, contrôles, gdUnit4) | ADR-0011 §8, §9 | Fait |
| `addons/gdUnit4` 6.2.2, `project.godot` racine, `project.yaml` | ADR-0011 §1, §2 | Fait (2026-11-01) ; `project.yaml` est désormais versionné |
| Doublures des ports `DataSource`, `FileStore`, `EventSink`, `PacingGate`, `ClockSource` (`tests/fixtures/`) | ADR-0011 §4 | Fait (2026-11-01) |
| `StateFactory`, `NullProfilePort`, `RecordingProfilePort` | ADR-0011 §4 | Avec `GameState` (ADR-0003) et `ProfilePort` (ADR-0004) |
| `export_presets.cfg` (preset Android, `include_filter="assets/data/*.json"`) | ADR-0009 §9 | À faire avec le premier export Android |
