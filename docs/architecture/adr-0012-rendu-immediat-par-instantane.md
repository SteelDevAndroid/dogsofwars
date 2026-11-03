# ADR-0012: Rendu des tuiles — dessin immédiat sur un instantané de la vue du joueur, effets transitoires minutés par l'horloge de présentation

## Status
Accepted — remplace ADR-0001 (décision de l'utilisateur, 2026-11-03, sur la revue d'architecture du 2026-11-02, A1)

## Date
2026-11-03

## Last Verified
2026-11-03 — d'après le code de `src/presentation/tiles/` (`TileRenderer`, `TileSnapshot`, `TileEffect`, `TilePalette`, `TileLayout`), `src/presentation/sequencer/tile_renderer_handler.gd` et les suites `tests/unit/presentation/tile_renderer_test.gd`, `tile_snapshot_test.gd`, `tile_layout_test.gd` et `tests/unit/sequencer/tile_renderer_handler_test.gd` ; captures retenues dans `production/qa/evidence/` (`sprites-map`, `terrain-textures`, `tiles-hud`, `sequencer-slide`, `first-turn-arrow`). Godot 4.7.2, rendu Mobile sur PC (Xvfb). **Aucune mesure de coût de dessin, ni sur PC ni sur Android ; le rendu Compatibility n'est pas vérifié.**

## Decision Makers
Utilisateur (direction de projet), Claude (rédaction).

## Summary
La carte est dessinée en **mode immédiat** par un seul `Node2D` (`TileRenderer._draw()`) à partir d'un **instantané en lecture seule** (`TileSnapshot`) pris sur la vue du joueur ; les animations sont des **effets transitoires** (`TileEffect`, des données pures) minutés par l'horloge de présentation et dessinés par-dessus l'instantané. Cela remplace le `MultiMeshInstance2D` avec shader d'ADR-0001, qui n'a jamais été construit : il reste le **repli** si la mesure sur appareil dépasse le budget.

## Engine Compatibility

| Field | Value |
|-------|-------|
| **Engine** | Godot 4.7.2 |
| **Domain** | Rendering |
| **Layer** | Presentation |
| **Knowledge Risk** | MEDIUM (aucune API postérieure à la connaissance du modèle ; le comportement de coût sur Android n'est pas sourcé) |
| **References Consulted** | Aucune référence moteur versionnée dans le dépôt (voir `references-externes.md`) ; code et tests cités en Last Verified |
| **Post-Cutoff APIs Used** | Aucune. `CanvasItem._draw`, `queue_redraw`, `draw_texture_rect`, `draw_texture_rect_region`, `draw_rect`, `draw_polyline`, `draw_colored_polygon`, `draw_line`, `draw_string`, `draw_set_transform`, `Image.blend_rect_mask`, `ImageTexture.create_from_image` existent depuis 4.0 et ne sont pas couverts par les références : NOT SOURCEABLE |
| **Verification Required** | (1) **Coût d'un redessin complet** sur Android d'entrée de gamme, rendu Mobile **et** Compatibility, carte 14×14 (la plus grande livrée) puis 16×16 : durée CPU de `_draw`, nombre de commandes de dessin ; (2) coût d'un redessin **à chaque image** pendant un effet (glissement d'une unité, onde) et pendant un défilement de la caméra ; (3) coût de la première teinte d'une texture (`_tint` : copie d'image, mélange, mipmaps) ; (4) mémoire des textures teintées en cache ; (5) pic de la première image (chargement des textures) |

## ADR Dependencies

| Field | Value |
|-------|-------|
| **Depends On** | ADR-0002 (séquenceur, `ClockSource`, `PresentationHandler`) ; ADR-0003 (`StateView`) ; ADR-0007 (`FactionView`, `VisionService.fog_level`) |
| **Supersedes** | ADR-0001 (rendu des tuiles par MultiMesh, shader et `WaveScheduler`) |
| **Enables** | ADR de composition des couches de présentation (HUD, caméra) ; stories d'art et d'effets |
| **Blocks** | Rien |
| **Ordering Note** | Le seuil de repli (section Decision, 8) se décide au spike de mesure sur appareil, avec celui d'ADR-0005 (spike A3) |

## Context

