# Nœuds

> **Status**: Designed (pending /design-review)
> **Author**: user + Claude (economy-designer, game-designer, systems-designer)
> **Last Updated**: 2026-10-30
> **Last Verified**: 2026-10-30
> **Implements Pillar**: Pilier 1 « La meute se voit grandir » ; pilier 3 « Lisible comme Polytopia » ; pilier 4 « La puissance se mérite »
> **Creative Director Review (CD-GDD-ALIGN)**: REVISED 2026-10-30 — CONCERNS (renvoi à une règle inexistante pour le repli ; aucune alerte pour l'élimination d'un nœud de départ ; parade d'une capture annoncée du dernier nœud non critérisée ; retour de la montée à relier au poids du territoire dans le score) corrigées : position sur le repli énoncée, alerte aussi sur capture annoncée, critère ajouté, contrôle d'équilibre relié aux poids du score

## Summary

Les nœuds sont les points fixes de la carte qui produisent l'énergie et ancrent le territoire : six
au MVP, chacun avec un propriétaire et un niveau de 1 à 3. Un nœud se capture instantanément, par un
Ouvrier ou un Bastion posé sur sa tuile libre, et perd alors un niveau ; il se monte avec de
l'énergie, sans unité, une fois par tour. Le niveau fixe le revenu et le rayon d'un territoire qui se
recolore autour du nœud ; une faction qui perd son dernier nœud est éliminée. Ce système existe pour
que la croissance de la meute se voie sur la carte (pilier 1) et pour que chaque perte soit annoncée
et évitable (pilier 4).

> **Quick reference** — Layer: `Feature` · Priority: `MVP` · Key deps: `Carte en tuiles et terrain, Énergie`

## Overview

Les nœuds sont les points fixes de la carte qui produisent l'énergie et ancrent le territoire :
au plus 10 par partie (`MAX_NODES`), six au MVP (un nœud de départ par camp et quatre neutres,
`design/gdd/carte-tuiles-terrain.md`). Chaque nœud a un **propriétaire** (une faction ou
personne) et un **niveau** de 1 à 3. Ce système possède la tranche « Nœuds » de l'état
(`design/gdd/modele-etat-partie.md`), la validation et l'écriture de **CAPTURER** et de
**MONTER_NŒUD**, et il est le **seul écrivain du propriétaire des tuiles** : quand un nœud
change de main ou de niveau, le territoire autour de lui est recalculé, et les ruines (13) et
la recoloration (15) passent par son interface pour l'écrire. Le niveau fixe le revenu
(`design/gdd/energie.md`) et le rayon du territoire.

Un nœud ne se capture que s'il est libre d'unité : la tuile n'accepte qu'une unité, donc le
défenseur doit d'abord être chassé ou détruit. Seuls l'Ouvrier de la meute et le Bastion des
Gardiens capturent (`design/gdd/unites-drones.md`). La capture est instantanée à l'action ;
pour l'IA, elle est annoncée un tour à l'avance comme une intention. Une faction qui perd son
dernier nœud est éliminée.

*Cadrage : à la fois la couche de données (tranche, territoire) et la règle qui rend la
croissance de la meute visible. Aucun ADR n'existe encore sur les nœuds.*

## Player Fantasy

*Cadrage : direct, avec une couche d'infrastructure dessous. Retenu (`creative-director`,
2026-10-30) : « Allumer le monde » comme fantasme principal, « Le point qu'on tient » comme
contrepoint.*

**Allumer le monde.** L'Ouvrier capture le nœud central, et la teinte de la meute se répand
d'un coup sur le gris, tuile après tuile, jusqu'au bout du rayon. Le revenu suit, mais ce que
le joueur retient, c'est la carte qui a changé (pilier 1). Monter un nœud élargit la lisière
saturée d'un anneau : on ne s'étend pas plus loin, on tient plus fort.

**Le point qu'on tient.** Les hachures orange-rouge annoncent une capture au prochain tour :
le joueur peut chasser l'unité ennemie à temps, ou la laisser faire et voir son territoire
repasser au gris. Ce qu'on a allumé peut s'éteindre, et on l'a vu venir (pilier 4).

**Ton.** Sobre, du côté de la machine : *allumer, ancrer, tenir, éteindre*, jamais *conquérir* ni
*piller*. Les nœuds sont bâtis par les drones, pas par les humains : ils restent droits et
froids, jamais ocre. Le moment où la conquête change de sens (« pour qui allume-t-on ? »)
appartient au pilier 2 et n'est pas écrit ici.

**Trois échecs à éviter.**
1. *Le compteur de revenu* : si monter un nœud ne fait qu'ajouter « +2 » dans le HUD, le
   pilier 1 est trahi. Chaque niveau se voit sur la carte.
2. *Le repli sur ses nœuds* : une unité garée sur le nœud bloque toute capture ; ce repli
   est **acceptable au MVP** : le chasser est la parade, comme dans Polytopia, et la montée reste
   possible (règle 11) ; à rejouer en test.
3. *L'élimination arbitraire* : perdre le dernier nœud élimine la faction d'un coup ; il faut
   une alerte de dernier nœud, et côté IA une capture qui ne vient jamais sans annonce
   (pilier 4).

## Detailed Design

*Décisions du 2026-10-30 : rayon du territoire 1, 2, 3 selon le niveau (le plus proche gagne) ;
capture instantanée, la tuile du nœud devant être libre d'unité ; seuls l'Ouvrier et le Bastion
capturent ; montée sans unité, une fois par nœud et par tour ; **un nœud capturé perd un
niveau (minimum 1)** ; capture de l'IA annoncée un tour à l'avance. Les valeurs chiffrées sont
des valeurs de départ [PROP].*

### Core Rules

**Tranche et mise en place**

