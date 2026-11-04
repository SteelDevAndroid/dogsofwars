# Dogs of Gods — ressources Interface (section 6)

## Livrables
- `ui/ui_*.svg` : 21 icônes monochromes (voir `manifest.json`).
- `ui/ui_panneau.png` : variante de panneau papier **96 × 96 px** avec marges 9-patch **24 px** ; la spécification indique qu’une version existe déjà, donc ce fichier est une proposition de remplacement facultative.
- `previews/interface_gallery.png` : planche de lecture des 21 icônes.
- `previews/panneau_preview.png` : aperçu du panneau.
- `previews/ui_*.png` : images d’aperçu, **pas les ressources à importer**.
- `source/generate_ui.py` : générateur autonome des ressources SVG, du panneau et des aperçus.

## Conformité
Chaque SVG : `viewBox="0 0 24 24"`, trait `2`, `stroke-linecap="square"`, blanc `#FFFFFF`, sans aplats colorés ni fond, utilisable à 20 dp minimum. Les détails suivent une esthétique techno-minérale sombre à géométrie anguleuse, évoquant un univers de SF graphique, sans reproduire une œuvre existante.

## Nommage / intégration
Le document de spécification énumère les **fonctions**, mais **pas les noms exacts des 21 fichiers déjà présents** dans `assets/art/ui/`. Ces fichiers sont nommés ici `ui_tour.svg`, `ui_energie.svg`, etc. **Vérifiez les noms attendus par le dépôt** avant de remplacer les ressources existantes. La table `manifest.json` permet d’automatiser leur correspondance. Importer en Godot via `assets/art/ui/`.

## Polices (non incluses)
Les polices sont des œuvres tierces et ne sont pas redistribuées dans cette livraison. Sélection suggérée à valider dans l'art bible : **IBM Plex Sans** Regular, Medium et SemiBold (SIL OFL 1.1) pour l’interface ; contrôler l’extension latin, les accents français et les chiffres tabulaires (`tnum`) dans le moteur de rendu choisi. Source officielle : https://github.com/IBM/plex .

## Points à valider
- Comparaison à l’écran Android à **20 dp**, et accessibilité (contraste sur les fonds réels).
- Mapping exact des noms et marges 9-patch selon le thème Godot.
- Typographie installée dans le projet, sous sa licence, par le développeur.
- Icônes “tour” et “retour” intentionnellement différentes : tour du jeu et navigation arrière.
