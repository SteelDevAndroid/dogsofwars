# Cartes illustrées (scénarios)

Une carte illustrée a deux sources dans `design/art/maps/<id>/` et un script qui produit le reste.

| Fichier | Rôle |
|---|---|
| `<id>.png` | L'illustration : carrée, avec une grille de 16 × 16 cases égales (les traits de grille sont ignorés). |
| `spec.json` | Le dessin du jeu, à la main : terrain (16 lignes de 16 : `.` plaine, `f` bois ou collines, `^` montagne, `~` eau ou gouffre), départs, nœuds, unités, drones endormis (`w` ouvrier, `p` meute), zones de ruines. |

```
python3 tools/maps/from_illustration.py <id>      # vérifie et écrit
python3 tools/maps/from_illustration.py --check   # CI : les fichiers sont ceux que le script écrit
```

Le script écrit `assets/data/maps/<id>.json` (symétrie `none`), `assets/art/maps/<id>_colors.png` (une couleur par case, la moyenne de la case dans l'image) et l'entrée de `assets/art/maps/art_index.json` (l'image est retrouvée par le SHA-256 du terrain, donc aussi pour une partie reprise). Il vérifie ce que le jeu vérifie (distances, terrains, couverture des drones côté IA) et ce que le jeu ne vérifie pas : tout point est atteignable depuis le départ du joueur avec les règles de déplacement (GDD 2). Pas de symétrie : un scénario n'a pas à être équitable par construction, il se joue et se mesure (`tests/balance/run_matches.gd -- 1 12 map=<id>`).

Pour ajouter une carte : déposer l'image et un `spec.json`, lancer le script, ajouter `maps/<id>.json` à `Bootstrap.MAP_FILES`, puis `from_illustration.py --check` passe en CI.

## Ce que l'image devient dans le jeu

- **Le relief reste le 3D low-poly** : l'image est peinte en perspective oblique, la caméra du jeu est inclinée autrement. Le terrain est donc dessiné à la main dans `spec.json`, d'après l'image.
- **Les couleurs viennent de l'image** (`MapArt`) : le gris de chaque tuile est multiplié par l'écart entre sa couleur dans l'image et la moyenne de son terrain (bornes 0,6 à 1,5, appliqué à 70 %). Le sable, la roche, le sel et le canyon se lisent comme dans l'image, et la recoloration des camps reste intacte.
- **La vignette de l'écran de choix** prend les mêmes couleurs, avec les marques de terrain (point, triangle, tiret). Elle ne montre ni nœud, ni ruine, ni départ (bible d'art, 6).
