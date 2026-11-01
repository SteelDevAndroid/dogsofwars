<!-- PROTOTYPE - NOT FOR PRODUCTION -->
<!-- Question: rendu de 144-256 tuiles en un MultiMesh avec onde de recoloration calculée dans le shader -->
<!-- Date: 2026-10-30 -->

# Rendu des tuiles — rapport du prototype

**Verdict : PROCEED** pour l'ADR du rendu des tuiles (MultiMesh + donnée par instance + temps global), **sous réserve d'un test sur Android d'entrée de gamme** (non fait). Les mesures ci-dessous viennent d'un PC de développement et ne prouvent rien sur mobile.

Les résultats viennent de l'agent prototyper (exécutions réelles de Godot 4.7.2) ; la session principale a relu `tile.gdshader` et deux captures (`02` et `08`). Rien n'a été actionné à la souris.

## Ce qui a été exécuté

- `--headless --path . --import` : OK, aucune erreur.
- `--headless --path . --check-only --script res://main.gd` : aucune erreur d'analyse.
- Lancement avec fenêtre (`--rendering-method mobile -- --bench`) : le banc va au bout, aucune erreur ni avertissement (shader, uniforme global, données personnalisées). Moteur : « Vulkan 1.4 – Forward Mobile – Intel UHD Graphics ».

## Ce qui marche (vu sur `screens/`)

- **MultiMesh** : un seul `MultiMeshInstance2D`, `TRANSFORM_2D`, `use_custom_data = true`, `set_instance_custom_data(i, Color)` ; le shader lit `INSTANCE_CUSTOM` dans `vertex()` et le passe en `varying flat vec4`. Testé avec 144 puis 256 instances.
- **Uniforme global** : `RenderingServer.global_shader_parameter_add("g_time", ...)` au lancement, `global_shader_parameter_set` à chaque frame ; `global uniform float g_time;` dans le shader. L'onde s'anime : `02_onde_r3_milieu.png` montre des anneaux à des stades de fondu différents. `TIME` n'est pas utilisé.
- **Palette** : `uniform vec3 pal[8]` ; la bascule daltonienne passe par un `int mode`, sans écrire d'état (`05_daltonien.png`).
- **Fondu f → g** : passe par le gris sans mélange de teintes (`04_f_vers_g_milieu.png`).
- **Brouillard** : INCONNUE aplatie (`#1E2329`), EXPLORÉE assombrie (mélange à 45 %), révélation 150 ms (`07`).
- **Animations réduites** : état final immédiat (`06`).
- **Répartition du calcul** : GDScript écrit une fois par tuile le début de fondu `t + min(k, K_MAX) × T_ANNEAU_eff` ; le shader calcule progression, saturation et teinte.
- `08_16x16_onde_milieu.png` : onde de rayon 3 sur 16×16, deux zones (PROPRE et ENNEMI) à des stades différents.

## Mesures

PC de développement, GPU intégré Intel UHD, VSync coupé. C'est le delta de `_process`, pas un temps GPU. Une seule mesure par phase.

| Phase | Frames | ms/frame moyen | max |
|---|---|---|---|
| 12×12 au repos | 5 378 | 0,566 | 44,3 (démarrage, non isolé) |
| 12×12, 1 capture de rayon 3 toutes les 0,6 s | 8 645 | 0,578 | 1,39 |
| 16×16 au repos | 4 823 | 0,622 | 1,39 |
| 16×16, 1 capture de rayon 3 toutes les 0,6 s | 7 646 | 0,658 | 24,7 (cause non investiguée) |

Écarts de moins de 0,1 ms : du bruit. Appels de dessin et temps GPU non mesurés.

## Non vérifié ou non sourcé

- **Android et GPU bas de gamme** : aucun test, ni en rendu Compatibility. « Mobile » ne signifie ici que Vulkan Mobile sur PC. À tester en particulier : `varying flat` et `global uniform`.
- **Entrées utilisateur** (clic gauche = PROPRE, clic droit = ENNEMI, 1/2/3, C, R, F, G) : codées, non actionnées ; le banc appelle `capture()`, `set_fog()`, `set_cb()` et `build()` directement.
- **Réécriture en plein fondu (règle 15)** : approximée par un décalage de progression ; une tuile retardée réécrite en plein fondu peut sauter (non testé).
- **Source effective F7** : implémentée dans `capture()`, non vérifiée visuellement.
- **Pics à 44 ms et 24,7 ms** : non expliqués.
- **TileMapLayer** : non testé.
- **`global_shader_parameter_add` au runtime** marche ; la déclaration dans les Project Settings (`shader_globals`) n'est pas testée.

## Recommandation pour l'ADR du rendu des tuiles (à valider sur Android)

1. **Donnée par instance (vec4 en custom data)** plutôt qu'un uniforme par instance : marche en 4.7.2 Mobile, 16 octets par tuile, un seul dessin, écriture seulement quand l'état change.
2. **MultiMesh plutôt que TileMapLayer** pour le contrôle du shader ; à arbitrer selon l'édition de carte (TileMapLayer non essayé).
3. **Temps global en uniforme global (`g_time`)**, pas `TIME` : pause, animations réduites et tests déterministes.
4. **Table de teintes en tableau uniforme plus un `mode`** : le daltonisme ne touche pas l'état (règle 20 de `recoloration-monde.md`).
5. **Débuts d'anneau calculés à l'écriture** : le shader n'a pas besoin de connaître la source.

## Questions restantes

- Le même code tient-il sur un Android d'entrée de gamme (Mobile et Compatibility) ?
- Précision float32 de `g_time` sur de longues sessions (le prototype utilise `Time.get_ticks_msec() / 1000`).
- Comment composer ce MultiMesh 2D avec les tuiles de l'art bible (maillages, couleurs par sommet, masque alpha) ?
- Surdessin de la lisière transparente du brouillard : hors périmètre.
- Coût CPU mobile de 256 `set_instance_custom_data` par commande, contre une écriture groupée via `multimesh.buffer`.
