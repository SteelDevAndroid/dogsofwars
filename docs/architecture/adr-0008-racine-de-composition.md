# ADR-0008: Racine de composition — un seul Bootstrap, deux portées (application, partie), aucun autoload

## Status
Accepted

## Date
2026-10-31

## Last Verified
2026-10-31 — conception sur les ADR-0001 à 0007 et 0009 ; **vérifié en headless** Godot 4.7.2 : le projet n'a aucun réglage `autoload/*` (aucun singleton à retirer). Construction réelle des scènes et libération en fin de partie : non prototypées.

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
| **Ordering Note** | Dernier des ADR Core à accepter : il assemble les autres ; ADR-0002 à 0006 et 0009 sont encore Proposed, l'ordre d'acceptation faisable est donné dans la section Related |

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
- `AppContext` (`RefCounted`, durée du processus) : `DataCatalog` (ADR-0009), `FileStore` réel, `SaveStore` (ADR-0006), `ProfileStore` et les réglages (profil). Construit au démarrage dans cet ordre : catalogue (échec : écran d'erreur de données, rien d'autre ne démarre) → `FileStore` → `SaveStore` → profil → réglages.
- `GameSession` (`RefCounted`, durée d'une partie) : l'état (`GameState` et son `ViewCache`, ADR-0007), la `RuleTable`, `CommandGate`, `UndoSlot`, `CommandLog`, `CommandPipeline`, `SaveCoordinator` (le `PostCommitPort` réel), le `ProfilePort` réel, le système des tours (3) et l'`AiPlanner` avec ses `AiParams`. Aucune de ces classes n'est un `Node`.

**3. `SessionFactory`, le seul constructeur de `GameSession`.** `SessionFactory.build(app: AppContext, state: GameState, ports: SessionPorts) -> GameSession` assemble dans l'ordre : `RuleTable` (instance immuable construite avec le catalogue et le `VisionContext`, ADR-0004 et 0007) → `CommandGate`, `UndoSlot`, `CommandLog` (avec `content_hash`, ADR-0009) → `SaveCoordinator` et `ProfilePort` → `CommandPipeline(state, rule_table, gate, undo, log, post_commit, profile_port, ports.event_sink)` → système des tours. `SessionPorts` ne contient que ce que la Presentation fournit **avant** la session : `event_sink` (la `EventQueue`) et `pacing_gate`. Une **nouvelle partie** et un **chargement** passent par la même fabrique : seul l'état change (`GameStateFactory.new_game(app, options)` ou `SaveStore.load_match()`), puis `pipeline.on_state_loaded()`.

**4. `MatchScreen`, l'arbre de présentation d'une partie, construit en deux phases.** `src/app/match_screen.tscn` porte, pour chaque partie : `PresentationClock` (−20, implémente `ClockSource`), `TileTimeSource` (−10), `PresentationSequencer` (0) et ses gestionnaires (tuiles, HUD, caméra), `World` (`Node2D`, reçoit le transform de la caméra, ADR-0010) **dont `TileRenderer` (10), les marqueurs et les surcouches sont des enfants**, `AiRunner` (20), `InputSurface` (`Control`, ADR-0010) et `HudLayer` (`CanvasLayer`). `EventQueue` (`RefCounted`, **Core**, ADR-0002) est créée par `Bootstrap`. Ordre : (1) `Bootstrap` instancie `MatchScreen` **sans liaisons** et lui prend ses adaptateurs (`pacing_gate`, adaptateur sur le séquenceur) ; (2) `SessionFactory.build(app, state, ports)` ; (3) `match_screen.bind(session)` : donne `session.gate` au séquenceur (qui pose et lève ses verrous du joueur **directement** sur le `CommandGate`, ADR-0002 §8, sans `lock_port`), `session.pipeline` à l'`InputSurface` et à l'`AiRunner`, et un `AiRunnerPort` (`resume`, `cancel`, `is_running`) au système des tours.

**5. Branchement des événements.** Le Core appelle par **appels directs et `Callable` injectés** (rappels `on_turn_finished`, `PacingGate`, `EventSink.push`). Les **signaux** ne servent qu'à l'intérieur de la Presentation (interface). Le séquenceur enregistre ses gestionnaires (`TileRendererHandler`, HUD, audio) à la construction de `MatchScreen`.

**6. Chargement, reprise, fin.**
- **Chargement** : `Bootstrap.resume_match()` → `SaveStore.load_match()` (ADR-0006) → `from_bytes(bytes, schema)` puis `VisionService.rebuild(state, vision_context)` (ADR-0007) → `MatchScreen` sans liaisons → `SessionFactory.build` → `match_screen.bind(session)` → `pipeline.on_state_loaded()` → RESYNCHRONISER du séquenceur. Si la phase stockée est EXÉCUTION_ENNEMIE, le système des tours appelle `AiRunnerPort.resume(state, pipeline, pacing)` (ADR-0005 §5, interface ajoutée) **après** `on_state_loaded()`.
- **Fin ou abandon** : dans cet ordre, (1) `ai_runner.cancel()` : lève un drapeau d'annulation **coopératif** que la tâche de planification teste, puis `WorkerThreadPool.wait_for_task_completion(id)` (la tâche ne fait jamais de `call_deferred` bloquant ni n'attend le fil principal : interblocage) ; (2) `set_process(false)` sur les nœuds de `MatchScreen` et le `CommandGate` lève les verrous ; (3) `session.shutdown()`, qui **rompt tous les cycles** (champs de rappel et `Callable` mis à `null` ou `Callable()`) ; (4) `MatchScreen.queue_free()` ; (5) `Bootstrap` ne met la session à `null` qu'après le signal `tree_exited`. Vérifié : `queue_free()` ne détruit qu'en fin d'image, un nœud de priorité 20 exécute encore son `_process` dans l'image où il est en file ; chaque nœud teste donc `session != null` et son drapeau d'arrêt. Aucune tâche, aucun nœud ni objet de session ne survit.
- **Retour au menu / nouvelle partie** : même séquence, puis nouvelle fabrique.

