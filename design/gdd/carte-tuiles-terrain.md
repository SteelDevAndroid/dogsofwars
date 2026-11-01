# Carte en tuiles et terrain

> **Status**: In Design
> **Author**: user + Claude (game-designer, level-designer, systems-designer)
> **Last Updated**: 2026-10-29
> **Last Verified**: 2026-10-29
> **Implements Pillar**: Pilier 3 « Lisible comme Polytopia » ; pilier 5 « Le brouillard cache une question » ; pilier 1 « La meute se voit grandir » (support)
> **Creative Director Review (CD-GDD-ALIGN)**: REVISED 2026-10-29 — CONCERNS (emplacements de ruines usés au fil des parties ; ce qu'une crête cache ; vue à sens unique ; pilier 5 non testé) corrigées : 3 candidats par zone, règle 16 précisée, question confiée au brouillard (5), AC-D2 ajouté

## Summary

La carte est une grille de tuiles carrées (12 × 12 au MVP, 10 × 10 et 14 × 14 au
lancement) où l'on se déplace dans les huit directions, sur quatre terrains qui
s'expliquent chacun en une phrase : la plaine est rapide, la forêt ralentit et protège,
la montagne protège davantage et cache l'horizon, l'eau ne se traverse pas. Elle place
les points d'intérêt — nœuds, drones endormis, ruines tirées au hasard parmi des
emplacements candidats — pour que le brouillard pose une question à chaque partie. Les
cartes sont symétriques et validées automatiquement, faites à la main au lancement,
générées en Alpha au même format.

> **Quick reference** — Layer: `Core` · Priority: `MVP` · Key deps: `Modèle d'état de partie`

## Overview

La carte est le plateau de la partie : une grille de tuiles carrées, de 16 × 16 au plus
(`MAX_MAP_SIZE`, `design/gdd/modele-etat-partie.md`), où les unités se déplacent dans
les **huit directions** (diagonales comprises) et où la distance se compte en « coups de
roi » (décisions du 2026-10-29). Chaque tuile porte un **terrain** parmi quatre au MVP —
plaine, forêt, montagne, eau — qui s'explique en une phrase et change trois choses :
le coût d'un déplacement, la défense de l'unité qui s'y trouve, et ce qu'on voit au-delà
(pilier 3, « Lisible comme Polytopia »). La carte place aussi les **points d'intérêt** :
nœuds, drones endormis et ruines, ces dernières tirées au hasard parmi des emplacements
candidats sur chaque carte fixe, pour que le brouillard pose une vraie question à chaque
partie (pilier 5, « Le brouillard cache une question » ; Creative Director Note de
`design/gdd/systems-index.md`). Au lancement, le jeu propose de 6 à 10 cartes faites à
la main ou à graine fixe ; le générateur procédural (21) viendra en Alpha et produira des
cartes au même format. Le joueur lit la carte en permanence : c'est sur elle que la
meute grandit et que le monde gris reprend ses couleurs (pilier 1). Ce système possède
les dimensions, le terrain et les points d'intérêt ; le propriétaire de chaque tuile
appartient aux nœuds (11) et sa couleur à la recoloration (15).

*Le rendu de la carte (modèles 3D low-poly, shader de saturation) relève de la
recoloration (15), de l'art bible et d'un ADR, pas de ce document.*

## Player Fantasy

**Une question sous le gris.** Le monde est un plateau gris, et chaque tuile peut cacher
quelque chose : une ruine, un drone endormi, un col derrière la crête. Tu avances parce
que tu veux savoir ce qui t'attend. Et chaque tuile se lit d'un regard : la forêt freine,
la montagne protège et cache ce qui se trouve derrière.

**L'émotion visée est la curiosité devant l'inconnu**, servie par une lecture immédiate
du terrain. Le pilier 5 (« chaque élément de la carte doit éveiller une question ») donne
à la carte un rôle qu'aucun autre système n'a ; le pilier 3 est servi par des terrains
qui s'expliquent chacun en une phrase.

**Moment d'ancrage.** Au troisième tour, une lueur sépia perce le brouillard derrière une
crête. La montagne cache le chemin ; le joueur choisit de contourner par la forêt, plus
lente mais à l'abri, plutôt que de foncer en plaine. La carte lui donne raison quand il
l'a bien lue.

*Cadrage proposé par le game-designer : « Une question sous le gris », avec la lecture du
terrain en appui.*

## Detailed Design

### Core Rules

*Conçu avec game-designer (règles) et level-designer (tailles, recette d'une carte
équitable, contrôles de validité). Les valeurs sont des valeurs de départ, à jouer en
test ; elles vivent dans des fichiers de données.*

#### La grille

1. **Tuiles carrées.** Une carte fait W × H tuiles, de 4 à 16 de côté (`MAX_MAP_SIZE`).
   Une tuile est désignée par (x, y), origine en haut à gauche, index `y × W + x`
   (formule `tile_index` du GDD 1). Hors de la grille, il n'y a pas de tuile.
2. **Huit voisins.** Deux tuiles sont voisines quand leur distance de Chebyshev vaut 1
   (formule 1) : les diagonales comptent (décision du 2026-10-29).
3. **Tailles** (décision du 2026-10-29) : la carte du **MVP fait 12 × 12**. Au lancement,
   deux tailles : **petite 10 × 10** (première partie contre l'IA passive) et **grande
   14 × 14**. Sur 12 × 12, traverser prend environ 6 à 8 tours, ce qui laisse le premier
   contact vers les tours 8 à 12.

#### Les terrains (MVP)

| Terrain | Coût d'entrée | Classe de défense | Vue | En une phrase |
|---|---|---|---|---|
| Plaine | 1 | 0 | Normale | Terrain ouvert : on y va vite, on y est exposé. |
| Forêt | 2 | 1 | Normale | Ralentit et protège. |
| Montagne | 3 | 2 | Cache ce qui est derrière ; une unité dessus voit plus loin | Lente à gravir, très protectrice, elle cache l'horizon. |
| Eau | infranchissable | — | Normale | On ne la traverse pas (MVP). |

4. **Points de mouvement entiers.** Se déplacer coûte la somme des coûts d'entrée des
   tuiles traversées ; quitter une tuile ne coûte rien ; une diagonale coûte comme un pas
   droit. Les points de mouvement de chaque unité appartiennent aux unités (6).
5. **Un pas toujours possible** (décision du 2026-10-29). Une unité qui a encore **tous**
   ses points de mouvement peut toujours entrer dans une tuile voisine franchissable et
   libre, même si elle coûte plus que ce qu'elle a. Sans cela, une unité lente ne
   gravirait jamais une montagne.
6. **Ce qui bloque le passage** : l'eau, le bord de la carte, et une tuile occupée par une
   unité visible. Une unité ennemie **cachée** ne bloque pas la validation : c'est
   l'embuscade (`design/gdd/commandes-evenements.md`, règle 6). Le passage d'une unité à
   travers une unité amie est décidé par les unités (6) ; valeur par défaut : interdit.
7. **Pas de coupe de coin** (décision du 2026-10-29). Un pas en diagonale est interdit
   quand les **deux** tuiles orthogonales qu'il longe sont infranchissables (eau, bord).
   Ce qui paraît fermé est fermé.
8. **La vue et les montagnes.** Seules les montagnes arrêtent la vue. Une tuile T est
   visible depuis V si elle est à portée (portée fixée par le brouillard, 5) et si aucune
   montagne ne se trouve **strictement entre** V et T sur la ligne entre leurs centres
   (formule 3, ligne fixe et déterministe). La montagne elle-même est visible ; ce qui est
   derrière est caché. Une unité **sur** une montagne voit une tuile plus loin et n'est pas
   gênée par les autres montagnes. La ligne n'est pas forcément symétrique (V voit T
   n'implique pas T voit V) : c'est accepté, chaque faction calcule sa propre vue.
9. **La défense vient de la tuile.** La classe de défense du terrain s'applique à l'unité
   qui s'y trouve. Ce système ne donne que la classe ; les bonus réels appartiennent au
   combat (8).

#### Les points d'intérêt

10. **Un par tuile, jamais sur l'eau.** Une tuile de départ porte le nœud de départ de sa
    faction et rien d'autre. Nœuds : en plaine seulement.
    Drones endormis : plaine ou forêt. Ruines : plaine ou forêt (pas de ruine sur une
    montagne au MVP).
11. **Distances minimales** (Chebyshev) : deux nœuds à 4 tuiles au moins l'un de
    l'autre ; une ruine candidate à 3 tuiles au moins de tout départ ; un drone endormi à
    3 tuiles au moins de tout départ ; un drone endormi jamais voisin d'un nœud.
12. **Ruines tirées par zones.** Une carte définit des **zones de ruines**, chacune avec
    au moins deux emplacements candidats et un nombre de ruines à tirer (en général 1).
    Au MVP : **9 emplacements, 3 ruines tirées**, une par zone de 3 candidats — près d'un
    départ, près de l'autre, au centre disputé — pour qu'aucun camp n'ait les ruines à sa
    porte, et pour qu'un joueur qui revient sur la même carte ne connaisse pas d'avance
    l'emplacement des ruines (CD-GDD-ALIGN : avec 2 candidats par zone, le pilier 5 s'use
    en quelques parties). Le tirage
    passe par la fonction de hasard de l'état (formule 2 du GDD 1), zone après zone dans
    l'ordre, pendant la mise en place de la partie seulement. Ce système tire ; les Ruines
    (13) écrivent et gèrent les ruines tirées.
13. **Un drone réveillé remplace son marqueur.** Le point d'intérêt « drone endormi »
    disparaît quand le drone se réveille ; l'unité prend sa place.

13bis. **Types des dormants tirés** (`design/gdd/reveil-drones.md`, règle 9). Pour chaque dormant dont le fichier donne une liste de types, le type est tiré pendant la mise en place par la fonction de hasard de l'état (formule 2 du GDD 1), dormant après dormant dans l'ordre, avec remise ; le tirage est reproduit par la symétrie de rotation, de sorte que les deux camps ont les mêmes types. Le coût de réveil d'un camp va ainsi de 13 (Ouvrier 5, deux Éclaireurs 4) à 21 (Ouvrier 5, deux Rempart 8).
13ter. **Contrainte de placement des ruines** (`design/gdd/ruines-fragments.md`, règle 32) : au moins une des 3 ruines tirées n'est pas sur le plus court chemin entre un départ et le nœud neutre le plus proche, pour qu'au moins une ruine coûte un vrai détour.

#### Le fichier de carte

14. **Contenu d'une carte** (données, dans `assets/data/maps/`) : version du schéma,
    identifiant, taille, grille des terrains, un départ par faction, emplacements des
    nœuds (départs compris), emplacements des drones endormis (pour chacun, un type fixe
    ou une **liste de types possibles** à tirer), zones de ruines (candidats et nombre à
    tirer), la **faction de mémoire** des ruines (une seule valeur au MVP), les postes des
    Gardiens, et en option sa symétrie. Le générateur procédural (21) produira
    des cartes dans le même format, validées par les mêmes contrôles. Une symétrie
    déclarée est **vérifiée** tuile par tuile, jamais supposée ; une version de schéma
    inconnue est refusée.
15. **Recette d'une carte équitable** (12 × 12). La carte est **symétrique par rotation
    de 180°** (ou par miroir) pour le terrain, les nœuds et les drones ; seules les ruines
    sont tirées au hasard. Part des terrains : eau 5 à 10 % de la carte ; parmi les
    tuiles de terre, forêt 20 à 25 % et montagne 8 à 10 %, **la plaine étant le reste**
    (environ 65 à 72 %), sans bande propre — sinon les bandes ne peuvent pas toutes être
    tenues sur une carte de 12 × 12 (formule 6). L'eau forme des lacs d'au moins
    2 tuiles, les montagnes des crêtes de 2 à 4 tuiles, jamais un mur : aucun groupe de
    montagnes reliées ne dépasse 4 tuiles. Départs à 8 ou 9
    tuiles l'un de l'autre ; autour de chaque départ, un rayon de 2 sans montagne ni eau.
    4 nœuds neutres (une paire proche de chaque départ, une paire disputée au centre) ;
    6 drones endormis : **un Ouvrier fixe à 3 tuiles de chaque départ** (garantie de
    capture), un dormant près des nœuds disputés de chaque côté et un derrière un terrain de
    chaque côté, dont le **type est tiré à la mise en place** parmi Éclaireur, Assaut et
    Rempart (règle 13bis). Ceux du côté de l'IA sont **gardés** : au moins un Gardien à
    portée d'attaque d'un tour de chacun (`design/gdd/ia-ennemie.md`, règle 11, calcul de
    couverture identique au générateur, 21).
16. **Lisible sur un téléphone.** Un amas de forêt ou de montagne tient dans un rectangle
    de 4 × 3 tuiles (dans un sens ou dans l'autre) ; une montagne ne cache jamais un point d'intérêt : chaque point
    d'intérêt (et chaque départ) est visible depuis **au moins la moitié** des tuiles
    franchissables situées à 2 ou 3 tuiles de lui (formule 3). Ce qu'une crête **peut**
    cacher : le terrain derrière elle (un col, un lac, une forêt) et les unités qui s'y
    trouvent, ennemies comprises — c'est la question que pose la montagne ;
    ce qu'elle ne cache jamais complètement : un point d'intérêt ; les terrains se distinguent par leur silhouette (hauteur, forme), pas
    seulement par leur couleur (`design/accessibility-requirements.md`).
17. **Une carte invalide est refusée.** Les contrôles de validité (Edge Cases, et
    formule 4 pour l'équité) s'exécutent dans l'intégration continue et au chargement.

### States and Transitions

| État | Depuis | Déclencheur | Ce qui se passe |
|---|---|---|---|
| ÉCRITE | — | Carte faite à la main, ou produite par le générateur (21) | Fichier de données |
| VALIDÉE | ÉCRITE | Contrôles de validité (CI ou chargement) | Une carte invalide est refusée et ne peut pas être jouée |
| MISE EN PLACE | VALIDÉE | Nouvelle partie (3) | Terrain, taille et points d'intérêt copiés dans l'état ; ruines tirées ; compteur de tirages avancé |
| EN JEU | MISE EN PLACE | Premier tour | Le terrain ne change plus ; les marqueurs ne changent que par leurs propriétaires (11, 13, 7) |
| TERMINÉE | EN JEU | Fin de partie (3) | — |

Une sauvegarde contient le terrain et les points d'intérêt de la partie : modifier un
fichier de carte plus tard ne corrompt jamais une partie en cours. Aucun tirage n'a lieu
après la mise en place.

### Interactions with Other Systems

Seuls l'état (1) et les commandes (23) ont un GDD : les autres lignes sont des **contrats
provisoires**.

| # | Système | Ce que la carte fournit ou reçoit |
|---|---|---|
| 1 | Modèle d'état de partie | Écrit taille, terrain et points d'intérêt à la mise en place ; tire les ruines par la fonction de hasard ; aucune écriture pendant la partie |
| 4 | Contrôles tactiles | Fournit les requêtes de tuile et de voisins, le terrain de chaque tuile |
| 5 | Brouillard et vision | Fournit la géométrie de la vue (règle 8, formule 3) ; le brouillard possède la portée, les tuiles visibles et l'exception « ruine visible dans le brouillard » |
| 6 | Unités drones | Fournit coût de déplacement, franchissabilité, règle du pas toujours possible et de la coupe de coin ; possède les points de mouvement |
| 8 | Combat | Fournit la classe de défense de chaque tuile et le voisinage ; possède les bonus |
| 9 | IA à intentions | Mêmes requêtes, à travers la vue de sa faction |
| 11 | Nœuds | Fournit les emplacements de nœuds ; possède le propriétaire de chaque tuile |
| 13 | Ruines et fragments | Fournit les ruines tirées ; 13 les écrit et les marque lues |
| 15 | Recoloration du monde | Fournit le terrain de chaque tuile (pour le rendu) ; 15 possède la couleur |
| 21 | Génération procédurale | Produit des cartes au même format, validées par les mêmes contrôles |
| 23 | Commandes et événements | La validation de DÉPLACER utilise les règles 4 à 7 |

## Formulas

*Proposées par systems-designer. Les points de mouvement des unités appartiennent aux
unités (6), la portée de vue au brouillard (5), les bonus de défense au combat (8).*

### 1. Distance de Chebyshev

The chebyshev formula is defined as:

`d = max(|x1 − x2|, |y1 − y2|)`

**Variables:**
| Variable | Type | Range | Source | Description |
|----------|------|-------|--------|-------------|
| x1, y1, x2, y2 | int | 0..15 | calculated | Coordonnées des deux tuiles |
| d | int | 0..15 | calculated | Distance en « coups de roi » |

**Output Range:** 0 à 15 ; d = 1 signifie voisines.
**Example:** (2, 3) → (5, 4) : max(3, 1) = 3.

### 2. Coût d'un chemin et accessibilité

The path_cost formula is defined as:

`path_cost = Σ_{i=1..k} c(t_i)` ;
`atteignable = franchissable_et_libre(t_1) ∧ (path_cost ≤ PM_restants ∨ (k = 1 ∧ PM_restants = PM_max))`

**Variables:**
| Variable | Type | Range | Source | Description |
|----------|------|-------|--------|-------------|
| c(t) | int | 1, 2, 3 ou infranchissable | data file | Coût d'entrée du terrain de t (eau infranchissable) |
| t_1..t_k | tuiles | k de 1 à 255 | calculated | Chemin sans la tuile de départ ; chaque pas respecte les règles 6 et 7 |
| PM_restants, PM_max | int | — | calculated (GDD 6) | Points de mouvement de l'unité |

**Output Range:** 1 à 765, ou infranchissable (refusé). Le coût le plus bas se calcule
par un plus court chemin sur des entiers (Dijkstra). La seconde moitié de la condition
est le pas toujours possible (règle 5).
**Example:** PM = 3, chemin forêt puis plaine : 2 + 1 = 3, atteignable. Une unité à
PM_max = 2, avec tous ses points, peut entrer dans une montagne (coût 3).

### 3. Ligne de vue

The sight_blocked formula is defined as:

`bloquée(V, T) = ¬sur_montagne(V) ∧ ∃ p ∈ ligne(V, T) \ {V, T} : terrain(p) = montagne`

`ligne` est un tracé de Bresenham en entiers, terme d'erreur doublé. L'axe principal est
celui du plus grand écart (x en cas d'égalité). Départ : D = 2·d_mineur − d_majeur. À
chaque pas : marquer la case ; si D > 0 (strictement), avancer sur l'axe mineur et faire
D = D − 2·d_majeur ; puis D = D + 2·d_mineur. **Départage** : quand D = 0 (ligne qui
passe exactement par un coin), l'axe mineur n'avance pas.

**Variables:**
| Variable | Type | Range | Source | Description |
|----------|------|-------|--------|-------------|
| V, T | tuiles | sur la carte | calculated | Tuile qui regarde, tuile regardée |
| d_majeur, d_mineur | int | 0..15 | calculated | Écarts absolus sur chaque axe |
| D | int | −60..60 | calculated | Terme d'erreur |

**Output Range:** vrai ou faux. Une tuile voisine n'est jamais cachée. La portée (et le
+1 sur une montagne) appartient au brouillard (5).
**Example:** V (0, 0) → T (4, 2) : D part de 0 ; cases (1, 0), (2, 1), (3, 1). Une
montagne en (2, 1) cache T.

### 4. Équité d'une carte non symétrique

The fairness formula is defined as:

`équitable = ∀ point d'intérêt p : |C_A(p) − C_B(p)| ≤ 1`

**Variables:**
| Variable | Type | Range | Source | Description |
|----------|------|-------|--------|-------------|
| C_f(p) | int | 0..765, ou infranchissable | calculated | Coût minimal depuis le départ de la faction f (formule 2, sans unités ni pas toujours possible) |

**Output Range:** vrai ou faux. Un coût infranchissable rend la carte invalide.
Obligatoire quand la carte ne déclare pas de symétrie.
**Example:** un nœud à 14 et 15 passe ; à 14 et 16, la carte échoue.

### 5. Tirage des ruines d'une zone

The zone_draw formula is defined as:

`pour i de 0 à k − 1 : j = i + draw(m − i) ; échanger c[i] et c[j]` → ruines = c[0..k − 1]

**Variables:**
| Variable | Type | Range | Source | Description |
|----------|------|-------|--------|-------------|
| c | liste de tuiles | ordre du fichier | data file | Emplacements candidats de la zone |
| m | int | 2..16 | data file | Nombre de candidats |
| k | int | 1..m − 1 | data file | Ruines à tirer |

**Output Range:** k candidats distincts. Le compteur de tirages avance de k (3 au total
sur la carte du MVP). Les zones sont tirées dans l'ordre du fichier.
**Example:** m = 2, k = 1, draw(2) = 1 → c[1] est retenu.

### 6. Part d'un terrain

The share_ok formula is defined as:

`lo × N ≤ 100 × compte_t ≤ hi × N`, avec N = W × H pour l'eau, et N = W × H − eau pour
les terrains de terre (forêt, montagne ; la plaine est le reste)

**Variables:**
| Variable | Type | Range | Source | Description |
|----------|------|-------|--------|-------------|
| compte_t | int | 0..256 | calculated | Tuiles du terrain t |
| lo, hi | int | 0..100 | data file | Bande en pourcentage |

**Output Range:** vrai ou faux, en entiers seulement.
**Example:** 144 tuiles, 10 d'eau : 5 × 144 = 720 ≤ 1 000 ≤ 1 440, l'eau passe ; 134
tuiles de terre, 30 de forêt : 20 × 134 = 2 680 ≤ 3 000 ≤ 3 350, la forêt passe.

## Edge Cases

*Proposés par systems-designer ; les contrôles de validité s'appliquent aux cartes faites
à la main comme à celles du générateur (21).*

### Validité d'un fichier de carte

- **Si une tuile porte un terrain inconnu** : la carte est refusée ; l'erreur donne la
  tuile (x, y) et l'identifiant. Jamais de plaine par défaut.
- **Si une zone a moins de max(2, k + 1) candidats** : la carte est refusée ; le tirage
  serait impossible ou sans hasard.
- **Si deux zones partagent un candidat** : la carte est refusée ; la même tuile pourrait
  être tirée deux fois.
- **Si une modification rend un candidat illégal** : l'intégration continue refuse toute
  la carte. Un candidat n'est jamais retiré en silence, ce qui changerait m et la suite
  des tirages.
- **Si un départ est entouré d'eau** : la carte est refusée (règle 15 ; formule 4 donne
  un coût infranchissable).
- **Si un point d'intérêt est visible depuis moins de la moitié des tuiles franchissables
  à 2 ou 3 tuiles de lui** : la carte est refusée (règle 16).
- **Si les bandes de terrain ne sont pas tenues** (formule 6) : la carte est refusée.

### Pendant la partie

- **Si un pas en diagonale passe entre l'eau et le bord de la carte** : impossible ; les
  deux tuiles orthogonales sont toujours dans la carte quand la destination l'est. La
  règle 7 se réduit à deux tuiles d'eau.
- **Si le pas toujours possible n'a pour voisin que de l'eau ou des tuiles occupées** :
  aucun déplacement ; DÉPLACER est refusée (23). Le pas toujours possible exige une tuile
  franchissable et libre.
- **Si une ligne de vue passe exactement par un coin** : le départage de la formule 3
  s'applique. V (0, 0) → T (2, 1) ne vérifie que (1, 0). La vue peut être à sens unique ;
  la règle 8 l'accepte.
- **Si une unité sur une montagne regarde une autre montagne** : elle voit cette montagne
  et les tuiles derrière, dans sa portée + 1. Portée : brouillard (5).

### Cas à reprendre dans un autre GDD

- **Si une sauvegarde est chargée après une modification de son fichier de carte** : la
  sauvegarde garde son propre terrain et ses points d'intérêt ; le fichier n'est pas
  relu ; un écart est seulement journalisé. Propriétaire : 1 et 16.
- **Si la carte est plus petite que l'écran en paysage** : elle est centrée, avec des
  marges neutres. Propriétaire : 4 et le HUD.
- **Si le générateur (21) produit une carte invalide** : les mêmes contrôles la refusent ;
  la politique de nouvel essai appartient à 21.
- **Ce que deviennent les ruines tirées** : propriétaire 13.

## Dependencies

### En amont (ce système dépend de)

| Système | Nature | Dure ou souple |
|---|---|---|
| 1 Modèle d'état de partie | La carte écrit sa tranche (taille, terrain, points d'intérêt) à la mise en place et tire les ruines par la fonction de hasard de l'état | Dure (`design/gdd/modele-etat-partie.md`, tranche Carte, formules 1 et 2) |

La carte dépend aussi du **contenu** : les fichiers de cartes faits à la main
(`assets/data/maps/`) et les valeurs de terrain (coûts, classes de défense) dans un
fichier de configuration.

### En aval (systèmes qui dépendent d'elle)

| Système | Ce qu'il utilise | Dure ou souple |
|---|---|---|
| 4 Contrôles tactiles | Requêtes de tuile et de voisins | Dure |
| 5 Brouillard et vision | Géométrie de la vue (règle 8, formule 3) | Dure |
| 6 Unités drones | Coûts, franchissabilité, pas toujours possible, coupe de coin | Dure |
| 8 Combat | Classe de défense par tuile, voisinage | Dure |
| 9 IA à intentions | Toutes les requêtes, par sa vue | Dure |
| 11 Nœuds | Emplacements de nœuds | Dure |
| 13 Ruines et fragments | Ruines tirées | Dure |
| 15 Recoloration du monde | Terrain de chaque tuile | Dure |
| 21 Génération procédurale | Format de carte et contrôles de validité | Dure |
| 23 Commandes et événements | Règles de déplacement pour valider DÉPLACER | Dure |

### Bidirectionnalité

- `design/gdd/modele-etat-partie.md` cite déjà la carte (tranche Carte, interaction 2).
- `design/gdd/commandes-evenements.md` cite la règle d'embuscade que la règle 6 reprend ;
  il doit citer ce document pour les règles de déplacement.
- Les GDD 4, 5, 6, 8, 9, 11, 13, 15 et 21 doivent citer ce document.

### Décisions techniques renvoyées à un ADR

- Rendu des terrains et de la grille (avec la recoloration, 15, et l'art bible).
- Format exact du fichier de carte et outil d'édition des cartes.

## Tuning Knobs

*Dans des fichiers de données (`assets/data/`). Valeurs de départ, à jouer en test.*

| Paramètre | Valeur | Plage sûre | Trop haut | Trop bas | Interagit avec |
|---|---|---|---|---|---|
| Coût d'entrée de la forêt | 2 | 1..3 | La forêt devient un mur pour les unités lentes | La forêt ne coûte rien de plus : plus de choix de chemin | Points de mouvement (6) ; pas toujours possible |
| Coût d'entrée de la montagne | 3 | 2..4 | Seul le pas toujours possible permet d'y monter | Montagne aussi facile que la forêt | Idem |
| Classes de défense (plaine, forêt, montagne) | 0, 1, 2 | 0..3 | Défendre domine, parties lentes | Le terrain ne compte plus en combat | Bonus du combat (8) |
| Bonus de vue sur une montagne | +1 | 0..2 | Les sommets dominent toute la carte | La montagne n'a plus d'intérêt de vue | Portée (5) |
| Taille de la carte du MVP | 12 × 12 | 10..14 | Plus de défilement, tour d'IA plus long | Contact trop tôt, ruines sans mystère | Budget de l'IA (GDD 1, formule 5) |
| Ruines : candidats / tirées (MVP) | 9 / 3 (3 candidats, 1 tirée par zone) | au moins k + 1 candidats par zone (contrôle de validité) ; 3 ou plus recommandés sur les cartes du lancement | Moins de place pour les autres points d'intérêt | 2 candidats par zone : un joueur qui revient connaît vite les emplacements (pilier 5) | Formule 5 ; pool de fragments (22) |
| Distance minimale ruine–départ | 3 | 2..5 | Premier fragment trop loin pour les 5 premiers tours | Une ruine visible dès le départ, sans question | Flow du concept (premier fragment avant le tour 5) |
| Bandes de terrain (eau, forêt, montagne) | 5–10 %, 20–25 %, 8–10 % | ± 5 points | Carte encombrée, chemins rares | Terrain sans choix | Formule 6 |

*Les valeurs de coût et de défense sont aussi lues par l'IA (9) : les changer change sa
façon de jouer.*

## Visual/Audio Requirements

Exigences pour l'art bible et la recoloration (15), qui possèdent le rendu :
- **Chaque terrain se reconnaît à sa silhouette** (hauteur, forme), pas seulement à sa
  couleur : la montagne est un relief net, la forêt un volume plus bas, l'eau une surface
  plate et basse (`design/accessibility-requirements.md`).
- **Le gris d'abord.** Une tuile non revendiquée garde son terrain lisible en gris-bleu
  désaturé ; la couleur de faction s'ajoute sans masquer le terrain (Visual Identity
  Anchor du concept).
- **Les points d'intérêt se voient de loin** : une ruine reste repérable sous le
  brouillard depuis l'autre bout de l'écran ; une montagne ne cache jamais un point
  d'intérêt (règle 16).

📌 **Asset Spec** — après l'approbation de l'art bible, lancer
`/asset-spec system:carte-tuiles-terrain` pour décrire les modèles de terrain.

## Game Feel

Sans objet en propre : la carte ne réagit pas au doigt, les contrôles (4) s'en chargent.
Une exigence : la vue d'ensemble se lit **d'un regard** — un joueur doit pouvoir dire,
en moins de deux secondes, quel terrain ralentit et où se trouve la crête qui cache
l'horizon.

## UI Requirements

- **Centrer sur son départ** : comme la carte de 12 × 12 dépasse l'écran en portrait
  (environ 8 colonnes visibles), le HUD doit offrir un moyen de revenir à son départ, en
  plus des puces qui centrent la carte sur une menace, une ruine ou une perte
  (`design/ux/hud.md`).
- **Aperçu de la portée** : les tuiles atteignables tiennent compte des coûts de
  terrain ; leur affichage appartient au HUD (17).
- **Information d'une tuile** : un appui long (avec son équivalent en appui simple,
  `design/accessibility-requirements.md`) dit le terrain, son coût et sa défense en une
  phrase.

