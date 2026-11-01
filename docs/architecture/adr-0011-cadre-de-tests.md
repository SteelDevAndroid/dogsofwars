# ADR-0011: Cadre de tests — gdUnit4 en headless, doublures et fabriques partagées, tests de propriétés déterministes, scripts shell pour l'outillage

## Status
Accepted

## Date
2026-10-31

## Last Verified
2026-10-31 — conception sur les standards du projet (`.claude/docs/coding-standards.md`, `.claude/rules/test-standards.md`, `.claude/docs/run-and-observe.md`) et les critères de validation des ADR-0001 à 0010. Selon `run-and-observe.md`, la commande gdUnit4 du projet a été exécutée avec **gdUnit4 6.2.2 sur Godot 4.7.2** (Windows) ; elle n'est **pas encore installée** dans ce dépôt (`addons/` absent). Les scripts shell de `tests/unit/ci/` ont tourné (8 cas) ; aucun test GDScript n'existe encore.

## Decision Makers
Utilisateur (direction de projet, choix « recommandé » délégué), Claude (rédaction), godot-specialist et technical-director (validation, TD-ADR : CONCERNS traités le 2026-10-31). **L'acceptation (`Accepted`) exige une confirmation explicite de l'utilisateur, ADR par ADR : le choix « recommandé » délégué ne vaut pas acceptation.**

## Summary
La revue d'architecture a relevé qu'aucun ADR ne choisit le cadre de tests, alors que les fixtures de la CI supposent GUT et que les standards du projet citent gdUnit4. Décision : **gdUnit4** épinglé à une version, exécuté en headless avec la commande du projet, une arborescence `tests/` par système et par type, des **doublures partagées** (fichiers en mémoire, puits enregistreur, cadence toujours prête) construites par la fabrique de test d'ADR-0008, des tests d'invariants sur états aléatoires à graine fixe, et des scripts shell pour l'outillage CI.

## Engine Compatibility

