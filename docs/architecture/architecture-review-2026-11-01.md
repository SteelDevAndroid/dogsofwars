# Revue d'architecture — 2026-11-01

**Périmètre** : ADR-0001 à ADR-0011 (tous Accepted), `docs/registry/architecture.yaml`, `tools/ci/check-slice-writes.sh`. Suivi de la revue du 2026-10-30 (B1–B5, M1–M11) et première revue croisée d'ADR-0007 à ADR-0011.

**Verdict : CONCERNS.** Les corrections de fond du 30/10 tiennent : planification sur `WorkerThreadPool` (B1), perception avant chaque `plan_next` (B2), schéma porté par l'enveloppe (B3), enum à 13 types (B4), `is_locked(faction, emitter)` (B5). Les ADR 0007 à 0011 comblent les trous de couverture signalés. Il reste quatre défauts de conception introduits ou laissés ouverts par les amendements, et une série de contrats contradictoires entre ADR, surtout autour de la `RuleTable`.

**Suivi (2026-11-01)** : B1 à B4 et M1 à M15 sont corrigés par amendement d'ADR-0001, 0003 à 0011 et du registre (même PR). M1 et M4 sont soldés avec B1. Pour M9, la décision retenue est : baisser un maximum est un changement de schéma, avec migration ; sans migration, le fichier est refusé. Les points d'attention de la section 3 sont traités : AC-IA33 à catalogue égal (ADR-0005) ; mesure de `t_write` placée avant les stories du runner (ADR-0005, ADR-0006, registre) ; `AiRunner` dans `src/core/ai/` (ADR-0005 §3, ADR-0008 §7) ; AC-HU23 aligné sur 1 600 ms (GDD 17). Section 4 : les sources externes sont listées dans `docs/architecture/references-externes.md`, avec l'endroit où leur contenu normatif est recopié ; `check-layer-deps`, `check-json-duplicate-keys`, `.gitattributes` et le workflow `tests` sont créés ; restent `addons/gdUnit4`, `project.yaml` et `export_presets.cfg`, qui exigent le projet Godot racine (`/test-setup`, premier export).

Les ADR étant `Accepted`, chaque correction ci-dessous est un **amendement** (date `Last Verified`, entrée `revised:` au registre si un contrat enregistré change).

---

## 1. Bloquants (à corriger avant la première story concernée)

