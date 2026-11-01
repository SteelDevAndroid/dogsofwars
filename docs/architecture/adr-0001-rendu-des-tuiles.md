# ADR-0001: Rendu des tuiles — MultiMesh, deux vec4 par instance, module d'onde pur

## Status
Accepted

## Date
2026-10-30

## Last Verified
2026-10-30 — sur le prototype `prototypes/rendu-tuiles/` (Godot 4.7.2, rendu Mobile sur PC, un vec4 par instance) et sur un test réel de godot-specialist (données personnalisées en float32). **Le second vec4 (`use_colors`), Android et le rendu Compatibility ne sont pas vérifiés.**

## Decision Makers
Utilisateur (direction de projet), Claude (rédaction), godot-specialist et technical-director (validation avant écriture).

## Summary
Le rendu de 144 à 256 tuiles, avec l'onde de recoloration, la palette daltonienne et les états de brouillard, doit rester à faible coût sur Android d'entrée de gamme tout en restant une pure projection de l'état. On retient un `MultiMeshInstance2D` unique avec **deux vec4 par instance** (données personnalisées et couleur d'instance), un temps de présentation global en uniforme de shader global, une palette de 4 teintes en tableau uniforme, et un **module GDScript pur** (`WaveScheduler`) qui est la source de vérité de l'onde ; le shader n'en est qu'un portage.

## Engine Compatibility

| Field | Value |
|-------|-------|
| **Engine** | Godot 4.7.2 |
| **Domain** | Rendering |
| **Layer** | Presentation |
| **Knowledge Risk** | HIGH (4.5, 4.6 et 4.7 postérieures à la connaissance du modèle) |
| **References Consulted** | `docs/engine-reference/godot/VERSION.md`, `docs/engine-reference/godot/modules/rendering.md`, `docs/engine-reference/godot/breaking-changes.md`, `docs/engine-reference/godot/deprecated-apis.md`, `prototypes/rendu-tuiles/REPORT.md` |
| **Post-Cutoff APIs Used** | Aucune API des références 4.5 à 4.7 n'est utilisée ; le **Shader Baker** (4.5) est envisagé pour la compilation. `MultiMesh.use_custom_data`, `use_colors`, `set_instance_custom_data`, `set_instance_color`, `RenderingServer.global_shader_parameter_*`, `varying flat`, `INSTANCE_CUSTOM`, `COLOR` en canvas_item et les tableaux de uniformes **ne sont pas couverts** par les références : NOT SOURCEABLE. Ces API existent depuis 4.0 ; confirmées pour un vec4 par le prototype et par un test réel de godot-specialist (4.7.2.stable.official.ed1daf0bf, Vulkan Mobile, Intel UHD : données personnalisées en float32 sans compression, 12 floats par instance) ; `use_colors` non testé |
| **Verification Required** | (0) **Avant le test Android** : un prototype avec `use_colors` lit bien le second vec4 dans le shader (valeurs non compressées, hors plage 0 à 1 comprise) ; (1) même code sur un Android d'entrée de gamme, rendu Mobile **et** Compatibility ; (2) en Compatibility, les données d'instance sont-elles stockées en demi-flottants ? Si oui, les instants absolus perdent toute précision : écrire les instants relatifs à une époque courte, ou basculer sur la texture de données (Alternative 4) ; (3) précision des flottants du **fragment** (`highp` ou `mediump`) sur Android ; (4) déclaration de `g_time` dans les Project Settings (Shader Globals) ; (5) coût de 256 écritures par commande contre une écriture groupée de `multimesh.buffer` ; (6) pics de 44 ms et 24,7 ms du prototype ; (7) parité du module pur et du shader sur des instants échantillonnés |

## ADR Dependencies

