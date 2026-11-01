# ADR-0007: Vision et visibilité — un service unique, un cache de vue transitoire, un prédicat partagé par FactionView et filtered_copy

## Status
Accepted

## Date
2026-10-31

## Last Verified
2026-10-31 — conception sur le GDD 5 (revu après la PR #3) et les ADR-0003 à 0005 ; **micro-banc headless** Godot 4.7.2 Windows : union de listes précalculées pour une faction (30 unités et 5 nœuds, 16 × 16) en **43 µs**, copie du cache de 256 octets en **0,26 µs**, précalcul sans occlusion en 8 ms (une fois). Android non mesuré.

## Decision Makers
Utilisateur (direction de projet, choix « recommandé » délégué), Claude (rédaction), godot-specialist et technical-director (validation, TD-ADR : CONCERNS traités le 2026-10-31). **L'acceptation (`Accepted`) exige une confirmation explicite de l'utilisateur : le choix « recommandé » délégué ne vaut pas acceptation.**

## Summary
Le GDD 5 tient la frontière anti-fuite du jeu, mais ADR-0004 (parité `FactionView` / `filtered_copy`) et ADR-0005 (perception de l'IA) reposent sur un « prédicat unique » et un cache de vision que rien ne définit. Cet ADR crée le module `VisionService` (fonctions sans état, `src/core/vision/`), un `ViewCache` transitoire attaché à `GameState` (copié en profondeur avec lui, jamais sérialisé ni comparé), des `FieldTable` précalculées tenues par un `VisionContext` injecté, et impose que `FactionView` et `filtered_copy` se fondent sur le même prédicat (unités et nœuds compris), prouvé par un test de parité. Les simulations de l'IA ne recalculent **pas** la vue.

## Engine Compatibility

| Field | Value |
|-------|-------|
| **Engine** | Godot 4.7.2 |
| **Domain** | Core |
| **Layer** | Core |
| **Knowledge Risk** | MEDIUM (GDScript pur, tableaux typés ; aucune API postérieure à la connaissance du modèle) |
| **References Consulted** | `docs/engine-reference/godot/VERSION.md`, `design/gdd/brouillard-vision.md`, `design/gdd/modele-etat-partie.md`, `design/gdd/carte-tuiles-terrain.md` (formule 3, tracé de Bresenham), ADR-0003, ADR-0004, ADR-0005 |
| **Post-Cutoff APIs Used** | Aucune |
| **Verification Required** | (1) **Android** : coût de `recompute` pour deux factions, seuil 1 ms par commande (GDD 5) ; (2) coût du précalcul **avec occlusion** (Bresenham) en 16 × 16 ; (3) parité exhaustive `FactionView` / `filtered_copy` sur des états aléatoires (test) ; (4) copie **profonde** du `ViewCache` par `duplicate_state()` : indépendance copie / original sur chaque faction (l'erreur `Array.duplicate()` superficiel est un piège vérifié) |

## ADR Dependencies

| Field | Value |
|-------|-------|
| **Depends On** | ADR-0003 (état, `duplicate_state`, `restore_from`, `filtered_copy`) ; ADR-0004 (`FactionView`, application des commandes) — Accepted avant celui-ci |
| **Enables** | ADR-0005 (perception de l'IA sur un prédicat défini) ; ADR-0001 (le brouillard lit `TUILES_RÉVÉLÉES` et le cache) ; stories du brouillard (5), de la recoloration (15), du HUD (17) |
| **Blocks** | Stories Core : vision, révélation pas à pas, embuscade, événements de l'autre faction |
| **Ordering Note** | Ordre d'acceptation : ADR-0003, ADR-0004, puis celui-ci ; ADR-0005 doit être relu contre lui avant acceptation |

## Context

### Problem Statement
Le brouillard décide ce que chaque faction sait. Le GDD 5 fixe les états (INCONNUE, EXPLORÉE, VISIBLE), la mémoire du propriétaire (octet 1), les champs de vue, la révélation pas à pas et le filtre d'événements. Depuis la PR #3, la vision actuelle et la couleur ne sont plus dans l'état : un cache les remplace. Trois contrats dépendent de ce cache sans qu'un ADR le définisse : la validation sur la vue (ADR-0004), la copie filtrée (ADR-0003, ADR-0005) et le filtre d'événements.

### Constraints
- GDScript, Godot 4.7.2, Android d'abord ; terrain fixe pendant la partie ; cartes jusqu'à 16 × 16, 60 unités, 10 nœuds.
- Entiers seulement, itération par id croissant, aucun hasard.
- Le cache est **hors de l'état** (GDD 1, règle 1 et PR #3) : ni sérialisé, ni comparé par l'égalité profonde.
- Budget : recalcul ≤ 1 ms par commande pour deux factions (GDD 5) ; budget IA de 0,3 ms par commande validée et appliquée (ADR-0004).
- Une simulation de l'IA part d'un état reconstruit à partir de sa vue (GDD 1, règle 11).

### Requirements
- Un seul prédicat « cette faction voit-elle cette tuile / cette entité » pour la validation, la copie filtrée, le rendu et le filtre d'événements.
- Aucun refus ni aperçu ne révèle une information cachée ; ATTAQUER sur cible cachée donne le même code que sur cible inexistante.
- Les copies de simulation portent un cache valable sans recalcul coûteux.

## Decision

**1. Un module, des fonctions sans état.** `VisionService` (`src/core/vision/`) est un ensemble de fonctions statiques ; il **est le seul** code qui lit la position des unités, des nœuds, des ruines et le propriétaire réel pour répondre à « qui voit quoi », et le seul qui écrit la tranche Visibilité (`découverte`, octet 1, `dormant_mémorisé`) et le cache. Aucun nœud, aucun singleton, aucune horloge.

**2. `ViewCache`, transitoire, attaché à l'état.** `GameState.view_cache` (`ViewCache`, `RefCounted`) tient, par faction, un `PackedByteArray` de `W × H` octets : `vue_maintenant`. Il est **copié par `duplicate_state()`**, **en profondeur** : `ViewCache.duplicate()` appelle `duplicate()` sur **chaque** `PackedByteArray` ; `Array.duplicate()` seul est **interdit** (vérifié : il est superficiel, les `PackedByteArray` restent partagés par référence et une simulation de l'IA écraserait la vue réelle du joueur ; `duplicate(true)` ou une boucle les rend indépendants et conserve le type). Coût : 256 octets par faction, de l'ordre de la microseconde (0,26 µs mesuré pour **un** tableau, à remesurer avec la copie profonde des deux), bien moins cher qu'un recalcul ; **reconstruit** par `VisionService.rebuild(state)` après `from_bytes` et `restore_from` (l'annulation du déplacement restaure donc aussi la vue), ignoré par `to_bytes` et `equals`. La validation de l'état vérifie : tout octet du cache à 1 correspond à une tuile `découverte`. Une incohérence dans un fichier chargé est une **corruption** : le fichier est refusé (repli sur `.bak`, ADR-0006), `from_bytes` ne répare jamais l'état en silence (l'égalité après aller-retour en dépend ; **GDD SYNC** : GDD 5, règle 24, qui parlait de poser le bit). **`filtered_copy(f)` ne garde que la ligne `f`** du `ViewCache` et de la tranche Visibilité (`découverte`, octet 1, `dormant_mémorisé`) ; les lignes des autres factions sont mises à zéro (sinon l'IA lirait la vision du joueur, donc la position de ses unités cachées).

**3. Champs précalculés, tenus par un `VisionContext` injecté.** `FieldTable` (`RefCounted`, hors de l'état, construite une fois par carte à la mise en place ou paresseusement, partagée en lecture seule) donne, pour un couple (tuile source, rayon effectif), la liste ordonnée des indices de tuiles vues, occlusion comprise (formule 3 du GDD 2), **sur le vrai terrain**. Elle n'est utilisée que sur l'état réel. Elle est tenue, avec les rayons de vue par type (`UnitTypes`, ADR-0009), par un `VisionContext` (`RefCounted`, immuable) construit par la fabrique de session (ADR-0008) et passé aux fonctions : aucun accès statique global au catalogue (ADR-0009). Mémoire : plusieurs centaines de listes (256 tuiles × 3 rayons effectifs, 40 à 80 indices de 4 octets), soit de l'ordre de **100 à 250 Ko** hors état, à mesurer (et non « quelques dizaines de Ko » comme l'estimait le GDD 5).

**4. Recalcul dans `apply`, par les fonctions du propriétaire 5.** `recompute(state, ctx) -> VisionDelta` et `reveal_step(state, ctx, unit_id, tile) -> VisionDelta` sont appelés **dans `apply`** des types DÉPLACER, ATTAQUER, CAPTURER, RÉVEILLER, MONTER_NŒUD et EXÉCUTER_UNE_INTENTION (règle 9 du GDD 5). `VisionContext.factions` porte l'ensemble des factions à recalculer : **les deux** pour la `RuleTable` réelle, **aucune** pour la variante de simulation (§8). `VisionDelta` (valeur) est ce que le pipeline remonte dans `ApplyResult` : `révélé` (cas a à e de la règle 13 du GDD 5), la liste triée des tuiles nouvellement découvertes (pour TUILES_RÉVÉLÉES, règle 14) et les unités nouvellement vues. Le déplacement appelle `reveal_step` à chaque pas (règle 11 du GDD 5). `recompute` remet à zéro le cache des factions concernées, parcourt les sources par id croissant (unités éveillées puis nœuds), pose le cache et `découverte`, puis rafraîchit l'octet 1 des tuiles VISIBLES (règle 5, avec son exception de perte ou gain de propriétaire).

**5. Un prédicat, deux consommateurs.** Le prédicat est `can_see(cache, faction, tile)` pour une tuile, `can_see_unit(state, cache, faction, unit_id)` et `can_see_node(state, cache, faction, node_id)` pour les entités (une unité propre est toujours vue ; une unité est vue si et seulement si sa tuile l'est ; un nœud adverse hors de vue se montre sans niveau). `FactionView` (ADR-0004) répond à ses requêtes en appelant ces fonctions, et `filtered_copy(faction)` (ADR-0003) construit son état en appelant **les mêmes** : lignes cachées absentes, propriétaire des tuiles hors vue lu dans l'octet 1, dormants d'après le bit `dormant_mémorisé`, ruines non repérées absentes. **Terrain** : l'état filtré porte sa **propre colonne de terrain** (copie de 256 octets, au lieu du terrain réel partagé par référence) où toute tuile non `découverte` vaut « plaine de coût 1, non occultante » (règle 12 du GDD 5, règle 11 du GDD 1) ; sans cela l'IA validerait et planifierait avec l'eau et les montagnes réelles. Un **test de parité** compare, sur des états aléatoires, chaque réponse de `FactionView` à la lecture de `filtered_copy` pour toutes les requêtes, terrain compris (AC-BR et AC-IA14), et vérifie que la ligne de l'autre faction est vide. Aucun autre code ne décide de la visibilité.

**6. Information cachée dans les refus.** Les validations ne lisent que la `FactionView`. Une cible cachée, inexistante, périmée ou dormante cachée renvoie le même code avec les mêmes paramètres (GDD 5, règles 18 et 19). Les **écarts permis** entre ce que voit `validate` et ce que rencontre `apply` sont l'embuscade (unité ennemie cachée) **et** un obstacle de terrain non découvert (eau) : dans les deux cas l'unité s'arrête sans erreur, le déplacement est consommé et l'obstacle devient vu (règle 12 du GDD 5, règle 11 du GDD 4 ; **GDD SYNC** : ADR-0004 §7 étendu).

**7. Filtre d'événements.** `event_visible(before: ViewCache, after: ViewCache, faction, event) -> bool` est une fonction pure de `VisionService`. Le pipeline copie le cache **avant** l'application, applique, puis filtre le lot d'événements pour la faction du joueur avant `EventSink.push` : un événement de l'autre faction n'est publié que si ses tuiles étaient VISIBLES avant ou après. `TUILES_RÉVÉLÉES` n'existe que pour le joueur, jamais pour l'IA.

**8. Simulations de l'IA : pas de recalcul.** La variante de simulation de la `RuleTable` (`RuleTable.simulation()`) a `VisionContext.factions = []` : `apply_on` ne recalcule rien et ne révèle rien. L'IA planifie sur sa vue figée, reperçue avant **chaque** appel à `plan_next` à partir de l'état réel (ADR-0005 §1) ; l'effet d'une embuscade n'est donc pas simulé (il l'est dans le run réel). Cela règle à la fois la fuite de terrain par `FieldTable` (calculée sur le vrai terrain) et le coût : le recalcul n'entre pas dans les 2 500 copies du tour d'IA, contrairement à ce que craignait le GDD 5 (750 ms).

**9. Rendu du brouillard.** Hors de ce périmètre : le canal `fog` du shader et les transitions sont décidés par ADR-0001 ; la présentation lit `TUILES_RÉVÉLÉES`, le cache reconstruit au chargement (`RESYNCHRONISER`) et jamais l'état brut.

**10. Budgets et seuil de repli.** Deux budgets séparés au registre : **recalcul de vue par commande réelle ≤ 1 ms** pour deux factions (GDD 5), compté dans l'image du commit mais distinct du 0,3 ms de validation plus application des commandes de l'IA (ADR-0004), qui n'en inclut pas puisque les simulations ne recalculent pas ; **plage de déplacement ≤ 2 ms** (ADR-0010). Si la mesure sur l'appareil dépasse 1 ms, `recompute` passe à un compteur par tuile et par faction (1 octet, même emplacement dans `ViewCache`) ; le contrat des fonctions ne change pas.

**11. Règles du GDD 5 portées par le module.** Règle 13 : le prédicat « a révélé » est `VisionDelta.révélé`. Règle 17 : `dormant_mémorisé` est posé à la mise en place pour chaque faction et effacé quand la tuile est VISIBLE sans dormant. Règle 21 : la position de l'auteur d'une intention n'est transmise à une faction que si sa tuile est VISIBLE pour elle. Règle 22 : à la mise en place, le territoire de chaque nœud possédé est au moins EXPLORÉ. Règle 24bis : le score décisif est la **seule exception nommée** à « aucun autre code ne décide de la visibilité » (un agrégat sur des données hors vue, sans décomposition ni delta, GDD 17 règles 4 et 23). Règle 20 : `event_visible` filtre les événements de l'autre faction.

### Architecture Diagram

```
 Commande appliquée (ADR-0004)                          Pipeline réel : factions {J, IA}     apply_on (IA) : {IA}
   │ DÉPLACER : reveal_step à chaque pas ──┐                       │                                │
   ▼                                       ▼                       ▼                                ▼
 VisionService (fonctions statiques) ── écrit : découverte, octet 1, dormant_mémorisé (état)  +  vue_maintenant (ViewCache)
   │  lit : FieldTable (partagée, lecture seule), unités éveillées, nœuds possédés
   ├─► can_see(cache, f, tuile) ──► FactionView (validation)       ┐ test de parité
   ├─► can_see(cache, f, tuile) ──► filtered_copy(f) (IA, aperçus) ┘
   └─► event_visible(avant, après, f, evt) ──► lot filtré ──► EventSink.push
 GameState ── duplicate_state() copie ViewCache ; from_bytes / restore_from ──► rebuild(state)
```

### Key Interfaces

```gdscript
class_name ViewCache extends RefCounted          # transitoire : jamais sérialisé ni comparé
var seen: Array[PackedByteArray]                 # par faction, W×H octets : vue_maintenant
func duplicate() -> ViewCache

class_name FieldTable extends RefCounted         # partagée, lecture seule, sur le vrai terrain
func field(source_tile: int, effective_radius: int) -> PackedInt32Array

class_name VisionContext extends RefCounted      # immuable, injecté par la fabrique de session
var fields: FieldTable
var view_radius: PackedInt32Array                # par type d'unité (UnitTypes, ADR-0009)
var factions: PackedInt32Array                   # à recalculer dans apply : [J, IA] réel, [] simulation

class_name VisionDelta extends RefCounted        # valeur rendue dans ApplyResult
var revealed: bool
var discovered_tiles: PackedInt32Array           # triées, pour TUILES_RÉVÉLÉES (joueur seulement)
var newly_seen_units: PackedInt32Array

class_name VisionService extends RefCounted      # fonctions statiques, aucun état
static func rebuild(state: GameState, ctx: VisionContext) -> void                # après from_bytes / restore_from
static func recompute(state: GameState, ctx: VisionContext) -> VisionDelta     # ctx.factions : deux (réel) ou aucune (simulation)
static func reveal_step(state: GameState, ctx: VisionContext, unit_id: int, tile: int) -> VisionDelta
static func can_see(cache: ViewCache, faction: int, tile: int) -> bool
static func can_see_unit(state: GameState, cache: ViewCache, faction: int, unit_id: int) -> bool
static func can_see_node(state: GameState, cache: ViewCache, faction: int, node_id: int) -> bool
static func tile_state(state: GameState, faction: int, tile: int) -> int        # UNKNOWN / EXPLORED / VISIBLE
static func event_visible(before: ViewCache, after: ViewCache, faction: int, event: PresentationEvent) -> bool
```

### Implementation Guidelines
- Aucun code hors `VisionService` **ne doit** décider de la visibilité ni lire le propriétaire réel d'une tuile pour une faction ; la validation **doit** passer par `FactionView`.
- `ViewCache` et `FieldTable` **ne doivent jamais** être sérialisés, comparés par `equals` ni écrits ailleurs que par `VisionService`.
- `duplicate_state()` **doit** copier le cache ; `restore_from`, `from_bytes` et la mise en place **doivent** appeler `rebuild`.
- Le parcours **doit** se faire par id croissant ; la table de champs **doit** être construite sans `Dictionary` parcouru.
- Tout nouveau lecteur d'information de faction **doit** être ajouté au test de parité `FactionView` / `filtered_copy`.

## Alternatives Considered

### Alternative 1: Vision actuelle stockée dans l'état (GDD 5 avant la PR #3)
- **Description**: `vue_maintenant` dans la tranche Visibilité, validée « stocké = recalculé ».
- **Pros**: copie et sauvegarde emportent tout.
- **Cons**: redondant, deux sources de vérité ; contredit la décision de la PR #3.
- **Estimated Effort**: moindre.
- **Rejection Reason**: décision prise ; un cache reconstruit ne diverge jamais.

### Alternative 2: Recalcul à chaque lecture, sans cache
- **Description**: `can_see` parcourt les sources à chaque requête.
- **Pros**: aucun cache à synchroniser.
- **Cons**: 2 à 6 ms par faction (GDD 5) à chaque requête de validation ; ruineux pour les 2 500 copies de l'IA.
- **Estimated Effort**: moindre.
- **Rejection Reason**: budget.

### Alternative 3: Cache dans un objet global
- **Description**: un service singleton garde le cache de la partie réelle.
- **Pros**: simple.
- **Cons**: une simulation ou un aperçu aurait besoin de son propre cache sans le polluer ; viole « aucun singleton » (ADR-0002).
- **Estimated Effort**: moindre.
- **Rejection Reason**: copie, rejeu et tests exigent un cache attaché à l'état.

## Consequences

### Positive
- Une seule définition de « visible », prouvée par un test de parité ; l'IA ne triche pas par construction.
- Copie du cache de l'ordre de la microseconde ; recalcul mesuré à 43 µs par faction sur PC **sans occlusion** (le précalcul et l'occlusion sont à remesurer) ; les simulations de l'IA ne recalculent pas.
- Annulation du déplacement, chargement et rejeu restaurent la vue sans état redondant.

### Negative
- Un objet transitoire de plus à copier et à reconstruire ; oublier `rebuild` après une restauration produit une vue périmée (test dédié).
- Le test de parité est un coût de maintenance à chaque nouvelle requête de faction.

### Neutral
- Le précalcul des champs coûte quelques millisecondes une fois par carte (au chargement).

## Risks
- **Seuil de 1 ms dépassé sur Android** : *Atténuation* : repli sur un compteur par tuile (section 8), mesure sur l'appareil.
- **Fuite par un lecteur oublié** : *Atténuation* : parité exhaustive, motif interdit enregistré, revue des nouvelles requêtes.
- **Cache périmé après `restore_from`** : *Atténuation* : `rebuild` appelé par `restore_from` lui-même, pas par l'appelant ; test AC-BR38.

## GDD Requirements Addressed

| GDD System | Requirement | How This ADR Addresses It |
|------------|-------------|--------------------------|
| brouillard-vision.md (5) | Règles 1 à 5, 9 à 11 : tranche Visibilité, recalcul, champs précalculés, révélation pas à pas | `VisionService`, `ViewCache`, `FieldTable`, `VisionContext`, `reveal_step` |
| brouillard-vision.md (5) | Règles 12, 13, 14, 17, 21, 22, 24, 24bis : obstacle non découvert, « a révélé », TUILES_RÉVÉLÉES, dormants, intentions, mise en place, refus de corruption, score décisif | Sections 5, 6, 10, 11 et `VisionDelta` |
| brouillard-vision.md (5) | Règles 18 à 20, 25 : refus qui ne révèlent rien, filtre d'événements, IA sur état filtré | Section 5 à 7, test de parité |
| modele-etat-partie.md (1) | Règle 11 : vue par faction, simulation sur état reconstruit | `filtered_copy` sur le prédicat partagé |
| commandes-evenements.md (23) | Règle 6 : validation sur la vue, embuscade | `FactionView` sur `can_see` |
| ia-ennemie.md (9) | Règle 3, AC-IA14 : perception sans information cachée | Section 5 |
| recoloration-monde.md (15) | La couleur se déduit de la vue et de l'octet 1 | `tile_state` et cache |

## Performance Implications
- **CPU**: recalcul par faction ≈ 43 µs (PC, union de listes, sans occlusion) ; seuil 1 ms par commande réelle ; précalcul une fois (8 ms sans occlusion) ; aucun recalcul en simulation.
- **Memory**: cache `W × H` octets par faction (256 par faction en 16 × 16, 512 pour deux) ; `FieldTable` de l'ordre de 100 à 250 Ko hors état, partagée, à mesurer.
- **Load Time**: précalcul à la mise en place ou paresseux.
- **Network**: sans objet.

## Migration Plan
Aucun code existant. Amendements : **faits** — ADR-0003 (le cache accompagne `duplicate_state`, `rebuild` après `restore_from` et `from_bytes`, colonne de terrain propre à la copie filtrée), ADR-0004 (`FactionView` sur `can_see`, `apply` rend `VisionDelta`, `RuleTable` instance immuable avec variante de simulation, filtre d'événements dans le flux, écart permis étendu à l'obstacle non découvert), registre (budgets vision et plage) ; **à faire** — GDD 5 (règle 24 : refuser plutôt que réparer ; règle 25 : état reconstruit ; cache transitoire ; mémoire du précalcul).

**Rollback plan**: stocker `vue_maintenant` dans la tranche Visibilité comme avant la PR #3 (changement de schéma, GDD 1 à rétablir).

## Validation Criteria
- Parité `FactionView` / `filtered_copy` sur 1 000 états aléatoires, 0 divergence.
- `recompute` deux factions ≤ 1 ms sur l'appareil Android de référence ; copie du cache indépendante de l'original.
- Après `restore_from` (annulation), la vue égale celle d'avant la commande annulée.

## Related
- ADR-0003 (état, copie filtrée), ADR-0004 (`FactionView`, pipeline), ADR-0005 (perception), ADR-0001 (rendu du brouillard).
- `design/gdd/brouillard-vision.md`, `design/gdd/modele-etat-partie.md`, `design/gdd/carte-tuiles-terrain.md`.