1. **Tranche Nœuds.** Par nœud : `id` (compteur d'en-tête, jamais réutilisé), `tuile` (fixe),
   `propriétaire` (identifiant de faction, ou NEUTRE), `niveau` (1 à 3), plus deux entiers
   proposés : `depuis_tour` (tour où le propriétaire actuel l'a acquis) et `monté_au_tour` (dernier
   tour de MONTER_NŒUD, −1 si aucun). Ces deux champs servent aux règles « possédé depuis le
   début du tour » et « une montée par nœud et par tour » ; ils ne figurent pas encore dans la
   tranche de `design/gdd/modele-etat-partie.md` (voir Open Questions). Chaque tuile porte aussi
   un `ancrage` (NŒUD ou RUINE, règle 15).
2. **Création.** À la mise en place, le fichier de carte donne les emplacements de nœuds (départs
   compris), parcourus dans l'ordre du fichier, avec des identifiants croissants. Un nœud de départ
   appartient à la faction de son départ ; les autres sont neutres. Tous sont de niveau 1,
   `depuis_tour` = 0, `monté_au_tour` = −1. Le territoire est calculé une fois (règle 13). Une carte
   de plus de `MAX_NODES` = 10 nœuds, ou avec un nœud hors plaine, est refusée.
3. **Écrivain unique.** Seul ce système écrit le `propriétaire` et l'`ancrage` des tuiles ; 13 et 15
   passent par son interface. Les parcours se font par identifiant croissant ; tout est entier.

**CAPTURER (valider, puis appliquer)**

4. **Ordre de validation** ; la première vérification qui échoue est rendue. Un astérisque marque
   un code à ajouter à 23 (`design/gdd/commandes-evenements.md`) :
   PARTIE_TERMINÉE, PAS_VOTRE_TOUR, UNITÉ_INCONNUE, TYPE_NON_CAPABLE* (autre qu'Ouvrier ou
   Bastion, `design/gdd/unites-drones.md`, règle 7), DÉJÀ_AGI, PAS_SUR_UN_NŒUD, NŒUD_DÉJÀ_POSSÉDÉ
   (le nœud appartient déjà à la faction de l'unité ; un nœud neutre **ou ennemi** est capturable).
5. **Application**, dans cet ordre : l'unité passe à « a agi » (fonction de 6) ; `propriétaire` =
   faction, `depuis_tour` = tour courant, `monté_au_tour` = −1 ; **le niveau baisse d'un cran
   (minimum 1)** ; recalcul complet du territoire (règle 13) ; appel de 15 ; si l'ancien
   propriétaire n'est pas neutre et ne tient plus aucun nœud, appel de l'élimination de 3 (règle 16).
6. **Niveau d'un nœud capturé : réduit d'un cran** (décision du 2026-10-30). La perte se voit (la
   zone se contracte, pilier 1) et le défenseur a une raison de défendre un niveau 3 (pilier 4),
   tandis que l'attaquant ne reçoit pas tout le capital de 32 d'énergie. Variante à jouer en test :
   remise à 1 (puits d'énergie plus fort, boule de neige moindre).
7. **Événements** dans l'ordre des écritures, publiés en un lot : NŒUD_CAPTURÉ (nœud, faction,
   ancien propriétaire, neutre possible) ; PROPRIÉTAIRE_DES_TUILES_CHANGÉ (un par couple ancien /
   nouveau, triés par identifiant d'ancien propriétaire croissant puis de nouveau propriétaire croissant, NEUTRE comptant avant toute faction) ; COULEUR_DES_TUILES_CHANGÉE (émis par 15) ; en cas d'élimination,
   UNITÉ_DÉTRUITE (identifiants croissants), puis FACTION_ÉLIMINÉE, puis PARTIE_TERMINÉE si c'était
   la dernière faction adverse.
8. **Aucun effet immédiat sur l'énergie.** Le nœud rapporte à partir du début du prochain tour de
   son propriétaire (`design/gdd/energie.md`, règle 3).
9. **« Nœuds tenus » est dérivé.** `nœuds_tenus(f)` est une fonction calculée de la tranche, sans
   valeur stockée : elle ne peut pas dériver (le score la lit, `tours-conditions-victoire.md`).
10. **Capture de l'IA annoncée.** Une capture de l'IA est une intention (cible : le nœud),
    exécutée au tour suivant (format et annulation à 9 et 1). L'unité doit encore se trouver sur le
    nœud, et le nœud encore appartenir à autrui, à l'exécution ; sinon l'intention est annulée.

**MONTER_NŒUD**

11. **Paramètre et validation.** Paramètre : l'identifiant du nœud. Ordre : PARTIE_TERMINÉE,
    PAS_VOTRE_TOUR, NŒUD_INCONNU*, NŒUD_NON_POSSÉDÉ*, NŒUD_ACQUIS_CE_TOUR* (`depuis_tour` ≥ tour
    courant), NIVEAU_MAX* (niveau 3), DÉJÀ_MONTÉ* (`monté_au_tour` = tour courant),
    ÉNERGIE_INSUFFISANTE (besoin, disponible) **en dernier** (`energie.md`, règle 7). Aucune unité
    n'est requise, et une unité ennemie debout sur le nœud n'empêche pas la montée.
12. **Application.** `dépenser(PRIX_MONTÉE[niveau])` avec `PRIX_MONTÉE` = {1 : 12, 2 : 20}, grille
    possédée par ce système (fichier de données) ; niveau + 1 ; `monté_au_tour` = tour courant ;
    recalcul du territoire ; appel de 15. Événements : ÉNERGIE_CHANGÉE, NŒUD_MONTÉ (nœud, faction,
    niveau ; nouveau, absent de 23), PROPRIÉTAIRE_DES_TUILES_CHANGÉ, COULEUR_DES_TUILES_CHANGÉE. Le
    revenu change au début du tour suivant.

**Territoire**

13. **Définition.** `territoire(f)` est l'ensemble des tuiles dont le propriétaire est f. Le calcul
    est un **recalcul complet** après toute écriture de nœud (au plus 256 tuiles × 10 nœuds). Les
    différences avec l'ancien tableau donnent les événements.
    - `R(niveau)` = `RAYON_NIVEAU` = {1 : 1, 2 : 2, 3 : 3} (fichier de données). Une tuile est à
      portée d'un nœud si `max(|dx|, |dy|) ≤ R(niveau)`, sans tenir compte du terrain ni du
      chemin : le territoire traverse l'eau et les montagnes.
    - Seuls les nœuds possédés projettent un territoire.
    - **La tuile d'un nœud** prend le propriétaire du nœud ; un nœud neutre reste gris, même dans la
      portée d'un autre nœud.
    - **Autre tuile** : parmi les nœuds à portée, ceux de plus petite distance ; si son propriétaire
      actuel est l'un d'eux, elle le garde ; sinon elle va au propriétaire du nœud d'identifiant le
      plus bas. Aucun nœud à portée : la tuile est neutre, sauf survie par une ruine (règle 15).
    - Le résultat ne dépend que de l'état : il est rejouable.
14. **Eau et montagne.** Elles sont possédées comme toute tuile : cela garde le territoire entre 0 et
    144 (score) et évite des trous dans une zone. Le rendu sur l'eau revient à 15.
15. **Interface des ruines et de la recoloration.** 13 appelle `recolorer_zone(faction, tuiles)` :
    seules les tuiles neutres et non-nœud sont écrites, avec l'`ancrage` RUINE ; une tuile ennemie
    n'est jamais prise. L'appel rend les tuiles réellement changées. Une tuile d'ancrage RUINE
    survit à la perte des nœuds de sa faction ; elle ne change que si un nœud d'une **autre**
    faction la couvre (l'ancrage repasse à NŒUD), ou si sa faction est éliminée (elle devient neutre).
    Elle compte dans le territoire. 15 ne fait que lire le propriétaire.
16. **Élimination et dernier nœud.** Si CAPTURER prend le dernier nœud d'une faction, l'ordre est :
    propriétaire changé, territoire recalculé, événements de la règle 7, destruction des unités de
    la faction (identifiants croissants), FACTION_ÉLIMINÉE, puis PARTIE_TERMINÉE si c'était la
    dernière adverse, le tout dans la même commande (`tours-conditions-victoire.md`, règles 10 et 11).
    La faction qui capture n'est jamais éliminée par cette commande. Le HUD affiche une **alerte de
    dernier nœud** à la faction qui n'en tient plus qu'un **ou dont l'unique nœud est visé par une capture
    annoncée** (pilier 4) : un rush précoce sur un nœud de départ est ainsi annoncé comme tout autre.
17. **Invariants** (pour la validation de l'état) : identifiants uniques ; au plus 10 nœuds ; niveau
    de 1 à 3 ; nœuds en plaine ; la tuile d'un nœud a le propriétaire du nœud ; un recalcul d'un état
    valide ne change rien (point fixe).

### Taille du territoire (contrôle sur 12 × 12)

*Coordonnées illustratives (aucun fichier de carte n'existe encore) : carte symétrique par rotation
de 180°, départs à 8 ou 9, nœuds à 4 ou plus.* Un carré de rayon R couvre (2R + 1)² tuiles avant
découpage par les bords.

| R | Non découpé | Découpé en (2, 2) | Découpé en (6, 2) |
|---|---|---|---|
| 1 | 9 | 9 | 9 |
| 2 | 25 | 25 | 25 |
| 3 | 49 | 36 | 42 |
| 4 | 81 | 49 | 63 |

Un joueur de trois nœuds en (2, 2), (6, 2), (2, 6), union calculée à la main :

| Rayons (niveau 1 / 2 / 3) | 3 nœuds au niveau 1 | 3 nœuds au niveau 2 | 3 nœuds au niveau 3 |
|---|---|---|---|
| **1 / 2 / 3** (retenu) | 27 (19 %) | 65 (45 %) | 84 (58 %) |
| 2 / 3 / 4 (écarté) | 65 (45 %) | 84 (58 %) | environ 110 (76 %) |

Avec 2 / 3 / 4, deux joueurs à trois nœuds de niveau 2 totaliseraient 168 tuiles, plus que les 144 :
le gris qui doit se recolorer (pilier 1) disparaît et le terme de territoire du score sature. Avec
1 / 2 / 3, deux départs à 8 ou 9 tuiles laissent une bande neutre au centre jusqu'aux nœuds disputés.

### States and Transitions

| De | Vers | Déclencheur | Conditions et effets |
|---|---|---|---|
| (mise en place) | NEUTRE (niveau 1) | Mise en place | Nœud hors départ ; gris |
| (mise en place) | POSSÉDÉ (f, 1) | Mise en place | Nœud de départ |
| NEUTRE | POSSÉDÉ (f, 1) | CAPTURER | `depuis_tour` = tour courant |
| POSSÉDÉ (f, n) | POSSÉDÉ (f, n + 1) | MONTER_NŒUD | n < 3 ; `depuis_tour` < tour ; énergie |
| POSSÉDÉ (f, n) | POSSÉDÉ (g, max(1, n − 1)) | CAPTURER par g ≠ f | Dernier nœud de f : élimination, même commande |
| POSSÉDÉ | NEUTRE | Aucune transition | Un nœud ne redevient jamais neutre |

### Interactions with Other Systems

| # | Système | Ce qui circule | Propriétaire de l'interface |
|---|---|---|---|
| 1 | État | Tranche et deux champs proposés ; compteur dérivé ; invariants de la règle 17 | 1 pour la forme, 11 pour les écritures |
| 2 | Carte | Emplacements en plaine ; distance de Chebyshev ; espacement d'au moins 4 | 2 |
| 3 | Tours | Élimination (règle 16) ; fournit N, ΣL et le territoire au score | 3 |
| 5 | Brouillard | Lit les nœuds ; le propriétaire d'un nœud hors de vue est le dernier vu | 5 |
| 6 | Unités | « a agi », type capable ; le bonus de soin lit le propriétaire de la tuile du nœud | 6 |
| 9 | IA | Intention de capture (cible : le nœud), exécution au tour suivant | 9 |
| 10 | Énergie | `dépenser(MONTÉE_NŒUD)` ; lit propriétaire et niveau pour le revenu | 10 pour l'écriture, 11 pour les prix |
| 13 | Ruines | `recolorer_zone` ; ne prend jamais une tuile ennemie | 11 |
| 15 | Recoloration | Lit le propriétaire ; appelée après chaque écriture | 15 pour la couleur, 11 pour la donnée |
| 17 | HUD | Niveau visible sur la carte ; bouton Capturer ; alerte de dernier nœud ; puce « Nœud perdu » | 17 |
| 21 | Génération | Respecte `MAX_NODES`, la plaine et l'espacement | 21 |
| 23 | Commandes | MONTER_NŒUD, six codes et l'événement NŒUD_MONTÉ à ajouter ; lot d'événements maximal (B_max) | 23 |

## Formulas

*Proposées par systems-designer ; les quatre valeurs du tableau de taille de territoire ont été
recalculées et sont justes. Les valeurs marquées [PROP] sont des valeurs de départ.*

### 1. Portée

The portée formula is defined as:

`en_portée(n, t) = max(|dx|, |dy|) <= RAYON_NIVEAU[niveau(n)]` avec `dx = x_t − x_n`, `dy = y_t − y_n`

**Variables:**

| Variable | Type | Range | Source | Description |
|---|---|---|---|---|
| dx, dy | int | −11..11 (carte 12×12) | calculated | Écarts de coordonnées entre la tuile t et le nœud n |
| niveau(n) | int | 1..3 | calculated (tranche) | Niveau du nœud |
| RAYON_NIVEAU | table d'entiers | {1 : 1, 2 : 2, 3 : 3} | data file | Rayon par niveau [PROP] |
| en_portée | bool | vrai / faux | calculated | La tuile est dans le carré du nœud |

**Output Range:** booléen ; le terrain et le chemin sont ignorés (règle 13) ; seuls les nœuds possédés sont testés.
**Example:** nœud de niveau 2 en (5, 5), tuile (7, 4) : dx = 2, dy = −1, max = 2 ≤ 2 → vrai ; tuile (8, 5) : max = 3 > 2 → faux.

### 2. Propriétaire d'une tuile

The tile owner formula is defined as:

`prop(t) = prop(n_t)` si t est la tuile du nœud n_t ; sinon `S` = nœuds possédés en portée de t à distance
minimale d_min ; `prop(t) = ancien(t)` si `ancien(t)` ∈ propriétaires(S), sinon `propriétaire(min_id(S))` ; si S est vide,
`prop(t) = NEUTRE` (sauf ruine, règle 15)

**Variables:**

| Variable | Type | Range | Source | Description |
|---|---|---|---|---|
| d(n, t) | int | 0..11 | calculated | Distance de Chebyshev (`carte-tuiles-terrain.md`, formule 1) |
| d_min | int | 0..3 | calculated | Plus petite distance parmi les nœuds en portée |
| S | ensemble de nœuds | 0..10 | calculated | Nœuds possédés en portée à distance d_min |
| ancien(t) | faction ou NEUTRE | — | calculated (état) | Propriétaire avant le recalcul |
| id | int | 1.. | calculated (état) | Identifiant de nœud, jamais réutilisé |

**Output Range:** une faction ou NEUTRE, toujours définie ; le résultat ne dépend que de l'état.
**Example (tuiles disputées):** A (faction 1, id 2) en (2, 5) et B (faction 2, id 5) en (6, 5), niveau 2 chacun (R = 2), à distance 4. La colonne
x = 4 est à 2 des deux nœuds : (4, 3) à (4, 7), soit 5 tuiles. 20 tuiles sont exclusives à A et 20 à B ; l'union couvre 25 + 25 − 5 = 45.
Les 5 tuiles étaient neutres : égalité, pas d'ancien propriétaire, identifiant le plus bas → faction 1, soit 25 pour A et 20 pour B. Si B avait déjà les 5
tuiles, il les garde (égalité, l'ancien propriétaire est dans S) : A reste à 20. Si une faction 3 qui a perdu son nœud les détenait, elle n'est pas dans S : elles vont à l'identifiant 2, donc à la faction 1.
**Point fixe:** après un passage, l'ancien propriétaire de chaque tuile est un propriétaire de S (ou S est vide) : un second passage ne change rien.

### 3. Niveau après capture et prix de montée

The captured level formula is defined as:

`niveau' = max(1, niveau − 1)` ; `coût = PRIX_MONTÉE[niveau]` si `niveau < NIVEAU_MAX`, sinon refus NIVEAU_MAX

**Variables:**

| Variable | Type | Range | Source | Description |
|---|---|---|---|---|
| niveau | int | 1..3 | calculated (état) | Niveau avant l'opération |
| NIVEAU_MAX | int | 3 | data file | Niveau maximal [PROP] |
| PRIX_MONTÉE | table d'entiers | {1 : 12, 2 : 20} | data file | Coût du passage n → n + 1 [PROP] |
| niveau' | int | 1..2 | calculated | Niveau du nœud capturé |

**Output Range:** niveau' ∈ {1, 2} ; un nœud neutre (niveau 1) reste à 1 ; aucun prix n'existe pour le niveau 3.
**Example:** 1 → 1, 2 → 1, 3 → 2. Monter de 1 à 3 coûte 12 + 20 = 32 d'énergie. Gain de revenu : +1 (3 → 4) pour 12, soit 12 tours de retour ; +1 (4 → 5) pour 20, soit 20 tours : la montée s'achète pour le **territoire et le score** plus que pour l'énergie (voir Open Questions).

### 4. Nœuds tenus et somme des niveaux

The held-nodes formula is defined as:

`nœuds_tenus(f) = |{n : propriétaire(n) = f}|` ; `ΣL(f) = Σ niveau(n)` pour ces n

**Variables:**

| Variable | Type | Range | Source | Description |
|---|---|---|---|---|
| propriétaire(n), niveau(n) | faction, int | — ; 1..3 | calculated (état) | Champs de la tranche |
| N = nœuds_tenus | int | 0..10 | calculated | Jamais stocké |
| ΣL | int | N..3N | calculated | Jamais stocké |

**Output Range:** 0 ≤ N ≤ 10 ; ΣL = 0 si N = 0, sinon N ≤ ΣL ≤ 3N.
**Example:** niveaux 2, 1, 1 → N = 3, ΣL = 4 ; le score (`tours-conditions-victoire.md`) en fait w_n·3 + w_l·4 ; parcours par identifiant croissant.

### 5. Taille du territoire d'un nœud isolé

The territory size formula is defined as:

`tuiles = (min(x+R, W−1) − max(x−R, 0) + 1) × (min(y+R, H−1) − max(y−R, 0) + 1)`

**Variables:**

| Variable | Type | Range | Source | Description |
|---|---|---|---|---|
| x, y | int | 0..W−1, 0..H−1 | data file (carte) | Position du nœud |
| R | int | 1..3 | data file | `RAYON_NIVEAU[niveau]` |
| W, H | int | 12, 12 (MVP) | data file (carte) | Dimensions de la carte |
| tuiles | int | (R+1)²..(2R+1)² | calculated | Carré découpé aux bords, avant chevauchement |

**Output Range:** minimum (R+1)² dans un coin (16 pour R = 3) ; maximum (2R+1)² : 9, 25 ou 49.
**Example:** R = 3 en (2, 2) : 6 × 6 = 36 ; en (6, 2) : 7 × 6 = 42. R = 4 (écarté) en (2, 2) : 49 ; en (6, 2) : 63.

### 6. Lot maximal d'événements (B_max)

The batch size formula is defined as:

`B_max = 1 + P + C + U + 2` avec `P ≤ 3` au MVP ; tuiles changées ≤ `(2 × RAYON_NIVEAU[3] + 1)² = 49`

**Variables:**

| Variable | Type | Range | Source | Description |
|---|---|---|---|---|
| 1 | constante | 1 | constant | NŒUD_CAPTURÉ |
| P | int | 0..3 | calculated | PROPRIÉTAIRE_DES_TUILES_CHANGÉ : un par couple (ancien, nouveau) distinct |
| C | int | 1 | calculated | COULEUR_DES_TUILES_CHANGÉE (liste de tuiles) |
| U | int | 0..60 | calculated | UNITÉ_DÉTRUITE, seulement en cas d'élimination |
| 2 | constante | 2 | constant | FACTION_ÉLIMINÉE et PARTIE_TERMINÉE |
| EVENT_QUEUE_MAX | int | 256 | data file (23) | File d'événements |

**Output Range:** pire cas à deux factions : couples (perdant → capturant, perdant → neutre, neutre → capturant), donc B_max = 7 + U. Exigence : 2 × B_max ≤ 256, soit U ≤ 121, sûr tant que le plafond d'unités (60) tient. Par tuile, le lot vaudrait 101 + U (U ≤ 27) : il faudrait alors monter la file vers 512.
**Example:** capture d'un niveau 3 en (6, 6), la faction perdante ayant 8 unités et son dernier nœud : B = 7 + 8 = 15 événements pour 49 tuiles au plus.

### 7. Variation de revenu d'une capture

The income swing formula is defined as:

`Δ_perdant = −REVENU_NIVEAU[n]` ; `Δ_capturant = +REVENU_NIVEAU[max(1, n − 1)]`

**Variables:**

| Variable | Type | Range | Source | Description |
|---|---|---|---|---|
| n | int | 1..3 | calculated (état) | Niveau avant la capture |
| REVENU_NIVEAU | table d'entiers | {1 : 3, 2 : 4, 3 : 5} | data file (`energie.md`) | Revenu par tour |
| Δ | int | −5..+4 | calculated | Effet au début du prochain tour du propriétaire |

**Output Range et Example:**

| n | Perdant | Capturant | Écart |
|---|---|---|---|
| 1 | −3 | +3 | 6 |
| 2 | −4 | +3 | 7 |
| 3 | −5 | +4 | 9 |

Le revenu total de la carte baisse de 1 pour n = 2 ou 3 ; un nœud neutre ne rapporte que +3 au capturant ; aucune énergie n'est versée à la capture (règle 8).

| Réglage | Défaut | Plage sûre |
|---|---|---|
| `RAYON_NIVEAU` | 1 / 2 / 3 | croissant, 1..3 (2 / 3 / 4 écarté : saturation du score) |
| `PRIX_MONTÉE` | 12 / 20 | 8..16 et 14..28 |
| `NIVEAU_MAX` | 3 | 3 |
| Perte de niveau à la capture | −1 | 0..−2, ou remise à 1 (variante de test) |

## Edge Cases

*Proposés par systems-designer ; les résolutions du 2026-10-30 sont intégrées.*

- **Si une unité tente CAPTURER pendant que le défenseur est encore sur la tuile du nœud**: impossible, une tuile ne porte qu'une unité : l'attaquante n'est pas sur le nœud (PAS_SUR_UN_NŒUD).
- **Si l'unité arrive sur le nœud après la mort du défenseur**: CAPTURER est valide si elle n'a pas déjà agi ; sinon DÉJÀ_AGI, sans effet (la règle de 6 décide).
- **Si deux factions capturent le même nœud au cours d'un même tour de jeu**: les tours sont séquentiels ; la seconde capture, dans son propre tour, est valide et baisse encore le niveau (un niveau 3 repris deux fois passe de 3 à 2 puis à 1) ; `depuis_tour` est remis à jour à chaque fois.
- **Si le nœud appartient déjà à la faction de l'unité**: NŒUD_DÉJÀ_POSSÉDÉ ; l'unité n'est pas marquée « a agi ».
- **Si l'unité n'est ni un Ouvrier ni un Bastion, hors d'un nœud**: TYPE_NON_CAPABLE, avant PAS_SUR_UN_NŒUD : le code dit la vraie raison.
- **Si MONTER_NŒUD vise un nœud capturé ce tour**: NŒUD_ACQUIS_CE_TOUR (`depuis_tour` ≥ tour courant). Les nœuds de départ (`depuis_tour` = 0) sont montables dès le tour 1.
- **Si le nœud est déjà au niveau 3 et a été monté ce tour**: NIVEAU_MAX, avant DÉJÀ_MONTÉ : le joueur reçoit le code le plus stable.
- **Si deux MONTER_NŒUD visent le même nœud dans un tour**: la seconde est refusée par DÉJÀ_MONTÉ (ou NIVEAU_MAX si le niveau 3 est atteint) ; aucune énergie n'est dépensée.
- **Si une unité ennemie se tient sur le nœud lors de MONTER_NŒUD**: la montée est valide (règle 11), sans effet sur la tuile.
- **Si un nœud monté ce tour est capturé dans la phase ennemie suivante**: son niveau baisse d'un cran pour le capturant ; l'énergie dépensée n'est pas remboursée — monter un nœud menacé est un risque assumé (pilier 4).
- **Si CAPTURER prend le dernier nœud de l'adversaire**: ordre de la règle 16 ; propriétaire, territoire, événements, destruction des unités (identifiants croissants), FACTION_ÉLIMINÉE, puis PARTIE_TERMINÉE si c'était la dernière adverse, dans la même commande.
- **Si une capture laisse une faction avec un seul nœud**: le HUD affiche l'alerte de dernier nœud lors du passage de N ≥ 2 à N = 1, jamais à la mise en place (un nœud de départ par camp). **Si une capture annoncée vise l'unique nœud d'une faction** (y compris son nœud de départ, N = 1 dès le début): l'alerte s'affiche aussi, dès l'annonce.
- **Si une capture fait changer des tuiles entre deux factions de façon alternée**: le recalcul lit l'ancien tableau et reste un point fixe (formule 2) ; un second recalcul ne change rien, donc l'état est déterministe.
- **Si une faction perd tous ses nœuds mais détient des tuiles de ruine**: elle est éliminée dans la même commande (règle 16) et ses tuiles de ruine deviennent neutres ; l'ancrage RUINE n'a de sens que tant que la faction tient au moins un nœud.
- **Si `recolorer_zone` reçoit des tuiles ennemies**: elles sont ignorées, sans erreur ; l'appel rend les tuiles réellement changées, et si la liste est vide aucun événement n'est émis.
- **Si une capture annoncée par l'IA devient impossible** (l'unité n'est plus sur le nœud, a été détruite, ou le nœud appartient maintenant à la faction de l'IA): l'intention est annulée. Raisons proposées à 9 : UNITÉ_ABSENTE, UNITÉ_DÉTRUITE, NŒUD_DÉJÀ_À_L'IA. Si le nœud est passé à une troisième faction, la capture reste valide (« appartient à autrui »).
- **Si un nœud hors de vue change de mains**: l'état stocke le vrai propriétaire ; le joueur voit le dernier propriétaire vu (système 5) ; CAPTURER est validé sur l'état réel, et l'unité posée sur le nœud le voit forcément.
- **Si un fichier de carte dépasse `MAX_NODES`, ou place un nœud hors d'une tuile de plaine**: la carte est refusée à la mise en place, sans création partielle.
- **Si la partie est sauvegardée puis chargée**: l'état stocke la tranche des nœuds (dont `depuis_tour` et `monté_au_tour`), le propriétaire par tuile (déjà dans `modele-etat-partie.md`) et la couche d'ancrage (nouvelle) ; sont recalculés `nœuds_tenus`, ΣL, le revenu et les tailles de territoire ; un recalcul qui ne serait pas un point fixe fait refuser la sauvegarde (règle 17) ; l'ancrage RUINE doit être stocké, les nœuds ne permettant pas de le retrouver.
- **Si un nœud neutre est dans la portée d'un nœud possédé**: sa tuile reste grise ; les tuiles autour suivent la règle normale.
- **Si une faction est éliminée**: toutes ses tuiles deviennent neutres dans la même commande, avec un événement PROPRIÉTAIRE_DES_TUILES_CHANGÉ (ancien, NEUTRE) dans le lot.

### Cas à traiter dans d'autres GDD

- **23 Commandes**: ajouter MONTER_NŒUD, les six codes (TYPE_NON_CAPABLE, NŒUD_INCONNU, NŒUD_NON_POSSÉDÉ, NŒUD_ACQUIS_CE_TOUR, NIVEAU_MAX, DÉJÀ_MONTÉ), l'événement NŒUD_MONTÉ et la valeur B_max (7 + U).
- **1 État**: champs `depuis_tour` et `monté_au_tour`, couche d'ancrage, `nœuds_tenus` dérivé.
- **3 Tours**: élimination, N, ΣL, territoire ; numérotation des tours (début à 1).
- **5 Brouillard**: dernier propriétaire vu d'un nœud hors de vue.
- **9 IA**: format de l'intention de capture et raisons d'annulation (UNITÉ_ABSENTE, UNITÉ_DÉTRUITE, NŒUD_DÉJÀ_À_L'IA).
- **13 Ruines et 15 Recoloration**: `recolorer_zone` ignore les tuiles ennemies ; ruines neutralisées à l'élimination.
- **17 HUD**: alerte de dernier nœud au passage N ≥ 2 → 1 ; niveau visible sur la carte.
- **`hud.md`**: le bouton « Capturer » est actif au moment de l'action, non au début du tour.
- **`unites-drones.md`**: le bonus de soin lit le propriétaire de la tuile du nœud ; plafond d'unités pour B_max.
- **`energie.md`**: retour sur investissement de la montée (12 et 20 tours) à valider.

## Dependencies

### En amont (ce système dépend de)

| Système | Nature | Dure ou souple |
|---|---|---|
| 2 Carte en tuiles et terrain | Emplacements de nœuds en plaine, distance de Chebyshev, taille de la carte (`design/gdd/carte-tuiles-terrain.md`) | Dure |
| 10 Énergie | `dépenser` pour la montée ; la valeur du revenu par niveau (`design/gdd/energie.md`) | Dure |

Dépendances de contrat : 1 (tranche Nœuds, propriétaire des tuiles), 3 (élimination), 6 (types capables : `design/gdd/unites-drones.md`), 23 (commandes).

### En aval (systèmes qui dépendent de lui)

| Système | Ce qu'il utilise | Dure ou souple |
|---|---|---|
| 3 Tours | Nœuds tenus, niveaux, territoire pour le score et l'élimination | Dure |
| 5 Brouillard | Positions et propriétaire des nœuds | Dure |
| 9 IA | Intention de capture ; montée de nœud | Dure |
| 13 Ruines | `recolorer_zone` | Dure |
| 15 Recoloration | Propriétaire de chaque tuile | Dure |
| 17 HUD | Niveau visible, bouton Capturer, alerte de dernier nœud, puce « Nœud perdu » | Dure |
| 21 Génération | Contraintes de placement | Dure |
| 23 Commandes | Validation et écriture de CAPTURER et de MONTER_NŒUD | Dure |

### Bidirectionnalité

- `design/gdd/modele-etat-partie.md`, `design/gdd/carte-tuiles-terrain.md`, `design/gdd/commandes-evenements.md`, `design/gdd/tours-conditions-victoire.md`, `design/gdd/unites-drones.md` et `design/gdd/energie.md` citent déjà ce système.
- `design/ux/hud.md` doit le citer (niveau visible, bouton Capturer à l'action, alerte de dernier nœud).
- Les GDD 5, 9, 13, 15, 17 et 21 doivent le citer à leur création.

### Décisions techniques renvoyées à un ADR

- Représentation du propriétaire par tuile et de la couche d'ancrage dans l'état.
- Calcul incrémental ou complet du territoire (le recalcul complet suffit au MVP).

## Tuning Knobs

*Dans un fichier de données (`assets/data/noeuds.*`). Valeurs de départ [PROP], à jouer en test.*

| Paramètre | Valeur | Plage sûre | Trop haut | Trop bas | Interagit avec |
|---|---|---|---|---|---|
| `RAYON_NIVEAU` | 1 / 2 / 3 | croissant, 1..3 | Plus de gris à recolorer ; territoire du score sature | Les nœuds ne marquent pas la carte | Score (3), recoloration (15) |
| `PRIX_MONTÉE` | 12 / 20 | 8..16 ; 14..28 | La montée n'est jamais achetée | La montée est un réflexe, le goulot disparaît | Énergie (10), `REVENU_NIVEAU` |
| `NIVEAU_MAX` | 3 | 3 | — | — | Tableau des rayons, revenu |
| Perte de niveau à la capture | −1 | 0 à −2, ou remise à 1 | Boule de neige (0) | Capture sans enjeu (remise à 1) | Prix de montée, score |
| `MAX_NODES` | 10 | 4..16 (GDD 1) | IA plus lente | Pas assez de nœuds sur une grande carte | Carte (2) |
| Espacement minimal des nœuds | 4 | 3..5 (GDD 2) | Peu de nœuds disputés | Territoires qui se touchent trop tôt | Carte (2) |

## Visual/Audio Requirements

*Système `Economy` : section facultative. Le rendu des nœuds appartient à l'art bible (sections 3, 6
et 7) et à la recoloration (15). `art-director` n'est pas reconsulté ici : les formes viennent d'une
bible déjà approuvée (REVISED 2026-10-30) ; la lecture du niveau est une proposition à valider.*

- **Forme.** Un nœud est une plateforme hexagonale basse à anneaux concentriques, bâtie par les drones :
  droite, froide, modulaire, alignée sur la grille, jamais ocre. Sans propriétaire, elle est grise.
- **Niveau lisible sur la carte** (pilier 1, exigence posée par `energie.md`). Proposition : la plateforme
  porte **trois anneaux hexagonaux concentriques**, dont autant sont allumés à la teinte de la faction
  que le niveau (un, deux ou trois). La forme du nœud ne change pas, seul le nombre d'anneaux allumés :
  la lecture tient en niveaux de gris. À valider avec le test de silhouette de l'art bible.
- **Territoire.** La lisière du territoire se lit par la saturation de la faction (art bible, section 2) ;
  la tuile du nœud porte la teinte pleine. La limite entre deux territoires reste lisible en niveaux
  de gris (le palier de valeur, non la teinte).
- **Capture.** L'onde de recoloration part du nœud et gagne tuile après tuile jusqu'au bout du rayon
  (par 15) ; la perte se lit par le retour au gris, jamais par une couleur d'alerte.
- **Annonce d'une capture ennemie.** Hachure orange-rouge à 135° et « ! » sur le nœud visé, comme
  toute menace annoncée.
- **Audio.** Aucune information de jeu ne passe par un son. Sons possibles, facultatifs : capture,
  montée de niveau, perte ; spécifiés avec le système 20.

> 📌 **Asset Spec** — Visual/Audio requirements are defined. After the art bible is approved,
> run `/asset-spec system:noeuds` to produce per-asset visual descriptions, dimensions, and
> generation prompts from this section.

## Game Feel

- **La carte change avant le chiffre.** À la capture, la couleur se répand aussitôt (de 400 ms à
  1 s, à régler) ; le revenu ne monte qu'au tour suivant.
- **Monter un nœud élargit visiblement la lisière** : l'anneau supplémentaire s'allume puis la zone
  gagne ses nouvelles tuiles, sans bloquer les commandes au-delà de l'animation.
- **Une perte se lit sans bruit** : le territoire se décolore vers le gris, comme l'inverse de la
  recoloration, sans secousse ni particules (pilier 4 : la perte était annoncée).
- **Animations réduites** : la recoloration, la montée et la perte s'affichent directement dans leur
  état final.

## UI Requirements

- **Niveau d'un nœud** : visible sur la carte (anneaux allumés) et dans une fiche brève à l'appui :
  propriétaire, niveau, revenu, prix de la montée.
- **Bouton « Monter »** : une action sur le nœud, grisée avec sa raison (`NIVEAU_MAX`, `DÉJÀ_MONTÉ`,
  `NŒUD_ACQUIS_CE_TOUR`, « manque n » pour l'énergie) ; le coût est affiché sur le bouton.
- **Bouton « Capturer »** : actif au moment de l'action quand l'unité capable est sur un nœud d'autrui
  (et non « au début du tour », `design/ux/hud.md`).
- **Alerte de dernier nœud** : puce persistante quand la faction du joueur passe de deux nœuds à un.
- **Puce « Nœud perdu »** et centrage de la carte sur le nœud (`hud.md`, aides à la navigation).
- **Lecteur d'écran** : propriétaire, niveau et revenu d'un nœud sont annoncés comme du texte.

> 📌 **UX Flag — Nœuds** : ce système a des exigences d'interface (niveau sur la carte, fiche de nœud,
> bouton « Monter », alerte de dernier nœud). En phase 4 (pré-production), lancer `/ux-design` pour la
> fiche de nœud **avant** d'écrire les épopées.

## Cross-References

| Ce document cite | Document | Élément précis | Nature |
|---|---|---|---|
| Tranche « Nœuds », propriétaire des tuiles, `MAX_NODES`, entiers, itération par identifiant | `design/gdd/modele-etat-partie.md` | Règles 2, 3, 8, 14 ; tranche Nœuds | Règle, valeur |
| Placement des nœuds en plaine, espacement, distance de Chebyshev | `design/gdd/carte-tuiles-terrain.md` | Règles 10, 11, 15 ; formule 1 | Règle |
| CAPTURER, codes de refus, lot d'événements, `EVENT_QUEUE_MAX` | `design/gdd/commandes-evenements.md` | Table des commandes ; règle 8 | Règle, valeur |
| Élimination par perte du dernier nœud, N, ΣL, territoire | `design/gdd/tours-conditions-victoire.md` | Règles 10 à 12 ; score | Règle |
| Ouvrier et Bastion capturent ; soin au repos sur un nœud | `design/gdd/unites-drones.md` | Règles 6 et 7 | Règle |
| Revenu par niveau, prix de montée, niveau visible sur la carte | `design/gdd/energie.md` | Règle 2 ; courbe de départ | Valeur, exigence |
| Nœud : plateforme hexagonale, anneaux, saturation | `design/art/art-bible.md` | Sections 2, 3 et 6 | Style |
| Pilier 1, pilier 3, pilier 4 | `design/gdd/game-concept.md` | Game Pillars | Intention |

## Acceptance Criteria

*Étiquettes : **Logic** = test unitaire dans `tests/unit/noeuds/`, sur un état construit par fabrique,
jamais par fichier de carte ; **Intégration** = `tests/integration/noeuds/` ; **UI** et **Visuel** =
capture conservée dans `production/qa/evidence/`, validée par l'art-director ; **Appareil** = sur
l'appareil cible. [BLOQUÉ n] = attend le GDD du système n.*

### Règles

- **AC-ND1** (Logic, règle 1) **GIVEN** une fabrique à 6 nœuds, **WHEN** on lit la tranche, **THEN** chaque nœud a identifiant, tuile, propriétaire, niveau de 1 à 3, `depuis_tour` et `monté_au_tour` entiers, et chaque tuile un `ancrage` ∈ {NŒUD, RUINE}. (Champs proposés, absents de `modele-etat-partie.md`.)
- **AC-ND2** (Logic, règle 2) **GIVEN** une fabrique à 2 départs et 4 nœuds neutres, **WHEN** mise en place, **THEN** identifiants croissants dans l'ordre de la liste, chaque départ à sa faction, les autres neutres, tous de niveau 1, `depuis_tour` = 0, `monté_au_tour` = −1, territoire calculé une fois.
- **AC-ND3** (Logic, règle 3) Recherche statique : aucune écriture de `propriétaire` ou d'`ancrage` hors du module Nœuds ; **GIVEN** deux nœuds touchés par une commande, **THEN** traitement par identifiant croissant.
- **AC-ND4** (Logic, règle 4) voir AC-ND18.
- **AC-ND5** (Logic, règle 5) **GIVEN** un Ouvrier valide sur un nœud ennemi de niveau 2, **WHEN** CAPTURER, **THEN** l'unité a agi, propriétaire = faction, `depuis_tour` = tour courant, `monté_au_tour` = −1, niveau 1, territoire recalculé avant l'appel de 15, puis de l'élimination.
- **AC-ND6** (Logic, règle 6) voir AC-F3 (1 → 1, 2 → 1, 3 → 2). La variante « remise à 1 » est un réglage, non un critère.
- **AC-ND7** (Logic, règle 7) **GIVEN** une capture sans élimination, **THEN** le lot est publié d'un bloc : NŒUD_CAPTURÉ (nœud, faction, ancien propriétaire), PROPRIÉTAIRE_DES_TUILES_CHANGÉ (couples triés par ancien puis nouveau, NEUTRE avant toute faction), COULEUR_DES_TUILES_CHANGÉE. [BLOQUÉ 15 : doublure de test]
- **AC-ND8** (Logic, règle 8) **GIVEN** un stock de 10, **WHEN** CAPTURER, **THEN** stock 10 ; le revenu du tour suivant du capturant inclut le nœud.
- **AC-ND9** (Logic, règle 9) Recherche statique : aucun champ `nœuds_tenus` stocké ; deux appels sans écriture donnent le même résultat, état identique à l'octet.
- **AC-ND10** (Intégration, règle 10) **GIVEN** une capture de l'IA annoncée au tour T, **WHEN** T + 1 avec l'unité sur le nœud et le nœud à autrui, **THEN** elle s'exécute ; elle est annulée si UNITÉ_ABSENTE, UNITÉ_DÉTRUITE ou NŒUD_DÉJÀ_À_L'IA ; un nœud passé à une troisième faction reste capturable. [BLOQUÉ 9 : format et codes proposés]
- **AC-ND11** (Logic, règle 11) voir AC-ND19.
- **AC-ND12** (Logic, règle 12) **GIVEN** un nœud de niveau 1 à la faction, tour 1, stock 12, **WHEN** MONTER_NŒUD, **THEN** stock 0, niveau 2, `monté_au_tour` = 1, territoire recalculé, événements ÉNERGIE_CHANGÉE (12, 0), NŒUD_MONTÉ, PROPRIÉTAIRE_DES_TUILES_CHANGÉ, COULEUR_DES_TUILES_CHANGÉE ; revenu inchangé jusqu'au tour suivant. [BLOQUÉ 23 : MONTER_NŒUD et NŒUD_MONTÉ absents de 23 ; 15]
- **AC-ND13** (Logic, règle 13) voir AC-F1 et AC-F2 ; **GIVEN** un nœud neutre dans la portée d'un nœud possédé, **THEN** sa tuile reste neutre.
- **AC-ND14** (Logic, règle 14) **GIVEN** une tuile d'eau et une de montagne à portée, **THEN** elles ont le propriétaire de la zone, et le territoire d'un camp reste dans 0..144. [rendu de l'eau : BLOQUÉ 15]
- **AC-ND15** (Logic, règle 15) **GIVEN** `recolorer_zone(f, [tuile neutre, tuile ennemie, tuile de nœud])`, **THEN** seule la neutre est écrite (ancrage RUINE) et l'appel rend cette seule tuile ; liste vide : aucun événement ; perte des nœuds de f : les tuiles RUINE restent à f ; un nœud d'une autre faction qui la couvre : elle change et l'ancrage repasse à NŒUD ; élimination de f : elle devient neutre. [BLOQUÉ 13]
- **AC-ND16** (Intégration, règle 16) voir AC-ND21 et AC-ND22.
- **AC-ND17** (Logic, règle 17) **GIVEN** un état valide, **WHEN** recalcul, **THEN** rien ne change (point fixe) ; sont rejetés : identifiant dupliqué, 11 nœuds, niveau 0 ou 4, nœud sur l'eau, tuile de nœud au mauvais propriétaire.

### Formules (vecteurs déterministes)

- **AC-F1** (Logic, formule 1) Nœud de niveau 2 en (5, 5) : (7, 4) vrai, (8, 5) faux ; niveau 1 en (5, 5) : (6, 6) vrai, (7, 5) faux.
- **AC-F2** (Logic, formule 2) A (faction 1, id 2) en (2, 5), B (faction 2, id 5) en (6, 5), niveau 2 : la colonne x = 4 compte 5 tuiles, de (4, 3) à (4, 7), union 45. Tuiles neutres : A 25, B 20 (égalité, id 2, faction 1). Déjà à B : B les garde, A 20. Détenues par une faction 3 sans nœud : à la faction 1. Un second passage ne change rien.
- **AC-F3** (Logic, formule 3) Niveau 1 → 1, 2 → 1, 3 → 2 ; un neutre de niveau 1 reste à 1 ; prix 1 → 12, 2 → 20, 3 → refus NIVEAU_MAX ; 1 à 3 coûte 32.
- **AC-F4** (Logic, formule 4) Niveaux 2, 1, 1 → N = 3, ΣL = 4 ; aucun nœud → N = 0, ΣL = 0.
- **AC-F5** (Logic, formule 5) R = 3 : (2, 2) → 36, (6, 2) → 42 ; R = 4 : (2, 2) → 49, (6, 2) → 63 ; R = 1 → 9 ; R = 2 → 25 ; coin à R = 3 → 16.
- **AC-F6** (Logic, formule 6) B_max = 7 + U ; U = 8 → 15 ; U = 60 → 134 ≤ 256 ; U = 121 → 256 passe, U = 122 → 258 échoue ; tuiles changées par capture ≤ 49.
- **AC-F7** (Logic, formule 7) n = 1 : −3 / +3 ; n = 2 : −4 / +3 ; n = 3 : −5 / +4 ; revenu total de la carte −1 pour n = 2 et 3, 0 pour n = 1 ; nœud neutre : +3 au capturant. [BLOQUÉ 11 : `REVENU_NIVEAU` vient de `energie.md`]

### Cas limites et transversaux

- **AC-ND18** (Logic, règle 4) Premier code en échec : unité ni Ouvrier ni Bastion hors nœud → TYPE_NON_CAPABLE (avant PAS_SUR_UN_NŒUD) ; Ouvrier ayant agi hors nœud → DÉJÀ_AGI ; Ouvrier sur son propre nœud → NŒUD_DÉJÀ_POSSÉDÉ, non marqué « a agi ».
- **AC-ND19** (Logic, règle 11) Premier code en échec : niveau 3 monté ce tour → NIVEAU_MAX avant DÉJÀ_MONTÉ ; nœud capturé ce tour → NŒUD_ACQUIS_CE_TOUR ; nœud de départ montable au tour 1 ; stock 11 pour 12 → ÉNERGIE_INSUFFISANTE (12, 11) en dernier, sans écriture ; une unité ennemie sur le nœud n'empêche pas la montée.
- **AC-ND20** (Logic, règle 2) Mise en place avec 11 nœuds, ou un nœud hors plaine : refusée sans création partielle (état identique). (On teste la fonction de création ; le format de fichier relève de 21.)
- **AC-ND21** (Intégration, règle 16) Capture du dernier nœud adverse (8 unités) en une commande : NŒUD_CAPTURÉ, PROPRIÉTAIRE_DES_TUILES_CHANGÉ, COULEUR_DES_TUILES_CHANGÉE, 8 × UNITÉ_DÉTRUITE par identifiant croissant, FACTION_ÉLIMINÉE, PARTIE_TERMINÉE si dernière adverse ; le capturant n'est jamais éliminé ; lot de 15.
- **AC-ND22** (Logic, règle 16) L'alerte de dernier nœud se déclenche au passage N ≥ 2 → N = 1 et dès l'annonce d'une capture visant l'unique nœud d'une faction, jamais à la mise en place ni pour 3 → 2. [BLOQUÉ 17]
- **AC-ND28** (Intégration, règles 10 et 16) **GIVEN** une capture annoncée par l'IA contre le dernier nœud du joueur, **WHEN** le joueur joue son tour suivant, **THEN** au moins une réponse permet d'annuler la capture (chasser ou bloquer l'unité, ou occuper la tuile) sans que le joueur ait dû agir avant l'annonce. [BLOQUÉ 9 : format de l'intention]
- **AC-ND23** (Logic) Un nœud monté ce tour puis capturé : niveau −1, aucun remboursement ; un niveau 3 repris deux fois : 2 puis 1.
- **AC-ND24** (Logic, transversal) Mêmes états et mêmes commandes, mêmes tuiles de territoire sur deux exécutions, comparaison d'octets ; recherche statique : aucun flottant ni division non entière dans le module.
- **AC-ND25** (Logic, sauvegarde) Sauvegarde puis chargement d'un état avec ruines : tranche, propriétaires et ancrage RUINE identiques ; `nœuds_tenus`, ΣL, revenu recalculés ; un recalcul qui n'est pas un point fixe fait refuser la sauvegarde.

### Visuel

- **AC-ND26** (Visuel + Appareil, règles 6 et 12) Captures conservées d'un nœud aux niveaux 1, 2, 3, en portrait, à 31 pt la tuile, en couleur et en niveaux de gris, sur l'appareil cible, validées par l'art-director. Critère : le niveau se lit sans la couleur seule (nombre d'anneaux allumés), jugé par deux relecteurs sur les trois niveaux. [BLOQUÉ 17]
- **AC-ND27** (Visuel, règle 7) Captures avant et après une capture : la teinte du camp couvre le carré de rayon R, eau comprise, validées par l'art-director. [BLOQUÉ 15]

### Non testable en l'état

- Règle 6 (justification de conception), règle 3 (vérifiable seulement par recherche statique) et règle 9 (en partie).
- Le système 5 (dernier propriétaire vu) : aucun critère écrit avant son GDD.
- MONTER_NŒUD manque dans 23 : AC-ND12 et AC-ND19 ne s'exécutent qu'après son ajout.

## Open Questions

| Question | Propriétaire | À résoudre avant | Résolution |
|---|---|---|---|
| La montée ne rapporte que +1 d'énergie par tour pour 12 puis 20 (retour en 12 et 20 tours) : sa valeur vient du territoire et du score. Faut-il élargir l'écart des revenus (par exemple 3 / 5 / 7) ou accepter ? **Le contrôle d'équilibre est relié aux poids du score** (`w_l` pour ΣL et `w_n` pour N, `tours-conditions-victoire.md`) : si ces poids sont trop faibles, la montée est un piège. | economy-designer | Prototype, `/balance-check` | Provisoire : accepté, à mesurer |
| Niveau d'un nœud capturé : réduit d'un cran (retenu) ; variante remise à 1 à comparer. | game-designer | Playtest | |
| Rayons 1 / 2 / 3 sur la vraie carte 12×12 (aucun fichier de carte n'existe) : recalculer les tailles de territoire. | level-designer | Fichiers de cartes du MVP | |
| Une unité garée sur son nœud bloque toute capture : quelle pression rend ce repli coûteux ? | game-designer | Playtest, GDD 9 | |
| Les tuiles de ruine survivent-elles à la perte des nœuds (retenu) ? À valider avec 13 et 15, ainsi que la taille de la zone d'une ruine. | game-designer | GDD 13, 15 | |
| Une ruine peut-elle prendre des tuiles ennemies ? Retenu : non. | game-designer | GDD 13 | |
| Le bonus de soin lit le propriétaire de la tuile du nœud (retenu) ou du territoire ? | game-designer | Revue de 6 | |
| Le territoire donne-t-il de la vision ? Le brouillard mémorise-t-il le dernier propriétaire vu d'un nœud ? | game-designer | GDD 5 | Provisoire : non / oui |
| Format de l'intention de capture (cible : le nœud ; l'unité déjà posée ?) et raisons d'annulation. | game-designer, ai-programmer | GDD 9 et 1 | |
| Rendu de l'eau possédée (15). | art-director | GDD 15 | |
| Lecture du niveau : trois anneaux dont autant d'allumés que le niveau. | art-director | Test de silhouette | Proposition |
| Reporter dans 23 : MONTER_NŒUD, six codes, NŒUD_MONTÉ, B_max ; dans 1 : `depuis_tour`, `monté_au_tour`, ancrage ; dans `hud.md` : bouton Capturer à l'action. | game-designer | Revue de 23, 1 et `hud.md` | |
