# Spécifications techniques des ressources graphiques

> **Statut** : proposition de l'équipe technique du 2026-11-02, à valider par l'art-director.
> Elle complète `design/art/art-bible.md` (palette, silhouettes, règles de lecture) et ne
> les remplace pas : en cas de conflit sur le *style*, la bible gagne ; sur le *format*, ce
> document gagne.

## 0. Une décision à prendre avant de produire

La bible d'art (section 4, « production hybride ») prévoit des **tuiles 3D low-poly** (`.glb`,
couleurs par sommet). Le moteur de rendu **réellement écrit** est en **2D** : il dessine la
carte à plat, vue de dessus, sur une **grille carrée**, avec des formes provisoires.

| Voie | Ce que l'artiste livre | Effort côté code | Quand la choisir |
|---|---|---|---|
| **A. Sprites 2D** (proposée, détaillée ci-dessous) | PNG en gris + masque de faction | Faible : le moteur a déjà tout le reste (brouillard, camera, effets) | Production à une personne, sortie rapide, Android d'entrée de gamme |
| **B. Tuiles 3D** (bible d'art) | `.glb`, 150 à 400 triangles par unité | Fort : un rendu 3D complet à écrire et à mesurer sur appareil (prototype prévu section 8 de la bible) | Si le rendu 3D est un choix de direction artistique assumé |

Les sections 1 à 7 décrivent la voie A. La section 8 résume la voie B. Les règles de
couleur, de silhouette et de lecture valent pour les deux.

## 1. Ce que le jeu affiche, et à quelle taille

- **Grille carrée**, vue de dessus. Cartes de 12 × 12 aujourd'hui, jusqu'à 16 × 16.
- Une tuile mesure **24 à 64 pt** à l'écran (pt = dp Android) ; au départ, la carte montre 8 colonnes, soit **environ 48 pt** sur un téléphone de 390 pt de large en portrait. La lisibilité se juge **à 31 pt**.
- Le jeu s'affiche jusqu'à **4 pixels par pt** (écrans xxxhdpi). Une tuile peut donc mesurer **256 px** au maximum : c'est la **taille source**.
- Toute chose doit se reconnaître à 31 pt : un détail de moins de 3 pt n'est pas dessiné.
- Lumière **à 45° depuis le haut à gauche**, cuite dans l'image, ombres douces courtes.
- **Grille indépendante du dessin** : le jeu trace lui-même les bords de tuile, le territoire, le brouillard et les sélections ; ne dessinez ni cadre ni grille dans les tuiles.

## 2. Règles communes à tous les PNG

| Point | Règle |
|---|---|
| Format | PNG 8 bits par canal, RGBA, sRGB, sans profil exotique, sans compression destructive |
| Taille d'une tuile ou d'une unité | **256 × 256 px**, la tuile occupe tout le carré |
| Marge | Une unité ou un décor garde **16 px** de marge transparente (le moteur y ajoute le contour de 1 pt) |
| Ancre | Le centre du carré est le centre de la tuile ; un élément plus haut que la tuile (ruine) garde son pied au centre bas du carré |
| Couleur | **Valeurs de gris seulement** pour tout ce qui change de faction ; la couleur de faction est appliquée par le jeu |
| Teintes fixes | Uniquement : ruines (ocre/sépia `#C8955A`), menace (`#FF6A3D`), eau (froid sombre `#2B323A`) |
| Nuancier | Les couleurs viennent de `palette_lmo.gpl` (à créer depuis la section 3) ; aucune teinte hors nuancier |
| Textures photographiques | Aucune en jeu (aplats, dégradés et grain léger) : le grain « peint » est réservé aux illustrations hors jeu |
| Poids | Pas de limite par fichier ; **budget total des tuiles et unités : 8 Mo en PNG**, 4 Mo une fois compressées pour le GPU |
| Sources | `.kra`, `.psd` (calques conservés) ou `.svg` livrés avec l'export |
| Nommage | `[catégorie]_[nom]_[variante]_[taille].[ext]`, minuscules, sans accents (voir la bible) ; ex. `terrain_foret_02.png` |

**Masque de faction.** Pour chaque élément qui change de faction (unités, nœuds), livrer deux fichiers de même taille : `xxx.png` (gris, avec son alpha) et `xxx_mask.png` (blanc là où la couleur de faction s'applique, noir ailleurs, sans alpha). Le jeu teinte le masque ; la silhouette ne change jamais d'une faction à l'autre, seuls la palette et le motif changent.

## 3. Palette de référence (codée dans le jeu)

| Usage | Couleur |
|---|---|
| Brouillard (jamais vu) | `#1E2329` |
| Plaine / forêt / montagne / eau | `#4E5862` / `#66717C` / `#808B96` / `#2B323A` |
| Meute | `#1FA38F` (variante daltonienne `#3A8EE6`) |
| Gardiens | `#C49BEA`, contour `#B07CE0` fixe (daltonienne : `#F0DC6E`) |
| Non revendiqué | `#A3ACB5` (daltonienne : `#5F6266`) |
| Menace | `#FF6A3D` |
| Ruine | `#C8955A` |
| Sélection | `#EADFC8` |
| Contour sombre | `#1E2329` |

## 4. Terrain (le contenu de la carte)

Chaque type existe en **3 variantes** (`_01`, `_02`, `_03`) pour casser la répétition. Opaques, **raccordables** sur leurs quatre côtés (bords identiques entre variantes d'un même type), **sans marge**.

| Fichier | Rôle | Remarque |
|---|---|---|
| `terrain_plaine_0N.png` | terrain de base, coût 1 | le plus calme : c'est le fond |
| `terrain_foret_0N.png` | couvert, coût 2 | masse plus sombre et plus dense, **pas de contour d'arbre fin** |
| `terrain_montagne_0N.png` | défense, coût 3 | plus clair, relief marqué par les ombres |
| `terrain_eau_0N.png` | infranchissable | plus sombre, surface plate |
| `terrain_brouillard_01.png` | tuile jamais vue | aplat `#1E2329` avec un très léger grain, aucun glyphe |
| `fog_lisiere_bord.png`, `fog_lisiere_angle_ext.png`, `fog_lisiere_angle_int.png` | lisière douce entre brouillard et terrain | transparente, 256 × 256, optionnelle (sinon le jeu fait un fondu) |

L'écart de **valeur** (et non de teinte) doit distinguer les quatre terrains : test en gris obligatoire.

## 5. Éléments posés sur la carte

**Nœuds** (plateformes des drones : hexagones concentriques, angles droits, intacts, gris tant qu'aucune faction ne les tient) : `node_niveau_1.png`, `node_niveau_2.png`, `node_niveau_3.png`, plus `_mask`. Le niveau se lit à la **taille et au nombre d'anneaux**, pas seulement à un chiffre. Le motif de faction (chevron, deux barres, deux hexagones) est dessiné par le jeu.

**Ruines** (le seul ocre/sépia, les seules formes plus hautes que les montagnes, courbes brisées) : `ruin_arche_brisee_01.png`, `ruin_arche_brisee_02.png`, `ruin_dome_brise_01.png`. Taille **256 × 384 px** (la partie haute déborde sur la tuile du dessus), transparent. Un état « lue » est obtenu par le jeu (assombrissement) : ne pas le livrer.

**Unités** (7 types) : `unit_eclaireur`, `unit_assaut`, `unit_rempart`, `unit_ouvrier` (meute) ; `unit_sentinelle`, `unit_chasseur`, `unit_bastion` (Gardiens). Un fichier gris + un `_mask` chacun, 256 × 256, **une seule orientation** (vue de dessus, tête vers le haut ; le jeu fait pivoter par paliers de 45°). Silhouette pleine reconnaissable à 31 pt, quatre types de la meute distincts côte à côte, aucun ne ressemble à un mât, une lame ou une carapace. Un drone endormi est la même image : le jeu dessine la barre « dormant ». Pas de contour : le jeu l'ajoute.

**Effets** (blancs, une couleur, teintés par le jeu), 256 × 256 : `fx_selection.png` (cadre), `fx_cible_crochets.png` (crochets d'angle), `fx_portee_point.png`, `fx_menace.png` (hachures + « ! »), `fx_debris.png` (glyphe de débris d'une unité détruite), `fx_ruine_lueur.png` (halo, 256 × 384). Pas de feuille d'animation : le jeu anime par déplacement et fondu. Animation de réveil : 6 images 256 × 256 en bande horizontale (1 536 × 256) si l'art-director la veut.

## 6. Interface

- **Icônes** : `.svg`, `viewBox` 24 × 24, trait de 2, extrémités carrées, une seule couleur blanche, taille affichée minimale 20 pt. Liste : tour, énergie, recherche, ruine, nœud, attaque, réveil, montée de niveau, pause, zoom +, zoom −, recentrer, réglages, chronique, menace, perte, vitesse, retour. Trois sont déjà en place en version provisoire dans `assets/art/ui/` (`ui_icon_tour.svg`, `ui_icon_energie.svg`, `ui_icon_ruine.svg`, dessinées par l'équipe technique) : à remplacer à nom égal.
- **Polices** : fournies en `.ttf` ou `.otf` avec licence, au plus 3 graisses (régulière, moyenne, 700), accents français complets, chiffres tabulaires pour le score et les compteurs.
- **Boutons et panneaux** : le jeu les dessine ; livrer seulement un **9-patch** (`ui_panneau.png`, 96 × 96 px, marges de 24 px) si un style papier ou métal est voulu pour le panneau de fragment.

## 7. Hors carte : illustrations, icône, magasin

| Ressource | Spécification |
|---|---|
| **Écran titre / splash** | image maîtresse portrait **1 440 × 2 560 px** (livré aujourd'hui : 941 × 1 672, à refaire à cette taille), `.webp` ou `.png` sRGB, sujet et titre dans le carré central de 1 080 × 1 080 ; version **sans** la phrase « Touchez pour jouer » (le jeu l'écrit) ; recadrage paysage 2 560 × 1 440 si le jeu se joue en paysage |
| **Illustrations de chronique / de carte** | maîtresse carrée **2 560 × 2 560**, sujet dans le carré central de 1 440 × 1 440, d'où l'on tire un portrait 1 440 × 2 560 et un paysage 2 560 × 1 440 ; `.webp`, pas de 4K |
| **Icône du lanceur (Android)** | **premier plan 432 × 432 px**, PNG transparent, sujet dans le **disque central de 288 px** (zone sûre de 66 %) ; **arrière-plan 432 × 432 px**, PNG opaque (uni ou dégradé) ; **monochrome 432 × 432 px**, silhouette blanche sur transparent (icônes thématiques d'Android 13) |
| **Icône classique** | 192 × 192 px, PNG, coins arrondis transparents |
| **Icône du Play Store** | 512 × 512 px, PNG 32 bits, sans coins arrondis (Google les applique), moins de 1 Mo |
| **Graphique de présentation** | 1 024 × 500 px, PNG ou JPEG sans transparence |
| **Captures d'écran** | 2 à 8, 16:9 ou 9:16, côtés entre 320 et 3 840 px (suggestion : 1 080 × 1 920), sans cadre de téléphone |

## 8. Voie B : tuiles 3D (rappel de la bible d'art)

`.glb` (glTF 2.0 binaire), un asset par fichier, source `.blend` ; **couleurs par sommet** sans texture, valeurs de gris, lumière et occlusion cuites ; masque de faction dans l'alpha de la couleur de sommet (1 = prend la teinte) ; **150 à 400 triangles par unité**, un seul niveau de détail ; origine au centre de la tuile, échelle 1 unité = 1 tuile ; contour des unités par coque inversée. Un prototype de rendu sur Android d'entrée de gamme (60 unités, carte 16 × 16) doit confirmer ces budgets **avant** de modéliser quoi que ce soit.

**Décision (2026-11-02) : voie A retenue.** La voie B reste documentée ci-dessus mais n'est pas lancée ; le pack de préparation du chapitre 8 (porte de validation, benchmark, validateur `.glb`) n'est pas intégré. Rouvrir la question seulement si le benchmark Android est un jour demandé.

## 9. Contrôle à la réception

Fait dans le jeu, avec la caméra du jeu, avant d'accepter une ressource :

1. Nom, taille, format et marges conformes (un script les relève dans `tools/`).
2. Silhouette noire reconnaissable à 31 pt ; les types d'unités se distinguent côte à côte.
3. Test en gris : sur une capture désaturée, chaque élément se détache de ses voisins par la valeur et la forme.
4. Aucune couleur hors nuancier (écarts relevés, jamais corrigés d'office).
5. Raccord sans couture entre variantes de terrain, sur une carte de 12 × 12.
6. Capture conservée dans `production/qa/evidence/`.

## 10. Livraison

Un dossier par catégorie (`terrain/`, `nodes/`, `ruins/`, `units/`, `fx/`, `ui/`, `illus/`, `store/`), les sources à côté, un `LISEZMOI` qui liste les fichiers et les écarts au présent document. Les fichiers prêts vont dans `assets/art/<catégorie>/` ; Godot les importe avec la compression pour Android (ETC2/ASTC) déjà activée.

## Questions ouvertes

| Question | Qui décide |
|---|---|
| Unités en vue de dessus pure ou en trois quarts (le moteur actuel est de dessus) ? | art-director |
| Faut-il 8 orientations dessinées plutôt qu'une rotation par paliers de 45° ? | art-director |
