# ADR-0014 : Carte en 3D low-poly — tuiles en aplats, caméra orthographique de trois-quarts, même instantané que le rendu 2D

## Status
Accepted — direction confirmée par l'utilisateur le 2026-11-04 sur les captures de la maquette (« beaucoup mieux en 3D »). Remplace ADR-0012 pour le dessin de la carte ; branché dans `MatchScreen` le même jour (Decision 6).

## Date
2026-11-04

## Last Verified
2026-11-04 — d'après `src/presentation/map3d/`, `tools/preview/map3d_preview.gd` et `tests/unit/map3d/map_view_3d_test.gd` ; Godot 4.7.2. Captures rendues par **OpenGL logiciel (llvmpipe) sous Xvfb**, pas par le renderer Mobile sur un téléphone.

## Decision Makers
Utilisateur (direction de projet : « le rendu graphique est nul »), Claude (maquette et rédaction).

## Summary
La carte passe d'un dessin 2D tuile par tuile à une **scène 3D low-poly** : des tuiles en volumes à faces plates et couleurs par sommet, sans texture, une caméra **orthographique inclinée à 42°**, une lumière directionnelle à gauche et devant, avec ombres. C'est la « production hybride » de l'art bible (décision du 2026-10-30), que le rendu 2D (ADR-0012) avait laissée de côté. Le HUD reste en 2D par-dessus, sans changement.

## Engine Compatibility

| Field | Value |
|-------|-------|
| **Engine** | Godot 4.7.2 |
| **Domain** | Rendu |
| **Layer** | Presentation |
| **Knowledge Risk** | MEDIUM |
| **References Consulted** | Aucune référence moteur versionnée ; code et tests cités en Last Verified |
| **Post-Cutoff APIs Used** | Aucune. `SurfaceTool`, `ArrayMesh`, `Camera3D` orthographique, `DirectionalLight3D`, shaders `spatial` existent depuis 4.0 |
| **Verification Required** | (1) coût d'une image sur l'appareil de référence (D2), renderer Mobile ; (2) ombres de la lumière directionnelle sur Mobile (qualité, coût) ; (3) lisibilité à 31–36 pt sur écran réel ; (4) taille des maillages et des matériaux en mémoire |

## ADR Dependencies

| Field | Value |
|-------|-------|
| **Depends On** | ADR-0002 (séquenceur et gestionnaires), ADR-0007 (vue filtrée du joueur), ADR-0010 (caméra et gestes) |
| **Enables** | Art bible 1, 5 et 6 en jeu ; GDD 15 (recoloration) par un paramètre de shader |
| **Blocks** | Rien tant que Proposed |

## Context
Le rendu 2D (textures de terrain, sprites teintés) est jugé mauvais par l'utilisateur. L'art bible prévoyait des tuiles 3D low-poly en aplats avec un shader de saturation par tuile. La carte est petite (12 × 12 au plus, 144 tuiles) : la 3D ne coûte presque rien en géométrie.

## Decision (proposée)

**1. Ce qui ne change pas.** La vue lit un `TileSnapshot` (comme `TileRenderer`) et rien d'autre : la règle « le rendu ne lit pas l'état réel » (registre `renderer_reads_real_state`) tient. Une case jamais vue est la même dalle sombre, non éclairée, quel que soit son terrain ; une unité adverse hors de vue n'est pas dessinée ; une case explorée hors de vue est assombrie vers le gris-bleu de la mémoire. Le HUD, les gestes et le séquenceur ne changent pas.

**2. Les volumes** (`LowPoly`, construits dans le code, sans fichier d'art) :
- plaine : dalle en terrasses légères (trois hauteurs par variante), un sillon droit sur une variante ;
- forêt : 3 à 5 prismes, au plus 30 % de la tuile (art bible 6) ;
- montagne : pics à facettes, une crête plus basse que les ruines ;
- eau : dalle plus basse, une ride fixe ;
- nœud : plateformes hexagonales concentriques, une par niveau ;
- ruine : arche courbe brisée, ocre, plus haute que les montagnes ; une lueur ocre tant qu'elle n'est pas lue ;
- unités : socle (hexagone pour la meute, losange pour les Gardiens), corps, trait du type (mât, lame, carapace, fourche ; pointe, cornes, créneaux), un œil à la couleur du camp, la niche de commande vide de la meute ; endormi : gris-bleu, enfoncé, trait replié. Contour sombre (violet pour les Gardiens) par une coque inversée.

**3. La couleur.** Un shader par tuile (`terrain.gdshader`) : la couleur de sommet est le gris du monde ; une case possédée prend la teinte de son camp **à la valeur du terrain** (`strength` de 0 à 1), pour que le relief et l'ombre restent lisibles sous la couleur. `strength` est le point d'accroche de l'onde de recoloration (GDD 15). Une marque de forme (chevron, barre) double la couleur, comme en 2D.

**4. La caméra.** Orthographique, inclinée à 42°, sans rotation autour de la verticale : les colonnes restent droites à l'écran, la grille et les gestes d'ADR-0010 gardent leur sens. Même zoom que la 2D (autant de colonnes dans la zone de carte), centre gardé dans la carte avec une demi-tuile de marge. La case sous le doigt se calcule par la projection orthographique, sans le moteur (testable sans affichage).

**5. Le modèle reste, le dessin change.** `TileRenderer` garde l'instantané, les effets (glissement, ligne d'attaque, nombres, fantôme, anneau, onde et son fondu binaire), la sélection, les cibles et la flèche des premiers tours, avec leur minutage déjà testé ; `TileRendererHandler` et le séquenceur ne changent pas. Il ne dessine plus (`draw_enabled = false`). `MapView3D.sync` copie ce modèle à chaque image : un nouvel instantané seulement si son contenu change (un appui en crée un à chaque fois), la teinte de chaque case couverte par une onde par `shown_state` (paramètre `strength`), la position des unités qui glissent, un nœud par effet passager.