### B1. L'aperçu du joueur ne dit pas quelle variante de `RuleTable` il utilise (ADR-0004 §6, ADR-0007 §3 et §8)
- `preview` applique la commande sur `filtered_copy(f)` puis `duplicate_state()`.
- La variante réelle a `VisionContext.factions = [J, IA]` : `apply` appelle alors `recompute`, qui lit `FieldTable`, calculée **sur le vrai terrain** (ADR-0007 §3 : « utilisée uniquement sur l'état réel »).
- Un aperçu qui passe par la variante réelle recalcule donc la vue sur une copie filtrée avec l'occlusion réelle. Les tuiles « découvertes » de la copie trahissent l'eau et les montagnes non explorées, et un aperçu de déplacement peut révéler une unité cachée (`VisionDelta.newly_seen_units`). C'est exactement la fuite que §6 d'ADR-0004 interdit.

**Correction** : écrire dans ADR-0004 §6 que `preview` et `check` utilisent `RuleTable.simulation()` (comme l'IA), et l'ajouter au test de parité d'ADR-0007 (un aperçu ne modifie ni `découverte` ni le `ViewCache` de la copie).

### B2. `VALIDER_LA_LECTURE` retentée en phase ennemie est refusée `PAS_VOTRE_TOUR` (ADR-0004 §4, ADR-0006 §8)
B5 de la revue précédente a corrigé le verrou, pas le préfixe de refus. Une retentative d'écriture du profil (changement suivant, arrière-plan, chargement) peut tomber pendant `EXÉCUTION_ENNEMIE`. La commande porte `faction = JOUEUR` : l'étape 3 du préfixe la refuse. Seul ABANDONNER est exempté. Le journal reste « en attente » jusqu'au tour suivant, et une réconciliation au chargement en phase ennemie échoue à chaque fois.

**Correction** : dans ADR-0004 §4, le contrôle PAS_VOTRE_TOUR ne s'applique qu'à `emitter == JOUEUR` (même règle que `is_locked`) ; ajouter un AC « VALIDER_LA_LECTURE soumise en phase ennemie est appliquée ».

### B3. Le budget par appel ne borne plus le tour (ADR-0005 §4, AC-IA32)
- §4 : plafond d'un appel = budget du tour ÷ nombre d'unités, `AiBudget` recréé à chaque appel.
- Mais une unité fait **plusieurs** appels (un par coup, plus l'appel final qui rend `null`), auxquels s'ajoutent l'annonce et les re-perceptions après refus (jusqu'à `N_REFUS_MAX` = 32).
- Le total du tour est donc borné par `appels × plafond`, pas par 2 500 copies et 20 000 évaluations. AC-IA32 ne peut pas être prouvé.

**Correction recommandée** : garder le budget par appel (c'est lui qui rend la reprise déterministe) et borner le **nombre d'appels** par unité et par tour en données (`APPELS_PAR_UNITÉ_MAX`). Le plafond du tour devient `unités × APPELS_PAR_UNITÉ_MAX × plafond_appel + annonce`. Ce produit, calculé au chargement du catalogue, est validé ≤ 2 500 / 20 000. Le compteur d'appels se déduit de l'état (coups consommés par l'unité), donc la reprise reste exacte. Reformuler AC-IA32 sur ce produit.

### B4. `rebuild` du cache de vue : qui l'appelle, avec quel contexte (ADR-0007 §2 et Risks, ADR-0003, ADR-0008 §6)
- ADR-0007 : `restore_from` et `from_bytes` « doivent appeler `rebuild` » ; Risks : « `rebuild` appelé par `restore_from` lui-même, pas par l'appelant ».
- Or `rebuild(state, ctx)` exige un `VisionContext`, que ni `from_bytes(bytes, schema)` ni `restore_from(snapshot)` ne reçoivent.
- ADR-0008 §6 appelle `rebuild(state, vision_context)` **avant** `SessionFactory.build`, alors que c'est la fabrique qui construit le `VisionContext` (ADR-0007 §3).

**Correction** : construire le `VisionContext` dans `AppContext` ou par une fonction pure `VisionContext.for_map(catalog, terrain)` appelée par `Bootstrap` avant `from_bytes`, puis le passer à la fabrique. Choisir **un** appelant de `rebuild` : `UndoMoveCommand` (via la `RuleTable`, qui détient le contexte) pour l'annulation, `Bootstrap` pour le chargement. Corriger la phrase des Risks d'ADR-0007 et l'Implementation Guideline.

---

## 2. Incohérences à corriger

| # | Où | Constat | Correction |
|---|---|---|---|
| M1 | ADR-0007 diagramme ; ADR-0004 Related | « `apply_on` (IA) : {IA} » et « la faction de la commande dans `apply_on` » contredisent ADR-0007 §8 (`factions = []` en simulation) | Aligner sur §8 : aucune faction recalculée en simulation |
| M2 | ADR-0004 §2 et Key Interfaces, ADR-0010 §7 et Key Interfaces | `check_move_range` est une méthode d'instance de `RuleTable` (§2), une méthode de `CommandPipeline` (Key Interfaces), puis un `static func` de `RuleTable` (ADR-0010). `static` contredit la `RuleTable` en instance immuable qui détient catalogue et `VisionContext` | Méthode d'instance de `RuleTable` ; le pipeline l'expose en délégation. Corriger les deux blocs Key Interfaces et l'entrée du registre |
| M3 | ADR-0010 Validation, ADR-0011 §5 | « Parité `check(Move)` / `check_move_range` » contredit ADR-0010 §7, qui compare `validate` et explique pourquoi pas `check` | Remplacer par `validate(view, Move)` dans les deux ADR |
| M4 | ADR-0004 §2 | « [la variante de simulation] est partagée par le pipeline réel et les simulations » : le pipeline réel utilise la variante réelle | Réécrire : la variante réelle sert à `submit`, la variante de simulation à `preview`, `check`, `apply_on` et à l'IA (voir B1) |
| M5 | ADR-0005 Validation et GDD Requirements (ancien M3/M4 non soldé) | AC-IA32 exige toujours « paliers à 70 % et 100 % » ; la ligne `hud-systeme.md` cite encore « Cadence par `sequencer.is_idle()` » ; la ligne des règles 19 et 20 aussi | Plafond dur au MVP ; `PacingGate.is_ready()` |
| M6 | ADR-0005 §5 ; registre `ai_agents` | `curseur_ia` (tranche « agents », propriétaire 9) est « écrit par l'application de chaque commande de l'IA », donc par les handlers de DÉPLACER (6) et MONTER_NŒUD (11). Viole « un écrivain par champ » et sera signalé par `check-slice-writes` | La couche des commandes appelle la fonction d'écriture du système 9 après `apply` pour `emitter == IA`, comme elle écrit la révision ; l'écrire dans ADR-0004 §4 |
| M7 | ADR-0009 Key Interfaces contre §7 | `content_hash` est calculé sur les **octets** (`get_file_as_bytes`), mais `DataSource` n'expose que `read_text` | Ajouter `read_bytes(path) -> PackedByteArray` ; `read_text` dérive des octets (une seule lecture) |
| M8 | ADR-0009 diagramme | « parse (`JSON.parse_string` / …) » contredit §4 (« jamais `JSON.parse_string` ») | `JSON.new().parse` seul |
| M9 | ADR-0009 §10 contre Constraints et §7 | Ramener une valeur au nouveau maximum « par une migration documentée » suppose un changement de schéma, alors qu'un changement d'équilibrage ne change pas le schéma (règle 17bis). Rien ne déclenche la migration | Soit la clamp est une règle de chargement explicite (`from_bytes` + catalogue, sans schéma), soit baisser un maximum est déclaré changement de schéma. Trancher et l'écrire |
| M10 | ADR-0009 Implementation Guidelines | « un rapport doit porter le suffixe `_pct` ou `_milli` » oublie `_micro` (§2, `ZOOM_EPS_MICRO`) | Ajouter `_micro` |
| M11 | ADR-0008 Consequences | `SessionOverrides` n'est défini nulle part | Supprimer ou définir |
| M12 | ADR-0001 et ADR-0008, Ordering Note | « l'ADR reste Proposed jusque-là » (0001) et « ADR-0002 à 0006 et 0009 sont encore Proposed » (0008) sont périmés depuis l'acceptation | Rafraîchir |
| M13 | ADR-0005 §5 contre Key Interfaces ; Risks | `resume(state)` contre `resume(state, pipeline, pacing)` ; Risks parle d'« une dizaine de `filtered_copy` » (une par unité) alors que §1 en fait une par appel | Aligner sur la signature et sur « une par appel » |
| M14 | ADR-0004 GDD Requirements | « MONTER_NŒUD : 12e type de commande » ; c'est la 5e valeur de l'enum | « type `UPGRADE_NODE` » |
| M15 | ADR-0007 Risks | « repli sur un compteur par tuile (section 8) » : le repli est en section 10 | Corriger le renvoi |

---

## 3. Points d'attention (non bloquants)

- **Reprise après mise à jour du jeu** : `content_hash` n'est pas sauvegardé (ADR-0009 §7, choix assumé). Une partie interrompue en phase ennemie et reprise après une mise à jour des `AiParams` ne rejoue pas le run sans arrêt. AC-IA33 doit préciser « à catalogue égal ».
- **Écritures synchrones en phase ennemie** (ancien M1) : décision toujours reportée à AC-F1. Avec 20 ms par écriture (GDD 16), chaque commande de l'IA dépasse la cible de 16,6 ms du registre. Mesurer `t_write` sur appareil **avant** les stories du runner : si le fil d'écriture est nécessaire, il amende ADR-0004 §4 et ADR-0006 §7, qui sont dans le chemin de toutes les commandes.
- **`AiRunner` : couche et dossier** : `Node` à `_process` dans `MatchScreen` (ADR-0008), mais Layer « Feature » et aucune Presentation référencée (ADR-0005). ADR-0008 §7 ne dit pas s'il vit sous `src/core/ai/` ou `src/presentation/`. Le placer explicitement, car `check-layer-deps` en dépend.
- **Verrou d'attaque** : 1 600 ms est désormais aligné (GDD 8, 17, 23, `hud.md`), sauf **AC-HU23**, qui garde « verrou ≈ 1,5 s (1,3 à 1,7 s) ».
- **Contrôle `check-slice-writes`** : les trois limites de la revue précédente sont traitées (noms uniques, `tests` analysés en lecture, accès dynamiques).

---

## 4. Références toujours introuvables dans le dépôt

`docs/engine-reference/godot/*` (tous les ADR), `.claude/docs/coding-standards.md`, `.claude/rules/test-standards.md`, `.claude/docs/run-and-observe.md`, `project.yaml` (ADR-0011 : commande de test, `testing.framework`). ADR-0011 en fait des sources normatives (commande unique, code de sortie 101). Les versionner, ou recopier la commande et les conventions dans ADR-0011.

Outils promis par des ADR acceptés et non encore créés (attendu, à planifier en story Foundation) : `tools/ci/check-layer-deps` (0008), `tools/ci/check-json-duplicate-keys` (0009), workflow `tests` et `addons/gdUnit4` 6.2.2 (0011), `.gitattributes` et `export_presets.cfg` (0009).

---

## 5. Ce qui est solide

- Les cinq bloquants du 30/10 sont corrigés sur le fond, pas seulement en surface : la reprise de la phase ennemie est déterministe par construction (perception et budget par appel, `curseur_ia` inclusif).
- Un seul prédicat de visibilité, avec une copie filtrée qui porte son propre terrain : la frontière anti-fuite est enfin définie et testable.
- Racine de composition sans autoload, fabrique partagée par le jeu et les tests, séquence de libération qui traite les cycles `RefCounted` invisibles au détecteur d'orphelins.
- Données en entiers seulement, schéma strict, échec franc : rien de flottant n'entre dans les règles.
- Gestes, caméra et décision d'appui purs et testables sans appareil ; la portée affichée **est** la validation.
- Registre : budgets d'image désormais vérifiables (cible 60 i/s, coût unitaire de copie séparé, planification sortie du fil principal).