| Field | Value |
|-------|-------|
| **Engine** | Godot 4.7.2 |
| **Domain** | Core |
| **Layer** | Foundation |
| **Knowledge Risk** | MEDIUM (extension tierce ; API moteur utilisées : `SceneTree`, `OS`, `Time`) |
| **References Consulted** | `docs/engine-reference/godot/VERSION.md`, `.claude/docs/coding-standards.md`, `.claude/rules/test-standards.md`, `.claude/docs/run-and-observe.md`, ADR-0002 à 0010 |
| **Post-Cutoff APIs Used** | Aucune dans le jeu ; gdUnit4 6.2.2 est postérieur à la connaissance du modèle : comportement à confirmer à l'installation |
| **Verification Required** | (1) installer gdUnit4 6.2.2 et exécuter la commande du projet sur un test témoin (exit 0 puis exit non nul sur un test rouge) ; (2) détection des orphelins sur un `Node` oublié et **code de sortie exact** (101 selon `.claude/rules/test-standards.md`, NOT SOURCEABLE ici : peut être un code d'avertissement distinct de l'échec, à confirmer à l'installation) ; les fuites `RefCounted` par cycle ne sont **pas** vues par ce détecteur ; (3) durée de la suite complète sur le runner CI ; (4) lancement headless de la suite avec un Godot épinglé et vérifié par empreinte dans la CI |

## ADR Dependencies

| Field | Value |
|-------|-------|
| **Depends On** | None |
| **Enables** | Toutes les stories (preuve par test), `TestSessionFactory` (qui s'appuie sur ADR-0008), validation de chaque ADR (critères de validation), `/test-setup`, `/smoke-check` |
| **Blocks** | Premier sprint de code : aucune story Logic ne peut se fermer sans ce cadre |
| **Ordering Note** | Foundation : accepter avant la première story ; `/test-setup` l'implémente |

## Context

### Problem Statement
Les standards exigent des tests avant les systèmes de jeu, un déterminisme strict, des doublures pour tout I/O et une preuve par capture pour le visuel. Les ADR ont posé des critères que seuls des tests spécifiques vérifient (parité `FactionView` / `filtered_copy`, indépendance copie / original, reprise à toute commande, injection de pannes de fichier, parité F5 GDScript / shader). Rien ne dit avec quel outil, dans quelle arborescence, avec quelles doublures.

### Constraints
- GDScript, Godot 4.7.2 ; exécution headless pour la CI (le rendu réel ne se teste pas par cette voie).
- Tests déterministes : pas d'horloge système, pas de hasard moteur (la graine du jeu suffit).
- Les unités n'appellent ni le système de fichiers, ni le réseau, ni la base de données : injection (ports).
- La commande de test du projet est fixée dans `project.yaml` (`commands.test`) et dans `coding-standards.md`.
- Nommage gdUnit4 : fichier `[système]_[fonction]_test.gd`, fonction `test_[scénario]_[résultat]`.

### Requirements
- Une suite exécutable en une commande, en CI à chaque push et chaque PR, bloquante.
- Des fabriques d'états et des doublures réutilisables par tous les systèmes.
- Des tests de rejeu, de reprise et de parité reproductibles à graine fixe.
- Le visuel reste une preuve par capture retenue, pas un test automatique.

## Decision

**1. gdUnit4, version épinglée.** Le cadre est **gdUnit4** (déjà nommé par les standards), version **6.2.2**, installé dans `addons/gdUnit4/` et **commité** (pas de téléchargement à la volée en CI). `project.yaml` porte le **nom** (`testing.framework: gdunit4`, comme `effects-map.md`) et la version épinglée vit dans `addons/gdUnit4/plugin.cfg` ; un changement de version est une décision tracée, avec ré-exécution de la suite sur le Godot épinglé. GUT n'est pas utilisé : aucune fixture ni doc ne doit le référencer.

**2. Commande et exécution.** La commande unique est celle de `project.yaml` : `godot --headless -s -d --remote-debug tcp://127.0.0.1:0 res://addons/gdUnit4/bin/GdUnitCmdTool.gd -a res://tests --ignoreHeadlessMode`. Le Godot de la CI est **épinglé à 4.7.2-stable** avec vérification d'empreinte du binaire téléchargé. Un test rouge, une erreur de script ou un orphelin (code 101) font échouer l'étape ; aucun test n'est désactivé pour passer la CI.

**3. Arborescence.** `tests/unit/<système>/<système>_<fonction>_test.gd` (Logic), `tests/integration/<système>/…` (multi-systèmes, rejeu, reprise), `tests/performance/…` (seuils chiffrés, échec si dépassés ; les mesures d'appareil sont des rapports), `tests/fixtures/` (fabriques, fichiers témoins, rejeux dorés), `tests/unit/ci/*.sh` (scripts d'outillage, voir 8). Chaque test suit arrange / act / assert.

**4. Fabriques et doublures partagées** (`tests/fixtures/`), toutes dérivées des ports des ADR :
- `StateFactory` : états minimaux nommés (carte 8 × 8, deux factions, N unités) et générateur d'états aléatoires **à graine fixe** fondé sur la fonction de tirage `draw` d'ADR-0003 (jamais `randi()`) ; aucun nombre magique en ligne (sauf test de bornes).
- `MemoryDataSource` (ADR-0009), `FaultInjectingFileStore` (ADR-0006, panne à chaque étape), `RecordingSink` et `NullSink` (ADR-0002), `AlwaysReadyPacingGate` (ADR-0005), `FakeClock` (implémente le port `ClockSource` d'ADR-0002, que `PresentationClock` implémente aussi), `NullProfilePort` / `RecordingProfilePort` (ADR-0004).
- `TestSessionFactory` (dans `tests/fixtures/`, **pas** dans `src/`) appelle la `SessionFactory.build` d'ADR-0008 avec ces doublures, sans `Bootstrap` ni scène : `src/` ne dépend jamais de `tests/`.

**5. Catégories de tests exigées par les ADR** :
- **Propriétés sur états aléatoires** (au moins 1 000 états, graine fixe affichée en cas d'échec) : parité `FactionView` / `filtered_copy` (ADR-0007), indépendance copie / original sur chaque colonne (ADR-0003), `check(Move)` ⇔ `check_move_range` (ADR-0010), égalité après `to_bytes` / `from_bytes`.
- **Rejeu** : un `CommandLog` doré rejoue au même état final ; un refus pendant le rejeu est une divergence (ADR-0004).
- **Reprise** : arrêt simulé après la commande k, pour tout k, d'un tour d'IA fixé : même état final qu'un tour sans arrêt (ADR-0005, AC-IA33).
- **Pannes de fichier** : injection à chaque étape de l'écriture ; un fichier valide reste toujours chargeable (ADR-0006).
- **Couches** : les contrôles CI (`check-slice-writes`, `check-layer-deps`, doublons de clés JSON) ont chacun leur auto-test.

**6. Ce que le cadre n'automatise pas.** Rendu des tuiles, onde de recoloration, sensation d'un geste, rendu réel du shader : **preuve par capture retenue** dans `production/qa/evidence/` selon `.claude/docs/run-and-observe.md` (lancement fenêtré, `--write-movie`, jamais `--headless`). La parité entre le calcul GDScript et le shader F5 se teste sur les entrées numériques (tests de vecteurs), pas sur les pixels.

**7. Mesures d'appareil.** Les budgets Android (écriture synchrone, copie, recalcul de vue, planification) sont mesurés par un `PerfHarness` qui imprime des lignes JSON (nom, durée, nombre d'itérations) ; sur PC il vérifie des seuils larges, sur appareil il produit un rapport archivé, jamais un échec automatique.

**8. Outillage hors GDScript.** Les contrôles CI écrits en shell ou Python (`tools/ci/*`) ont un auto-test shell dans `tests/unit/ci/` qui construit ses fixtures dans un répertoire temporaire et prouve qu'un cas rouge **échoue** (règle « un contrôle qu'on n'a pas vu échouer n'est pas un contrôle »). Le workflow `.github/workflows/` exécute ces auto-tests, puis la suite gdUnit4.

**9. CI.** Les classes de test et de doublure déclarent des `class_name` : sur un dépôt propre, la CI exécute d'abord `godot --headless --import` pour construire le cache de classes globales (`.godot/global_script_class_cache.cfg`), sans quoi elles ne se résolvent pas (vérifié : un script de test a dû passer par `preload`). Un code de sortie 101 (orphelins) est traité par le workflow comme un échec explicite. Le workflow `tests` s'exécute à chaque push sur `main` et chaque PR ; la suite gdUnit4 est une étape **bloquante** ; un échec bloque la fusion. Le rapport JUnit est archivé.

### Architecture Diagram

```
 tests/
  ├─ unit/<système>/*_test.gd         Logic, doublures injectées, aucun I/O réel
  ├─ integration/<système>/*_test.gd  rejeu, reprise, pannes de fichier, session complète
  ├─ performance/*_test.gd            seuils chiffrés (PC) ; PerfHarness → rapports d'appareil
  ├─ fixtures/                        StateFactory, doublures (ports des ADR), rejeux dorés, fichiers témoins
  └─ unit/ci/*.sh                     auto-tests des contrôles shell (cas vert ET cas rouge)
 TestSessionFactory (tests/fixtures) ► SessionFactory.build  ◄── MemoryDataSource, FaultInjectingFileStore, RecordingSink,
                                                AlwaysReadyPacingGate, FakeClock, RecordingProfilePort
 CI : auto-tests shell ► validation des données (ADR-0009) ► suite gdUnit4 headless (bloquante) ► rapport JUnit
 Visuel : capture retenue (run-and-observe), jamais headless
```

### Key Interfaces

```gdscript
# tests/fixtures/state_factory.gd
class_name StateFactory extends RefCounted
static func minimal(seed_value: int = 1) -> GameState                       # carte 8x8, deux factions
static func random_states(count: int, seed_value: int) -> Array[GameState]  # déterministe

# doublures (ports des ADR)
class_name MemoryDataSource extends DataSource
class_name FaultInjectingFileStore extends FileStore     # fail_at(step) ; journal des appels
class_name RecordingSink extends EventSink               # batches: Array[EventBatch]
class_name AlwaysReadyPacingGate extends PacingGate
class_name FakeClock extends ClockSource                  # advance(seconds)
```

### Implementation Guidelines
- Un test **doit** suivre `test_[scénario]_[résultat]` dans `[système]_[fonction]_test.gd` et la structure arrange / act / assert.
- Un test **ne doit jamais** dépendre de l'ordre d'exécution, de l'horloge système, du hasard du moteur, du système de fichiers réel ni du réseau.
- Un `Node` créé par un test **doit** être libéré (`auto_free`) ; un orphelin est un échec. Les cycles `RefCounted` (session, pipeline, rappels) échappent à ce contrôle : un test dédié compare `Performance.get_monitor(Performance.OBJECT_COUNT)` avant et après une partie (ADR-0008).
- Tout test de propriété **doit** afficher sa graine en cas d'échec.
- Une correction de bogue **doit** ajouter un test de régression qu'on a vu échouer sur le code non corrigé.
- Un test **ne doit jamais** être désactivé ni sauté pour faire passer la CI.
- Les valeurs de jeu dans les fixtures **doivent** venir de fabriques ou de fichiers témoins, pas de nombres en ligne.

## Alternatives Considered

### Alternative 1: GUT
- **Description**: l'autre cadre de tests GDScript courant.
- **Pros**: très répandu ; léger.
- **Cons**: non nommé par les standards ni par la commande de test du projet ; moins d'outillage de CI intégré ici.
- **Estimated Effort**: similaire.
- **Rejection Reason**: les standards, `project.yaml` et `run-and-observe.md` sont écrits pour gdUnit4 (déjà exécuté sur 4.7.2).

### Alternative 2: Scripts `SceneTree` maison
- **Description**: scripts exécutés par `--script`, assertions maison.
- **Pros**: aucune dépendance.
- **Cons**: aucune détection d'orphelins, pas de rapport, pas d'attributs ; réinvente un cadre.
- **Estimated Effort**: plus.
- **Rejection Reason**: coût de maintenance sans gain.

### Alternative 3: Tests uniquement manuels et captures
- **Description**: valider par jeu et captures.
- **Pros**: peu de code.
- **Cons**: aucune garantie de régression ; incompatible avec le déterminisme exigé et les parités des ADR.
- **Estimated Effort**: moindre.
- **Rejection Reason**: les critères des ADR sont des propriétés à prouver mécaniquement.

## Consequences

### Positive
- Les critères de validation des ADR 0001 à 0010 deviennent des tests nommés, exécutés à chaque PR.
- Mêmes doublures pour le jeu et les tests : aucune divergence de câblage (ADR-0008).
- Le déterminisme est testé (rejeu, reprise, graine fixe).

### Negative
- Une extension tierce à épingler et à mettre à jour avec le moteur.
- Les fabriques et doublures sont un investissement initial avant les premières stories.

### Neutral
- Le visuel et la sensation restent humains ; le cadre ne les remplace pas.

## Risks
- **gdUnit4 incompatible avec une montée de version du moteur** : *Atténuation* : version épinglée, suite de test témoin, décision tracée à chaque montée.
- **Suite trop lente en CI** : *Atténuation* : séparer unit / integration / performance, seuils de durée par catégorie.
- **Tests fragiles par couplage aux fabriques** : *Atténuation* : fabriques minimales et nommées, états aléatoires seulement pour les propriétés.

## GDD Requirements Addressed

Foundational — no direct GDD requirement. Enables : tous les critères d'acceptation des GDD (étiquettes Logic, Intégration), `coding-standards.md` (« tests avant les systèmes de gameplay », « un moyen de prouver »), les critères de validation d'ADR-0001 à 0010 et la règle de CI « aucun merge si les tests échouent ».

## Performance Implications
- **CPU**: la suite s'exécute hors jeu ; durée à mesurer sur le runner (vérification 3).
- **Memory**: sans objet.
- **Load Time**: sans objet.
- **Network**: sans objet.

## Migration Plan
Aucun test existant en GDScript. À faire via `/test-setup` : installer `addons/gdUnit4` (6.2.2), créer `tests/`, les fabriques et doublures, le workflow `tests` (auto-tests shell puis gdUnit4), renseigner `testing.framework` dans `project.yaml`, retirer toute mention de GUT dans les fixtures de `tests/unit/ci/`.

**Rollback plan**: si gdUnit4 devient incompatible avec le moteur, basculer vers GUT en gardant les fabriques et doublures (elles ne dépendent pas du cadre).

## Validation Criteria
- La commande du projet rend 0 sur la suite verte et non nul sur un test rouge ; un orphelin donne 101.
- Les catégories de la section 5 existent, chacune avec au moins un test vu échouer sur une défaillance introduite volontairement.
- La CI bloque une PR dont un test échoue.

## Related
- ADR-0002, ADR-0003, ADR-0004, ADR-0005, ADR-0006, ADR-0007, ADR-0008, ADR-0009, ADR-0010.
- `.claude/docs/coding-standards.md`, `.claude/rules/test-standards.md`, `.claude/docs/run-and-observe.md`, `project.yaml`.