**6. Branchement (2026-11-04).** `MatchScreen` crée la vue 3D (`use_3d`, vrai par défaut ; `set_3d(false)` remet le dessin 2D). La caméra logique reste `MapCamera` (centre, zoom, zone, recentrage) ; la vue 3D s'y cadre à chaque image. Un appui passe par `tile_under` (la projection orthographique de `MapView3D.tile_at`) ; un défilement vertical est divisé par sin(42°), parce que le sol incliné défile plus vite que l'écran. Jauge de PV blanche au-dessus de l'unité, pastille des unités qui n'ont pas joué, cadres orange-rouge des cibles, flèche des premiers tours qui oscille sauf en animations réduites.

**Reste à faire** : la lisière du brouillard en fondu d'une demi-tuile ; les hachures de menace (le « ! » en tient lieu) ; `MultiMeshInstance3D` par terrain si la mesure le demande ; le serrage de `MapCamera` qui ignore l'inclinaison (la vue 3D recadre elle-même, avec une demi-tuile de marge).

## Alternatives Considered
- **Garder la 2D et refaire les textures** : moins de code, mais l'art bible demande la 3D et un artiste 2D pour tout redessiner ; rejeté par la demande de l'utilisateur.
- **Caméra en perspective, avec rotation** : plus spectaculaire, mais les cases du fond rapetissent (lisibilité à 31 pt) et la rotation casse la correspondance entre la grille et l'écran ; rejetée.
- **Modèles faits dans Blender** : meilleur résultat, mais il faut un artiste ; les volumes en code suffisent pour une maquette et restent remplaçables à nom égal.

## Consequences
- Positives : relief, ombres et volumes ; plus aucune texture de terrain à produire ; la recoloration devient un paramètre de shader.
- Négatives : un renderer 3D sur mobile (coût à mesurer, D2) ; les effets de la 2D (glissement, attaque, onde) sont à refaire en 3D ; les captures de la maquette ne sont pas celles d'un téléphone.

## Risks
- Les ombres de la lumière directionnelle peuvent coûter cher sur un téléphone d'entrée de gamme : repli sur des ombres cuites dans les couleurs de sommet.
- L'inclinaison peut cacher une unité derrière un pic : la hauteur des pics est bornée (`PEAK_MAX`) ; à vérifier sur la carte « marais ».

## GDD Requirements Addressed

| GDD | Exigence | Comment |
|-----|----------|---------|
| art-bible.md 1 | Tuiles 3D low-poly en aplats, couleurs par sommet, shader de saturation | `LowPoly`, `terrain.gdshader` |
| art-bible.md 5 | Trois volumes par unité, trait par type, œil à la teinte du camp, niche vide, endormi gris | `LowPoly.unit` |
| art-bible.md 6 | Décor ≤ 30 % de la tuile, ruines plus hautes que les montagnes, brouillard en aplat sombre | `DECOR_MAX`, `PEAK_MAX`, `FOG_SLAB` |
| brouillard-vision.md (5) | Ce qui n'est pas vu n'est pas montré | Lecture du seul `TileSnapshot`, test anti-fuite |

## Performance Implications
144 tuiles et une vingtaine d'unités : quelques centaines d'objets, des maillages partagés par terrain et variante. Un matériau par tuile dans la maquette ; un `MultiMesh` avec des paramètres par instance si la mesure le demande.

## Validation Criteria
- Les captures (`docs/architecture/maquette-3d/`) sont jugées meilleures que la 2D par l'utilisateur : **fait le 2026-11-04**. `jeu-portrait.png` et `jeu-paysage.png` montrent le vrai écran de partie en 3D.
- Tests : budget de triangles (unité ≤ 400), case jamais vue = dalle de brouillard, unité adverse hors de vue absente, teinte et mémoire par tuile, centre gardé dans la carte, case sous le doigt.
- Sur l'appareil de référence : 60 images par seconde au repos, 30 au pire pendant une onde.

## Related
ADR-0012 (rendu 2D en mode immédiat, à remplacer si retenu), `design/art/art-bible.md`, `tools/preview/map3d_preview.gd` (captures).
