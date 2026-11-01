# ADR-0002: Événements de présentation — file explicite, horloge de présentation et séquenceur en machine à états

## Status
Accepted

## Date
2026-10-30

## Last Verified
2026-10-30 — conception sur les GDD 23 et 17 ; **aucun prototype du séquenceur** ; tests headless de godot-specialist sur Godot 4.7.2.stable.official.ed1daf0bf (annulation d'`await`, pause, `process_priority`, réentrance de signaux). L'ordre de reprise des `await` entre coroutines reste NOT SOURCEABLE ; la décision l'évite.

## Decision Makers
Utilisateur (direction de projet), Claude (rédaction), godot-specialist et technical-director (validation avant écriture).

## Summary
Les commandes publient leurs événements en lots dans une file explicite, par un `EventSink` injecté ; un unique `PresentationSequencer`, **machine à états avancée dans `_process`** par une `PresentationClock` pausable, dépile un lot à la fois, appelle les gestionnaires de présentation (rendu des tuiles, HUD, audio) dans un ordre fixe et possède les durées, la fusion en animations réduites, la resynchronisation et le verrou des commandes du joueur. Il n'y a ni `await`, ni diffusion par signaux : les signaux de Godot n'interviennent pas dans la distribution.

## Engine Compatibility

| Field | Value |
|-------|-------|
| **Engine** | Godot 4.7.2 |
| **Domain** | Core |
| **Layer** | Core (`EventBatch`, `EventQueue`, `EventSink`, `CommandGate`) / Presentation (`PresentationSequencer`, `PresentationClock`, gestionnaires) |
| **Knowledge Risk** | HIGH (prudence : aucune API postérieure à la connaissance du modèle n'est utilisée) |
| **References Consulted** | `docs/engine-reference/godot/VERSION.md`, `docs/engine-reference/godot/current-best-practices.md`, `docs/engine-reference/godot/deprecated-apis.md`, `design/gdd/commandes-evenements.md` |
| **Post-Cutoff APIs Used** | Aucune. `Tween.tween_await()` (4.7) existe mais n'est pas utilisé. `process_priority`, `_process(delta)` et les classes `RefCounted` existent depuis 4.0 |
| **Verification Required** | (1) **Mesuré** : un signal émis depuis son gestionnaire s'exécute en récursion synchrone (profondeur 3 sans protection), d'où l'absence de distribution par signaux ; (2) **mesuré** : `process_priority` plus bas appelé en premier, à égalité l'ordre dans l'arbre ; (3) **mesuré** : `create_timer(t)` continue en pause (`process_always` vrai par défaut) ; il n'est pas utilisé ; (4) coût par image du séquenceur sur Android (budget proposé 0,3 ms) ; (5) aucune allocation par image du séquenceur au repos ; (6) l'ordre de reprise des `await` entre coroutines est NOT SOURCEABLE et n'est pas utilisé |

## ADR Dependencies

| Field | Value |
|-------|-------|
| **Depends On** | ADR-0003 `docs/architecture/adr-0003-etat-de-partie.md` (déclare `StateView`, interface de lecture seule ; couche Foundation) — doit être Accepted avant l'acceptation de celui-ci |
| **Enables** | ADR-0001 (rendu des tuiles) ; ADR audio ; ADR de composition des couches de présentation |
| **Blocks** | Stories du séquenceur, de l'horloge, du HUD (distribution) et de la présentation de la recoloration. Les stories Logic de `EventQueue`, `EventSink` et de la fusion peuvent démarrer |
| **Ordering Note** | À accepter **après** ADR-0003 (qui déclare `StateView`) et **avant** ADR-0001. `StateView` est ici une **interface abstraite en lecture seule** ; ADR-0003 la déclare et l'implémente |

## Context

### Problem Statement
Le GDD 23 fixe que les événements d'une commande sont publiés en un lot après l'application complète, que l'état est déjà final, que la file est lue « à son rythme », jamais sauvegardée, bornée et remplacée par RESYNCHRONISER au débordement, et qu'un auditeur n'émet jamais de commande ; il renvoie à un ADR le format exact et la propriété de la file. Le GDD 17 ajoute un lot entier avant le suivant, une seule animation de HUD à la fois, des séquences à durées (onde, 400 ms, panneau, verrou d'attaque), une fusion en animations réduites et une reconstruction sans onde au chargement. Aucun document ne dit **qui** possède la file et l'horloge, **qui** attend **quoi**, ni comment on le teste.

### Constraints
- GDScript, Godot 4.7.2 ; comportement des signaux et reprise des `await` non sourcés.
- L'état est final avant tout événement ; perdre la file ne change jamais la partie (23, règle 9).
- Une simulation ne publie jamais d'événement : seules les fonctions de la couche des commandes publient (23, règle 8 ; PR #3) ; l'aperçu de combat lit la liste des événements des effets rendus, hors file (règle 7).
- Au plus 3 flashs par seconde (WCAG 2.3.1) ; état final immédiat en animations réduites.
- Dépendances injectées, pas de singleton (`.claude/docs/coding-standards.md`).

### Requirements
- Ordre total des lots (révision croissante) et des événements d'un lot (ordre des écritures).
- Un lot entier présenté avant le suivant ; une seule animation de HUD à la fois.
- Durées en données ; horloge injectable et pausable pour les tests.
- Annulation propre sur RESYNCHRONISER et ÉTAT_CHARGÉ, sans coroutine orpheline.
- Verrou des commandes du joueur seulement, sans toucher l'IA ni les commandes internes (23, règle 12).

## Decision

**1. Événements typés.** Un événement est une classe `RefCounted` typée, une par fichier (`ColorTilesChanged`, `TilesRevealed`, `UnitMoved`, `UnitHit`, `RuinRead`, `IntentionAnnounced`…), héritant de `PresentationEvent` qui porte `event_id = (revision, index dans le lot)`. Elle ne contient que des identifiants et des tuiles (jamais de `Node`, `Callable` ni `RID`). Un `EventBatch` (`RefCounted`) porte `revision`, `command_id` et `events: Array[PresentationEvent]`. Ce format est le même pour la file, l'aperçu et les tests ; aucun `Dictionary`.

**2. Puits d'événements injecté.** Le pipeline de commandes reçoit un `EventSink` (interface : `push(batch)`). L'application normale reçoit l'`EventQueue` ; le rejeu reçoit un `NullSink` (les simulations n'appellent pas le pipeline : elles jettent les effets) ; l'aperçu de combat reçoit un collecteur local qui construit la liste sans la publier. Le pipeline ne connaît jamais la file par un nom global : « une copie ne publie jamais » est garanti structurellement.