### Problem Statement
ADR-0001, accepté le 2026-10-30, décrivait un rendu en MultiMesh à deux vec4 par instance, un shader portant la progression de l'onde, un `g_time` global et un module pur `WaveScheduler`. Rien de cela n'a été construit : le prototype de rendu n'a jamais été migré, et le rendu livré (2026-11-02) dessine directement les textures de l'art bible avec `_draw()`. Le registre, les ADR 0002, 0007 et 0009 et le GDD 15 renvoyaient pourtant à un contrat de données à huit canaux et à un shader qui n'existent pas. La revue du 2026-11-02 (A1) a demandé de décider : documenter le rendu réel, ou construire celui d'ADR-0001. L'utilisateur a choisi de documenter le rendu réel.

### Constraints
- Cible Android d'abord, puis iOS ; Godot 4.7.2, GDScript ; rendu Mobile (`project.godot`), Compatibility non exclu.
- Cartes jusqu'à 16×16 (256 tuiles) ; deux cartes livrées, 12×12 et 14×14.
- L'état de jeu est final avant les événements ; la présentation ne bloque jamais la logique et ne lit **que** ce que le joueur sait (ADR-0007).
- Mêmes règles de jeu quel que soit le rendu : le mode daltonien ne change que des couleurs (GDD 15, règle 20).
- Au plus 3 flashs par seconde (WCAG 2.3.1) ; états finaux directs en animations réduites (ADR-0002, Écarts).
- Art livré : textures par terrain (3 variantes), lisières de brouillard, sprites d'unités, de nœuds et de ruines, effets (`assets/art/`).

### Requirements
- Aucune fuite d'information cachée jusqu'à l'écran, par construction.
- Reconstruction complète depuis l'état (chargement, RESYNCHRONISER) sans animation.
- Tests unitaires du minutage des effets sans moteur de rendu (horloge factice).

## Decision

**1. Un nœud, un `_draw()`.** `TileRenderer` (`Node2D`, `process_priority` 10) dessine dans l'ordre : tuiles (terrain, lisières de brouillard, teinte et motif du propriétaire), nœuds, ruines, unités, marqueurs de menace, flèche d'aide, effets, crochets de cible, portée, sélection. Aucun nœud, matériau ni shader par tuile. Les unités, nœuds et ruines sont dans le même dessin que les tuiles (pas de couches séparées).

**2. L'instantané est la seule entrée de lecture.** `TileSnapshot.take(state, catalog)` construit une valeur (`RefCounted`) à partir de `FactionView(JOUEUR)` et de `VisionService.fog_level` : brouillard et terrain par tuile, dernier propriétaire vu, nœuds, ruines et unités **découverts**. Deux lectures passent hors de `FactionView`, à connaître : le drapeau « lue » d'une ruine déjà connue du joueur, et `IntentionMarkers.visible_to_player(state)`, qui filtre lui-même les marqueurs de menace pour le joueur. Le renderer **ne lit jamais l'état réel** (`GameState`) ni une autre vue : la frontière anti-fuite d'ADR-0007 est tenue par le type de l'entrée. Une tuile non découverte ne porte rien, une tuile explorée porte ce que le joueur se rappelle (sans unité), une tuile visible porte tout. Une unité n'est dessinée que sur une tuile visible, sauf les siennes.

**3. Quand l'instantané est repris.** L'état du Core est déjà final quand ses événements jouent. Pendant un lot, la carte garde l'**ancien** instantané et les effets jouent par-dessus ; `MatchScreen.refresh` reprend un instantané neuf à la fin du lot (`batch_finished`), à l'état inactif (`idle_reached`) et au chargement. Une resynchronisation (`rebuild_from_state`) efface les effets et la carte affiche l'état directement.

