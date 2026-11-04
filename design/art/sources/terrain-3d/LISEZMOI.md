# Dogs of Gods — terrain 3D, pack 01

**Contenu :** les **12 modèles de terrain** demandés dans la section 4 de `asset-specs (1).md` : plaine, forêt, montagne et eau, chacun en trois variantes. Les modèles suivent une direction graphique **minérale, narrative et dystopique** : volumes rocheux facettés, gris froids, contrastes francs et traces d'un monde artificiellement altéré. C'est une interprétation originale de cette intention visuelle, sans textures peintes.

## Livrables

- `terrain/terrain_*.glb` : 12 fichiers glTF 2.0 binaires prêts à copier dans `assets/art/3d/` du projet Godot. Il n'y a **qu'un maillage** par fichier.
- `previews/terrain_gallery.png` : planche orthographique de vérification à 42° ; 12 aperçus détaillés individuels dans le même dossier.
- `manifest.json` : inventaire, budgets de triangles, bornes 3D et présence des couleurs de sommet.
- `source/generate_terrain.py` : source procédurale éditable et reproductible ; réexporte les 12 GLB.
- `source/render_previews.py` : régénère les aperçus.
- `source/import_to_blender.py` : convertit les GLB en **12 fichiers `.blend` éditables** si Blender est installé.

**Limitation de livraison :** Blender n'est pas disponible dans l'environnement de génération, donc les `.blend` ne sont pas directement inclus. En revanche, les `.glb` sont des maillages éditables et le code de génération est fourni. Pour obtenir les `.blend` :

```bash
blender -b -P source/import_to_blender.py
```

## Règles respectées

- Empreinte de la dalle : **0,98 × 0,98 unité** ; épaisseur **0,22** sous son plan supérieur.
- Couleurs de sommet `COLOR_0` **RGBA**, alpha = 255 (pas de teinte de camp à appliquer directement au terrain ; la coloration du terrain est prise en charge par le shader du jeu).
- Pas de textures, matériaux complexes, contours géométriques ou animation.
- Budget : **16 à 80 triangles** par tuile, inférieur au maximum de 300.
- Caméra attendue : +Z vers la caméra, +Y en haut, orthographique 42°.
- Plaine : dessus à **0 / +0,05 / +0,025** respectivement ; petits sillons, impact hexagonal, stratification.
- Forêt : **4 / 5 / 4** prismes facettés, hauteurs maximales **+0,27 / +0,30 / +0,30**, centre dégagé.
- Montagne : sommets **+0,38 / +0,42 / +0,40** ; plateforme centrale **+0,12** pour l'unité.
- Eau : dessus à **−0,10**, une unique ride anguleuse par variante.

## Installation

Copiez les douze fichiers de `terrain/` dans `<racine-du-projet>/assets/art/3d/`, sans les renommer. Godot 4.7 les importe ; le système `ModelLibrary` décrit dans la spécification peut alors les charger individuellement. Il reste à vérifier visuellement le résultat **dans le jeu** en vue galerie et en partie sur Pixel 8.

## Contrôles et différences

Les 12 `.glb` ont été réouverts et contrôlés par programme après export (maillage, bornes, triangles et couleurs). Les aperçus utilisent une projection orthographique et un éclairage de simulation, mais ne sont pas des captures du moteur Godot. **Aucune validation sur appareil Android ni dans le moteur Godot n'a été effectuée.**

La variante `plaine_02` comporte un impact facetté, et les trois plaines portent des reliefs graphiques très bas (jusqu'à +0,002) pour matérialiser la trace sans modifier le profil du terrain. Les faces arrière et inférieures de la dalle sont omises, conformément à la spécification.