**3. File.** `EventQueue` (`RefCounted`, Core) est une file FIFO de lots bornée par `Q_max` = 256 événements (donnée). Si `len + B > Q_max`, elle est vidée et ne contient plus qu'un lot `RESYNCHRONISER`. Elle n'est jamais sauvegardée. Les révisions dépilées sont strictement croissantes.

**4. Horloge de présentation.** `PresentationClock` (`Node`, Presentation, `process_priority` −20) possède le temps de présentation : `current()` (secondes), `paused`, `scale` (vitesses Normale, Rapide, Instantanée du tour ennemi). Elle avance par `_process(delta)` d'un nœud pausable ; **`get_tree().create_timer` n'est jamais utilisé** (il continue en pause). `TileTimeSource` (ADR-0001) ne fait qu'écrire `g_time` depuis cette horloge, une fois par image : un seul propriétaire du temps, pas de divergence entre débuts de fondu et tenues du séquenceur.

**5. Séquenceur en machine à états.** `PresentationSequencer` (`Node`, `process_priority` 0) avance dans `_process` : états `IDLE` et `PLAYING(lot, étape, échéance)`. Inactif, il dépile un lot ; pour chaque événement il appelle explicitement les gestionnaires **dans un ordre fixe** (rendu des tuiles, HUD, audio) ; chaque appel rend une `PresentationHold` (`duration_ms`) ; il passe à l'étape suivante quand `clock.current()` atteint l'échéance, et au lot suivant quand toutes les tenues du lot sont écoulées. `ctx.t0 = clock.current()` au moment du dépilement.
- **Annulation et pause triviales** : annuler remet l'état à `IDLE` ; en pause l'horloge est arrêtée, aucune échéance n'avance. Il n'y a aucune coroutine orpheline.
- **Séquences** : l'**ordre des étapes** est du code, une fonction testée par type de séquence (lecture de ruine : recentrage, onde, délai, panneau ; attaque : trait, cible, riposte, destruction ; action du tour ennemi) ; les **durées** sont des données (`assets/data/presentation.json`, ADR-0009 : `DÉLAI_PANNEAU`, `DÉLAI_FERMETURE`, `ATTACK_LOCK_MS` — valeur unique, car le GDD 23 dit 1,6 s et le GDD 17 1,5 s —, `T_CRENEAU_RÉDUIT`, `Q_max`). Un langage de séquence en données est reporté au palier de lancement.
- **Gestionnaires** (`PresentationHandler`, `RefCounted`) : `handle(event, ctx) -> PresentationHold`, `handle_merged(events, ctx)`, `on_idle(view)` (rappelé quand la file se vide ; sert E04, E07, E14, E19, E20, E23 et `undo_allowed`) et `rebuild_from_state(view)`. Au MVP il y a **trois gestionnaires réels** (tuiles, HUD, caméra) : le `CameraHandler` (ADR-0010) rend un `PresentationHold` de `RECENTER_MS` (0 en animations réduites) pour le recentrage, première étape de la séquence de lecture d'une ruine, et mémorise la caméra à FINIR_LE_TOUR pour la restituer au début du tour du joueur ; l'audio arrive plus tard avec le même contrat. Le rendu des tuiles passe par un **adaptateur** `TileRendererHandler` (référence injectée vers le `TileRenderer`) qui appelle `apply_color_event(event, ctx.t0)` et rend la durée d'onde.

