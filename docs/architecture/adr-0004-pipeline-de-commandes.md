# ADR-0004: Pipeline de commandes — commandes en données pures, handlers typés par système, validation sur vue filtrée

## Status
Accepted

## Date
2026-10-30

## Last Verified
2026-10-30 — conception sur le GDD 23 et les ADR-0002 et 0003 ; **aucun prototype** ; `@abstract` (4.5) et la règle 4.7 sur les redéfinitions de type de retour sont des API postérieures à la connaissance du modèle, à vérifier avant l'acceptation.

## Decision Makers
Utilisateur (direction de projet), Claude (rédaction), technical-director (validation avant écriture).

## Summary
Toute modification de l'état en partie passe par un `CommandPipeline` synchrone : une commande est une **classe `RefCounted` typée en données pures**, validée contre la **vue filtrée paresseuse** de sa faction puis appliquée par un **handler typé par système propriétaire** (tableau indexé par un enum de 13 types) ; l'application est une **fonction de règle pure** qui ne peut pas échouer : elle écrit l'état par les fonctions des propriétaires, fait avancer la révision et **rend ses effets** (événements dans l'ordre des écritures, écriture du profil) sous forme de valeurs, que **seule la couche des commandes applique** (décision de la PR #3, 2026-10-30). L'aperçu et les simulations appliquent la même fonction sur une copie de l'état **vu par la faction** et jettent les effets ; l'annulation du déplacement restaure un instantané gardé hors de l'état.

## Engine Compatibility

| Field | Value |
|-------|-------|
| **Engine** | Godot 4.7.2 |
| **Domain** | Core |
| **Layer** | Core |
| **Knowledge Risk** | HIGH |
| **References Consulted** | `docs/engine-reference/godot/VERSION.md`, `docs/engine-reference/godot/breaking-changes.md` (ligne 17 : une redéfinition hérite du type de retour), `docs/engine-reference/godot/current-best-practices.md` (lignes 32-39 `@abstract`, ligne 46), `design/gdd/commandes-evenements.md`, ADR-0002, ADR-0003 |
| **Post-Cutoff APIs Used** | `@abstract` (4.5) pour la classe de base des handlers, **option** : à vérifier par un test headless ; la règle 4.7 « une redéfinition hérite du type de retour, donc `return` explicite » s'applique aux sous-classes de handlers |
| **Verification Required** | (1) coût validation plus application sur Android (budget 0,3 ms par commande, provisoire) ; (2) `@abstract` et héritage de type de retour sur les handlers (sinon une interface par convention) ; (3) coût de `FactionView` par lecture et parité avec `filtered_copy` ; (4) `check`, `preview` et l'IA n'utilisent jamais la table dans un ordre d'itération |

## ADR Dependencies

| Field | Value |
|-------|-------|
| **Depends On** | ADR-0003 (copie, `filtered_copy`, `restore_from`, `StateView`) ; ADR-0002 (`EventSink`, `CommandGate`) — tous deux Accepted avant celui-ci |
| **Enables** | ADR de l'IA (planification sur copies et aperçus) ; ADR du système de sauvegarde (16, port post-commit) ; chaque système propriétaire (handlers) |
| **Blocks** | Stories Core : pipeline de commandes, aperçu, annulation, rejeu ; stories de commandes de chaque système |
| **Ordering Note** | Ordre d'acceptation : ADR-0003, ADR-0002, celui-ci. ADR-0001 dépend d'ADR-0002, pas de celui-ci |

## Context

### Problem Statement
Le GDD 23 fixe : valider puis appliquer (règle 1), un résultat sans texte (2), une application qui ne peut pas échouer (3), tout ou rien (4), un écrivain par champ (5), une validation sur la vue de la faction qui ne révèle rien de caché avec embuscade permise (6), un aperçu qui est la commande sur une copie (7), des événements en un seul lot après l'application (8), pas de commande pendant la distribution (11), un verrou du joueur (12), des changements de tour par commandes internes (13), une révision monotone (14), une annulation par instantané (15), un rejeu déterministe (16) et des commandes en données pures (17). Les GDD 13, 16 et 22 ajoutent la lecture de ruine (journal « en attente », sauvegarde, écriture du profil). Il laisse à un ADR la forme concrète.

### Constraints
- GDScript, Godot 4.7.2 ; l'état est celui d'ADR-0003 (colonnes, copie, `filtered_copy`, `restore_from`).
- Budget IA : validation plus application ≤ 0,3 ms par commande (formule 3 du GDD 23, provisoire) ; la planification utilise environ une copie par unité plus K aperçus, 2 500 copies étant un plafond.
- Aucun hasard du moteur ; une copie ne publie jamais d'événement (`EventSink`, ADR-0002).
- Treize types de commandes : DÉPLACER, ATTAQUER, CAPTURER, RÉVEILLER, MONTER_NŒUD, RECHERCHER, FINIR_LE_TOUR, ABANDONNER, ANNULER_LE_DÉPLACEMENT et les internes COMMENCER_LE_TOUR, ANNONCER_LES_INTENTIONS, EXÉCUTER_UNE_INTENTION, VALIDER_LA_LECTURE.

### Requirements
- Commandes sérialisables sans perte ; validation sans écriture, complète.
- Aperçu, IA et joueur partagent le même code ; l'aperçu ne révèle rien de caché.
- La lecture d'une ruine, l'écriture du profil et la sauvegarde ont un ordre défini.

## Decision

**1. Commandes en données pures.** Une commande est une classe `RefCounted` typée, une par fichier, héritant de `Command` (`faction`, `emitter` : JOUEUR, IA ou SYS). Elle ne porte que des entiers et des identifiants, jamais de `Node`, `Callable` ni `RID`, et **aucune logique**. Un `CommandCodec` unique la sérialise avec un **identifiant de type entier et stable** (un `StringName` n'est pas un format).

**2. Handlers typés par système.** Un enum entier `CommandType` (13 valeurs, dont la commande interne VALIDER_LA_LECTURE) indexe un tableau de **handlers typés**, une classe par système propriétaire (`validate(view: StateView, cmd) -> ValidationResult`, `apply(state: GameState, cmd) -> ApplyResult`, où `ApplyResult` porte `révélé`, `ruine_lue`, le `VisionDelta` (tuiles découvertes, unités nouvellement vues, ADR-0007) et la liste ordonnée des **effets**). Le tableau est construit **une fois**, immuable et **sans état** : c'est la `RuleTable`, **instance immuable** construite par la fabrique de session avec le catalogue (ADR-0009) et le `VisionContext` (ADR-0007) — plus de fonctions statiques qui liraient un catalogue global —, dont `check`, `apply_on` et `check_move_range(view, unit_id) -> PackedInt32Array` (plage de déplacement de la **validation** `validate`, sans préfixe de refus, ADR-0010, avec test de parité) sont des méthodes que le pipeline enveloppe. `RuleTable.simulation()` rend la **variante de simulation** (même handlers, `VisionContext.factions = []` : aucun recalcul de vue, ADR-0007 §8) (le pipeline, lui, détient `CommandGate`, `UndoSlot` et les ports) ; elle est partagée par le pipeline réel et les simulations, y compris celles de l'IA sur un fil de travail (ADR-0005 §7) (qui appellent `apply` sans passer par la couche des commandes et jettent les effets) ; un test de démarrage vérifie que chaque type est enregistré. `validate` est une fonction pure ; `apply` appelle les **fonctions d'écriture des propriétaires**, jamais une colonne directe, et **n'émet jamais de commande** (l'enchaînement des tours est porté par le système des tours, hors du pipeline).

**3. Vue filtrée paresseuse.** La validation d'une commande réelle utilise `FactionView(state, faction)`, une `StateView` qui teste la visibilité **à chaque lecture, sans copie**. L'IA fige sa vue une fois par perception (`filtered_copy`, ADR-0003), puis valide et prévisualise sur des `duplicate_state()` de cette copie : jamais un `filtered_copy` par candidate. Une seule source de filtrage : `filtered_copy` et `FactionView` s'appuient sur le même prédicat de visibilité (système 5) ; un test de parité compare `validate(FactionView(réel, f))` à `validate(filtered_copy(f).view())` sur un corpus de fabrique.

**4. Flux d'une commande** (synchrone), avec un **préfixe commun fixe de refus** :
1. réentrance (COMMANDES_VERROUILLÉES, erreur en développement) ; 2. PARTIE_TERMINÉE ; 3. PAS_VOTRE_TOUR ; 4. verrou du joueur (COMMANDES_VERROUILLÉES) ; 5. vérifications propres à la commande, dans un ordre fixe couvert par un test. PARTIE_TERMINÉE et PAS_VOTRE_TOUR sont des lectures d'état (système 3), **pas** le `CommandGate` (qui ne porte que la réentrance et les verrous du joueur, ADR-0002). Exception : ABANDONNER est permis en phase ennemie.
- **Appliquer** : avant un DÉPLACER du joueur, l'instantané d'annulation est pris (`duplicate_state()`, dans l'`UndoSlot`, hors de l'état) ; `apply` s'exécute et enregistre les événements dans l'ordre des écritures ; la **révision** (tranche « journal des commandes », propriété du pipeline) augmente de 1 par la fonction d'écriture de cette tranche (`command_id = révision`, un seul numéro). Une copie incrémente sa propre révision sans effet sur l'état réel.
- **Phase après validation (post-commit)** : un `PostCommitPort` injecté (réel pour la partie, nul pour le rejeu ; l'aperçu et les simulations n'y passent jamais, puisqu'elles n'appellent que `apply`) déclenche la sauvegarde (16) **après chaque commande appliquée, du joueur, de l'IA ou interne**, annulation et abandon compris, et à la fin de partie (décision du 2026-10-30 ; prédicat et séquence : ADR-0006), **synchrone et avant** l'application des autres effets et `EventSink.push`, pour que le panneau de fragment ne s'ouvre qu'après l'écriture. La sauvegarde **n'écoute jamais la file d'événements** (une resynchronisation la vide). En synchrone il n'y a pas de coalescence (ADR-0006 §7) : chaque commande écrit, donc une phase ennemie de N commandes coûte N écritures ; si AC-F1 dépasse le budget sur l'appareil, le fil d'écriture est décidé dans ADR-0006.
- **Filtrer et publier** : avant l'application, le pipeline réel copie le `ViewCache` ; après l'application, il retire du lot les événements de l'autre faction que `VisionService.event_visible(avant, après, faction, événement)` juge invisibles (ADR-0007 §7) ; le lot (`EventBatch`, ADR-0002) est poussé après le post-commit.

**5. Lecture d'une ruine.** Dans la même application de DÉPLACER : arrivée, marquage de la ruine, calcul du fragment **sur l'état seul** (instantané de la chronique plus journal, formule 1 du GDD 22 : aucune règle ne lit le profil), entrée « en attente » au journal, zone recolorée, compteur, et deux effets **rendus** : l'événement RUINE_LUE et « enregistrer un fragment » (`ruines-fragments.md`, règle 14 a–g). Après le commit, la couche des commandes enchaîne : (1) `PostCommitPort` sauvegarde la partie ; (2) un `ProfilePort` (réel pour la partie, **nul** pour le rejeu) applique l'effet « enregistrer un fragment » (idempotent par id) et écrit le profil ; (3) `EventSink.push` ; (4) si l'écriture du profil a réussi, la commande interne **VALIDER_LA_LECTURE** est soumise **après** la fin de la soumission courante (liste de commandes de suite vidée en sortie de `submit`, car la garde de réentrance refuse tout appel imbriqué) : c'est une commande ordinaire, avec révision, sauvegarde et entrée dans le `CommandLog`, qui passe l'entrée du journal à « validée ». **Il n'y a plus d'exception à la règle 3 du GDD 1** ni de `FragmentSource`. Si l'écriture du profil échoue, l'entrée reste « en attente » et le chargement la réconcilie (règle 10 du GDD 1).

**6. Aperçu et vérification.** `preview(command) -> PreviewResult` valide puis applique sur `FactionView` → copie de **l'état vu par la faction émettrice** (`filtered_copy(f)` puis `duplicate_state()`, y compris pour le joueur), en lisant la liste d'événements des effets rendus **sans la publier ni appliquer les autres effets** : l'aperçu d'un déplacement dont le chemin traverse un ennemi caché ne montre ni arrêt ni unité cachée. `PreviewResult` porte la révision de base, pour jeter un aperçu périmé. `check(command) -> ValidationResult` valide **sans appliquer** (boutons grisés du HUD, y compris `check(UndoMoveCommand)` qui rend le **code** du motif). `apply_on(copy, command) -> ValidationResult` enchaîne des coups sur une même copie pour l'IA. Copies d'aperçu et de simulation : transitoires, possédées par l'appelant, jamais retenues par le pipeline.

**7. Embuscade.** Un déplacement dont le chemin rencontre une unité ennemie cachée est **permis** ; `apply` arrête l'unité sur la dernière tuile libre avant l'ennemi, qui est révélé ; **s'il n'y a aucune tuile libre avant l'ennemi, l'unité ne bouge pas**, l'ennemi est révélé et le déplacement est consommé. Les **seuls** écarts permis entre ce que voit `validate` et ce que rencontre `apply` sont l'embuscade et un **obstacle de terrain non découvert** (eau : l'unité s'arrête sans punition et l'obstacle devient vu, GDD 5 règle 12, GDD 4 règle 11) ; tout autre écart est un bogue.

**8. Annulation.** `UndoSlot` (possédé par le pipeline réel seulement : instantané, `rev_instantané`, motif ; jamais sauvegardé ni copié). `undo_allowed = armé ∧ ¬révélé ∧ ¬ruine_lue ∧ (rev = rev_instantané + 1)` ; « révélé » et « ruine_lue » viennent d'un **résultat rendu par `apply`** (drapeaux remontés par les fonctions du brouillard et des ruines), pas de la liste d'événements (un collecteur nul ne doit pas casser l'annulation). `UndoMoveCommand` appelle `state.restore_from(snapshot)` (ADR-0003 : le journal des commandes est conservé), fait avancer la révision (instantané + 2), publie DÉPLACEMENT_ANNULÉ et supprime l'instantané. `on_state_loaded()` (appelé par 16) remet le slot à AUCUN avec RIEN_À_ANNULER.

**9. Commandes internes et intentions.** Début de tour, publication et exécution des intentions passent par le pipeline (émetteur SYS), avec leur révision. `ExecuteIntentionCommand` appelle **directement** les fonctions d'application d'attaque ou de capture sous une seule révision, **sans `submit` imbriqué** ; un ATTAQUER ou un CAPTURER émis par l'IA via `submit` est toujours refusé `AUCUNE_INTENTION`. Une intention annulée (cible déplacée…) fait +1 sur la révision et publie INTENTION_ANNULÉE.

**10. Rejeu.** Un `CommandLog { format_version, content_hash, initial_chronicle, commands }` (`content_hash` : empreinte du catalogue de données, ADR-0009 ; un rejeu avec d'autres données est signalé) porte **toutes** les commandes appliquées, quel que soit l'émetteur (JOUEUR, IA, SYS), annulation comprise, dans l'ordre des révisions ; les commandes refusées sont exclues, et un refus pendant le rejeu est une **divergence** signalée. Le rejeu tourne sans `CommandGate`, **avec** l'`UndoSlot`, le port post-commit nul et le `ProfilePort` nul (le fragment vient de l'instantané de la chronique, déjà dans l'état initial) ; il **ne relance pas** le planificateur de l'IA (déterminisme de l'IA testé à part). Un rejeu d'une autre version est refusé `FORMAT_INCOMPATIBLE`. `replay()` peut vivre dans un utilitaire de test.

### Architecture Diagram

```
 Contrôles (4) / IA (9) / Tours (3) ──► CommandPipeline.submit(Command)
   préfixe de refus : réentrance → PARTIE_TERMINÉE → PAS_VOTRE_TOUR → verrou joueur → vérifs de la commande
   validate(FactionView(état, faction))  ── ValidationResult (code + paramètres, aucun texte)
   [DÉPLACER du joueur : instantané ──► UndoSlot (hors de l'état)]
   handler[type].apply(GameState, cmd) ── fonctions des propriétaires ──► ApplyResult{effets}
   révision + 1 (tranche « journal des commandes ») ──► PostCommitPort (sauvegarde) ──► ProfilePort (profil) ──► EventSink.push(EventBatch) ──► commandes de suite (VALIDER_LA_LECTURE)
 check(cmd) : validate seul          preview(cmd) : filtered_copy(f) + duplicate_state, événements non publiés
```

### Key Interfaces

```gdscript
enum CommandType { MOVE, ATTACK, CAPTURE, WAKE, UPGRADE_NODE, RESEARCH, END_TURN, ABANDON, UNDO_MOVE, BEGIN_TURN, ANNOUNCE_INTENTIONS, EXECUTE_INTENTION, VALIDATE_RUIN_READ }
class_name Command extends RefCounted             # faction: int, emitter: int ; données pures, une classe par fichier
class_name ValidationResult extends RefCounted    # permitted: bool, code: StringName, params: PackedInt64Array
class_name CommandHandler extends RefCounted      # @abstract (option) ; une sous-classe par système propriétaire
func validate(view: StateView, command: Command) -> ValidationResult
func apply(state: GameState, command: Command) -> ApplyResult   # fonction de règle pure ; ne rend jamais d'échec de jeu ; remonte révélé / ruine_lue et les effets

class_name CommandPipeline extends RefCounted
func submit(command: Command) -> ValidationResult
func check(command: Command) -> ValidationResult
func preview(command: Command) -> PreviewResult        # faction = command.faction
func apply_on(copy: GameState, command: Command) -> ValidationResult   # effets jetés
func on_state_loaded() -> void
func check_move_range(view: StateView, unit_id: int) -> PackedInt32Array   # RuleTable : tuiles où validate(Move) est permis (ADR-0010)
class_name PostCommitPort extends RefCounted            # on_commit(state, command, result) ; réel, nul
class_name ProfilePort extends RefCounted               # apply(effect) -> bool (écriture réussie) ; réel, nul (rejeu)
class_name CommandCodec extends RefCounted             # identifiants de type entiers stables
```

### Implementation Guidelines
- Une commande **ne doit** contenir aucune logique ni référence à un objet du moteur.
- `validate` **doit** être pure et **ne doit jamais** lire hors de la vue de la faction ni écrire.
- `apply` **ne doit jamais** échouer pour un cas de jeu, **ne doit jamais** émettre de commande ni appeler `submit`, et **doit** écrire par les fonctions des propriétaires en parcourant par id croissant.
- Un refus **ne doit jamais** révéler une information que la faction ne voit pas.
- La sauvegarde et la copie persistante **ne doivent jamais** être déclenchées pendant `apply`, seulement après le commit.
- Le pipeline **ne doit jamais** connaître la file d'événements par un nom global : il reçoit un `EventSink`.
- Un handler **doit** utiliser un `return` explicite (règle 4.7 sur les redéfinitions).

## Alternatives Considered

### Alternative 1: Objets `Command` avec une méthode `execute()`
- **Description**: chaque commande porte sa logique.
- **Pros**: familier (patron Commande).
- **Cons**: contredit « commandes en données pures » (règle 17) ; sérialisation et rejeu plus délicats ; logique dispersée hors du système propriétaire.
- **Rejection Reason**: la règle 17 et « un écrivain par champ » demandent des données et des fonctions séparées.

### Alternative 2: Commandes typées et un `match` de 13 branches vers des fonctions statiques
- **Description**: un seul fichier central dispatche vers des fonctions statiques des propriétaires.
- **Pros**: le plus simple, typé ; garde la frontière par système.
- **Cons**: un fichier central qui touche tous les systèmes.
- **Rejection Reason**: non retenu pour garder une classe handler par système et un test de démarrage d'enregistrement ; **repli simple** si `@abstract` ou l'héritage de type de retour posent problème.

### Alternative 3: Commandes en `Dictionary` et `Callable` dans un `Dictionary`
- **Description**: dispatch dynamique par clé.
- **Pros**: souple, très peu de code.
- **Cons**: `Callable.call()` rend un `Variant`, pas de typage ; un oubli d'enregistrement passe jusqu'à l'exécution.
- **Rejection Reason**: contraire au typage statique voulu.

### Alternative 4: Un signal par commande
- **Description**: chaque système écoute le signal de ses commandes.
- **Pros**: découplage apparent.
- **Cons**: ordre d'appel non sourcé, récursion synchrone mesurée (ADR-0002), aucune garantie « une validation, une application, une révision ».
- **Rejection Reason**: mêmes raisons que dans ADR-0002.

## Consequences

### Positive
- Un chemin d'écriture unique, tracé par la révision, rejouable.
- Joueur, IA, aperçu et rejeu partagent le même code ; l'aperçu ne fuit pas.
- Validation et application testables par système, sans moteur de rendu.
- La sauvegarde ne dépend pas de la file de présentation.

### Negative
- 13 handlers typés et un enum à maintenir ; le style « données plus fonctions » est moins familier.
- La complétude de `validate` repose sur des tests et la validation des invariants.
- Une commande interne de plus (VALIDER_LA_LECTURE) et une liste de commandes de suite vidée en sortie de `submit` ; plus aucune exception à la règle 3 du GDD 1.
- Un coût de `filtered_copy` pour chaque aperçu du joueur (une copie filtrée par appui, dans le budget de la formule 5).

## Risks
- **Budget de 0,3 ms par commande non tenu sur Android** : *Atténuation* : l'IA évalue moins de candidates (`C`), pas une autre représentation.
- **Divergence `validate` / `apply`** : bogue silencieux. *Atténuation* : tests de parité et validation des invariants après chaque application en développement.
- **Parité `FactionView` / `filtered_copy`** : fuite par un prédicat divergent. *Atténuation* : un seul prédicat, test sur un corpus de fabrique.
- **`@abstract` / héritage de type de retour** (APIs récentes) : *Atténuation* : vérification 2 ; repli vers l'alternative 2 (`match`).
- **Ordre sauvegarde / push** : la sauvegarde avant le push retarde le lot ; négligeable à l'échelle d'une commande.

## GDD Requirements Addressed

| GDD System | Requirement | How This ADR Addresses It |
|------------|-------------|--------------------------|
| commandes-evenements.md (23) | Règles 1 à 5 : valider puis appliquer, résultat sans texte, application totale, tout ou rien, écrivain unique | Handlers typés `(validate, apply)`, fonctions des propriétaires |
| commandes-evenements.md (23) | Règle 6 : validation sur la vue de la faction, embuscade permise | `FactionView`, §7 embuscade (y compris sans tuile libre) |
| commandes-evenements.md (23) | Règle 7 : aperçu = commande sur une copie | `preview` sur copie de l'état vu par la faction |
| commandes-evenements.md (23) | Règles 8 à 12 : lot, révision, verrous | `EventSink`, `CommandGate`, préfixe de refus |
| commandes-evenements.md (23) | Règles 13 à 15 : commandes internes, révision, annulation | SYS, `restore_from`, `UndoSlot` |
| commandes-evenements.md (23) | Règles 16 et 17 : rejeu, données pures | `CommandLog`, `CommandCodec`, classes sans logique |
| ruines-fragments.md (13) | Règle 14 a–g, règle 17 : séquence de lecture, fragment suivant | §5, instantané de la chronique, effet « enregistrer un fragment », `ProfilePort`, VALIDER_LA_LECTURE |
| sauvegarde-automatique.md (16) | Règle 10 : sauvegarde avant le panneau, profil écrit après l'application | `PostCommitPort` avant `EventSink.push` |
| ia-ennemie.md (9) | Règles 4 et 7 : aucune attaque sans intention ; règle 19 : copies | `AUCUNE_INTENTION`, §9, vue figée et `duplicate_state()` |
| noeuds.md (11) | MONTER_NŒUD : six codes de refus, NŒUD_MONTÉ | 12e type de commande |
| modele-etat-partie.md (1) | Règles 2, 3, 10, 14 : un écrivain, chemin unique, journal des lectures de ruine, révision | `apply` par propriétaires, effets rendus et appliqués par la couche des commandes, VALIDER_LA_LECTURE ordinaire |

## Performance Implications
- **CPU**: validation plus application ≤ 0,3 ms par commande (provisoire) ; copie 15 µs mesurée sur PC (ADR-0003) ; une copie filtrée par aperçu du joueur ; un lot par commande.
- **Memory**: un instantané d'annulation (une copie d'état, environ 8 Ko) ; la liste de rejeu existe en tests seulement.
- **Load Time**: négligeable.
- **Network**: sans objet.

## Migration Plan
Sans objet : aucun code de production n'existe.

## Validation Criteria
- AC du GDD 23 : refus ne change pas la révision, appliquée fait +1 ; annulation : révision = instantané + 2, journal non reculé ; aperçu = résultat ; copie ne publie pas ; commande depuis un gestionnaire refusée ; rejeu identique sur 100 exécutions (commandes JOUEUR, IA, SYS et une annulation ; refus en rejeu signalé).
- **Aperçu sans fuite** : l'aperçu d'un déplacement qui traverse un ennemi caché ne montre ni arrêt ni unité cachée ; ATTAQUER sur copie filtrée égal à l'application réelle (AC-X1).
- Parité `FactionView` / `filtered_copy` sur un corpus de fabrique ; non-fuite d'information par faction (AC-X2).
- Lecture de ruine : ordre d'écriture, sauvegarde, profil, « validée » ; simulation et rejeu sans écriture du profil (AC-RF19, effet rendu puis jeté) ; rejeu avec `ProfilePort` nul et même fragment (AC-RF28).
- Exécution d'intention sous une seule révision ; ATTAQUER émis par l'IA via `submit` refusé `AUCUNE_INTENTION` ; intention annulée : +1 et INTENTION_ANNULÉE.
- MONTER_NŒUD : ordre des six refus ; préfixe commun de refus avec l'exception ABANDONNER ; test de démarrage : chaque type est enregistré.
- `UndoSlot` remis à zéro au chargement (AC-X3) ; une sauvegarde ou une copie persistante ne se déclenche qu'après le commit (AC-04).
- Mesure de validation plus application sur Android de référence (≤ 0,3 ms provisoire).

## Related

- ADR-0007 (vision) : `FactionView` répond par `VisionService.can_see` ; l'application recalcule la vue (`recompute`, les deux factions dans le pipeline réel, la faction de la commande dans `apply_on`) ; ADR-0010 : `check_move_range`.- GDD : `design/gdd/commandes-evenements.md` (23), `modele-etat-partie.md` (1), `ia-ennemie.md` (9), `ruines-fragments.md` (13), `sauvegarde-automatique.md` (16), `noeuds.md` (11), `profil-donnees-meta.md` (22). **GDD SYNC** : GDD 23 (MONTER_NŒUD dans le tableau, préfixe de refus, `command_id = révision`) ; GDD 1 (règle 3 : plus d'exception, VALIDER_LA_LECTURE est une commande ordinaire ; tranche « journal des commandes » propriété du pipeline). GDD 23 : 13ᵉ type VALIDER_LA_LECTURE (émetteur SYS).
- ADR-0002, ADR-0003, ADR-0001.
