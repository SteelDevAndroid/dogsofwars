# Dogs of Gods — Éléments posés sur la carte (3D), chapitre 5

## Livraison

- `assets/art/3d/` : 13 fichiers GLB 2.0, un modèle par fichier.
- `sources/generate_models.py` : source procédurale modifiable (Python + trimesh + numpy).
- `sources/convert_to_blend.py` : script Blender pour importer chaque GLB et enregistrer un fichier `.blend` correspondant.
- `VALIDATION.json`, `model_report.json` et deux planches de vérification.

## Direction graphique

Design original de science-fiction dystopique, surfaces facettées, volumes géométriques sobres, gris minéraux pour unités et nœuds, ocre uniquement pour ruines. Matériaux sans textures, couleurs RGBA par sommet : alpha = 1 sur les zones à teinter de faction. Le jeu dessine les contours et effets.

## Installation dans Godot

Copier les 13 fichiers `.glb` dans `assets/art/3d/` du projet. Les noms correspondent aux modèles que charge `ModelLibrary`, d'après `asset-specs.md` du 4 novembre 2026.

## Écarts / validations restant à faire

- Aucun fichier `.blend` n'est inclus : Blender n'est pas disponible ici. Générer les `.blend` avec `blender -b --python sources/convert_to_blend.py -- <racine du pack>`.
- Il s'agit de modèles de production candidats, **non validés en moteur** : inspection réelle sur Godot 4.7/Pixel 8 à effectuer.
- Contrôler que le shader `use_mask` conserve bien les alpha RGBA de `COLOR_0` après import.
- Vérifier la lecture à 31 pt avec `tools/preview/map3d_preview.gd -- gallery`.
- La niche de commande arrière des unités de la meute n'est pas modélisée et doit être ajoutée si le modèle est utilisé avec une caméra pivotante.
- Les détails de pierres des ruines sont des segments anguleux, plutôt que des courbes continues.
- Pas de modèles endormis : le jeu assombrit/enfonce les modèles éveillés.
