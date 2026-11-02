# ADR-0008: Racine de composition — un seul Bootstrap, deux portées (application, partie), aucun autoload

## Status
Accepted

## Date
2026-10-31

## Last Verified
2026-10-31 — conception sur les ADR-0001 à 0007 et 0009 ; **vérifié en headless** Godot 4.7.2 : le projet n'a aucun réglage `autoload/*` (aucun singleton à retirer). Construction réelle des scènes et libération en fin de partie : non prototypées. Amendé le 2026-11-01 (revue d'architecture, B4 : le `VisionContext` vient du chargement ou de la mise en place ; M11, M12 ; point d'attention : dossier d'`AiRunner`).

## Decision Makers
Utilisateur (direction de projet, choix « recommandé » délégué), Claude (rédaction), godot-specialist et technical-director (validation, TD-ADR : CONCERNS traités le 2026-10-31). **L'acceptation (`Accepted`) exige une confirmation explicite de l'utilisateur, ADR par ADR : le choix « recommandé » délégué ne vaut pas acceptation.**

## Summary
Tous les ADR injectent leurs dépendances (ports, puits d'événements, portes de cadence, magasins de fichiers) et interdisent les singletons, mais personne ne dit qui construit le pipeline, la file, le séquenceur, le runner de l'IA et les ports, dans quelle scène, ni comment tout est reconstruit au chargement. Décision : un seul fichier `Bootstrap` dans `src/app/` qui connaît à la fois le Core et la Presentation, deux portées d'objets (`AppContext` pour le processus, `GameSession` pour une partie), une `SessionFactory` qui prend tous ses ports en paramètre (donc réutilisée par les tests), et zéro autoload.

## Engine Compatibility

| Field | Value |
|-------|-------|
| **Engine** | Godot 4.7.2 |
| **Domain** | Core |
| **Layer** | Core |
| **Knowledge Risk** | MEDIUM (scènes, `Node`, `queue_free`, `process_priority` : API stables depuis 4.0) |
| **References Consulted** | `docs/engine-reference/godot/VERSION.md`, `docs/engine-reference/godot/current-best-practices.md`, ADR-0001 à 0007 et 0009 |
| **Post-Cutoff APIs Used** | Aucune |
| **Verification Required** | (1) libération complète d'une partie (aucun orphelin, tâche de l'IA terminée) ; (2) ordre de `_process` des nœuds selon la liste d'ADR-0002 ; (3) durée de construction d'une partie sur Android (budget à fixer) |

## ADR Dependencies