> **📌 UX Flag — Carte en tuiles et terrain** : le bouton « Centrer sur mon départ » et la
> fiche de tuile sont à ajouter à `design/ux/hud.md` avant d'écrire les epics.

## Cross-References

| Document | Ce qui en est repris ou ce qui y est imposé |
|---|---|
| `design/gdd/game-concept.md` | Core Mechanics point 1 (carte en tuiles, brouillard, terrain) ; Visual Identity Anchor (gris d'abord, ruines visibles sous le brouillard, silhouettes) ; Flow State Design (premier fragment dans les 5 premiers tours) ; Technical Considerations (cartes à graine, 2 tailles) |
| `design/gdd/systems-index.md` | Creative Director Notes (points d'intérêt, ruines tirées parmi des emplacements candidats) ; Producer Note (6 à 10 cartes fixes au lancement, générateur en Alpha) |
| `design/gdd/modele-etat-partie.md` | Tranche Carte ; formules `tile_index` et `draw` ; `MAX_MAP_SIZE` |
| `design/gdd/commandes-evenements.md` | Règle 6 (embuscade) ; validation de DÉPLACER |
| `design/ux/hud.md` | Tuiles ≥ 31 pt ; 8 colonnes visibles en portrait, 12 en paysage ; puces qui centrent la carte |
| `design/accessibility-requirements.md` | Terrains distingués par la forme ; appui long jamais seul accès à une information |

## Acceptance Criteria

*Rédigés avec qa-lead. Étiquettes : **[U]** test unitaire dans `tests/unit/map/`, sur des
cartes construites par des fonctions de fabrique (aucun accès fichier) ; **[I]** test
d'intégration dans `tests/integration/map/` — les critères de validité s'exécutent sur
**chaque** fichier de `assets/data/maps/` ; **[D]** capture d'écran conservée dans
`production/qa/evidence/` et validation par le responsable artistique.*

### Règles

- **AC-01 (règle 1)** [U] — **GIVEN** des cartes de 3, 4, 16 et 17 tuiles de côté,
  **WHEN** on les valide, **THEN** 4 et 16 passent, 3 et 17 sont refusées ; **GIVEN**
  W = 12, **THEN** (5, 2) a l'index 29 et (12, 0) n'est pas une tuile.
- **AC-02 (règle 2)** [U] — **GIVEN** la tuile (5, 5), **THEN** elle a 8 voisines ;
  **GIVEN** un coin, **THEN** 3.
- **AC-03 (règle 3)** [I] — **GIVEN** les cartes livrées, **THEN** chacune fait 10 × 10,
  12 × 12 ou 14 × 14, et la carte du MVP fait 12 × 12.
- **AC-04 (règle 4)** [U] — **GIVEN** 3 PM et un pas en diagonale en forêt puis un pas en
  plaine, **THEN** le coût vaut 3 et l'arrivée est atteignable ; quitter une montagne
  coûte 0.
- **AC-05 (règle 5)** [U] — **GIVEN** PM_max = 2 et tous ses PM, **THEN** une montagne
  voisine et libre est atteignable ; **GIVEN** 1 PM sur 2, **THEN** elle ne l'est pas ;
  **GIVEN** seulement de l'eau ou des tuiles occupées autour, **THEN** DÉPLACER est
  refusée.
- **AC-06 (règle 6)** [U] — **GIVEN** une unité visible (amie ou ennemie), de l'eau ou le
  bord, **THEN** le passage est bloqué.
- **AC-07 (règle 7)** [U] — **GIVEN** de l'eau en (1, 0) et en (0, 1), **THEN** le pas
  (0, 0) → (1, 1) est refusé ; **GIVEN** une seule de ces deux tuiles en eau, **THEN** il
  est permis.
- **AC-08 (règle 8)** [U] — **GIVEN** une montagne strictement entre V et T, **THEN** T
  est cachée et la montagne reste visible ; **GIVEN** V sur une montagne, **THEN** aucune
  montagne ne lui cache rien.
- **AC-09 (règle 9)** [U] — **GIVEN** un fichier de configuration modifié dans la
  fabrique, **THEN** la classe de défense de chaque terrain suit la valeur du fichier
  (preuve qu'elle n'est pas écrite en dur).
- **AC-10 (règle 10)** [I] — **GIVEN** les cartes livrées, **THEN** aucun point d'intérêt
  n'est sur l'eau ou une montagne, une tuile de départ ne porte que son nœud de départ,
  les nœuds sont en plaine, et une tuile porte au plus un point d'intérêt.
- **AC-11 (règle 11)** [I] — **GIVEN** les cartes livrées, **THEN** les quatre distances
  minimales tiennent ; [U] **GIVEN** deux nœuds à 3 tuiles, **THEN** la carte est
  refusée.
- **AC-12 (règle 12)** [U] — **GIVEN** une graine fixe, **WHEN** la mise en place
  s'exécute deux fois, **THEN** les mêmes ruines sont tirées et le compteur avance de 3 ;
  un espion n'enregistre aucun tirage après la mise en place.
- **AC-13 (règle 13)** [I] — **GIVEN** un drone qui se réveille, **THEN** son marqueur a
  disparu et l'unité est sur sa tuile.
- **AC-14 (règle 14)** [U] — **GIVEN** un fichier auquel il manque un champ obligatoire,
  ou une version de schéma inconnue, **THEN** il est refusé et l'erreur nomme le champ.
- **AC-15 (règle 15)** [I] — **GIVEN** chaque carte livrée de 12 × 12, **THEN** la
  symétrie déclarée est vérifiée pour le terrain, les nœuds et les drones ; les départs
  sont à 8 ou 9 tuiles ; le rayon de 2 autour de chaque départ n'a ni montagne ni eau ;
  4 nœuds neutres et 6 drones ; chaque lac a au moins 2 tuiles ; aucun groupe de
  montagnes ne dépasse 4 tuiles.
- **AC-16 (règle 16)** [I] — **GIVEN** les cartes livrées, **THEN** chaque point
  d'intérêt et chaque départ est visible (formule 3) depuis au moins la moitié des tuiles
  franchissables à 2 ou 3 tuiles, et chaque amas de forêt ou de montagne tient dans 4 × 3 ;
  [U] **GIVEN** une crête qui cache une ruine, **THEN** la carte est refusée.
- **AC-17 (règle 17)** [I] — **GIVEN** une carte de fabrique par cas de validité des Edge
  Cases, **THEN** elle est refusée par l'intégration continue et par le chargement,
  l'erreur donne la tuile et l'identifiant, et un terrain inconnu ne devient jamais de la
  plaine.

### Formules

- **AC-F1** [U] — (2, 3) → (5, 4) donne 3 ; une tuile vers elle-même donne 0.
- **AC-F2** [U] — sur 20 cartes de fabrique, le plus court chemin calculé est égal au
  minimum obtenu par recherche exhaustive.
- **AC-F3** [U] — cas de référence : (0, 0) → (4, 2) vérifie (1, 0), (2, 1), (3, 1) ;
  (0, 0) → (2, 1) vérifie seulement (1, 0) ; (2, 1) → (0, 0) vérifie (1, 1), donc une
  montagne en (1, 0) donne une vue à sens unique ; une voisine n'est jamais cachée.
- **AC-F4** [U] — 14 et 15 passent, 14 et 16 échouent, un point d'intérêt inaccessible
  échoue.
- **AC-F5** [U] — m = 2, k = 1, draw(2) = 1 → c[1] ; les zones sont tirées dans l'ordre du
  fichier.
- **AC-F6** [U] — 10 tuiles d'eau sur 144 passent, 6 échouent (600 < 720) ; 30 forêts
  sur 134 tuiles de terre passent ; tous les calculs sont entiers.

### Entre systèmes

- **AC-X1** [I] — **GIVEN** un ennemi caché sur le chemin, **WHEN** DÉPLACER est validée
  puis appliquée, **THEN** l'unité s'arrête sur la dernière tuile libre et l'ennemi est
  révélé (`design/gdd/commandes-evenements.md`, règle 6).
- **AC-X2** [I] — **GIVEN** une carte sans symétrie déclarée, **THEN** la formule 4
  s'applique ; une carte en miroir dont un nœud a été déplacé de 2 tuiles échoue.
- **AC-X3** [I] — **GIVEN** une sauvegarde, **WHEN** le terrain de son fichier de carte
  est modifié et la sauvegarde rechargée, **THEN** le terrain et les points d'intérêt
  sauvegardés sont inchangés, le fichier n'est pas relu, et l'écart est journalisé.
- **AC-D1** [D] — **GIVEN** des captures en niveaux de gris, en portrait, de chaque carte
  livrée sur l'appareil de référence, **WHEN** 5 personnes qui ne les connaissent pas
  nomment 20 tuiles marquées, **THEN** au moins 95 % des réponses sont justes et chaque
  réponse est donnée en moins de 2 secondes (*seuils proposés, à confirmer*).
- **AC-D2 (pilier 5, test de jeu)** [D] — **GIVEN** 5 testeurs sur la carte du MVP,
  **WHEN** chacun joue les 5 premiers tours, **THEN** au moins 4 sur 5 ont repéré une
  ruine (lueur visible sous le brouillard) avant la fin du tour 5, et chaque ruine tirée
  est repérable depuis l'autre bout de l'écran sur une capture en portrait. La lueur
  elle-même appartient au brouillard (5) et aux ruines (13).

### Limites connues

- La durée d'une traversée (6 à 8 tours) et le tour du premier contact (8 à 12) dépendent
  des points de mouvement (6) : ils se vérifient en playtest, pas ici.
- Les emplacements « proche des nœuds disputés » et « derrière un terrain » des drones
  (règle 15) restent des consignes de conception, sans seuil automatique.
- AC-D1 attend le modèle exact de l'appareil de référence et un responsable artistique.

## Open Questions

| Question | Owner | Deadline | Resolution |
|---|---|---|---|
| Une unité peut-elle traverser une unité amie ? (valeur par défaut : non) | game-designer | GDD des unités (6) | |
| Valeurs des bonus de défense par classe de terrain | systems-designer | GDD du combat (8) | |
| Portée de vue des unités et règle exacte de l'exception « ruine visible dans le brouillard » | game-designer | GDD du brouillard (5) | |
| Ruines sur des montagnes (cachées par la ligne de vue) : à envisager en Alpha ? | level-designer | Après le palier MVP | |
| Ligne de vue à sens unique (règle 8) : le joueur la comprend-il, ou dit-il « l'IA m'a vu et je ne la voyais pas » ? Sinon, rendre la vue symétrique (V voit T si et seulement si T voit V) | game-designer | GDD du brouillard (5) et premier playtest | |
| Nombre de candidats par zone sur les cartes du lancement (3 au MVP) : suffisant pour que le pilier 5 tienne après plusieurs parties sur la même carte ? | level-designer | Premier playtest de rejouabilité | |
| Les 6 à 10 cartes du lancement : qui les dessine, avec quel outil ? | producer, level-designer | Avant le palier de lancement | |
| Eau franchissable plus tard (bateaux) ? | game-designer | Alpha | |
| Les terrains, les coûts et les classes de défense sont des valeurs de départ, à jouer en test | game-designer | Premier playtest du MVP | |
