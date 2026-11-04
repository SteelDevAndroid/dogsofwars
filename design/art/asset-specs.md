# Spécifications techniques des ressources graphiques

> **Statut** : mis à jour le 2026-11-04 pour la carte en 3D (ADR-0014, direction confirmée par
> l'utilisateur). À valider par l'art-director. Ce document complète
> `design/art/art-bible.md` (palette, silhouettes, règles de lecture) sans la remplacer : la
> bible gagne sur le *style*, ce document gagne sur le *format*.
>
> **Historique.** Le 2026-11-02, la voie A (sprites 2D en PNG) avait été retenue. Le
> 2026-11-04, l'utilisateur a choisi la voie B (tuiles 3D low-poly), décrite par l'art bible.
> La carte du jeu est maintenant en 3D. Les PNG de terrain, d'unités, de nœuds, de ruines et
> d'effets restent dans le dépôt pour le dessin 2D de secours (`MatchScreen.set_3d(false)`),
> mais **on n'en produit plus**.

## 0. Ce qui existe aujourd'hui et ce qu'un artiste remplace

Toutes les pièces de la carte 3D sont **construites dans le code** (`src/presentation/map3d/low_poly.gd`) avec des formes simples. Elles suffisent à jouer et à juger la direction. Un artiste les **remplace à nom égal** par des modèles `.glb`, sans toucher au reste du jeu.

**Comment le jeu les charge** (`ModelLibrary`, 2026-11-04) : si `assets/art/3d/<nom>.glb` existe, le jeu prend le premier maillage du modèle ; sinon il garde la forme du code. On peut donc livrer les modèles un par un, dans n'importe quel ordre. Godot importe les `.glb` déposés dans ce dossier ; un `.glb` non importé est aussi lu, avec `GLTFDocument`.

| Catégorie | Pièces | Construit dans le code | Livré par un artiste |
|---|---|---|---|
| Terrain | plaine, forêt, montagne, eau, 3 variantes chacun | oui | **oui** (`.glb`) |
| Nœuds | niveaux 1, 2, 3 | oui | **oui** |
| Ruines | arche brisée (2 variantes), dôme brisé | oui (arches seulement) | **oui** |
| Unités | 7 types | oui | **oui** |
| Brouillard, lisière du brouillard, portée, sélection, cibles, hachures de menace, « ! », jauge de PV, pastille d'unité en attente, flèche des premiers tours, marques de possession | — | oui | **non** : le jeu les dessine en aplats |
| Effets (trait d'attaque, nombres, fantôme d'une unité détruite, anneau) | — | oui | **non** |
| Icônes d'interface, polices, illustrations, icône du lanceur, magasin | — | — | **oui**, inchangés (sections 6 et 7) |

## 1. Ce que le jeu affiche, et sous quel angle

- **Grille carrée.** Cartes de 12 × 12 aujourd'hui, jusqu'à 16 × 16.
- **Caméra orthographique**, inclinée à **42° sous l'horizontale**, **sans rotation autour de la verticale** : les colonnes restent droites à l'écran.
  - Le joueur voit le **dessus** et la **face avant** (vers la caméra, +Z) de chaque pièce.
  - Il ne voit **jamais** l'arrière (−Z) ni le dessous.
- **Taille à l'écran.** Une tuile fait **24 à 64 pt** de large (pt = dp Android) ; au zoom de départ, la carte montre 8 colonnes, soit environ **48 pt**. La lisibilité se juge **à 31 pt** : un détail de moins de 3 pt à l'écran n'est pas modélisé.
- **Lumière** : une seule lumière directionnelle, venant de la gauche et un peu de devant, avec des **ombres en temps réel**, plus une lumière ambiante.
  - **Ne cuisez pas de lumière directionnelle** dans les couleurs : le jeu éclaire déjà.
  - Une **occlusion ambiante légère** cuite dans les couleurs de sommet est la bienvenue (creux, pieds des volumes).
- **Appareil de référence : Pixel 8, Android 15 ou plus** (décision D2), renderer Mobile de Godot 4.7.

## 2. Règles communes à tous les modèles

| Point | Règle |
|---|---|
| Format | **glTF 2.0 binaire (`.glb`)**, un modèle par fichier, source `.blend` livrée à côté |
| Échelle | **1 unité = 1 tuile.** Une tuile occupe le carré de −0,5 à +0,5 en X et en Z |
| Origine | Au **centre de la tuile**, le **dessus du terrain à Y = 0** (voir les hauteurs, section 4) |
| Axes | **+Y en haut, +Z vers la caméra** (le bas de l'écran), +X à droite. L'avant d'une unité (son œil, sa lame) regarde **+Z** ; le jeu tourne les Gardiens de 180° |
| Faces | Faces **plates** (pas de lissage), aplats, **aucune texture**, aucun matériau autre que la couleur de sommet |
| Couleur | **Couleurs de sommet** (attribut `COLOR_0`), en **valeurs de gris** pour tout ce qui change de camp. Teintes fixes permises seulement pour les ruines (ocre `#C8955A`) |
| Masque de camp | Dans l'**alpha** de la couleur de sommet : **1 = prend la teinte du camp**, 0 = garde son gris. La silhouette ne change jamais d'un camp à l'autre |
| Triangles | **Unité : 150 à 400.** Tuile de terrain : au plus 300. Nœud, ruine : au plus 200. Un seul niveau de détail |
| Faces cachées | L'arrière et le dessous peuvent être omis : ils ne sont jamais vus |
| Contour | Ne pas le modéliser : le jeu ajoute une coque inversée (sombre `#1E2329` pour la meute, violet `#B07CE0` pour les Gardiens) |
| Nommage | Minuscules, sans accents : `terrain_plaine_01.glb`, `unit_eclaireur.glb`, `node_niveau_2.glb`, `ruin_arche_brisee_01.glb` |

Le shader du jeu lit ce masque pour les modèles livrés (`use_mask`). Les formes du code, elles, portent la couleur du camp directement.

**Ce que le jeu fait d'un modèle livré** :
- **Unités et nœuds** : la teinte du camp va là où l'alpha vaut 1, un nœud libre reste gris. Un nœud vu mais hors de vue est assombri.
- **Unité endormie** : le jeu prend `unit_<type>_endormi.glb` s'il existe. Sinon, il prend le modèle éveillé, sans teinte, assombri et enfoncé de 0,03.
- **Ruine lue** : assombrie par le shader, il n'y a pas de second modèle à livrer.
- **Contour** : les unités gardent la coque de contour du jeu.

## 3. Palette en jeu (valeurs du code)

Les gris du terrain sont un cran plus clairs que ceux de la 2D, parce que la lumière et l'ombre les assombrissent.

| Usage | Couleur |
|---|---|
| Fond (hors carte) | `#1E2329` |
| Dalle de brouillard (jamais vu), dessinée par le jeu | `#323A44` |
| Plaine / forêt (sol) / prismes de forêt / montagne / eau | `#7A848E` / `#68737E` / `#5A6772` / `#98A2AC` / `#34495C` |
| Flancs des volumes | la couleur du dessus assombrie d'environ 28 % |
| Corps des unités | `#B4BBC3` ; unité endormie : `#4E5862` |
| Meute | `#1FA38F` (variante daltonienne `#3A8EE6`) |
| Gardiens | `#C49BEA`, contour `#B07CE0` fixe (variante daltonienne `#F0DC6E`) |
| Menace (hachures, « ! ») | `#FF6A3D` |
| Ruine | `#C8955A` |
| Sélection, portée, jauge de PV | `#EADFC8` |

**Couleur d'une case possédée.** Le jeu donne à la case la teinte de son camp **à la valeur du terrain** (shader `terrain.gdshader`). La valeur d'un modèle compte donc plus que sa teinte : chaque terrain doit rester reconnaissable une fois teinté. Faites un test en gris.

## 4. Terrain

Chaque type existe en **3 variantes** (`_01`, `_02`, `_03`). Le jeu choisit la variante d'après la case, toujours la même pour une case donnée.

| Fichier | Rôle | Hauteurs (Y) | Ce qu'il faut |
|---|---|---|---|
| `terrain_plaine_0N.glb` | base, coût 1 | dessus à **0 / +0,05 / +0,025** selon la variante (terrasses légères) | une dalle, au plus un élément plat en gris (sillon droit, cratère net) |
| `terrain_foret_0N.glb` | couvert, coût 2 | sol à 0, prismes **au plus +0,30** | 3 à 5 prismes ou cônes facettés, pas d'arbre fin. Les coins restent dégagés pour une unité posée au centre |
| `terrain_montagne_0N.glb` | défense, coût 3 | pics **au plus +0,42** ; une unité se pose à **+0,12** | pics facettés, un sommet aplati au centre pour l'unité. La crête ne doit pas cacher plus de la moitié de ce qui se trouve sur la case derrière (art bible 6) |
| `terrain_eau_0N.glb` | infranchissable | surface à **−0,10** | dalle plus basse, une seule ride fixe |

**Pour tous** : une **dalle de 0,98 × 0,98** (2 % de jour entre deux tuiles, pour que la grille se lise), épaisse de **0,22** sous le dessus. Bords droits, sans biseau qui sorte du carré. Le brouillard et sa lisière ne sont pas à livrer : le jeu les dessine.

## 5. Éléments posés sur la carte

**Nœuds** (`node_niveau_1.glb` à `node_niveau_3.glb`) :
- plateformes hexagonales **concentriques**, à angles droits, intactes ;
- une marche de **0,05** de haut par niveau, rayon extérieur **0,42** ;
- le niveau se lit au **nombre de marches**, pas seulement à un chiffre ;
- gris tant qu'aucun camp ne tient le nœud (alpha = 1 sur les dessus des marches).

**Ruines** (`ruin_arche_brisee_01.glb`, `ruin_arche_brisee_02.glb`, `ruin_dome_brise_01.glb`) :
- le seul ocre et sépia de la carte, des **courbes brisées** ;
- les seules formes **plus hautes que les montagnes** : environ **+0,70** ;
- pied au centre de la tuile ;
- l'état « lue » (assombri) et la **lueur** d'une ruine non lue sont faits par le jeu : ne pas les livrer.

**Unités** (`unit_eclaireur`, `unit_assaut`, `unit_rempart`, `unit_ouvrier` pour la meute ; `unit_sentinelle`, `unit_chasseur`, `unit_bastion` pour les Gardiens) :
- **Proportions** : le jeu les affiche à **1,25 ×** leur taille de modèle. Modélisez-les pour qu'elles tiennent dans un cylindre de **rayon 0,30** et de **hauteur 0,50** (environ 0,62 avec le trait).
- **Volumes** (art bible 5) : au plus trois, un socle, un corps et le trait du type, plus un œil.
  - **Socle** : hexagonal pour la meute, en losange pour les Gardiens. Alpha = 1 sur son dessus.
  - **Œil** : à l'avant (+Z), alpha = 1.
  - **Niche de commande vide** : à l'arrière, pour la meute.
  - Corps des Gardiens environ 10 % plus haut et plus étroit.
- **Traits** :
  - meute : **mât** (éclaireur), **lame vers l'avant** (assaut), **carapace plate** (rempart), **fourche à deux pointes** (ouvrier) ;
  - Gardiens : un vocabulaire à angles aigus, distinct de celui de la meute (pointe, cornes, créneaux dans la version du code).
- **Unité endormie** : le jeu utilise **le même modèle**, recoloré en gris-bleu et enfoncé. Si le trait doit se replier à mi-course, livrer `unit_<type>_endormi.glb` ; sinon rien.
- **Pas d'animation squelettique** : le jeu fait glisser, affaisser et estomper les unités.

## 6. Interface

Sans changement. L'interface reste en 2D par-dessus la carte.

- **Icônes** : `.svg`, `viewBox` 24 × 24, trait de 2, extrémités carrées, une seule couleur blanche, taille affichée minimale de 20 pt.
  - 21 icônes sont en place dans `assets/art/ui/`. Ce sont des versions provisoires dessinées par l'équipe technique, à remplacer à nom égal.
  - La liste : tour, énergie, recherche, ruine, nœud, attaque, réveil, montée de niveau, pause, zoom +, zoom −, recentrer, réglages, chronique, menace, perte, vitesse, retour, mouvement, défense, vue.
- **Polices** : `.ttf` ou `.otf` avec leur licence, au plus 3 graisses, accents français complets, chiffres tabulaires.
- **Panneau papier du fragment** : un 9-patch `ui_panneau.png`, 96 × 96 px, marges de 24 px (déjà livré).

## 7. Hors carte : illustrations, icône, magasin

Sans changement. Les illustrations restent peintes : c'est le registre de la mémoire (art bible 1).

| Ressource | Spécification |
|---|---|
| **Écran titre / splash** | image maîtresse portrait **1 440 × 2 560 px**, `.webp` ou `.png` sRGB, sujet et titre dans le carré central de 1 080 × 1 080, sans la phrase « Touchez pour jouer » ; recadrage paysage 2 560 × 1 440 |
| **Illustrations de chronique et de carte** | maîtresse carrée **2 560 × 2 560**, sujet dans le carré central de 1 440 × 1 440 ; `.webp`. Même caméra de trois-quarts et même composition que la carte en jeu (art bible 6) |
| **Icône du lanceur (Android)** | premier plan 432 × 432 px transparent, sujet dans le disque central de 288 px ; arrière-plan 432 × 432 px opaque ; monochrome 432 × 432 px |
| **Icône classique** | 192 × 192 px, PNG |
| **Icône du Play Store** | 512 × 512 px, PNG 32 bits, moins de 1 Mo |
| **Graphique de présentation** | 1 024 × 500 px, PNG ou JPEG sans transparence |
| **Captures d'écran** | 2 à 8, en 9:16 ou 16:9 (suggestion : 1 080 × 1 920), sans cadre de téléphone, **prises sur le Pixel 8** |

## 8. Contrôle à la réception

À faire dans le jeu, avec sa caméra, avant d'accepter un modèle :

1. Nom, format `.glb`, échelle, origine et axes conformes : le modèle posé sur une tuile ne déborde pas du carré et son avant regarde la caméra.
2. **Budget de triangles** respecté. Le test `tests/unit/map3d/map_view_3d_test.gd` vérifie les formes du code ; `model_library_test.gd` vérifie qu'un `.glb` se charge avec son masque. Un test des budgets sur les modèles livrés reste à ajouter quand le premier arrivera.
3. **Galerie** : `tools/preview/map3d_preview.gd -- gallery` montre côte à côte tous les terrains, les 7 unités, les nœuds et les ruines. Les silhouettes doivent se reconnaître à 31 pt, et les quatre types de la meute se distinguer côte à côte.
4. **Test en gris** : sur une capture désaturée, chaque élément se détache de ses voisins par la valeur et la forme, y compris sur une case teintée par un camp.
5. **En partie** : le mode `match` du même outil donne le vrai écran (portrait et paysage). Une crête ne doit pas cacher une unité sur la case derrière.
6. **Mesure** sur le Pixel 8 (`docs/architecture/mesures-appareil-de-reference.md`) : pas d'image au-delà de 33 ms au repos.
7. Captures conservées dans `production/qa/evidence/`.

## 9. Livraison

- Un dossier par catégorie : `terrain/`, `nodes/`, `ruins/`, `units/`, `ui/`, `illus/`, `store/`.
- Les sources (`.blend`, `.kra`, `.psd`, `.svg`) à côté des fichiers exportés.
- Un `LISEZMOI` qui liste les fichiers et les écarts au présent document.
- Les modèles prêts vont dans `assets/art/3d/` ; les autres ressources gardent leur dossier actuel sous `assets/art/`.

## Questions ouvertes

| Question | Qui décide |
|---|---|
| Faut-il des modèles d'unité endormie distincts (trait replié) ou le même modèle enfoncé suffit-il ? | art-director |
| Faut-il un dôme brisé en plus des deux arches (le code n'en fait pas) ? | art-director |
| Les PNG 2D de la carte sont-ils gardés pour le repli 2D ou retirés du paquet pour l'alléger ? | utilisateur |