| Field | Value |
|-------|-------|
| **Depends On** | ADR-0002 (`EventSink`, `CommandGate`, séquenceur), ADR-0003 (état), ADR-0004 (pipeline), ADR-0005 (runner), ADR-0006 (`SaveStore`, `FileStore`), ADR-0009 (`DataCatalog`) — Accepted avant celui-ci |
| **Enables** | ADR-0010 (la surface d'entrée reçoit son pipeline et sa caméra), ADR-0011 (fabrique de test), toutes les stories d'écran et de partie |
| **Blocks** | Stories : nouvelle partie, continuer, fin de partie, reprise de la phase ennemie, écran d'erreur de données |
| **Ordering Note** | Assemble les autres ADR Core, tous Accepted depuis le 2026-10-31 ; toute nouvelle dépendance injectée amende la fabrique (§3) |

## Context

### Problem Statement
Sans racine de composition, chaque système construirait ses dépendances (donc des singletons de fait) ou les chercherait dans l'arbre de scène. Les ADR définissent des **ports** (`EventSink`, `PacingGate`, `PostCommitPort`, `ProfilePort`, `FileStore`, `DataSource`) pour que le Core ne dépende jamais de la Presentation ; il reste à décider l'endroit unique où ils sont branchés.

### Constraints
- GDScript, Godot 4.7.2, Android d'abord.
- Pas de singleton ni d'autoload (ADR-0002) ; le Core ne référence jamais la Presentation.
- `process_priority` : `PresentationClock` −20, `TileTimeSource` −10, `PresentationSequencer` 0, `TileRenderer` 10, `AiRunner` 20 (liste d'ADR-0002, source unique).
- Une seule partie à la fois (GDD 16, règle 12) ; l'état d'une partie est rechargeable à tout moment (ÉTAT_CHARGÉ).
- Les tests doivent construire la même partie avec des doublures (fichiers en mémoire, puits enregistreur, cadence toujours prête).

### Requirements
- Un graphe d'objets construit en un seul endroit, dans un ordre défini, libéré sans fuite.
- Reconstruction au chargement sans code dupliqué avec la nouvelle partie.
- La fabrique de partie est indépendante de l'arbre de scène (testable en headless).

## Decision

**1. Aucun autoload, un seul `Bootstrap`.** La scène principale `src/app/main.tscn` porte `Bootstrap` (`Node`) ; c'est, avec les autres fichiers de `src/app/`, le **seul** code autorisé à instancier des classes concrètes du Core **et** de la Presentation (la Presentation peut nommer le Core ; le Core ne nomme jamais `app` ni `presentation`). Il n'y a **aucun** réglage `autoload/*`. Les dépendances se passent par **paramètres de constructeur ou d'initialisation** ; un `get_node("/root/…")` pour trouver un service est interdit.

**2. Deux portées.**
- `AppContext` (`RefCounted`, durée du processus) : `DataCatalog` (ADR-0009), `FileStore` réel, `SaveStore` (ADR-0006), `ProfileStore` et les réglages (profil). Construit au démarrage dans cet ordre : catalogue (échec : écran d'erreur de données, rien d'autre ne démarre) → `FileStore` → `SaveStore` (qui reçoit le catalogue pour l'étape 5 du chargement, ADR-0006 §3) → profil → réglages.
- `GameSession` (`RefCounted`, durée d'une partie) : l'état (`GameState` et son `ViewCache`, ADR-0007), la `RuleTable`, `CommandGate`, `UndoSlot`, `CommandLog`, `CommandPipeline`, `SaveCoordinator` (le `PostCommitPort` réel), le `ProfilePort` réel, le système des tours (3) et l'`AiPlanner` avec ses `AiParams`. Aucune de ces classes n'est un `Node`.

**3. `SessionFactory`, le seul constructeur de `GameSession`.** `SessionFactory.build(app: AppContext, state: GameState, vision: VisionContext, ports: SessionPorts) -> GameSession` assemble dans l'ordre : `RuleTable` (instance immuable construite avec le catalogue et le `VisionContext` **reçu**, ADR-0004 et 0007 ; la fabrique n'appelle jamais `rebuild`) → `CommandGate`, `UndoSlot`, `CommandLog` (avec `content_hash`, ADR-0009) → `SaveCoordinator` et `ProfilePort` → `CommandPipeline(state, rule_table, gate, undo, log, post_commit, profile_port, ports.event_sink)` → système des tours. `SessionPorts` ne contient que ce que la Presentation fournit **avant** la session : `event_sink` (la `EventQueue`) et `pacing_gate`. Une **nouvelle partie** et un **chargement** passent par la même fabrique : seuls l'état et son `VisionContext` changent (`GameStateFactory.new_game(app, options)` ou `SaveStore.load_match()`, qui rendent tous deux un état au cache reconstruit et son contexte, ADR-0007 §2), puis `pipeline.on_state_loaded()`.

**4. `MatchScreen`, l'arbre de présentation d'une partie, construit en deux phases.** `src/app/match_screen.tscn` porte, pour chaque partie : `PresentationClock` (−20, implémente `ClockSource`), `TileTimeSource` (−10), `PresentationSequencer` (0) et ses gestionnaires (tuiles, HUD, caméra), `World` (`Node2D`, reçoit le transform de la caméra, ADR-0010) **dont `TileRenderer` (10), les marqueurs et les surcouches sont des enfants**, `AiRunner` (20), `InputSurface` (`Control`, ADR-0010) et `HudLayer` (`CanvasLayer`). `EventQueue` (`RefCounted`, **Core**, ADR-0002) est créée par `Bootstrap`. Ordre : (1) `Bootstrap` instancie `MatchScreen` **sans liaisons** et lui prend ses adaptateurs (`pacing_gate`, adaptateur sur le séquenceur) ; (2) `SessionFactory.build(app, state, ports)` ; (3) `match_screen.bind(session)` : donne `session.gate` au séquenceur (qui pose et lève ses verrous du joueur **directement** sur le `CommandGate`, ADR-0002 §8, sans `lock_port`), `session.pipeline` à l'`InputSurface` et à l'`AiRunner`, et un `AiRunnerPort` (`resume`, `cancel`, `is_running`) au système des tours.

**5. Branchement des événements.** Le Core appelle par **appels directs et `Callable` injectés** (rappels `on_turn_finished`, `PacingGate`, `EventSink.push`). Les **signaux** ne servent qu'à l'intérieur de la Presentation (interface). Le séquenceur enregistre ses gestionnaires (`TileRendererHandler`, HUD, audio) à la construction de `MatchScreen`.

**6. Chargement, reprise, fin.**
- **Chargement** : `Bootstrap.resume_match()` → `SaveStore.load_match()` (ADR-0006 : `from_bytes`, `VisionContext.for_map`, `rebuild` et validation à l'étape 5, repli sur `.bak` si la vue est incohérente) → `MatchScreen` sans liaisons → `SessionFactory.build(app, state, vision, ports)` → `match_screen.bind(session)` → `pipeline.on_state_loaded()` → RESYNCHRONISER du séquenceur. Si la phase stockée est EXÉCUTION_ENNEMIE, le système des tours appelle `AiRunnerPort.resume(state, pipeline, pacing)` (ADR-0005 §5, interface ajoutée) **après** `on_state_loaded()`.
- **Fin ou abandon** : dans cet ordre, (1) `ai_runner.cancel()` : lève un drapeau d'annulation **coopératif** que la tâche de planification teste, puis `WorkerThreadPool.wait_for_task_completion(id)` (la tâche ne fait jamais de `call_deferred` bloquant ni n'attend le fil principal : interblocage) ; (2) `set_process(false)` sur les nœuds de `MatchScreen` et le `CommandGate` lève les verrous ; (3) `session.shutdown()`, qui **rompt tous les cycles** (champs de rappel et `Callable` mis à `null` ou `Callable()`) ; (4) `MatchScreen.queue_free()` ; (5) `Bootstrap` ne met la session à `null` qu'après le signal `tree_exited`. Vérifié : `queue_free()` ne détruit qu'en fin d'image, un nœud de priorité 20 exécute encore son `_process` dans l'image où il est en file ; chaque nœud teste donc `session != null` et son drapeau d'arrêt. Aucune tâche, aucun nœud ni objet de session ne survit.
- **Retour au menu / nouvelle partie** : même séquence, puis nouvelle fabrique.

**7. Dossiers et sens des dépendances.** `src/core/<système>/` (règles, état, vision, pipeline, IA dont `AiRunner`, seul `Node` du Core, sans `get_tree()` ni `get_node()`, sauvegarde), `src/presentation/` (séquenceur, rendu, HUD, entrées, audio), `src/app/` (Bootstrap, fabriques, écrans). Dépendances permises : `app` → `core`, `presentation` ; `presentation` → `core` ; **jamais** `core` → `presentation` ni `core` → `app`. Un contrôle CI (`tools/ci/check-layer-deps`) interdit, dans `src/core/**`, tout `preload`/`load`/nom de classe provenant de `src/presentation/**` ou `src/app/**` ; les motifs interdits `autoload_or_service_locator` et `core_references_presentation` sont enregistrés.

**8. Fabrique de test hors de `src/`.** `TestSessionFactory` (dans `tests/fixtures/`, ADR-0011) appelle la même `SessionFactory.build` avec des ports factices et des doublures (`DataSource` mémoire, `FileStore` à injection de pannes, `RecordingSink`, `PacingGate` toujours prêt, `ProfilePort` nul ou enregistreur). `src/` ne dépend jamais de `tests/`. Aucun test ne construit un `Bootstrap` ni une scène pour exercer le Core.

### Architecture Diagram

```
 main.tscn ── Bootstrap (Node)  ← seul à connaître Core et Presentation
   │ 1. DataCatalog.load_all ──(échec)──► écran d'erreur de données
   │ 2. FileStore ► SaveStore ► ProfileStore ► Réglages        ═══ AppContext (processus) ═══
   │
   ├─ Menus (18)  ──► « Nouvelle partie » / « Continuer »
   │        │ état + VisionContext : GameStateFactory.new_game | SaveStore.load_match (from_bytes, for_map, rebuild)
   │        ▼
   │   EventQueue (Core, créée par Bootstrap) + MatchScreen sans liaisons ──► SessionPorts{event_sink, pacing_gate}
   │        ▼
   │   SessionFactory.build(app, state, vision, ports)  ═══ GameSession (partie, RefCounted) ═══
   │        RuleTable ► Gate/Undo/Log ► SaveCoordinator + ProfilePort ► CommandPipeline ► TurnSystem + AiPlanner
   │        ▼
   └─ MatchScreen (Node, une par partie)
         ├─ PresentationClock −20 ─ TileTimeSource −10 ─ PresentationSequencer 0 ─ TileRenderer 10 ─ AiRunner 20
         ├─ World (Node2D, transform de la caméra) ⊃ TileRenderer, marqueurs, surcouches   ├─ InputSurface (ADR-0010)   └─ HudLayer (CanvasLayer)
         match_screen.bind(session) : gate ► séquenceur ; pipeline ► InputSurface, AiRunner ; AiRunnerPort ► système des tours
         fin : AiRunner.cancel() ► process off ► shutdown() ► queue_free() ► tree_exited ► Bootstrap.session = null
```

### Key Interfaces

```gdscript
class_name AppContext extends RefCounted
var catalog: DataCatalog
var file_store: FileStore
var save_store: SaveStore
var profile_store: ProfileStore
var settings: Settings

class_name SessionPorts extends RefCounted      # fournis par la Presentation (ou des doublures)
var event_sink: EventSink
var pacing_gate: PacingGate                      # adaptateur sur le séquenceur, pris à MatchScreen avant la session

class_name GameSession extends RefCounted
var state: GameState
var pipeline: CommandPipeline
var turns: TurnSystem
var planner: AiPlanner
func shutdown() -> void                          # idempotent ; sans nœud, sans tâche vivante

class_name SessionFactory extends RefCounted     # src/app/
static func build(app: AppContext, state: GameState, vision: VisionContext, ports: SessionPorts) -> GameSession
```

### Implementation Guidelines
- Aucun autoload ni service global **ne doit** exister ; une dépendance **doit** arriver par paramètre.
- Seuls les fichiers de `src/app/` **peuvent** instancier des classes concrètes du Core et de la Presentation ; la Presentation peut nommer le Core ; le Core **ne doit jamais** nommer `app` ni `presentation`.
- Une partie **doit** être libérée entièrement à sa fin (tâche de l'IA terminée, verrous levés, nœuds libérés) ; un test de fuite (aucun orphelin) l'exige.
- Le Core **ne doit jamais** appeler `get_tree()`, `get_node()` ni un signal de la Presentation.
- Nouvelle partie et chargement **doivent** passer par la même `SessionFactory`.
- Les `process_priority` **doivent** suivre la liste d'ADR-0002 ; toute nouvelle valeur s'y ajoute.

## Alternatives Considered

### Alternative 1: Autoloads (`Game`, `Events`, `Save`)
- **Description**: services globaux de Godot accessibles de partout.
- **Pros**: idiomatique, rapide à écrire.
- **Cons**: singletons de fait ; états partagés entre tests ; dépendances cachées ; ordre d'initialisation implicite.
- **Estimated Effort**: moindre.
- **Rejection Reason**: contredit ADR-0002 et rend les doublures impossibles.

### Alternative 2: Chaque scène cherche ses services (`get_node`, groupes)
- **Description**: localisation dynamique dans l'arbre.
- **Pros**: pas de fabrique.
- **Cons**: couplage à la structure de la scène ; échecs à l'exécution ; Core dépendant de l'arbre.
- **Estimated Effort**: moindre.
- **Rejection Reason**: viole le sens de dépendance Core → Presentation interdit.

### Alternative 3: Un seul objet « Game » qui contient tout
- **Description**: dieu-objet qui détient pipeline, rendu, IA, sauvegarde.
- **Pros**: un point d'entrée.
- **Cons**: mélange Core et Presentation ; impossible à tester sans scène.
- **Estimated Effort**: similaire.
- **Rejection Reason**: pas de séparation par portée ni par couche.

## Consequences

### Positive
- Un graphe lisible, construit à un endroit ; tests et jeu partagent la fabrique.
- La reprise, le chargement et la nouvelle partie ne divergent pas.
- Le sens de dépendance est vérifiable par grep.

### Negative
- Plus de code d'assemblage (fabrique, `SessionPorts`) qu'avec des autoloads.
- Toute nouvelle dépendance exige de toucher la fabrique.

### Neutral
- Les scènes ne contiennent pas de logique de jeu ; elles ne servent qu'à l'arbre de présentation.

## Risks
- **Fuite à la fin d'une partie** (tâche de l'IA, nœuds, cycles `RefCounted` par `Callable` retenus) : *Atténuation* : `shutdown()` idempotent qui rompt les cycles, test d'orphelins et de compte d'objets, `cancel()` coopératif qui attend la tâche.
- **Ordre de construction fragile** : *Atténuation* : un seul endroit, un test de construction par la fabrique de test.
- **Contrôle de couches contourné par une chaîne** (`load("res://…")`) : *Atténuation* : le contrôle CI inspecte aussi les chemins.

## GDD Requirements Addressed

| GDD System | Requirement | How This ADR Addresses It |
|------------|-------------|--------------------------|
| sauvegarde-automatique.md (16) | Règle 14 : ordre au lancement ; règle 12 : une seule partie | `AppContext` dans l'ordre profil → partie ; une `GameSession` à la fois |
| tours-conditions-victoire.md (3) | Règle 3 : reprise de la phase ennemie après chargement | Section 6, `ai_runner.resume` après `on_state_loaded` |
| commandes-evenements.md (23) | Règles 10 à 12 : file, verrous, aucun appel de la Presentation par le Core | `SessionPorts`, `CommandGate` donné au séquenceur par `bind`, direction Core → Presentation interdite |
| hud-systeme.md (17) | Règle 2 : le HUD lit l'état par `StateView` et les événements | `HudLayer` construit par `MatchScreen`, session injectée |
| modele-etat-partie.md (1) | Règle 4 : état indépendant de la SceneTree | `GameSession` sans `Node` |

## Performance Implications
- **CPU**: construction d'une partie à mesurer (vérification 3) ; hors boucle de jeu.
- **Memory**: un `GameSession` et un arbre `MatchScreen` à la fois.
- **Load Time**: catalogue puis profil au démarrage ; partie à la demande.
- **Network**: sans objet.

## Migration Plan
Aucun code existant. À créer : `Bootstrap`, `AppContext`, `GameSession`, `SessionFactory`, `MatchScreen` (avec `bind`), `AiRunnerPort`. **Fait** (2026-11-01) : `tools/ci/check-layer-deps.sh`, avec son auto-test `tests/unit/ci/test_check_layer_deps.sh`, exécuté par le workflow `tests` (il contrôle aussi l'absence de section `[autoload]`). Registre : interfaces `GameSession`, `SessionPorts`, `AppContext` ; motifs interdits `autoload_or_service_locator`, `core_references_presentation`.

À amender : ADR-0005 (`resume`, `cancel` ajoutés, fait), ADR-0002 (`CameraHandler`, `ClockSource`, fait), ADR-0011 (`TestSessionFactory`).

**Rollback plan**: si la fabrique devient trop lourde, regrouper `GameSession` et `SessionPorts` ; le principe (une racine, pas d'autoload) ne se retire pas sans réviser ADR-0002.

## Validation Criteria
- Aucun réglage `autoload/*` dans `project.godot` (contrôle CI).
- `check-layer-deps` : 0 référence de `src/core/**` vers `src/presentation/**` ou `src/app/**`.
- Une partie nouvelle, une partie chargée et une partie reprise en phase ennemie passent toutes par `SessionFactory.build`.
- Après `shutdown` et `queue_free` (suivi d'un `await get_tree().process_frame`), 0 orphelin de `Node`, 0 tâche de planification vivante et le compte d'objets (`Performance.get_monitor(Performance.OBJECT_COUNT)`) revenu à sa valeur d'avant la partie : les cycles `RefCounted` (session, pipeline, file, coordinateur, rappels) ne sont **pas** vus par le détecteur d'orphelins de `Node` et ne sont jamais libérés par le moteur.

## Related
- **Ordre d'acceptation faisable** : ADR-0009 et ADR-0011 (sans dépendance entrante), puis ADR-0003, 0002, 0004, puis 0007, puis 0005 et 0006, puis celui-ci, puis ADR-0010.
- ADR-0002, ADR-0003, ADR-0004, ADR-0005, ADR-0006, ADR-0007, ADR-0009, ADR-0010, ADR-0011.
- `design/gdd/sauvegarde-automatique.md`, `design/gdd/tours-conditions-victoire.md`, `design/gdd/commandes-evenements.md`.

## Mise en place d'une partie (2026-11-02)

`GameStateFactory.new_game(catalogue, carte, graine, ia_passive, chronique, id_partie, époque)` (`src/core/setup/`) construit l'état CRÉÉE du tour 0 : terrain copié, nœuds de départ (un par faction, niveau 1) et nœuds neutres, unités de départ avec leurs postes de Gardiens (rôle initial déduit des capacités du type), dormants, ruines, instantané de la chronique (trié), énergie de départ, drapeau d'IA passive, territoire initial et vue initiale. Les tirages passent tous par la fonction de hasard de l'état, dans un ordre fixe : types des dormants (un dormant « same_as » répète son modèle, GDD 7 règle 9), puis ruines zone après zone sans remise (GDD 2 règle 12) ; la même carte, la même graine et les mêmes options donnent toujours le même état. Le compteur de tirages vaut le nombre de choix ouverts (5 sur la carte livrée).

`MapDefinition` (`src/core/setup/map_definition.gd`) lit et **valide** un fichier de carte (`assets/data/maps/*.json`) : schéma strict, taille, glyphes, départs et nœuds en plaine à 4 tuiles au moins, dormants (plaine ou forêt, à 3 tuiles au moins d'un départ, jamais voisins d'un nœud, types de la meute avec un prix de réveil, `same_as`), ruines (candidats hors des abords des départs, tirage possible), unités (type connu, bon camp, pas sur l'eau ni la montagne, un capturer au départ du joueur), symétrie déclarée vérifiée tuile par tuile, couverture des dormants du côté de l'IA par un Gardien armé (GDD 9 règle 11). Une carte invalide est refusée. Carte livrée : `maps/plaine.json` (12 × 12, rotation de 180°, 4 nœuds neutres, 6 dormants dont 4 tirés par paires, 3 zones de 3 ruines).

**Écarts à confirmer** : (1) le format de carte gagne `units` (unités de départ des deux camps, question ouverte du GDD 6) et `same_as` (tirage reproduit par la symétrie) ; (2) les unités de départ de la carte livrée (Ouvrier, Assaut, Éclaireur contre Bastion, deux Chasseurs, Sentinelle) sont provisoires ; (3) le GDD parle de « 4 nœuds neutres (une paire proche de chaque départ, une paire au centre) » : la carte en place 4 en tout, deux par moitié ; (4) la contrainte 13ter (une ruine hors du plus court chemin) et les formules d'équité du GDD 2 ne sont pas contrôlées ; (5) le chargement d'une carte par nom, `SessionFactory` et `MatchScreen` (couche `src/app/`) restent à écrire : la fabrique ne sait pas lire un fichier.

Test de bout en bout : `tests/integration/ai/full_match_test.gd` joue des matchs entiers depuis la mise en place (joueur passif, IA par son runner) jusqu'à la fin, sans refus, avec un état valide et un journal qui se rejoue à l'identique.

## SessionFactory et MatchScreen (2026-11-02)

Écrits : `AppContext` (`src/app/`, catalogue → `FileStore` → `SaveStore` → port de profil ; une erreur de données laisse `catalog == null` et la liste des erreurs), `SessionFactory` (`src/app/`, `build` / `new_game` / `resume`, la seule voie de construction d'une `GameSession`), `GameSession` et `SessionPorts` (`src/core/session/`), `TurnSystem` (`src/core/session/`, le pilote des commandes de tour : phase stockée → COMMENCER_LE_TOUR(joueur), attente du joueur, COMMENCER_LE_TOUR(IA) puis runner, reprise de la phase ennemie ; `end_player_turn()` ; `shutdown()` qui rompt les cycles), `AiRunnerPort` et `NodeAiRunnerPort` (le runner est un `Node`, le système des tours un objet simple), `ImmediatePacingGate` (porte toujours prête, jusqu'au séquenceur), `EventQueue` (le `EventSink` de la partie), et `MatchScreen` (`match_screen.gd` et `.tscn` : `World`, `AiRunner` à la priorité 20, `InputSurface`, `HudLayer`).

Sauvegarde, dans la mesure où `SessionFactory` en dépend (ADR-0006) : `SaveEnvelope` (marque, version, longueur, schéma de contenu, révision, charge utile, SHA-256 ; contrôles dans l'ordre marque → longueur → empreinte), `SaveStore` (`save_match` : `.tmp`, relecture vérifiée, courant → `.bak`, suppression de la cible avant renommage, fichier douteux mis de côté en `.bad1` / `.bad2` ; `load_match` : `.tmp` supprimés et jamais promus, courant puis `.bak`, courant abîmé mis de côté, schéma plus récent refusé sans repli, vue reconstruite et invariants contrôlés avant de rendre `LoadResult`), `SaveCoordinator` (le `PostCommitPort` réel : une écriture synchrone après chaque commande, l'erreur est gardée et retentée par `retry`).

**Ordre en deux phases de `MatchScreen`** (ADR-0008 §4) : (1) l'écran, instancié sans liaison, prête `ports(event_sink)` et `runner_port()` ; (2) `SessionFactory` construit la session avec ces ports ; (3) `bind(session)` démarre le système des tours (nouvelle partie : premier tour du joueur ; partie chargée : phase stockée, reprise de la phase ennemie après `on_state_loaded()`). `shutdown()` suit la séquence du §6 : annulation du runner, arrêt des nœuds et levée des verrous du joueur, rupture des cycles de la session, `queue_free()` ; il est idempotent.

**Écarts à confirmer** : (1) ni `Bootstrap` ni les menus n'existent : rien ne construit encore un `AppContext` réel (fichiers `user://`, `ResDataSource`) ; (2) le profil est un `ProfilePort` fourni à `AppContext` : `ProfileStore` (système 22) reste à écrire, de même que la réconciliation du journal des ruines au chargement (ADR-0006 §9) et le garde-fou d'époque ; (3) pas de migration : un schéma plus ancien rend `OLDER` (mis de côté avant le test fermé) ; (4) `PresentationClock`, le séquenceur, `TileRenderer`, les gestionnaires et le HUD ne sont pas dans la scène (l'écran n'a que ses conteneurs) ; (5) la création d'une nouvelle partie supprime l'ancienne sauvegarde sans demander (le menu doit confirmer) ; (6) `load_match` ne vérifie pas l'époque de réinitialisation du profil.

## Bootstrap et menus (2026-11-02)

`Bootstrap` (`src/app/bootstrap.gd`, scène principale du projet : `run/main_scene` → `bootstrap.tscn`, **pas d'autoload**) construit l'`AppContext` dans l'ordre (catalogue de `ResDataSource`, `RealFileStore`, `ProfileStore`), puis montre l'écran d'erreur de données ou le menu principal. Il enchaîne les écrans : nouvelle partie (carte `maps/plaine.json` lue par le `DataSource`, graine aléatoire sauf `forced_seed`, chronique et époque du profil, identifiant de partie pris au profil), continuer (`SessionFactory.resume`, retour au menu s'il n'y a rien à reprendre), pause (bouton Retour d'Android ou appel), abandon (commande ABANDONNER), écran de fin (déclenché quand la session est terminée ; la sauvegarde n'est effacée qu'à la sortie de cet écran, ADR-0006 §10), retour au menu. `NOTIFICATION_APPLICATION_PAUSED` retente une sauvegarde en échec. Les dépendances sont injectables avant `_ready` pour les tests.

Écrans (`src/presentation/menus/`, construits en code, signaux vers l'app) : `MainMenu` (Continuer seulement si une sauvegarde existe ; Nouvelle partie demande confirmation quand elle en efface une), `PauseMenu` (reprendre, menu en gardant la partie, abandonner), `EndScreen` (issue et scores décisifs), `DataErrorScreen` (liste bornée des erreurs de données).

Nouveaux éléments de socle : `RealFileStore` (`src/app/`, seul appel de `FileAccess` / `DirAccess` pour les sauvegardes), `ProfileStore` (`src/core/profile/`, le `ProfilePort` réel d'une première version du GDD 22 : chronique idempotente par id, meilleur score par (faction, difficulté) avec mémoire des 8 derniers identifiants de partie, compteur de parties, époque, remise à zéro ; écriture immédiate avec `.tmp` vérifié et `.bak` ; profil d'une version plus récente en lecture seule ; repli sur la copie de secours puis profil neuf).

**Écarts à confirmer** : (1) le GDD 18 n'existe pas (« inferred ») : textes, enchaînements et boutons des menus sont provisoires, sans réglages, chronique, scores détaillés, ni accueil ; (2) le profil réel est minimal : pas de réglages, de factions débloquées ni de plafond de taille (formule 6 du GDD 22), `reset_progress` n'a pas de menu, et la réconciliation du journal des ruines au chargement reste à faire ; (3) l'écran de partie reste un conteneur (pas de rendu, de HUD ni d'entrées) : le menu ne peut pas encore *jouer* au-delà de la fin de tour ; (4) l'identifiant de partie est pris au profil à chaque nouvelle partie, y compris si elle est abandonnée avant son premier tour.

## Rendu des tuiles et HUD (2026-11-02)

**Rendu** (`src/presentation/tiles/`) : `TileSnapshot.take(state, catalogue)` est la **seule** lecture du rendu : la vue du joueur (`FactionView`) et le niveau de brouillard de chaque tuile (`VisionService.fog_level` : jamais vue, explorée, visible). Une tuile jamais vue ne porte rien (terrain neutre, aucun propriétaire), une tuile explorée garde la mémoire du terrain et du dernier propriétaire vu sans aucune unité, une tuile visible tout ce qui est dans la vue ; les trois ruines tirées restent visibles sous le brouillard (GDD 5, règle 6). Le rendu ne voit donc jamais l'état réel : une propriété sur 120 états aléatoires vérifie qu'aucune unité adverse hors de vue, aucun nœud jamais découvert ni propriétaire d'une tuile jamais vue n'entrent dans l'instantané. `TileRenderer` (`Node2D`, priorité 10) dessine l'instantané : terrain (palette du bible d'art, section 4), brouillard (aplat #1E2329), territoire (teinte + motif : chevron pour la meute, barre pour l'ennemi), nœuds (losange, un point par niveau), ruines, unités (un polygone par type, contour sombre pour la meute, violet pour les Gardiens, barre pour un dormant, jauge de PV sous les PV max), sélection et portée de déplacement, marqueurs de menace (crochets d'angle). `TileLayout` (géométrie pure : `fitting`, `rect_of`, `tile_at`) est partagée avec la surface d'entrée ; `TilePalette` porte les couleurs.

**Marqueurs d'intention** : `IntentionMarkers.visible_to_player(état)` (`src/core/ai/`) est le seul lecteur des intentions de l'IA pour le joueur : une ligne par intention annoncée dont la tuile cible est visible (un nœud ciblé l'est toujours), la tuile de l'auteur seulement si elle est visible (GDD 9, règle 18). Les marqueurs sont recalculés depuis l'état, donc ils survivent à un chargement sans rejouer d'événements.

**HUD** (`src/presentation/hud/`) : `HudModel.build(état, catalogue, verrouillé, sélection, journal)` calcule tout ce que le HUD affiche (tour, énergie, ruines lues, score décisif « Victoire : a contre b », bouton de fin de tour actif seulement en phase du joueur sans verrou, puce de menace, puces de perte tirées des rappels, puce « Ruine repérée » sans nombre, panneau d'unité avec caractéristiques effectives, journal du tour ennemi borné à 12 lignes) ; `Hud` (`Control`) recopie le modèle dans ses widgets, montre au plus deux puces plus un compteur, et émet `end_turn_pressed` et `pause_pressed` ; aucune règle de jeu n'y vit. `InputSurface` convertit un appui (tactile ou souris) en position ; `MatchScreen.on_tap_tile` sélectionne une unité du joueur (portée de déplacement par `check_move_range`), déplace l'unité sélectionnée sur une tuile atteignable, sinon désélectionne. `MatchScreen` vide la `EventQueue` à chaque image (priorité du séquenceur, à venir), tient le journal et redessine.

**Écarts à confirmer** : (1) pas de séquenceur : aucune animation, onde de recoloration, chiffre de dégâts ni cadence (le Core avance seul, un redessin par lot) ; (2) pas de caméra (défilement, zoom, boutons +/−/recentrer) : la carte est ajustée à la zone laissée par le HUD, en portrait seulement (pas de rail paysage, pas d'insets système) ; (3) pas de ciblage ni d'attaque, de capture, de réveil, de montée de nœud ni de recherche depuis l'écran : seuls déplacer et finir le tour y sont ; (4) pas de panneau de fragment à la lecture d'une ruine ni d'aperçu de combat ; (5) textes en français provisoires, sans mode daltonien ni mise à l'échelle du texte (HUD section 10) ; (6) les polygones par type sont des repères de rendu provisoires, en attendant les sprites.

**Preuve visuelle** : `production/qa/evidence/tiles-hud-2026-11-02.png`, capture du premier tour (Xvfb, 390 × 844, rendu OpenGL, une unité sélectionnée) : brouillard en aplat, territoire de la meute avec son motif, nœuds, ruines visibles sous le brouillard, barre du haut, score décisif, puce « Ruine repérée », panneau d'unité et bouton « Fin du tour » (la première capture avait révélé que le panneau du bas sortait de l'écran : corrigé par `grow_vertical`).

## Réglages et textes des fragments (2026-11-02)

**Réglages** (GDD 22, règle 14 ; hud.md 10.5) : `GameSettings` (`src/core/profile/`) est une table clé → entier avec défaut et bornes : taille du texte (100, 125 ou 150 %, borne 100 à 150), palette daltonienne, animations réduites, portée de déplacement (défaut : affichée), vitesse du tour ennemi (0 normale, 1 rapide, 2 instantanée), panneau à gauche. `ProfileStore` les range dans la même enveloppe que le reste du profil, sous la clé `settings`, **sans changer `SCHEMA_VERSION`** (ajout compatible : un profil sans cette clé charge avec les défauts, clé par clé ; une clé inconnue ou invalide est écartée). `set_setting(clé, valeur)` valide, écrit aussitôt et revient en arrière si l'écriture échoue ; un profil en lecture seule refuse. `reset_progress` garde les réglages (règle 11).

`SettingsScreen` (`src/presentation/menus/`) n'émet que `changed(clé, valeur)` et `back_requested` ; il est ouvert par `Bootstrap.show_settings` au-dessus du menu principal ou de la pause (bouton « Réglages » des deux). `Bootstrap.change_setting` enregistre puis applique : échelle de l'interface (`UiScale.factor(dpi, texte/100)`, relue au lancement avant le premier écran et à chaque redimensionnement ; la densité compte pour 160 dpi quand elle est inconnue), puis `MatchScreen.apply_settings` (animations réduites → `PresentationSequencer.reduced_motion`, vitesse → `PresentationClock.speed`, palette → `TileRenderer.colorblind`, portée → surbrillance non dessinée mais déplacements inchangés, panneau à gauche → `HudLayout.compute(..., mirrored)` qui échange le rail et le panneau en paysage). Un nouveau `MatchScreen` reçoit les réglages avant d'être lié. Le bouton de vitesse du HUD émet `speed_changed`, que `Bootstrap` enregistre : la vitesse choisie est retenue.

Palette daltonienne : joueur #3A8EE6, ennemi #F0DC6E, non revendiqué #5F6266 (bible d'art, section 4) ; menace, ruines, formes et motifs inchangés.

**Textes des fragments** (GDD 13, règles 27 à 30) : `assets/data/fragments.json` porte maintenant, par fragment, `title` (28 caractères au plus), `text` (140 au plus ; 90 à 120 visés, vérifié sur les livrés), `source` (24 au plus), `tones` (1 ou 2, distincts, parmi obéissance, usure, doute, absence, question) et `link` (aucun, verbe, question). `FragmentPool.build` refuse : un champ vide ou trop long, un chiffre dans l'un des trois textes (règle 29), une source qui nomme une faction ou une ruine (règle 27), un lien « verbe » ou « question » dont le texte n'emploie pas « allum… », un lien « question » sans point d'interrogation, des actes qui reculent le long des ids, et, par faction, les seuils de la règle 28 : le dernier fragment est un lien « question », la part de liens dans l'acte 3 (`act3_link_percent`, 50) et le nombre de fragments « verbe » dans l'acte 1 (`act1_verb_min`, 1) sont des **données** du pool. `FragmentPanel.open` montre titre, source et texte (le texte défile dans le panneau plutôt que d'être coupé, hud.md 10.2) ; sans texte il retombe sur « Fragment N ». `HudPresenter` reçoit le pool du catalogue.

**Écarts à confirmer** : (1) les cinq textes de la meute sont une première écriture à relire par le narrative-director (ton, longueur, enchaînement VERBE → QUESTION) ; les tons sont validés mais ne servent à rien (règle 30) ; (2) l'échelle du texte agrandit toute l'interface par `content_scale_factor`, pas seulement le texte : la matrice 10.2 (top bar sur deux lignes à 150 %, etc.) reste à vérifier sur appareil ; (3) « Animations réduites » vaut « non » par défaut et ne suit pas le réglage système (Godot n'expose pas d'indicateur portable) ; (4) volumes et difficulté préférée du GDD 22 ne sont pas dans la table : pas de son ni de choix de difficulté à régler ; (5) « Fin du tour » ne passe pas en bas à gauche en mode inversé : il reste dans le panneau de contexte, qui change de côté ; (6) la fusion des réglages entre appareils reste ouverte (GDD 22) ; (7) la chronique n'a pas d'écran : les textes ne se lisent qu'à la lecture d'une ruine ; (8) le test d'échelle ne distingue pas 100 % de 150 % à 96 dpi (borné à 1) : la densité est injectable (`Bootstrap.screen_dpi`).

## Export Android (2026-11-02)

**Préréglage** (`export_presets.cfg`) : APK arm64-v8a sans Gradle (modèle préconstruit), `package/unique_name` `org.steeldev.dogsofgods`, version 1 / `0.1.0`, signature activée, bord à bord (`screen/edge_to_edge`, nécessaire aux zones sûres de l'ADR-0010), mode immersif. Filtres : les JSON de `assets/data/` sont inclus explicitement (le filtre d'export par défaut ne les emporte pas) ; `addons/gdUnit4`, `tests`, `docs`, `design`, `tools`, `reports` sont exclus. L'orientation `screen/orientation` du préréglage n'existe pas dans Godot 4 : elle est remplacée par `display/window/handheld/orientation=6` (capteur : portrait et paysage, tous deux conçus) dans `project.godot`. `config/quit_on_go_back=false` garde le bouton Retour pour le menu pause.

**Vérifié ici** : `tools/ci/check-export-pack.sh` exporte le pack du préréglage, vérifie que les 13 fichiers de données (cartes comprises) y sont et qu'aucun fichier de test, d'add-on ou de conception n'y est, puis **lance le jeu depuis le pack seul** (hors du dossier du projet) : il atteint le menu sans erreur (`Bootstrap` imprime « data error: … » sur la sortie d'erreur, aussi lisible dans logcat). Deux mutations du préréglage (retirer un JSON, ne plus exclure `tests`) sont détectées. Le script tourne dans `tests.yml`.

**Non vérifié** : l'APK lui-même. L'environnement de cette session n'atteint pas `dl.google.com` (SDK Android refusé par la politique réseau) ; le SDK, les build-tools et le JDK de signature manquent donc. `.github/workflows/android-export.yml` (déclenchement manuel ou tag `v*`) fait le travail sur un exécuteur GitHub : Godot et ses modèles d'export fixés par SHA-512, JDK 17, composants du SDK (`platform-tools`, `build-tools;35.0.1`, `platforms;android-35`), clé de débogage générée, réglages de l'éditeur écrits, contrôle du pack, `--export-debug`, `apksigner verify`, dépôt de l'artefact. Une version de publication est exportée seulement si les secrets `ANDROID_KEYSTORE_BASE64`, `ANDROID_KEYSTORE_USER` et `ANDROID_KEYSTORE_PASSWORD` existent.

**Écarts à confirmer** : (1) le premier passage du workflow peut demander d'ajuster les versions du SDK ou des outils exigées par Godot 4.7.2 (non lues dans la documentation du moteur depuis ici) ; (2) pas d'icône (icône par défaut du moteur) ni d'écran de démarrage ; (3) pas de paquet AAB pour le Play Store (il demande `use_gradle_build`) ; (4) la sauvegarde automatique d'Android (profil inclus, partie exclue, GDD 16 règle 18) demande un manifeste personnalisé, donc Gradle : non fait, voir ADR-0006 ; (5) la clé de publication est à créer et à garder par le propriétaire du projet ; (6) mesures sur appareil toujours à faire (écriture, renommage, tactile, zones sûres).

## Garde d'époque, conseils, chronique et équilibrage (2026-11-02)

**Garde d'époque** (GDD 16 AC-18) : `SaveStore.load_match(min_epoch)` écarte (renomme en `match.bad1`) une partie dont l'époque de réinitialisation est inférieure à celle du profil ; une époque égale ou supérieure se charge. La copie de secours est essayée ensuite. `SessionFactory.resume` passe `ProfilePort.current_epoch()` ; le menu dit « Cette partie datait d'avant la remise à zéro de la progression : elle a été écartée. » Le code de retour est `LoadResult.STALE`.

**Conseils des premiers tours** : `HudHint` (pur) donne une ligne aux tours 1 et 2 du joueur, avant puis après la sélection d'une unité, jamais pendant le ciblage ni le tour ennemi ; réglage `hints` (défaut : oui) dans la table des réglages, case dans l'écran des réglages. Ce n'est pas un didacticiel : la ligne dit quoi toucher ensuite.

**Chronique** : `ChronicleScreen` (menu principal, bouton « Chronique ») liste les fragments de la meute dans l'ordre des ids, ceux trouvés avec titre, source et texte, les autres comme « Fragment non trouvé », sous une barre de N segments (● trouvé, ○ à trouver : le glyphe double la couleur). Un id inconnu du pool est ignoré, un id d'une autre faction n'est pas compté.

**Équilibrage** : `tests/balance/` (`ScriptedPlayer`, `run_matches.gd`, test d'intégration de la sûreté du harnais) ; mesure et lecture dans `production/qa/balance-2026-11-02.md`. Aucun poids n'a été changé : aucune cible de taux de victoire n'existe dans le GDD 9.

**Écarts à confirmer** : (1) la cible de taux de victoire et l'équilibre à régler sont à fixer par le game-designer ; (2) le joueur scripté est rudimentaire (pas de réveil, de recherche ni de coordination) ; (3) la chronique ne montre que la meute (le pool n'a qu'une faction) et n'offre ni filtre par ton ni indication des actes ; (4) les conseils sont fixes, en français, sans variante par situation (ruine, réveil, recherche) ; (5) l'écran de chronique est joignable depuis le menu seulement, pas depuis la fin de partie.

**Nom du jeu (2026-11-02)** : le jeu s'appelle *Dogs of Gods* partout dans le code et les données (nom du projet, libellé Android, titre du menu, noms des APK) et l'identifiant du paquet Android est `org.steeldev.dogsofgods` (le préréglage ci-dessus le citait sous l'ancien nom). Un identifiant de paquet ne change plus une fois l'application publiée : c'est donc fait avant tout test fermé. Le nom du dépôt GitHub (`dogsofwars`) n'est pas dans le code : il se renomme sur GitHub, et ses adresses redirigent.