**6. Animations réduites.** La fusion en créneaux de `T_CRENEAU_RÉDUIT` = 334 ms ne concerne que les événements **fusionnables** : `ColorTilesChanged`, `TilesRevealed` et les changements de luminance forte. Ne sont **jamais** fusionnés : les étapes d'attaque (mêmes étapes et même ordre, chiffres fixes 800 ms, trait fixe 150 ms), `RuinRead` et son panneau, `GameEnded`. C'est le **gestionnaire** qui calcule la « dernière valeur par tuile » à partir de la liste fusionnée (`handle_merged`) ; le séquenceur n'a pas à connaître la charge. La vitesse **Instantanée** du tour ennemi est un autre réglage (échelle de l'horloge, journal conservé), distinct de la limite de 3 flashs.

**7. Resynchronisation et chargement.** Sur `RESYNCHRONISER` ou `ÉTAT_CHARGÉ`, dans cet ordre : vider la file, annuler (retour à `IDLE`), lever les verrous du joueur **sauf** `FRAGMENT_PANEL` si le panneau est déjà ouvert (hud-systeme, règle 16), appeler `rebuild_from_state(view)` sur chaque gestionnaire avec une `StateView` en lecture seule (affichage direct, aucune onde), puis traiter `ÉTAT_CHARGÉ` sans attente.