| Field | Value |
|-------|-------|
| **Depends On** | ADR-0002 `docs/architecture/adr-0002-evenements-de-presentation.md` (file, séquenceur, `PresentationClock`, `StateView` ; le renderer consomme la file, règles 10, 13, 16 et 17 de `hud-systeme.md`) — doit être Accepted avant l'acceptation de celui-ci |
| **Enables** | ADR de composition des couches de présentation (unités, marqueurs, HUD au-dessus des tuiles) |
| **Blocks** | Les stories de **rendu** de l'epic « Recoloration du monde » et de la présentation du brouillard. Les stories Logic (module pur `WaveScheduler`, formules F3, F4, F5, F7, tests `tests/unit/recoloration/`) ne dépendent pas de la primitive de rendu et peuvent démarrer |
| **Ordering Note** | Le test Android est une story « spike » de l'epic, à faire sur le contrat amendé ; l'ADR reste Proposed jusque-là |

## Context

### Problem Statement
La recoloration du monde (GDD 15) demande, par tuile, une couleur affichée, un fondu binaire (gris ↔ teinte de faction, f → g par le gris), une onde d'anneaux de 600 à 1 000 ms, une réécriture en plein fondu sans saut (règle 15), une palette qui change avec le mode daltonien sans écrire d'état, trois états de brouillard et un affichage direct en animations réduites. Il faut décider comment le moteur dessine les tuiles et où vit chaque calcul, avant d'écrire du code, car le choix fixe le format de données entre la logique, la présentation et le shader.

### Constraints
- Cible Android d'abord, puis iOS ; Godot 4.7.2, GDScript ; rendu Mobile, Compatibility non exclu (repli probable sur des appareils anciens).
- Carte de 12×12 au MVP, jusqu'à 16×16 (256 tuiles).
- L'état de jeu est final avant l'onde ; la présentation ne bloque jamais la logique et se reconstruit depuis l'état (GDD 23, règle 10).
- Aucune règle de jeu ne dépend du rendu : mêmes octets de couleur dans tous les modes (GDD 15, règles 20 et 21).
- Au plus 3 flashs par seconde (WCAG 2.3.1) ; état final immédiat en animations réduites.
- Les critères AC-RC15 à AC-RC17 et AC-RC19 sont des tests Logic en millièmes entiers : ils ne s'exécutent pas contre un shader.

### Requirements
- Une écriture de donnée par tuile **seulement quand son état change**.
- Onde déterministe : mêmes entrées, mêmes instants de début.
- Une réécriture en plein fondu repart de la saturation affichée, y compris pendant le retard d'anneau de la nouvelle onde.
- Un changement de brouillard en cours de fondu de couleur ne redémarre pas ce fondu (AC-RC22).
- Reconstruction complète depuis l'état (chargement, RESYNCHRONISER) sans onde.

### Budget de performance (proposé, à confirmer par l'utilisateur ; aucun appareil de référence n'est encore nommé)
60 images par seconde visées, 30 en plancher ; couche des tuiles ≤ 1 ms de CPU par image au repos comme pendant une onde ; écriture de 256 tuiles ≤ 0,5 ms ; 1 appel de dessin pour la couche des tuiles ; 0 allocation par image.

## Decision

On rend les tuiles avec **un seul `MultiMeshInstance2D`** par carte, une instance par tuile, `transform_format = TRANSFORM_2D`, `use_custom_data = true` et `use_colors = true`.

**Contrat de données par instance** (versionné ici ; toute modification se fait dans cet ADR, avec le shader) :

| Canal | Champ | Plage | Valeur au repos | Rôle |
|---|---|---|---|---|
| custom `x` | `shown` | 0, 1, 2 | 0 | Indice de teinte affichée (0 gris, 1 PROPRE, 2 ENNEMI) |
| custom `y` | `previous` | 0, 1, 2 | 0 | Indice de teinte au début du fondu |
| custom `z` | `fog` | 0, 1, 2 | 2 | État de brouillard (0 INCONNUE, 1 EXPLORÉE, 2 VISIBLE) |
| custom `w` | `start` | secondes de présentation | −1 | Début du fondu de couleur |
| color `r` | `s0` | 0 à 1 | 1 si teinte, 0 si gris | Saturation de départ, **tenue tant que `t < start`** (règle 15) |
| color `g` | `dur` | secondes | 0,4 | Durée du fondu (`T_FONDU` en onde, `T_REV` en révélation) |
| color `b` | `fog_start` | secondes de présentation | −1 | Début de la transition de brouillard (150 ms), indépendant de `start` |
| color `a` | `fog_prev` | 0, 1, 2 | 2 | État de brouillard avant la transition |