**4. Effets transitoires minutés par l'horloge de présentation.** `TileEffect` est une donnée pure (genre, début, durée, tuiles, texte, couleur) ; `progress(now)` est une fonction pure. `TileRendererHandler` (adaptateur du séquenceur, ADR-0002) transforme chaque événement en effet : `MOVE` (glissement), `LINE` (trait d'attaque), `FLOAT_TEXT` (chiffre de dégâts ou de soin), `GHOST` (affaissement d'une unité détruite), `WAVE` (recoloration), `PULSE` (anneau de sélection). Le temps est `ClockSource.current()` (injecté ; `FakeClock` en test) : jamais `TIME`, `Time.get_ticks_*`, `create_timer` ni `Tween` dans le rendu des tuiles. Les durées sont des données (`presentation.json` : `move_step_ms`, `attack_line_ms`, `hit_ms`, `destroy_ms`, `recolor_ms`, `damage_number_ms`).

**5. Politique de redessin.** `queue_redraw()` est appelé sur un changement d'instantané, de sélection, de cibles, de portée, de mise en page ou de rectangle de découpe. Un redessin **à chaque image** n'a lieu que tant qu'un effet est actif ou que la flèche d'aide des premiers tours oscille hors animations réduites. Au repos, aucun redessin et aucun travail par image (`_process` ne fait que tester deux conditions).

**6. Animations réduites et palette.** En animations réduites (`still`, `SequenceContext.reduced`), les glissements et les ondes durent 0 ms ; les étapes d'attaque gardent leurs durées (chiffres 800 ms, trait 250 ms) et le séquenceur espace les changements de couleur d'un créneau de temps réel (ADR-0002, Écarts). La palette daltonienne est un drapeau du renderer (`colorblind`) qui change seulement la table des teintes de `TilePalette` ; il n'écrit aucun état de partie. La couleur n'est jamais le seul signal : un chevron marque le camp du joueur, une barre le camp ennemi.

**7. Découpe et mise en page.** `TileLayout` (géométrie pure, partagée avec la surface d'entrée) donne le rectangle de chaque tuile ; la caméra (`MapCamera`) fournit la mise en page. La zone visible est découpée **dans le dessin** (`clip_area`, `visible_tiles()`), pas par la découpe du moteur, qui laissait des tuiles parasites hors de la zone.

**8. Budget et repli.** Budget proposé (registre `tile-rendering`, inchangé) : couche des tuiles ≤ 1 ms de CPU par image de redessin, 0 allocation par image au repos. **Non mesuré.** Ordre des replis si la mesure sur appareil le dépasse : (a) séparer une **couche statique** (terrain, brouillard, propriétaires, nœuds, ruines), redessinée seulement quand l'instantané ou la mise en page change, d'une **couche dynamique** (unités, effets, sélection) redessinée à chaque image d'effet ; (b) mettre en cache les commandes par tuile ; (c) en dernier, le **MultiMesh d'ADR-0001**, dont le contrat de données et le module `WaveScheduler` restent la référence de conception.

### Architecture Diagram

```
 GameState ─(FactionView JOUEUR + fog_level)─► TileSnapshot (valeur, lecture seule)
                                                   │ pris à la fin d'un lot / à l'état inactif / au chargement
 Séquenceur (ADR-0002) ─► TileRendererHandler ─► TileRenderer (Node2D, priorité 10)
        événements             add_effect(TileEffect)      _draw() : tuiles, nœuds, ruines, unités,
        ClockSource.current() ──────────────────────────►          menaces, effets, cibles, portée, sélection
 MapCamera ─► TileLayout + clip_area ───────────────────►  (aucun nœud par tuile, aucun shader)
 TilePalette (+ drapeau colorblind) ────────────────────►
```

### Key Interfaces

```gdscript
class_name TileSnapshot extends RefCounted
static func take(state: GameState, catalog: DataCatalog) -> TileSnapshot   # FactionView(JOUEUR) + fog_level, jamais l'état réel

class_name TileEffect extends RefCounted                                   # donnée pure
enum Kind { MOVE, LINE, FLOAT_TEXT, GHOST, WAVE, PULSE }
func progress(now: float) -> float                                         # 0 au début, 1 une fois fini
func is_over(now: float) -> bool

class_name TileRenderer extends Node2D
var clock: ClockSource                       # injectée ; null pour une image fixe
var colorblind: bool                         # table de teintes seulement, jamais un état
var still: bool                              # animations réduites : aucune oscillation
func show_state(state: GameState, catalog: DataCatalog) -> void   # reprend l'instantané
func add_effect(effect: TileEffect) -> void
func clear_effects() -> void                                       # resynchronisation
func set_selection(tile: int, reachable: PackedInt32Array) -> void
func set_targets(tiles: PackedInt32Array, chosen: int) -> void
func set_clip_rect(rect: Rect2) -> void
```

### Implementation Guidelines
- Le renderer **ne doit jamais** lire `GameState` hors de `TileSnapshot.take`, ni écrire un état de jeu.
- `TileSnapshot.take` **ne doit** lire que par `FactionView(JOUEUR)`, `VisionService` et les deux lectures filtrées de la Decision 2 ; une nouvelle donnée affichée **doit** entrer dans l'instantané avec un test de non-fuite.
- Un effet **doit** rester une donnée pure ; son minutage **doit** dépendre de la seule horloge injectée.
- Il **ne faut pas** créer un nœud, un matériau ou un shader par tuile, ni utiliser `TIME`, `Tween` ou `create_timer` pour animer la carte.
- Un redessin par image **doit** rester conditionné à un effet actif ou à la flèche d'aide.
- Les durées **doivent** rester dans `presentation.json`.

## Alternatives Considered

### Alternative 1: MultiMesh, deux vec4 par instance, shader et `WaveScheduler` (ADR-0001)
- **Description**: une instance par tuile, données d'onde dans les canaux d'instance, progression calculée dans le shader.
- **Pros**: un seul appel de dessin, coût par image quasi nul au repos, onde déterministe testable.
- **Cons**: jamais construit ; il fallait un shader, des canaux d'instance non vérifiés sur Android (`use_colors`, demi-flottants en Compatibility), un `g_time` global et une composition avec le dessin des unités et des textures de l'art bible, que le prototype (en 2D carré) ne couvrait pas.
- **Rejection Reason**: la valeur ajoutée est un budget de performance que rien ne montre dépassé, au prix d'un travail important ; il reste le **repli** (Decision, 8).

### Alternative 2: `TileMapLayer`
- **Description**: tuiles dans un `TileMapLayer` avec atlas et tuiles alternatives.
- **Pros**: rendu standard, groupé par le moteur.
- **Cons**: le brouillard, les lisières orientées et l'instantané par vue du joueur se mappent mal sur des données de tuile ; non essayé.
- **Rejection Reason**: contrôle insuffisant pour les lisières et les teintes de camp ; non essayé.

### Alternative 3: Un nœud (`Sprite2D`) par tuile
- **Description**: 144 à 256 nœuds animés par `Tween`.
- **Pros**: simple.
- **Cons**: l'état d'animation est réparti dans les nœuds, ce qui complique la reconstruction ; interdit par le registre (`per_tile_node_or_material`).
- **Rejection Reason**: mêmes raisons qu'ADR-0001.

## Consequences

### Positive
- Le rendu existe, est testé sans moteur de rendu (instantané, minutage des effets sur horloge factice) et suit l'art bible.
- La frontière anti-fuite est tenue par le type de l'entrée : le renderer ne peut pas lire une information cachée, y compris pour une future fonctionnalité.
- Aucun état d'animation caché : une resynchronisation efface les effets et c'est fini.
- Le repli (couche statique, puis MultiMesh) est documenté et ne change ni le contrat d'instantané, ni celui des effets.

### Negative
- Un redessin complet de la carte (terrain, lisières, propriétaires, nœuds, unités) à chaque image d'effet : de l'ordre de plusieurs centaines à environ 1 500 commandes de dessin sur une carte pleine (estimation, non mesurée).
- Pas de calcul d'onde déterministe par anneaux (voir Écarts ci-dessous) ; le code de l'onde du GDD 15 n'est pas testé de façon isolée.
- Les teintes de `TilePalette` sont des constantes du code, pas un fichier de données (ADR-0009 prévoyait `TABLE_TEINTES`).
- La première teinte d'une texture coûte une copie d'image : repérée par la vérification 3.

## Risks
- **Coût du redessin sur Android d'entrée de gamme** (non mesuré). *Atténuation* : spike de mesure ; replis ordonnés (Decision, 8).
- **Coût du défilement de la caméra** (redessin complet à chaque image de défilement). *Atténuation* : `visible_tiles()` ne dessine que les tuiles qui touchent la zone ; couche statique si la mesure l'exige.
- **Police des chiffres flottants** : `TileRenderer` dessine avec `ThemeDB.fallback_font`, pas avec la police Inter des menus. *Atténuation* : à vérifier avec le thème (hors périmètre).
- **Écart au GDD 15** (ci-dessous) non tranché : l'onde ne reproduit pas le GDD.

## Écarts au GDD 15 (recoloration du monde), à décider
Le rendu livré ne reproduit pas les formules F3 à F5 du GDD 15 :
- **Anneaux** (règles 12 et 13) : toutes les tuiles d'un groupe `TileOwnersChangedEvent` se fondent **ensemble** sur `recolor_ms` (400 ms) ; il n'y a ni anneau par distance à la source, ni retard `T_ANNEAU` (200 ms), ni plafond `T_TOTAL_MAX`.
- **Fondu binaire** (règle 14) : la recoloration est une teinte de camp dont l'opacité monte à 0,30 sur la tuile (`WAVE`), pas un fondu gris ↔ teinte, et f → g ne passe pas par le gris.
- **Écriture pendant une onde** (règle 15) : deux ondes se jouent en parallèle sur la même tuile, sans animation depuis la valeur affichée.
- **Révélation de brouillard** : le passage d'un état de brouillard à l'autre est instantané (pas de transition de 150 ms).
- **Source effective** (F7, règle 18) : l'événement `TileOwnersChangedEvent` ne porte ni source ni drapeau VISIBLE par tuile.

Deux issues, au choix du game-designer : **simplifier le GDD 15** (une seule teinte qui apparaît, sans anneaux) ou **construire les anneaux** dans `TileRendererHandler` (une fonction pure de la source et de la distance de Chebyshev, testée sur horloge factice, qui crée un `WAVE` par anneau avec un départ décalé). Cet ADR ne tranche pas.

## GDD Requirements Addressed

| GDD System | Requirement | How This ADR Addresses It |
|------------|-------------|--------------------------|
| recoloration-monde.md (15) | Règles 16 et 20, E10 : animations réduites, palette daltonienne sans écrire d'état | `still`, durées à 0, drapeau `colorblind` qui ne change que `TilePalette` |
| recoloration-monde.md (15) | Règles 12 à 15 : anneaux, fondu binaire, écriture pendant une onde | **Non couvert** : voir Écarts |
| brouillard-vision.md (5) | INCONNUE aplatie, EXPLORÉE assombrie, VISIBLE ; aucune fuite | `TileSnapshot` sur `FactionView` et `fog_level` ; texture de brouillard, assombrissement `MEMORY_DIM`, lisières orientées |
| carte-tuiles-terrain.md (2) | Carte 12×12 à 16×16, tuiles carrées | `TileLayout` et `visible_tiles()` |
| hud-systeme.md (17) | Règles 2, 10, 16, 17 : le HUD ne lit pas l'état pendant la file, reconstruction sans onde | Instantané repris à la fin d'un lot ; `rebuild_from_state` efface les effets |
| art-bible.md §4, §8 | Teintes de camp, motif en plus de la couleur | `TilePalette`, chevron et barre |
| accessibility-requirements.md | Pas de signal par la seule couleur ; au plus 3 flashs par seconde | Motifs de camp ; créneaux de temps réel du séquenceur (ADR-0002) |

## Performance Implications
- **CPU**: au repos, aucun redessin ; pendant un effet ou un défilement, un redessin complet par image (non mesuré). Budget proposé 1 ms par redessin.
- **Memory**: textures de l'art livré (3 variantes par terrain, sprites) et textures teintées en cache (une par type et par couleur).
- **Load Time**: chargement de toutes les textures à la création du nœud ; pic de première image non mesuré.
- **Network**: sans objet.

## Migration Plan
Aucune migration de code : le rendu décrit est celui qui existe. Marquer ADR-0001 comme remplacé, mettre à jour le registre (`tile_render_data`, `tile_wave_animation`, `shader_reads_game_state`, `global_shader_parameter_get_in_game` marqués remplacés ; `per_tile_node_or_material`, `renderer_writes_game_state`, `tile-rendering` et `color_event_to_renderer` rattachés à cet ADR) et corriger les renvois d'ADR-0002, ADR-0007 et du GDD 15.

## Validation Criteria
- `TileSnapshot` ne contient ni unité cachée, ni nœud non découvert, ni ruine non repérée (suite `tile_snapshot_test.gd`, dont `test_the_snapshot_of_random_states_never_shows_what_the_player_cannot_see` sur 120 états aléatoires).
- Le minutage des effets sur horloge factice : début, milieu, fin, durée 0 en animations réduites (`tile_renderer_handler_test.gd`).
- Mesure sur l'appareil Android de référence (Mobile et Compatibility) : durée de `_draw` et nombre de commandes, carte 14×14 puis 16×16, au repos, pendant un glissement d'unité, pendant un défilement ; décision du repli (Decision, 8) sur le seuil de 1 ms.
- Captures retenues validées par l'art-director : carte pleine, brouillard, mode daltonien, animations réduites.

## Related
- Remplace : ADR-0001 (`docs/architecture/adr-0001-rendu-des-tuiles.md`), conservé pour son contrat MultiMesh, qui sert de repli.
- ADR-0002 (séquenceur, horloge, gestionnaires), ADR-0003 (`StateView`), ADR-0007 (vision, `FactionView`), ADR-0009 (données), ADR-0010 (caméra et entrées).
- GDD : `design/gdd/recoloration-monde.md` (15), `brouillard-vision.md` (5), `carte-tuiles-terrain.md` (2), `hud-systeme.md` (17). Art bible : `design/art/art-bible.md` §4, §8.
- Revue : `docs/architecture/architecture-review-2026-11-02.md`, A1.