**8. Commandes bloquées : deux notions distinctes.** `CommandGate` (`RefCounted`, Core, injecté, jamais sauvegardé ni copié, ignoré par les simulations (qui n'appellent pas le pipeline) et le rejeu) porte : (a) une **garde de réentrance** armée seulement pendant l'appel synchrone de `handle()`, qui refuse **toute source** avec COMMANDES_VERROUILLÉES et signale une erreur en développement (23, règle 11) ; (b) des **verrous du joueur**, un ensemble de raisons (`ATTACK_RESOLUTION`, `FRAGMENT_PANEL`), posés par le séquenceur et valant pour la faction du joueur **seulement** (23, règle 12) ; l'IA et les commandes internes ne sont jamais bloquées par (b). Que les boutons soient inactifs hors idle (hud-systeme, règle 6) relève de l'interface (`sequencer.is_idle()`), pas du gate. `_exit_tree()` du séquenceur lève ses verrous. Le pipeline (Core) ne référence jamais le séquenceur : Presentation dépend de Core, jamais l'inverse.

### Architecture Diagram

```
 Pipeline de commandes (Core) ── valider → appliquer ──► EventSink.push(EventBatch)   (NullSink pour les copies ; collecteur pour l'aperçu)
        ▲  CommandGate (réentrance + verrous joueur)              │
        │                                                         ▼
        │                                              EventQueue (RefCounted, Q_max 256)
        │                                                         │ pop, un lot à la fois
        └───────────────────── PresentationSequencer (machine à états, _process) ◄── PresentationClock (−20, pausable)
                                   ├─► TileRendererHandler ──► TileRenderer (ADR-0001) ◄── TileTimeSource (écrit g_time)
                                   ├─► HudPresenter
                                   └─► AudioPresenter (plus tard)
                                         handle / handle_merged / on_idle / rebuild_from_state → PresentationHold
```

### Key Interfaces

```gdscript
# Une classe par fichier .gd
class_name PresentationEvent extends RefCounted     # event_id: Vector2i (revision, index)
class_name EventBatch extends RefCounted            # revision: int, command_id: int, events: Array[PresentationEvent]
class_name EventSink extends RefCounted             # func push(batch: EventBatch) -> void   (interface)
class_name EventQueue extends EventSink             # pop() -> EventBatch (null si vide), is_empty() -> bool

class_name PresentationHandler extends RefCounted
func handle(event: PresentationEvent, ctx: SequenceContext) -> PresentationHold
func handle_merged(events: Array[PresentationEvent], ctx: SequenceContext) -> PresentationHold
func on_idle(view: StateView) -> void
func rebuild_from_state(view: StateView) -> void

class_name PresentationHold extends RefCounted      # duration_ms: int
class_name ClockSource extends RefCounted            # port : current() -> float ; PresentationClock l'implémente, FakeClock (tests) aussi
class_name SequenceContext extends RefCounted       # t0: float, direct: bool, clock: ClockSource
# StateView : déclarée par ADR-0003 (Foundation) ; les gestionnaires la reçoivent, ils ne la définissent pas

class_name CommandGate extends RefCounted
func enter_dispatch() -> void
func exit_dispatch() -> void
func lock(reason: StringName) -> void               # faction du joueur seulement
func unlock(reason: StringName) -> void
func is_locked(faction: int, emitter: int) -> bool  # vrai si réentrance, ou verrou joueur pour la faction du joueur ET un émetteur JOUEUR (l'IA et SYS, dont VALIDER_LA_LECTURE, ne sont jamais bloquées par un verrou)
func clear_player_locks(except: StringName = &"") -> void
```

### Implementation Guidelines
- Les gestionnaires **doivent** être appelés explicitement dans l'ordre fixe ; le séquenceur **ne doit jamais** s'appuyer sur un signal ni sur l'ordre de reprise d'un `await`.
- Le séquenceur **ne doit jamais** utiliser `await` ni `get_tree().create_timer` ; il avance par `_process` et l'horloge.
- Un gestionnaire **ne doit jamais** émettre de commande ni écrire d'état de jeu.
- Les événements **ne doivent** porter que de la présentation : l'état est final à la publication.
- Les durées de séquence, `Q_max`, `T_CRENEAU_RÉDUIT`, `ATTACK_LOCK_MS` et les délais **doivent** rester dans des fichiers de données.
- Le pipeline **ne doit jamais** connaître la file par un nom global : il reçoit un `EventSink`.
- Le séquenceur et la file **doivent** pouvoir être construits sans scène, avec une horloge et des gestionnaires factices, pour les tests unitaires.
- Les priorités de traitement sont explicites : `PresentationClock` −20, `TileTimeSource` −10, `PresentationSequencer` 0, `TileRenderer` 10, `AiRunner` 20 (ADR-0005) (la valeur la plus basse est appelée en premier ; cette liste est la source unique).
- `pop()` rend `null` quand la file est vide ; une classe par fichier `.gd`.

## Alternatives Considered

### Alternative 1: Un signal Godot par événement (diffusion directe)
- **Description**: chaque système émet un signal ; HUD, audio et renderer s'y connectent.
- **Pros**: idiomatique, peu de code.
- **Cons**: l'ordre d'appel n'est pas sourcé ; un signal émis depuis son gestionnaire s'exécute en récursion synchrone (mesuré, profondeur 3 sans protection) ; aucun propriétaire de l'ordre, des durées, de la fusion ni de l'annulation.
- **Rejection Reason**: ne garantit pas « un lot à la fois » ni l'annulation propre.

### Alternative 2: Bus d'événements en autoload global
- **Description**: un singleton diffuse les événements à tous les abonnés.
- **Pros**: accès partout.
- **Cons**: couplage caché par le nom de l'autoload, tests impossibles sans le singleton, ordre de chargement ; contredit l'injection de dépendances.
- **Rejection Reason**: untestable en isolation ; mêmes problèmes d'ordre que l'alternative 1.

### Alternative 3: Séquences en coroutines `await` avec jeton d'annulation
- **Description**: une coroutine par séquence, attente de signaux de fin.
- **Pros**: lisible pour une séquence.
- **Cons**: un jeton seul n'annule pas une coroutine suspendue sur un signal jamais émis ; une coroutine dans un `RefCounted` est libérée sans reprise ; `create_timer` continue en pause (mesurés) ; verrous oubliés après annulation.
- **Rejection Reason**: la machine à états dans `_process` donne annulation et pause gratuites. Option de repli documentée, avec jeton partagé, signal d'annulation par tenue et test du jeton après chaque `await`.

### Alternative 4: Séquences entièrement en données (petit langage)
- **Description**: un fichier décrit les étapes de chaque séquence.
- **Pros**: souple sans recompiler.
- **Cons**: deux ou trois séquences au MVP ne justifient pas un langage à concevoir et à tester.
- **Rejection Reason**: sur-ingénierie pour un palier de 5 mois ; reporté au lancement si une 4e ou 5e séquence le justifie.

## Consequences

### Positive
- Un seul propriétaire de l'ordre, des durées, de la fusion, de l'horloge, de la resynchronisation et du verrou.
- Testable sans moteur de rendu (horloge et gestionnaires factices) ; annulation et pause sans coroutine.
- Format d'événement unique, typé, partagé avec l'aperçu et les tests ; identité d'événement stable.
- « Une copie ne publie jamais » garanti par injection.
- Aucune dépendance à l'ordre des signaux de Godot.

### Negative
- Un objet de plus (séquenceur) et un contrat `PresentationHandler` à maintenir.
- L'ordre des étapes est en code : modifier une séquence demande une recompilation.
- Dépendance à des `process_priority` corrects entre quatre nœuds.
- Les séquences à plusieurs étapes s'écrivent en machine à états, moins lisibles qu'une coroutine.

## Risks
- **Machine à états difficile à lire** pour des séquences longues. *Atténuation* : une fonction par séquence, tests de séquence avec horloge factice ; repli documenté sur des coroutines (alternative 3).
- **Fusion qui perd un état utile** (E6). *Atténuation* : seuls les événements fusionnables le sont ; l'état de jeu est inchangé.
- **Verrous oubliés** : un `unlock` manquant après annulation bloque le joueur. *Atténuation* : ensemble de raisons, levées à la resynchronisation (sauf `FRAGMENT_PANEL` ouvert) et à `_exit_tree()`.
- **Q_max contre B_max** : `Q_max ≥ 2 × B_max` n'est pas encore démontré. *Atténuation* : critère de validation sur le pire cas (élimination à 256 tuiles, un seul événement de couleur).

## GDD Requirements Addressed

| GDD System | Requirement | How This ADR Addresses It |
|------------|-------------|--------------------------|
| commandes-evenements.md (23) | Règles 8 à 10 : lot après application, état final, file lue à son rythme, non sauvegardée, bornée, RESYNCHRONISER ; renvoi du format exact à un ADR | `EventBatch`, `EventQueue` (Q_max 256), événements typés, séquenceur |
| commandes-evenements.md (23) | Règle 8 : une copie ne publie jamais ; règle 7 : aperçu lit la liste des événements | `EventSink` injecté (NullSink, collecteur local) |
| commandes-evenements.md (23) | Règle 11 : aucun auditeur n'émet de commande | Garde de réentrance de `CommandGate` |
| commandes-evenements.md (23) | Règle 12 : verrou d'attaque côté joueur, pas l'IA ni les commandes internes | Verrous du joueur par raisons ; `ATTACK_LOCK_MS` unique |
| hud-systeme.md (17) | Règles 10 à 13 : un lot à la fois, une animation de HUD à la fois, onde puis panneau à 400 ms | Machine à états, séquences, durées en données |
| hud-systeme.md (17) | Règles 16 et 17 : RESYNCHRONISER, chargement sans onde, panneau ouvert conservé | Ordre d'annulation en 7, `FRAGMENT_PANEL` exempté |
| hud-systeme.md (17) | Règle 14 et 24 : attaque inchangée en animations réduites ; 3 flashs par seconde | Liste des événements fusionnables et non fusionnables |
| recoloration-monde.md (15) | E4, E5, E6 : resynchronisation, chargement, animations réduites | Annulation, reconstruction directe, fusion |

## Performance Implications
- **CPU**: opérations O(1) sur la file ; un lot par image au plus ; budget proposé ≤ 0,3 ms par image pour le séquenceur (à confirmer sur appareil de référence, non encore nommé) ; 0 allocation par image au repos.
- **Memory**: file bornée à 256 événements ; lots libérés après présentation.
- **Load Time**: négligeable.
- **Network**: sans objet.

## Migration Plan
Sans objet : aucun code de production n'existe.

## Validation Criteria
- AC-F4 (23) : len = 250, B = 12, Q_max = 256 → la file contient exactement [RESYNCHRONISER], état inchangé ; AC-11 : une commande émise depuis `handle()` est refusée (COMMANDES_VERROUILLÉES), erreur en développement ; AC-12 : pendant le verrou d'attaque, la commande du joueur est refusée et celle de l'IA permise ; AC-X4 : une commande sur une copie ne pousse rien.
- Séquenceur avec horloge factice : ordre des lots (révisions strictement croissantes), un lot à la fois, durées (AC-HU18 à AC-HU21, AC-HU23), fusion à 334 ms jamais appliquée aux étapes d'attaque ni à `RuinRead` (AC-HU38), vitesse Instantanée distincte.
- Après RESYNCHRONISER et chargement : aucune raison de verrou restante, sauf `FRAGMENT_PANEL` si le panneau est ouvert, et ce panneau reste ouvert (AC-HU27, AC-HU28).
- Pause : horloge arrêtée N images, aucune tenue ne progresse, reprise au même point.
- Annulation au milieu d'un lot : aucun appel de gestionnaire après l'annulation.
- Ordre des gestionnaires déterministe, vérifié par un gestionnaire factice.
- `Q_max ≥ 2 × B_max` sur le pire cas (élimination à 256 tuiles, un seul événement de couleur).
- Mesure du séquenceur sur Android (0,3 ms proposé).

## Related
- GDD : `design/gdd/commandes-evenements.md` (23), `hud-systeme.md` (17), `recoloration-monde.md` (15), `modele-etat-partie.md` (1, règle 9 et copies).
- ADR-0001 (rendu des tuiles) : dépend de celui-ci ; amendé (adaptateur `TileRendererHandler`, `StateView`, `event_id`, propriété de l'horloge).
- ADR-0003 (`StateView`, modèle d'état, copies) : celui-ci en dépend ; ordre d'acceptation ADR-0003, puis celui-ci, puis ADR-0001.