Le brouillard est porté par `fog` seul (pas d'indice de teinte « fond »). Sa transition a son propre instant : changer l'état de brouillard **n'écrit jamais `start`**, donc ne redémarre pas le fondu de couleur ; l'assombrissement se compose en multiplication (AC-RC22).

**Qui calcule quoi.**
- **`WaveScheduler`** (`RefCounted`, GDScript pur, sans nœud) est la **source de vérité** de F3 (anneau), F4 (début et durée), F5 (saturation, réécriture) et F7 (source effective). Il est testé dans `tests/unit/recoloration/` (AC-RC8 à AC-RC22) et tient un **miroir CPU** (`PackedFloat32Array`, 8 flottants par tuile) des données d'instance ; il n'y a jamais de relecture du MultiMesh. L'écriture groupée via `multimesh.buffer` est donc triviale si 256 appels individuels coûtent trop.
- Le **shader** est un **portage** de F5 : progression et saturation à partir de `g_time` et du contrat ; il ne connaît ni la source de l'onde ni l'état de jeu. La parité avec `WaveScheduler` est vérifiée sur des instants échantillonnés et par captures retenues.
- **`TileRenderer`** (nœud) orchestre : il reçoit les événements, appelle `WaveScheduler`, écrit les données et expose les signaux.
- **Entrées** : toutes les entrées de F3, F4 et F7 viennent de **l'événement** COULEUR_DES_TUILES_CHANGÉE (source effective, ou drapeau VISIBLE des tuiles changées), jamais d'une lecture de l'état pendant la consommation de la file (règle 2 de `hud-systeme.md`). Cela exige un amendement de la charge de l'événement (GDD 15, règle 18 ; GDD 23) : **dépendance ouverte**, propriétaire game-designer.
- **Temps** (amendé par ADR-0002) : l'horloge de présentation est **`PresentationClock`**, propriété d'ADR-0002 (`current()`, `paused`, `scale`, avancée par `_process(delta)`, jamais `create_timer`). `TileTimeSource` ne fait qu'**écrire `g_time` depuis cette horloge**, une fois par image : un seul propriétaire du temps, donc pas de divergence entre les instants de début des tuiles et les tenues du séquenceur. `g_time` reste monotone depuis le chargement de la scène, jamais sauvegardé, aucune onde au chargement. **Jamais** `TIME` ni `Time.get_ticks_msec()`. **Source unique** : toute écriture d'instant de début et toute évaluation côté GDScript utilisent la même valeur de `PresentationClock.current()` que le shader. **Priorités de traitement** : `PresentationClock` −20, `TileTimeSource` −10, `PresentationSequencer` 0, `TileRenderer` 10 (la valeur la plus basse est appelée en premier). Le getter `global_shader_parameter_get` n'est **jamais** utilisé (erreur moteur observée) : les tests lisent la valeur côté horloge. Garde-fou : rebaser les instants si la session dépasse plusieurs heures.
- **Déclaration** : `g_time` est déclaré dans les **Project Settings (Shader Globals)**, pas au runtime, pour exister avant tout matériau qui référence le shader ; `global_shader_parameter_add` au runtime n'est qu'un repli de prototype.
- **Palette** : `uniform vec3 pal[4]` (gris, PROPRE, ENNEMI, fond de brouillard), rechargée depuis `TABLE_TEINTES[mode][faction_P]` à chaque changement de mode ou de faction. Le shader ignore les modes (E10, AC-RC30). Les tableaux de uniformes n'ont pas `source_color` : les teintes sont des valeurs sRGB brutes et les mélanges se font en sRGB (règle 20 : mêmes octets de couleur dans tous les modes).
- **Animations réduites** : `WaveScheduler` écrit l'état final (`start` dans le passé). La **fusion en créneaux de 334 ms** (au plus 3 flashs par seconde, E6) appartient au **séquenceur de présentation** (ADR-0002) ; le gestionnaire calcule la dernière valeur par tuile (`handle_merged`).
- **Brouillard** : INCONNUE aplatie à `pal[3]`, EXPLORÉE mélangée à 45 % vers `pal[3]` (valeur en donnée, `FOG_EXPLORED_MIX`), VISIBLE inchangée.

### Architecture Diagram

```
 État de partie (1) ──événements (23)──► Séquenceur de présentation (ADR-0002)
   couleur déduite (15), visibilité (5)          │ lots, durée d'onde, fusion en animations réduites
                                                  ▼
                              TileRenderer (nœud, Presentation)
                               ├─ WaveScheduler (RefCounted, pur) ── F3 F4 F5 F7, miroir CPU 8 floats/tuile
                               ├─ TileTimeSource ──► uniforme global g_time (1×/image, avant TileRenderer)
                               ├─ PaletteTable (TABLE_TEINTES) ──► pal[4]
                               └─ MultiMeshInstance2D (custom data + color) ──► tile.gdshader (portage de F5)
```

### Key Interfaces

```gdscript
# Adaptateur (ADR-0002) : le séquenceur appelle le handler, jamais le TileRenderer directement
class_name TileRendererHandler extends PresentationHandler
func handle(event: PresentationEvent, ctx: SequenceContext) -> PresentationHold   # appelle apply_color_event(event, ctx.t0), rend la durée d'onde
func handle_merged(events: Array[PresentationEvent], ctx: SequenceContext) -> PresentationHold  # animations réduites : dernière valeur par tuile
func rebuild_from_state(view: StateView) -> void                                 # direct, sans onde

class_name TileRenderer extends Node2D     # référence injectée dans l'adaptateur
signal wave_finished(event_id: Vector2i)   # assertions de test seulement ; le séquenceur attend l'échéance de l'horloge
func apply_color_event(event: ColorTilesChanged, t0: float) -> int   # durée de l'onde en ms (F4), 0 si affichage direct
func apply_visibility_event(event: TilesRevealed, t0: float) -> int
func set_palette(mode: int, faction: int) -> void                     # n'écrit aucun état de partie
func set_reduced_motion(on: bool) -> void
```
`StateView` est l'interface en lecture seule déclarée par ADR-0003 (Foundation) et reçue par les gestionnaires d'ADR-0002 (le `TileViewQuery` du premier brouillon n'existe plus). `ColorTilesChanged` est une classe `RefCounted` typée dont `event_id = (révision, index)`. Contrat de données : le tableau de la section Decision ; le miroir CPU et le shader lisent exactement ces huit canaux.

### Implementation Guidelines
- Le moteur de rendu **doit** ne lire que l'état présenté (événements) et, à l'idle seulement, l'état interrogé (`hud-systeme.md`, règle 2) ; il **ne doit jamais** écrire d'état de jeu.
- Le shader **ne doit jamais** lire d'état de jeu autre que les huit canaux, `pal` et `g_time`.
- `WaveScheduler` **doit** rester pur (aucun nœud, aucun accès au moteur de rendu) et **doit** passer les critères AC-RC8 à AC-RC22 avant tout test visuel.
- Il **faut** écrire une tuile seulement quand son octet change, via le miroir CPU, et passer à l'écriture groupée si les appels individuels coûtent trop.
- Il **faut** garder `T_ANNEAU`, `T_FONDU`, `K_MAX`, `T_TOTAL_MAX`, `T_REV`, `FOG_EXPLORED_MIX` et `TABLE_TEINTES` dans des fichiers de données.
- Il **ne faut pas** créer un nœud, un matériau ou un uniforme d'instance par tuile, ni utiliser `TIME`.
- Les unités, nœuds, marqueurs et le HUD **doivent** vivre dans des couches séparées dessinées au-dessus du MultiMesh.

## Alternatives Considered

### Alternative 1: `TileMapLayer` avec matériau de shader
- **Description**: tuiles dans un `TileMapLayer`, couleur et fondu par données de tuile (atlas, tuiles alternatives, `custom_data`).
- **Pros**: outil d'édition de carte intégré ; rendu des tuiles standard.
- **Cons**: passer une donnée dynamique par tuile (instant de début, saturation de départ) à un shader est mal adapté ; non essayé ; les tuiles alternatives multiplient les cas pour 3 factions × états.
- **Rejection Reason**: contrôle insuffisant des données dynamiques par tuile ; l'édition de carte n'est pas nécessaire (cartes en fichiers de données). **Non essayé** ; à reconsidérer si un éditeur de carte est exigé.

### Alternative 2: Un nœud (`Sprite2D` ou `ColorRect`) par tuile
- **Description**: 144 à 256 nœuds animés par `Tween` sur `modulate` ou par matériau.
- **Pros**: simple à écrire, facile à déboguer.
- **Cons**: l'état d'animation réparti dans 256 nœuds ou tweens complique la reconstruction (RESYNCHRONISER, chargement) et la règle 15 ; un appel de dessin par tuile hors regroupement automatique.
- **Rejection Reason**: coût **non mesuré** ; rejeté pour la complexité de l'état d'animation et le contrôle de la règle 15, pas sur un budget chiffré.

### Alternative 3: Un uniforme de shader par instance (`instance uniform`)
- **Description**: un matériau partagé avec `instance uniform` par tuile.
- **Pros**: pas de format de données personnalisé.
- **Cons**: impose une instance par nœud ; nombre limité d'uniformes d'instance.
- **Rejection Reason**: ramène à l'alternative 2.

### Alternative 4: Texture de données RGBA32F
- **Description**: un quad (ou le même MultiMesh) plus une texture de L×H texels en RGBA32F, écrite par `Image` / `ImageTexture.update` depuis le miroir CPU ; le shader lit la tuile par texel.
- **Pros**: autant de canaux qu'on veut ; évite `varying flat`, les données personnalisées et la question de leur précision en Compatibility ; une écriture groupée naturelle.
- **Cons**: une lecture de texture par fragment (non mesurée) ; mise à jour de texture à chaque changement ; un peu plus de code.
- **Rejection Reason**: pas rejetée définitivement : c'est le **repli** si la Verification Required 0 ou 2 échoue (second vec4 indisponible, ou données d'instance en demi-flottants en Compatibility). Le miroir CPU de `WaveScheduler` rend la bascule peu coûteuse.

## Consequences

### Positive
- Un dessin pour toute la carte ; 64 octets par instance (`TRANSFORM_2D` 8 flottants, données personnalisées 4, couleur d'instance 4 : 16 flottants), soit environ 16 Ko de tampon pour 256 tuiles.
- La règle 15 (réécriture sans saut) et AC-RC22 (brouillard sans redémarrage) sont portées par le contrat.
- La source de vérité est testable sans moteur de rendu ; le shader n'est qu'un portage vérifié.
- Palette, animations réduites et daltonisme sans toucher à l'état (règle 20).
- Le renfort de tests Logic démarre avant le test Android.

### Negative
- Un format de données partagé entre GDScript et shader à maintenir, avec un test de parité.
- Pas d'éditeur de tuiles visuel pour les cartes.
- Dépendance à des API non couvertes par les références (données personnalisées, couleur d'instance, uniformes globaux) : le risque est porté par les vérifications 0 à 4.
- Une dépendance ouverte sur la charge de l'événement de couleur (GDD 15/23) et sur ADR-0002.
- **Alignement PR #3 (2026-10-30)** : l'état ne stocke ni couleur de tuile ni vision actuelle ; `couleur(état, vue, P)` est une fonction pure du GDD 15 (cache de couleur hors de l'état) et le miroir CPU du `TileRenderer` n'est jamais une donnée d'état. Au chargement, au `RESYNCHRONISER` et après `restore_from`, le renderer se remplit depuis ce cache reconstruit, sans onde ; en cours de partie il ne lit que l'événement de couleur.

## Risks
- **`use_colors` en canvas_item** : `COLOR` pourrait être modulé ou limité à [0, 1]. *Atténuation* : Verification 0 avant le test Android ; repli : texture de données.
- **Données d'instance en demi-flottants en Compatibility** (de mémoire, non sourcé) : `start` en secondes absolues perdrait toute précision. *Atténuation* : instants relatifs à une époque courte rebasée, ou texture de données.
- **Android d'entrée de gamme** : `varying flat` ou `global uniform` peuvent se comporter différemment ; précision des flottants du fragment inconnue. *Atténuation* : test sur appareil en Mobile et en Compatibility ; repli texture de données.
- **Composition avec les tuiles de l'art bible** (maillages, masque alpha) : le prototype est en 2D carré. *Atténuation* : validation avec l'art-director avant l'acceptation.
- **Compilation au premier affichage** : peu de variantes ; précompiler par un matériau dessiné hors écran ou activer le Shader Baker, à mesurer sur appareil.
- **Pics de 44 ms et 24,7 ms** du prototype, non expliqués : à investiguer avant de conclure sur la fluidité.

## GDD Requirements Addressed

| GDD System | Requirement | How This ADR Addresses It |
|------------|-------------|--------------------------|
| recoloration-monde.md (15) | Règles 10 à 16 : onde par anneaux, fondu binaire, f → g par le gris, une écriture, animations réduites | `WaveScheduler` (F3, F4, F5), contrat de données, `g_time` global |
| recoloration-monde.md (15) | Règle 15, F5 : réécriture sans saut, y compris pendant le retard d'anneau | Champ `s0` tenu tant que `t < start` |
| recoloration-monde.md (15) | Règle 20, E10, AC-RC29 et AC-RC30 : palette daltonienne sans écrire d'état | `pal[4]` rechargée ; le shader ignore les modes |
| recoloration-monde.md (15) | E3, AC-RC22 : le brouillard ne redémarre pas le fondu | `fog_start` et `fog_prev` distincts de `start` |
| recoloration-monde.md (15) | E6, AC-RC33 : fusion en animations réduites | Propriété du séquenceur (ADR-0002) |
| recoloration-monde.md (15) | F7, règle 18 : source effective | Entrées prises dans l'événement ; amendement de la charge demandé |
| brouillard-vision.md (5) | INCONNUE aplatie, EXPLORÉE assombrie, VISIBLE ; révélation 150 ms | Champs `fog`, `fog_start`, `fog_prev` |
| carte-tuiles-terrain.md (2) | Carte 12×12 à 16×16, `tile_index` | Une instance par tuile, ordre `tile_index` |
| hud-systeme.md (17) | Règles 10, 13, 16, 17 ; E39 : onde jamais bloquante, durée connue du HUD, reconstruction sans onde | `apply_color_event` rend la durée, signal `wave_finished`, `rebuild_from_state` |
| art-bible.md §4, §8 | Teintes de faction, ennemi `#C49BEA` | Table `TABLE_TEINTES` en données |

## Performance Implications
- **CPU**: écritures seulement pour les tuiles changées (jusqu'à 49 par capture, 256 pour une élimination) ; 0,6 ms de delta de `_process` en 16×16 sur le PC de test avec un seul vec4 (non représentatif d'Android ; second vec4 non mesuré).
- **Memory**: 64 octets par instance (≈ 16 Ko pour 256 tuiles) plus le miroir CPU de 32 octets par tuile.
- **Load Time**: un shader, compilation à la première utilisation ; Shader Baker envisagé.
- **Network**: sans objet.

## Migration Plan
Sans objet : aucun code de production n'existe. Le prototype `prototypes/rendu-tuiles/` n'est pas migré ; il est réécrit aux standards de production (`.claude/rules/prototype-code.md`). Un second prototype jetable ajoute `use_colors` et le contrat à huit canaux avant le test Android.

## Validation Criteria
- Verification 0 : le second vec4 est lu correctement dans le shader.
- Test sur un Android d'entrée de gamme, Mobile et Compatibility : onde de rayon 3 sur 16×16, sans saut visible, dans le budget de performance, mesures dans un rapport.
- `WaveScheduler` passe AC-RC8 à AC-RC22 en tests unitaires ; test de parité avec le shader ; captures retenues (`production/qa/evidence/recoloration/`) validées par l'art-director.

## Related
- Prototype : `prototypes/rendu-tuiles/REPORT.md`.
- GDD : `design/gdd/recoloration-monde.md` (15), `brouillard-vision.md` (5), `carte-tuiles-terrain.md` (2), `hud-systeme.md` (17), `commandes-evenements.md` (23).
- Art bible : `design/art/art-bible.md` §4, §8.
- ADR-0002 (modèle d'événements de présentation et séquenceur) : écrit (Proposed), dépendance directe.