**7. Dossiers et sens des dépendances.** `src/core/<système>/` (règles, état, vision, pipeline, IA, sauvegarde), `src/presentation/` (séquenceur, rendu, HUD, entrées, audio), `src/app/` (Bootstrap, fabriques, écrans). Dépendances permises : `app` → `core`, `presentation` ; `presentation` → `core` ; **jamais** `core` → `presentation` ni `core` → `app`. Un contrôle CI (`tools/ci/check-layer-deps`) interdit, dans `src/core/**`, tout `preload`/`load`/nom de classe provenant de `src/presentation/**` ou `src/app/**` ; les motifs interdits `autoload_or_service_locator` et `core_references_presentation` sont enregistrés.

**8. Fabrique de test hors de `src/`.** `TestSessionFactory` (dans `tests/fixtures/`, ADR-0011) appelle la même `SessionFactory.build` avec des ports factices et des doublures (`DataSource` mémoire, `FileStore` à injection de pannes, `RecordingSink`, `PacingGate` toujours prêt, `ProfilePort` nul ou enregistreur). `src/` ne dépend jamais de `tests/`. Aucun test ne construit un `Bootstrap` ni une scène pour exercer le Core.

### Architecture Diagram

```
 main.tscn ── Bootstrap (Node)  ← seul à connaître Core et Presentation
   │ 1. DataCatalog.load_all ──(échec)──► écran d'erreur de données
   │ 2. FileStore ► SaveStore ► ProfileStore ► Réglages        ═══ AppContext (processus) ═══
   │
   ├─ Menus (18)  ──► « Nouvelle partie » / « Continuer »
   │        │ état : GameStateFactory.new_game | SaveStore.load_match + from_bytes (rebuild ViewCache)
   │        ▼
   │   EventQueue (Core, créée par Bootstrap) + MatchScreen sans liaisons ──► SessionPorts{event_sink, pacing_gate}
   │        ▼
   │   SessionFactory.build(app, state, ports)  ═══ GameSession (partie, RefCounted) ═══
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
static func build(app: AppContext, state: GameState, ports: SessionPorts) -> GameSession
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
- Plus de code d'assemblage (fabrique, `SessionPorts`, `SessionOverrides`) qu'avec des autoloads.
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
Aucun code existant. À créer : `Bootstrap`, `AppContext`, `GameSession`, `SessionFactory`, `MatchScreen` (avec `bind`), `AiRunnerPort`, `tools/ci/check-layer-deps`. Registre : interfaces `GameSession`, `SessionPorts`, `AppContext` ; motifs interdits `autoload_or_service_locator`, `core_references_presentation`.

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
