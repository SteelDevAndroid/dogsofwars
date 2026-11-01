# Contrôles tactiles et caméra de carte

> **Status**: Designed (pending /design-review)
> **Author**: user + Claude (game-designer, ux-designer, gameplay-programmer)
> **Last Updated**: 2026-10-30
> **Last Verified**: 2026-10-30
> **Implements Pillar**: Pilier 3 « Lisible comme Polytopia » (appuis simples) ; pilier 4 « La puissance se mérite » (toute perte est annoncée par des signaux visibles ; un joueur attentif peut l'éviter) ; accessibilité Standard + Comprehensive (`design/accessibility-requirements.md`)
> **Creative Director Review (CD-GDD-ALIGN)**: REVISED 2026-10-30 — CONCERNS (garantie du Player Fantasy trop large dans le brouillard ; grappe de boutons contraire à l'art bible et marge d'une tuile trop étroite ; règle 8 contre le brouillard) corrigées : garantie limitée aux tuiles vues, explorer assumé comme engagement ; marge de 2 tuiles, plage de défilement continue, exception inscrite dans l'art bible §7 ; eau jamais vue traitée comme une embuscade

## Summary

Ce système transforme les doigts du joueur en ordres et en mouvements de caméra : un appui
net sélectionne ou déplace, un glissement fait défiler la carte, des boutons +/− (et le
pincement, en raccourci) règlent le zoom, et une grappe de boutons recentre la vue. Il
n'écrit jamais dans la partie : tout ordre passe par une commande validée par le système 23,
et la portée affichée est la validation elle-même. Il existe pour que le pilier 3 « lisible
comme Polytopia » tienne au pouce, sur des tuiles de 31 pt, sans jamais exiger un geste à
deux doigts ni lire un glissement comme un ordre.

> **Quick reference** — Layer: `Core` · Priority: `MVP` · Key deps: `Carte en tuiles et terrain, Commandes et événements`

## Overview

Ce système fait le lien entre le doigt du joueur et la partie. Il possède deux choses :
l'**interprétation des gestes** (appui, glissement, pincement, boutons de zoom) en
intentions de jeu — sélectionner une unité ou une tuile, afficher la portée, déplacer,
entrer en ciblage, recentrer sur une puce d'alerte — et la **caméra de carte** : défilement,
zoom, bornes et recentrage sur une carte de 16 × 16 tuiles au plus
(`MAX_MAP_SIZE`, `design/gdd/modele-etat-partie.md`). Il n'écrit jamais dans l'état de
la partie : une intention qui change le jeu devient une commande, émise vers le système 23
(`design/gdd/commandes-evenements.md`), qui valide et applique ; pour savoir quelle tuile
est sous le doigt et quelles tuiles voisines existent, il lit la carte (2,
`design/gdd/carte-tuiles-terrain.md`). Toute la partie se joue en appuis simples : le
pincement n'est qu'un raccourci, jamais le seul accès (`design/accessibility-requirements.md`).

Il existe parce que le pilier 3 (« lisible comme Polytopia ») se gagne ou se perd au
doigt : une tuile de 31 pt visée au pouce, un défilement qui ne confond pas un appui avec
un glissement, un zoom qui ne coûte pas un geste à deux doigts. Sans lui, la meilleure
règle de jeu est injouable sur un téléphone.

*Cadrage : technique et joueur à la fois, la catégorie du système étant `Core` mais son
effet étant tout entier ressenti à la main. Pas d'ADR cité (aucun n'existe encore) ; le choix
des événements d'entrée de Godot et du nœud de caméra est renvoyé à un ADR (voir
Dependencies).*

## Player Fantasy

*Cadrage : indirect. Le joueur ne sent pas un système de gestes ; il sent que la meute lui
obéit exactement. Retenu : cadrage « Un appui, un ordre », avec « Rien ne part sans vous »
comme garantie (`creative-director`, 2026-10-30).*

La machine attendait un ordre : la niche de commande des drones est vide
(`design/art/art-bible.md`, section 5), et c'est le doigt du joueur qui la remplit. Le
moment type : on touche un drone, son hexagone blanc s'allume et sa portée se dessine ;
un second appui l'envoie vers une ruine ocre, à la lisière du brouillard. Le drone y va,
sans délai et sans interprétation. La sensation visée est **l'obéissance exacte**, pas la
puissance : sobre, au présent, mécanique.

La garantie qui rend cette fantaisie vraie, **sur les tuiles vues** : un geste raté ne
coûte rien. Un appui tombé sur la mauvaise tuile se voit avant d'engager (portée, aperçu),
se défait (annulation du dernier déplacement, `design/gdd/commandes-evenements.md`) ou ne
part pas du tout. **Dans le brouillard, explorer est un engagement** : un déplacement qui
révèle quelque chose ne s'annule pas, et c'est voulu — c'est le prix de la question que pose
le brouillard (pilier 5). Cet engagement ne coûte jamais une perte non annoncée : aucune
attaque n'a lieu sans intention annoncée, une embuscade arrête l'unité sans la blesser, et
les GDD 5 et 6 doivent le garantir. Le défaut à éviter est l'interface qui donne un ordre
que le joueur n'a pas donné — un glissement lu comme un appui, un zoom qui exige deux
doigts. Test : **aucune commande irréversible ne naît d'un geste ambigu** (un appui net sur
une tuile voisine n'est pas ambigu ; le risque d'un mauvais appui sur 31 pt est accepté et
se mesure sur appareil).

*Piliers servis : 3 « Lisible comme Polytopia » (un appui, un effet) et 4 « La puissance
se mérite » (aucun geste ne cause une perte non annoncée). Le sentiment d'une carte « tenue dans la main »
relève de la caméra et va dans Game Feel.*

## Detailed Design

*Décisions du 2026-10-30 : un appui sur une tuile de portée déplace aussitôt l'unité, y
compris vers le brouillard ; zoom par boutons +/− avec pincement facultatif ; les boutons
de la carte forment une grappe flottante. Les valeurs entre crochets sont des valeurs de
départ à jouer en test (voir Tuning Knobs). Les 5 (brouillard) et 17 (HUD) n'ont pas encore
de GDD : leurs lignes sont des contrats provisoires.*

### Core Rules

**A. Interprétation des gestes**

1. **Zone tactile.** Ce système n'interprète que les appuis tombés dans le rectangle de
   carte (règle 14). Le HUD consomme les siens. Un contact est jugé **au relâchement**,
   jamais à la pose : un défilement ne déclenche donc jamais de commande.
2. **Appui ou défilement.** À la pose, on mémorise le point. Tant que le doigt reste à
   moins d'une **demi-tuile** de ce point (distance mesurée en pixels écran, donc
   proportionnelle au zoom), le contact est un appui potentiel ; relâché dans ce rayon,
   c'est un **appui**. Dès que la demi-tuile est dépassée, le contact devient un
   **défilement** et ne redevient jamais un appui, même si le doigt revient.
3. **Défilement.** La carte suit le doigt 1:1 dans tous les modes, y compris quand le
   doigt a commencé sur une unité (aucun glisser-déposer d'unité). Pas d'inertie : la carte
   s'arrête au relâchement, pour la précision et avec les animations réduites.
4. **Pincement (facultatif).** Une seconde pose pendant un contact annule l'appui ou le
   défilement en cours et démarre un pincement : zoom continu ancré au milieu des deux
   doigts, borné entre le zoom minimal et le zoom maximal. Quand un doigt se lève, le
   pincement s'arrête et le doigt restant ne reprend pas le défilement avant d'avoir été
   relevé (aucun saut). Rien n'exige jamais deux doigts.
5. **Boutons de zoom +/−** (zone tactile de 48 dp / 44 pt, dans la grappe de la règle 15) :
   zoom ancré au centre du rectangle de carte, multiplié ou divisé par `ZOOM_STEP_MILLI`.
   Grisés — jamais cachés — aux bornes.
6. **Ni double appui, ni appui long, ni glisser-déposer.** Deux appuis rapprochés sont
   deux appuis indépendants. Cela tranche la question ouverte de
   `design/accessibility-requirements.md` : le zoom sans pincement se fait par les boutons.
7. **Contact interrompu.** Une interruption système, une pause ou une perte de focus
   abandonne le contact : ni appui, ni défilement.
8. **La portée affichée est la validation.** Ce système ne calcule jamais la portée : pour
   chaque tuile, il demande au système 23 de valider DÉPLACER **sans appliquer**
   (`design/gdd/commandes-evenements.md`, règle 7) ; les tuiles « permises » reçoivent le
   point de portée. Une seule source de vérité (pilier 4). Pour une tuile jamais vue, la
   validation se fait d'après la vue du joueur (règle 11) : le point de portée ne dépend
   alors que de la distance.

**B. Effet d'un appui** (colonne = mode d'interaction ; « E » = émet la commande ;
« — » = ignoré, aucune commande)

| Cible | Repos | Unité sélectionnée | Ciblage | Verrouillé |
|---|---|---|---|---|
| Unité du joueur, autre que la sélection | Sélectionne | Change de sélection | Retour au panneau d'unité, sans sélectionner | — |
| Unité du joueur, la sélection | — | Désélectionne | Retour au panneau d'unité | — |
| Tuile dans la portée | — | **E : DÉPLACER**, sans confirmation | Retour au panneau d'unité | — |
| Tuile hors portée | — | Refus affiché (code de 23) ; sélection gardée | Retour au panneau d'unité | — |
| Unité ennemie visible | — | Si ATTAQUER est validée : ouvre le ciblage avec cette cible déjà choisie ; sinon le refus de 23 | Cible marquée : la choisit (aperçu recalculé) ; même cible une seconde fois : **E : ATTAQUER** | — |
| Tuile sous brouillard | — | Traitée comme une tuile ordinaire de portée (règle 11) | Retour au panneau d'unité | — |
| Fond vide (hors carte) | — | Désélectionne | Retour au panneau d'unité | — |

9. **Ciblage.** « Confirmer l'attaque » et « Annuler » appartiennent au HUD. Défilement et
   zoom restent possibles en ciblage.
10. **Un ordre seulement par un appui net.** Aucune commande ne naît d'un défilement, d'un
    pincement ni d'un contact interrompu : c'est le test de la Player Fantasy.
11. **Brouillard (5).** Une tuile sous brouillard n'a pas de fiche : un appui n'affiche
    aucune information cachée. Une tuile jamais vue est validée d'après la vue du joueur,
    donc comme franchissable : un DÉPLACER vers elle est permis. S'il rencontre une unité
    ennemie cachée, ou une eau ou un obstacle jamais vus, l'unité s'arrête avant, le
    déplacement est consommé jusqu'à l'arrêt et l'obstacle devient vu (embuscade,
    `commandes-evenements.md`, règle 6 — à étendre à l'eau jamais vue, voir Open
    Questions). Le seul refus possible sur une tuile jamais vue est la distance, avec **un
    code unique** (`HORS_DE_PORTÉE`), jamais un code qui révélerait de l'eau ou une unité
    (`CASE_BLOQUÉE`). **Explorer est un engagement** : ce déplacement ne s'annule pas s'il a
    révélé quelque chose (23, règle 15), mais il ne coûte jamais une perte non annoncée.
    Risque de mauvais appui accepté, à mesurer sur appareil.
12. **Annuler le déplacement.** Un bouton « Annuler le déplacement », dans le panneau
    d'unité, émet ANNULER_LE_DÉPLACEMENT ; il est grisé avec sa raison (`RIEN_À_ANNULER`,
    `DÉPLACEMENT_A_RÉVÉLÉ`, `AUTRE_ACTION_DEPUIS`). À l'événement DÉPLACEMENT_ANNULÉ, l'unité
    est resélectionnée et la caméra la garde visible (règle 19).

**C. Caméra**

13. **Repère.** Tuile (x, y) du système 2, origine en haut à gauche. Écran = (tuile −
    centre de la caméra) × taille de tuile + centre du rectangle de carte. Une taille de
    tuile unique pour X et Y ; la caméra mémorise un centre (en tuiles, flottant) et un zoom.
14. **Rectangle de carte.** L'écran moins les insets système, la barre du haut et la zone
    d'alerte (portrait) ou le rail (paysage), et le panneau de contexte
    (`design/ux/hud.md`, section 3). Aucun panneau ne recouvre une tuile jouable. En tour
    du joueur, le rectangle **ne change pas de taille** : on réserve la hauteur du panneau
    d'unité, même quand il se réduit au bouton « Fin du tour ». Il ne change qu'aux états à
    commandes verrouillées (panneau de fragment, tour ennemi), où le point de focus reste
    visible par le décalage minimal.
15. **Grappe de boutons flottante.** Les boutons +/− et « Recentrer » (48 dp chacun) sont
    une colonne dans un coin bas du rectangle de carte, du côté opposé au pouce de
    l'option « Panneau à gauche » (inversée en paysage miroir). C'est une **exception
    assumée** à « aucun panneau ne recouvre une tuile jouable », inscrite dans l'art bible
    (section 7) : la marge de défilement de la règle 18 — deux tuiles, soit 62 pt au zoom
    minimal pour une grappe de 48 dp de large — permet toujours de sortir une tuile de
    dessous la grappe, même quand la carte tient entière.
16. **Zoom.** Zoom minimal : tuile de `ZOOM_MIN_TILE_PT` = 31 pt au moins. Zoom maximal :
    `ZOOM_MAX_MILLI` = 2 fois la taille minimale (62 pt). Zoom par défaut : 8 colonnes
    visibles en portrait, 12 en paysage (`hud.md`, Tuning Knobs). La carte entière **n'est
    jamais visible** en portrait : 12 colonnes de 31 pt font 372 pt pour 358 pt utiles, et
    16 colonnes en font 496 ; le défilement est obligatoire.
17. **Zoom en points.** « Point » est une unité indépendante de la densité (dp sur Android,
    pt sur iOS) : la conversion en pixels du viewport et le seuil de la règle 2 en pixels
    écran dépendent du mode d'étirement du projet, renvoyé à un ADR.
18. **Bornes.** Sur chaque axe, le centre est borné pour que le bord de la carte puisse
    dépasser le bord du rectangle d'au plus `EDGE_MARGIN_TILES` = 2 tuiles, en portrait comme
    en paysage : la carte ne sort jamais entièrement de l'écran, le joueur peut faire
    descendre les tuiles du haut vers son pouce, et même une carte qui tient entière peut
    être décalée de la marge (de quoi dégager un coin de dessous la grappe). Quand
    la plage de défilement d'un axe se réduit à un point (carte très petite dans le
    rectangle, formule 6), la carte est centrée et verrouillée sur cet axe.
19. **Recentrage animé** sur `RECENTER_MS` ; instantané avec « Réduction des animations ».
    Un recentrage ne change ni le zoom, ni la sélection, ni le mode.
20. **Déclencheurs de recentrage.**
    - (a) Appui sur une puce d'alerte : sur la ruine (puce de ruine), sur la perte (puce de
      perte), ou sur la prochaine tuile visée, en cyclant (puce de menace).
    - (b) Lecture d'une ruine (RUINE_LUE) : une seule fois, si la ruine est hors du
      rectangle, que le panneau de fragment réduit.
    - (c) Un changement du rectangle (panneau qui s'ouvre, puce qui apparaît) ou une
      sélection garde la tuile de focus visible par le **décalage minimal**, sans
      recentrer si elle l'est déjà.
    - (d) Début du tour du joueur : la caméra revient à l'état qu'elle avait à FINIR_LE_TOUR.
      Elle ne suit pas les actions ennemies : le journal et le cadre violet suffisent.
    - (e) « Recentrer » : sur l'unité sélectionnée ; sinon sur la dernière sélectionnée ;
      sinon sur l'unité du joueur d'identifiant le plus bas (déterministe).

### States and Transitions

**Mode d'interaction** — dérivé de l'état de partie et du HUD (17), jamais stocké dans l'état.

| Mode | Entrée | Sorties valides |
|---|---|---|
| REPOS | Début du tour (TOUR_COMMENCÉ), désélection, ÉTAT_CHARGÉ | SÉLECTION |
| SÉLECTION | Appui sur une unité du joueur ; DÉPLACEMENT_ANNULÉ | REPOS ; SÉLECTION (autre unité) ; CIBLAGE ; RÉSOLUTION ; LECTURE (déplacement sur une ruine) |
| CIBLAGE | « Attaquer », ou appui sur un ennemi à portée | SÉLECTION (« Annuler », appui hors cible) ; RÉSOLUTION (confirmation) |
| RÉSOLUTION | ATTAQUER confirmée (verrou d'environ 1,6 s) | SÉLECTION ou REPOS à la fin du verrou |
| LECTURE | RUINE_LUE | REPOS ou SÉLECTION par « Continuer » |
| TOUR_ENNEMI | FINIR_LE_TOUR | REPOS à TOUR_COMMENCÉ |
| SUSPENDU | Pause ; fin de partie | Mode précédent à la reprise ; fin |

**Geste, par contact** : LIBRE → APPUI_POSSIBLE (pose) → APPUI (relâché dans la demi-tuile)
ou DÉFILEMENT (dépassement, irréversible) ; APPUI_POSSIBLE ou DÉFILEMENT → PINCEMENT
(seconde pose) → LIBRE (relève) ; tout état → LIBRE par contact interrompu (règle 7).

En RÉSOLUTION, LECTURE et TOUR_ENNEMI, le défilement, le zoom et les puces de recentrage
restent actifs (la caméra n'est pas une commande ; `hud.md` : la carte reste visible) ;
les appuis sur une tuile sont ignorés, sans commande. En SUSPENDU, tout est ignoré.

### Interactions with Other Systems

| # | Système | Sens | Ce qui circule | Propriétaire de l'interface |
|---|---|---|---|---|
| 2 | Carte en tuiles | lit | Requêtes de tuile et de voisins ; taille W × H (au plus 16) pour les bornes. Aucune écriture | 2 |
| 23 | Commandes et événements | émet / lit | Émet DÉPLACER, ATTAQUER, ANNULER_LE_DÉPLACEMENT, FINIR_LE_TOUR. Lit les validations (portée, boutons grisés). Écoute DÉPLACEMENT_ANNULÉ, ÉTAT_CHARGÉ, UNITÉ_DÉPLACÉE, RUINE_LUE, TOUR_COMMENCÉ. N'émet rien dans les modes verrouillés | 23 |
| 5 | Brouillard et vision (sans GDD) | lit | Vu / non vu, par la vue du joueur ; aucune information cachée (règle 11) | 5 |
| 17 | HUD (sans GDD) | bidirectionnel | 17 fournit le rectangle de carte et les puces ; 4 fournit le mode d'interaction, la sélection et les demandes de recentrage | 17 pour la mise en page, 4 pour le mode |
| 16 | Sauvegarde automatique | aucun | La caméra (centre, zoom) n'est **pas sauvegardée** : c'est de la présentation, comme la file d'événements (23, règle 10). Au chargement : zoom par défaut, centre sur l'unité du joueur d'identifiant le plus bas | — |

### Ce que le joueur ne peut pas faire

- Écrire l'état, ou agir hors commande, hors de son tour ou pendant un verrou.
- Déplacer une unité par glisser-déposer, ou agir par appui long, double appui ou geste à
  plusieurs doigts (seul le pincement existe, en raccourci).
- Sortir la carte de l'écran, ou zoomer hors de la plage [31 pt, 62 pt] par tuile.
- Lire une information cachée en appuyant sur le brouillard.
- Annuler un déplacement qui a révélé quelque chose ou lu une ruine, ou après une autre
  commande (23, règle 15).

## Formulas

*La caméra est de la présentation : les flottants sont permis (`float` GDScript, 64 bits) et
rien de ce qui suit n'est sauvegardé ni n'entre dans l'état de partie. Une commande ne
reçoit que des entiers (x, y), issus de `floori` et validés par le système 23 ; deux
appareils qui diffèrent d'un pixel ne cassent donc pas le déterminisme du modèle d'état
(`design/gdd/modele-etat-partie.md`). Convention : le centre de caméra `c = (cx, cy)` est en
tuiles, la tuile (x, y) couvre [x, x+1[. Le rectangle de carte a pour taille `rw × rh` (pt)
et pour centre `rc`. `h = rect / (2 × tile_pt)` est la demi-étendue visible, en tuiles.
Exemples calculés pour un rectangle d'environ 350 × 460 pt en portrait et 436 × 366 pt en
paysage.*

### 1. Taille de tuile et zoom par défaut

The tile size formula is defined as:

`tile_pt = ZOOM_MIN_TILE_PT * z` ; `tile_px = tile_pt * px_per_pt` ;
`tile_default = clamp(rw / cols_default, ZOOM_MIN_TILE_PT, ZOOM_MAX_MILLI * ZOOM_MIN_TILE_PT)`

**Variables:**

| Variable | Type | Range | Source | Description |
|---|---|---|---|---|
| z | float | 1..2 | calculated | Facteur de zoom |
| ZOOM_MIN_TILE_PT | float | 31 | constant | Tuile minimale, en pt (`hud.md`) |
| ZOOM_MAX_MILLI | int | 1500..3000 | data file (2000) | Facteur maximal en millièmes (2000 = 2×) ; la formule lit `ZOOM_MAX_MILLI / 1000` |
| rw | float | 200..500 | calculated (HUD) | Largeur du rectangle de carte, en pt |
| cols_default | int | 6..10 portrait, 10..14 paysage | data file (`hud.md`) | Colonnes visibles par défaut (8 / 12) |
| px_per_pt | float | 1..4 | calculated | Densité (formule 4) |

**Output Range:** `tile_pt` dans [31, 62] ; 14 colonnes sur un rectangle étroit donnent 31 et non moins.
**Example (12 × 12, portrait, rw = 350):** 350 / 8 = 43,75 pt, soit z = 1,411. **Paysage (rw = 436):** 436 / 12 = 36,33 pt.

### 2. Bornes et pas de zoom

The zoom step formula is defined as:

`z' = min(z * S, Z_MAX)` (zoom +) ; `z' = max(z / S, 1)` (zoom −) ; bouton grisé si
`|z' - z| < ZOOM_EPS_MICRO`. Pincement : `z' = clamp(z0 * d / d0, 1, Z_MAX)`

**Variables:**

| Variable | Type | Range | Source | Description |
|---|---|---|---|---|
| S | float | 1,15..1,5 | calculé : `ZOOM_STEP_MILLI / 1000` (`ZOOM_STEP_MILLI` = 1260, soit 2^(1/3) arrondi) | Facteur par appui |
| Z_MAX | float | 1,5..3 | calculé : `ZOOM_MAX_MILLI / 1000` | Facteur maximal |
| ZOOM_EPS_MICRO | int | 100..10000 | data file (1000) | Tolérance de borne en millionièmes (`ZOOM_EPS = ZOOM_EPS_MICRO / 1 000 000`), sans unité |
| d, d0 | float | > 0 | calculated | Écart des doigts, courant et initial |

**Output Range:** z dans [1, 2] ; le dernier pas est tronqué à la borne (aucun dépassement).
**Example:** avec S = 2^(1/3), trois appuis exactement du minimum au maximum : 31 → 39,06 → 49,21 → 62 pt. Depuis 43,75 pt : 55,12 → 62 (69,5 tronqué).

### 3. Écran vers tuile

The screen-to-tile formula is defined as:

`w = c + (s - rc) / tile_pt` ; `tile = (floori(w.x), floori(w.y))` ; valide ssi
`0 <= x < W` et `0 <= y < H`

**Variables:**

| Variable | Type | Range | Source | Description |
|---|---|---|---|---|
| s | vec2 float | rectangle de carte | calculated | Point touché, en pt |
| c, rc | vec2 float | voir formule 6 | calculated | Centre de la caméra, centre du rectangle |
| W, H | int | 1..16 | data file (système 2) | Dimensions de la carte |

**Output Range:** entiers non bornés ; une tuile hors [0, W[ × [0, H[ est un **fond vide**
(désélectionne), jamais ramenée dans les bornes. `floori` est obligatoire : `int()` tronque
vers zéro et ferait de −0,3 la tuile 0. Un bord exact appartient à la tuile suivante.
**Example (paysage, c = (6, 6), tuile de 36,33 pt):** 100 pt à droite et 50 pt au-dessus de
`rc` → w = (8,752 ; 4,624) → tuile (8, 4). **Portrait, c = (2, 6), 200 pt à gauche de `rc`:**
w.x = −2,571 → x = −3, hors carte.

### 4. Seuil d'appui

The tap slop formula is defined as:

`slop_px = TAP_SLOP_MILLI * tile_pt * px_per_pt` ; défilement ssi `dist² > slop_px²`

**Variables:**

| Variable | Type | Range | Source | Description |
|---|---|---|---|---|
| TAP_SLOP_MILLI | int | 300..700 | data file (500) | Fraction de tuile en millièmes ; la formule lit `TAP_SLOP_MILLI / 1000` |
| px_per_pt | float | 1..4 | calculated | Android : dpi / 160 ; iOS : facteur d'échelle ; dépend du mode d'étirement (règle 17, ADR) |
| dist | float | ≥ 0 | calculated | Distance entre la pose et le doigt, en px |

**Output Range:** de 15,5 pt (zoom minimal) à 31 pt (zoom maximal). Le zoom est figé pendant un contact (un pincement l'annule). Une distance égale au seuil reste un appui.
**Example (densité 3, portrait par défaut):** tile_px = 131,25 ; slop = 65,6 px (21,9 pt).

### 5. Ancrage du zoom

The zoom anchor formula is defined as:

`c' = c + (a - rc) * (1/tile_pt - 1/tile_pt')`, puis clamp (formule 6)

**Variables:**

| Variable | Type | Range | Source | Description |
|---|---|---|---|---|
| a | vec2 float | rectangle de carte | calculated | Ancre : `rc` (boutons), milieu des doigts (pincement) |
| tile_pt, tile_pt' | float | 31..62 | calculated | Taille de tuile avant et après |

**Output Range:** le point du monde sous `a` est conservé tant que le clamp n'agit pas ; si le clamp déplace `c'`, **le clamp l'emporte** (l'ancre dérive). Avec `a = rc`, `c' = c`.
**Example (portrait, c = (4, 6), `a` à 100 pt à droite de `rc`, tuile 43,75 → 54,69):** c'.x = 4 + 100 × (0,022857 − 0,018286) = 4,457. Contrôle : 4 + 100 / 43,75 = 6,2857 avant ; 4,457 + 100 / 54,69 = 6,2857 après.

### 6. Bornes de défilement

The pan clamp formula is defined as:

`lo = hx - M` ; `hi = W - hx + M` ; `cx = clamp(cx, lo, hi)` si `lo < hi`, sinon
`cx = W / 2` (verrouillé) (idem pour y avec H et rh)

**Variables:**

| Variable | Type | Range | Source | Description |
|---|---|---|---|---|
| M | float | 0..3 | data file (`EDGE_MARGIN_TILES` = 2, minimum 2 pour dégager la grappe) | Dépassement de bord autorisé, en tuiles |
| hx, hy | float | 1,6..8 | calculated | `rw / (2 · tile_pt)`, `rh / (2 · tile_pt)` |

**Output Range:** intervalle de largeur `W + 2M − 2h`, centré sur W/2. Il se réduit à un point quand `W + 2M = 2h` : la transition entre « libre » et « verrouillé » est donc continue, sans saut ni tolérance de comparaison. `M` doit dépasser la largeur de la grappe en tuiles au zoom minimal (48 / 31 ≈ 1,55) pour que le coin de la carte sorte de dessous : d'où 2.

| Cas | tile (pt) | Axe x | Axe y |
|---|---|---|---|
| 12×12 portrait (350×460), défaut | 43,75 | hx = 4,0 → [2,0 ; 10,0] | hy = 5,257 → [3,257 ; 8,743] |
| idem, zoom minimal | 31 | [3,645 ; 8,355] | hy = 7,419 → [5,419 ; 6,581] |
| idem, zoom maximal | 62 | [0,823 ; 11,177] | [1,710 ; 10,290] |
| 12×12 paysage (436×366), défaut | 36,33 | hx = 6,0 → [4,0 ; 8,0] | hy = 5,037 → [3,037 ; 8,963] |
| 10×10 portrait, zoom minimal | 31 | [3,645 ; 6,355] | 10 + 4 = 14 ≤ 14,84 : **cy = 5 verrouillé** |
| 16×16 portrait, zoom minimal | 31 | [3,645 ; 12,355] | [5,419 ; 12,581] |
| 16×16 paysage, défaut | 36,33 | [4,0 ; 12,0] | [3,037 ; 12,963] |

### 7. Focus au décalage minimal

The focus formula is defined as:

`p = (fx + 0.5, fy + 0.5)` ; `K_eff = min(K, h - 0.5)` ; `g = max(0, h - 0.5 - K_eff)` ;
`c' = clamp(c, p - g, p + g)` par axe, puis clamp (formule 6)

**Variables:**

| Variable | Type | Range | Source | Description |
|---|---|---|---|---|
| (fx, fy) | int | 0..W−1, 0..H−1 | calculated | Tuile à montrer |
| K | float | 0..1 | calculé : `FOCUS_CLEARANCE_MILLI / 1000` (`FOCUS_CLEARANCE_MILLI` = 500) | Dégagement entre le bord de la tuile et le bord du rectangle |
| g | float | ≥ 0 | calculated | Demi-fenêtre où `p` ne déclenche aucun mouvement |

**Output Range:** `c' = c` si `p` est déjà dans la fenêtre (règle 20c : aucun recentrage) ; sinon décalage minimal, axes indépendants. Un axe verrouillé reste inchangé. Le clamp prime ; la tuile reste entièrement visible tant que K ≤ M + 0,5 (vrai : 0,5 ≤ 1,5).
**Example (portrait, c = (6, 6), focus (10, 2), g_x = 3,0, g_y = 4,257):** cx = clamp(6 ; 7,5 ; 13,5) = 7,5, cy inchangé : décalage de 1,5 tuile (65,6 pt). **Paysage, focus (3, 11):** cy = clamp(6 ; 7,463 ; 15,537) = 7,463 (53,2 pt), déjà dans [3,037 ; 8,963] ; cx = 6, inchangé.

### 8. Tuiles visibles par axe

The visible tiles formula is defined as:

`n_x = rw / tile_pt` ; `n_y = rh / tile_pt` ; entièrement visibles : `floori(n)` ;
affichées : `min(n, W)`

**Variables:**

| Variable | Type | Range | Source | Description |
|---|---|---|---|---|
| n | float | 3,2..15,5 | calculated | Tuiles par axe |

**Output Range:** minimum 3,2 (tuile de 62 pt, rw = 200) ; maximum `rw / 31`.
**Example:** portrait 12×12 : défaut 8,0 × 10,51 ; zoom minimal 11,29 × 14,84 ; zoom maximal 5,65 × 7,42. Paysage, défaut : 12,0 × 10,07 ; zoom minimal 14,06 × 11,81.

### Écarts relevés par les formules

- Le rectangle de carte portrait vaut 358 pt dans la règle 16, environ 350 pt au brouillon et
  336 pt si l'on déduit « 42 pt × 8 » de `design/ux/hud.md` : à figer avec le HUD (17). Avec
  358 pt, la tuile par défaut vaut 44,75 pt.
- `hud.md` écrit « ≈ 34 pt en paysage (436 pt sur 12 colonnes) » : 436 / 12 = 36,33. À corriger.
- « La carte entière n'est jamais visible en portrait » (règle 16) est vraie pour W ≥ 12
  seulement : une carte de 11 colonnes ou moins tient entière au zoom minimal.
- 12×12 en paysage : 12 × 31 = 372 > 366, donc un défilement vertical subsiste au zoom minimal.
- Règle 18 (révisée après le gate CD-GDD-ALIGN) : la plage de défilement se réduit
  continûment à un point ; il n'y a ni saut du centre ni tolérance de comparaison. L'ancienne
  ligne « 16×16 portrait, zoom minimal » donnait y [6,419 ; 9,581] avec une marge de 1 : erreur
  corrigée en [5,419 ; 12,581] (marge de 2).

## Edge Cases

*Résolutions marquées « (choix) » : décidées ici faute de règle existante.*

### Gestes et contacts

- **Si un second doigt se pose pendant l'appui possible ou le défilement, dans le rectangle de carte hors grappe**: pincement (règle 4), aucune commande. Aucun des deux contacts ne redevient un appui. Un troisième doigt est ignoré.
- **Si un doigt se pose sur la grappe ou une puce pendant un défilement**: c'est un contact HUD indépendant (choix), il ne déclenche pas de pincement. S'il lance un recentrage, le défilement en cours est abandonné jusqu'au relevé du doigt. Un bouton n'annule ainsi jamais un pincement, ni l'inverse.
- **Si un contact démarre dans un panneau du HUD et finit sur la carte**: le HUD l'a consommé ; la carte ne reçoit rien, aucun appui. **S'il démarre sur la carte et finit sur le HUD**: la cible reste jugée à la pose (choix) ; un appui relâché dans la demi-tuile agit sur la tuile posée, un défilement se termine normalement.
- **Si un appui tombe sur un bouton de la grappe, au-dessus d'une tuile**: le bouton gagne, la tuile ne reçoit rien. Un doigt posé hors bouton puis relâché sur un bouton agit sur la tuile posée, jamais sur le bouton.
- **Si le doigt sort du rectangle ou de l'écran pendant un défilement**: le défilement continue d'après la position écran (bornée par la formule 6) jusqu'au relevé. Un appui possible garde sa tuile de pose.
- **Si un geste système (retour, accueil, bord d'écran) interrompt le contact**: contact abandonné, ni appui ni défilement (règle 7). **Si Godot n'envoie aucun événement d'annulation**: NOT SOURCEABLE (`docs/engine-reference/godot/` ne le couvre pas). Repli sûr : une nouvelle pose du même index de doigt remplace le contact resté ouvert.
- **Si deux appuis sont relâchés dans la même image**: traités dans l'ordre d'arrivée, **une seule commande par image** ; le second appui est jeté sans commande ni refus affiché, pour ne jamais montrer à tort un refus tel que DÉJÀ_DÉPLACÉE (23).
- **Si un appui arrive pendant RÉSOLUTION, LECTURE, TOUR_ENNEMI ou SUSPENDU**: ignoré, aucune commande émise et 23 n'est pas interrogé (donc aucun COMMANDES_VERROUILLÉES affiché). **S'il coïncide avec la distribution d'un lot d'événements**: l'entrée est traitée après le lot, car ce système n'est pas un auditeur (23, règle 11).
- **Si l'état change entre la pose et le relâchement (UNITÉ_DÉPLACÉE, unité détruite)**: la tuile visée est celle mémorisée à la pose ; la commande est revalidée au relâchement par 23. Si l'unité sélectionnée n'existe plus : retour à REPOS, appui jeté. Sinon le code de refus de 23 s'affiche.
- **Si le rectangle de carte change, ou si un recentrage automatique démarre, pendant un contact**: contact abandonné (choix), car le seuil en pixels n'a plus de sens sous un décor mobile. Un appui perdu coûte moins qu'un ordre non voulu (Player Fantasy).
- **Si la cadence d'images est très basse**: le geste se juge à la distance cumulée depuis la pose, à chaque événement de glissement, jamais à un nombre d'images ni à une durée. **Si le moteur fusionne les événements d'une image**: un aller-retour au-delà de la demi-tuile peut être manqué — NOT SOURCEABLE, renvoyé à un ADR (désactiver l'accumulation des événements d'entrée).

### Brouillard et refus

- **Si DÉPLACER vers une tuile jamais vue est refusé**: il ne peut l'être que pour la distance, avec le code unique `HORS_DE_PORTÉE`, jamais `CASE_BLOQUÉE`. Une fois la tuile vue, elle reçoit son code réel. Le point de portée d'une tuile cachée ne dépend que de la distance (choix), pour ne pas révéler l'eau.
- **Si un DÉPLACER vers une tuile jamais vue rencontre une eau ou un obstacle jamais vus**: l'unité s'arrête avant l'obstacle, le déplacement est consommé jusqu'à l'arrêt (comme une embuscade, 23 règle 6), l'obstacle devient vu et « Annuler le déplacement » est grisé avec `DÉPLACEMENT_A_RÉVÉLÉ`. Aucune perte n'en résulte : aucune attaque n'a lieu sans intention annoncée.
- **Si un déplacement dans le brouillard révèle un ennemi**: l'unité s'arrête avant lui (23, règle 6) et reste sélectionnée ; « Annuler le déplacement » est grisé avec `DÉPLACEMENT_A_RÉVÉLÉ`. La caméra suit l'unité (règle 20c), pas l'ennemi : aucun recentrage s'il est déjà visible.
- **Si l'unité ne peut pas bouger du tout dans une embuscade**: même résultat — l'ennemi est révélé et le déplacement est consommé (23).

### Zoom et bornes

- **Si un bouton de zoom est au maximum ou au minimum**: grisé ; un appui dessus est ignoré sans message (règle 5, formule 2).
- **Si un pincement dépasse [31 ; 62] pt**: `z` est tronqué à la borne, sans rebond.
- **Si le rectangle rétrécit ou grandit pendant un zoom** (insets, pliage ou dépliage, écran partagé, police système à 150 %): `tile_pt` ne change pas, car ses bornes sont absolues en pt ; seuls le centre (formule 6) et le focus (formule 7) sont recalculés.
- **Si l'écran passe de portrait à paysage (ou l'inverse) en partie**: contact abandonné. Le centre `c` (en tuiles) et `tile_pt` sont conservés, puis le clamp de la formule 6 s'applique avec la nouvelle marge M ; le centre peut bouger si la nouvelle plage l'exclut.
- **Si `W + 2M ≤ 2h` sur un axe** (10 × 10 au zoom minimal en portrait, axe vertical : 10 + 4 = 14 ≤ 14,84): la carte est centrée et verrouillée sur cet axe ; le défilement de cet axe est ignoré, les boutons de zoom restent actifs. Un appui hors carte est un fond vide (désélection). 16 × 16 ne se verrouille jamais.
- **Si le zoom maximal est appliqué sur W = 16** (992 pt): en double précision l'erreur reste de l'ordre de 1e-13 pt. Le `Vector2` d'une build standard est en simple précision (NOT SOURCEABLE ici) : l'erreur y reste inférieure à environ 1e-4 pt, sous `ZOOM_EPS_MICRO`. Un bord exact va à la tuile suivante, sans effet de jeu.

### Recentrage

- **Si un recentrage est demandé pendant un recentrage en cours**: l'animation repart de la position actuelle vers la nouvelle cible. **Si le joueur défile ou pince pendant l'animation**: elle s'arrête sur place.
- **Si plusieurs puces d'alerte sont appuyées rapidement**: la dernière gagne ; le curseur de cycle de la puce de menace avance à chaque appui, même si l'animation n'est pas finie.
- **Si la cible est hors carte, ou si le nœud est perdu**: la cible est bornée par les formules 6 et 7. Si l'unité visée est détruite, la puce de perte vise sa dernière tuile connue. « Recentrer » sans unité du joueur vise le centre de la carte (W/2, H/2).
- **Si « Réduction des animations » est active**: recentrage, décalage de la règle 20c et zoom des boutons sont instantanés (choix).
- **Si l'option « Panneau à gauche » ou le paysage miroir change le côté de la grappe**: le contact est abandonné, la grappe change de côté, le centre est inchangé. Une unité sous la grappe est atteinte par défilement (marge de la règle 18), car la règle 20c ignore la grappe.

### Pause, reprise, accessibilité

- **Si une pause, une perte de focus ou un appel survient pendant un geste**: mode SUSPENDU, contact abandonné. À la reprise, le mode précédent revient et un doigt encore posé est ignoré jusqu'au relevé.
- **Si la partie est reprise après un arrêt (ÉTAT_CHARGÉ)**: aucune caméra n'est sauvegardée (16). Zoom par défaut de la formule 1, centre sur l'unité du joueur d'identifiant le plus bas — ou sur le centre de la carte s'il n'en a aucune —, mode REPOS, aucune sélection.
- **Si un lecteur d'écran (TalkBack, VoiceOver) est actif**: NOT SOURCEABLE (`design/accessibility-requirements.md` : prise en charge par le moteur non vérifiée, carte au niveau « Exemplary » seulement). Repli sûr : le jeu ne promet aucun geste de carte avec un lecteur d'écran ; les boutons de la grappe et des puces, nommés et activables par le lecteur, restent le seul accès garanti.

### Cas à traiter dans d'autres documents

- **23**: étendre la règle d'embuscade à l'eau et aux obstacles jamais vus (la validation se fait d'après la vue du joueur ; l'unité s'arrête avant) ; ne refuser une tuile jamais vue que pour la distance (`HORS_DE_PORTÉE`) ; inscrire que la validation par tuile (règle 8) ne divulgue rien par le point de portée.
- **5**: définir « jamais vue » contre « vue puis cachée » (code de refus et point de portée de chacune), et si une attaque suit une embuscade.
- **17 / `hud.md`**: fournir un rectangle minimal garanti (police à 150 %, écran partagé) ; figer 358 / 350 / 336 pt ; corriger « 34 pt » en 36,33 ; ajouter les boutons de la grappe et « Annuler le déplacement » ; prévoir un contrôle « unité suivante » pour le lecteur d'écran ; la grappe n'entre pas dans le rectangle de focus.
- **16**: consigner que la caméra n'est pas sauvegardée, avec le repli de l'identifiant le plus bas.
- **ADR**: accumulation des événements d'entrée, annulation des contacts par le système, précision de `Vector2`, mode d'étirement.

## Dependencies

### En amont (ce système dépend de)

| Système | Nature | Dure ou souple |
|---|---|---|
| 2 Carte en tuiles et terrain | Requêtes de tuile et de voisins, taille W × H (`design/gdd/carte-tuiles-terrain.md`) | Dure |
| 23 Commandes et événements | Seul chemin pour agir ; validation sans application pour la portée et les boutons grisés ; événements écoutés (`design/gdd/commandes-evenements.md`) | Dure |
| 5 Brouillard et vision (pas de GDD) | Distinction vu / non vu, sans information cachée | Dure, **contrat provisoire** |
| 17 HUD (seul `design/ux/hud.md` existe) | Rectangle de carte, puces d'alerte, panneaux qui verrouillent les modes | Dure, **contrat provisoire** |

### En aval (systèmes qui dépendent de lui)

| Système | Ce qu'il utilise | Dure ou souple |
|---|---|---|
| 17 HUD | Mode d'interaction, unité sélectionnée, demandes de recentrage, état des boutons de la grappe | Dure |
| 6 Unités, 8 Combat, 11 Nœuds, 12 Protocoles, 7 Réveil | Rien directement : leurs commandes passent par 23. Ils n'appellent pas 4 | — |

### Bidirectionnalité

- `design/gdd/carte-tuiles-terrain.md` et `design/gdd/commandes-evenements.md` citent déjà ce système.
- `design/ux/hud.md` doit citer ce document (grappe de boutons, « Annuler le déplacement », rectangle de carte, correction de « 34 pt »).
- Les GDD 5 et 17 doivent le citer à leur création ; le GDD 16 doit consigner que la caméra n'est pas sauvegardée.

### Décisions techniques renvoyées à un ADR

- Événements d'entrée tactiles de Godot, annulation des contacts, accumulation des événements (NOT SOURCEABLE, voir Edge Cases).
- Nœud de caméra et projection (orthographique ou perspective), prise de la tuile sous le doigt.
- Mode d'étirement du projet et conversion du point en pixels.

## Tuning Knobs

*Entiers seulement dans les fichiers de données (ADR-0009) : les facteurs sont en millièmes (`_MILLI`) ou millionièmes (`_MICRO`) et divisés au chargement ; ces calculs de caméra sont de la présentation, non des règles de jeu. Renommés le 2026-10-31 (GDD SYNC avec ADR-0009).*

*Dans un fichier de données (`assets/data/`), sauf la tuile minimale, qui est un plancher
d'accessibilité et non un réglage. Valeurs de départ, à jouer sur appareil.*

| Paramètre | Valeur | Plage sûre | Trop haut | Trop bas | Interagit avec |
|---|---|---|---|---|---|
| `TAP_SLOP_MILLI` | 500 (0,5 tuile) | 300..700 | Un léger défilement est lu comme un appui : ordres non voulus | Un doigt qui tremble défile au lieu de viser | Formule 4 ; taille de tuile ; accessibilité (tolérance au glissement) |
| `ZOOM_MIN_TILE_PT` | 31 pt (plancher) | Non réglable | — | Tuiles trop petites pour le pouce (`accessibility-requirements.md`) | Colonnes par défaut (`hud.md`) |
| `ZOOM_MAX_MILLI` | 2000 (2×) | 1500..3000 | Tuiles énormes, très peu de carte visible | Le zoom n'aide presque plus les mains peu précises | Formules 1, 2 et 6 |
| `ZOOM_STEP_MILLI` | 1260 (2^(1/3) ≈ 1,26) | 1150..1500 | Peu de pas, zoom brutal | Beaucoup d'appuis pour parcourir la plage | Formule 2 |
| `EDGE_MARGIN_TILES` | 2 | 2..3 | La carte se perd, on voit du vide | Sous 2 : une tuile de coin reste sous la grappe (48 / 31 ≈ 1,55 tuile au zoom minimal) | Formule 6 ; grappe de boutons |
| `FOCUS_CLEARANCE_MILLI` | 500 (0,5 tuile) | 0..1000 | La caméra bouge pour un focus déjà visible | Une tuile de focus peut être coupée par le bord | Formule 7 ; règle 20c |
| `RECENTER_MS` | 250 ms | 150..300 | Lent, gêne la lecture | Saut brusque, désorientant | Animations réduites (instantané) |
| `cols_default` | 8 portrait / 12 paysage | 6..10 / 10..14 (`hud.md`) | Tuiles plus petites | Tuiles plus grandes, moins de carte | Formule 1 — valeur possédée par le HUD |
| `ZOOM_EPS_MICRO` | 1000 (0,001) | 100..10000 | Zoom rendu trop tôt | Battement aux bornes (flottants) | Formule 2 |

*Constante de règle, non réglable : une seule commande par image (Edge Cases).*

## Visual/Audio Requirements

*Système `Core` : section facultative, courte. Le rendu des repères est possédé par l'art
bible (section 7) ; `art-director` n'est pas reconsulté ici, la bible étant déjà approuvée
(REVISED 2026-10-30).*

- **Visuel.** Les repères de ce système sont posés sur les tuiles et suivent le zoom
  (art bible, section 7) : hexagone blanc de sélection, point blanc de portée, crochets blancs
  de cible, tous à contour sombre de 1 pt ; le blanc se distingue par la forme, jamais par la
  teinte. La grappe de boutons reprend le style de l'interface (aplats sombres, icônes de 24 pt
  à trait de 2 pt, texte à 4,5:1) et ne porte aucune teinte de faction.
- **Pas de son qui porte une information.** Aucune information de jeu ne passe par un son
  (`design/accessibility-requirements.md`) : l'appui, le refus et le recentrage se lisent à
  l'écran. Un retour sonore ou haptique de confirmation est possible mais facultatif ; il
  n'est pas spécifié ici (à confier à `audio-director`, GDD 20).

## Game Feel

- **Obéissance exacte, pas de puissance** (Player Fantasy). Un appui net produit son effet
  sans attendre : le hexagone de sélection et le point de portée apparaissent dans la même
  image que le relâchement.
- **Délai d'entrée.** Cible : l'effet visible d'un appui en une image (≤ `T_FRAME` =
  33 ms, `design/registry/entities.yaml`). À mesurer sur appareil d'entrée de gamme.
- **Défilement 1:1 sans inertie** : la carte colle au doigt et s'arrête quand il se lève. La
  caméra s'arrête net à la bordure (pas de rebond).
- **Mouvements de caméra** : recentrage de 150 à 300 ms, ralenti en fin de course, sans
  rebond ni dépassement (art bible, « Animation ») ; instantané avec les animations réduites.
- **Une seule chose bouge à la fois** dans le HUD : un recentrage ne se superpose pas à
  l'ouverture d'un panneau, sauf pour la règle 20b (panneau de fragment).

## UI Requirements

- **Grappe de boutons** (règle 15) : « + », « − », « Recentrer » ; 48 dp / 44 pt chacun, 8 dp
  d'écart au moins avec tout autre bouton (accessibilité, protection contre l'appui
  involontaire), dans un coin bas du rectangle de carte ; côté inversé par l'option « Panneau
  à gauche ». Les boutons de zoom se grisent aux bornes ; chacun porte un nom lisible par le
  lecteur d'écran.
- **« Annuler le déplacement »** (règle 12) : bouton du panneau d'unité, grisé avec sa raison
  (`RIEN_À_ANNULER`, `DÉPLACEMENT_A_RÉVÉLÉ`, `AUTRE_ACTION_DEPUIS`) ; à ajouter à
  `design/ux/hud.md`.
- **Rectangle de carte** : fourni par le HUD (17) ; il ne change de taille qu'aux états à
  commandes verrouillées. Largeur portrait à figer (358 / 350 / 336 pt).
- **Repères sur la carte** : sélection, portée, cible, menace, ruine, perte — déjà décrits
  dans `hud.md`, section 5 ; ce système fournit l'état qui les pilote (mode, sélection).
- **Réglages** : « Portée de déplacement » On/Off, « Panneau à gauche », « Réduction des
  animations » (`hud.md`, 10.5). Aucun réglage de sensibilité du glissement n'est prévu au
  lancement (voir Open Questions).

> **📌 UX Flag — Contrôles tactiles et caméra de carte** : ce système a des exigences
> d'interface (grappe de boutons, « Annuler le déplacement », rectangle de carte). En phase 4
> (pré-production), lancer `/ux-design` pour la grappe et pour les modifications de `hud.md`
> **avant** d'écrire les épopées.

## Cross-References

| Ce document cite | Document | Élément précis | Nature |
|---|---|---|---|
| Taille maximale de la carte | `design/gdd/modele-etat-partie.md` | `MAX_MAP_SIZE` = 16 | Valeur |
| Requêtes de tuile, taille W × H, rencontre dans le brouillard | `design/gdd/carte-tuiles-terrain.md` | Règle 6 (embuscade), requêtes de voisins | Règle |
| Commandes DÉPLACER, ATTAQUER, ANNULER_LE_DÉPLACEMENT, FINIR_LE_TOUR ; validation sans application ; codes de refus ; annulation du dernier déplacement | `design/gdd/commandes-evenements.md` | Règles 6, 7, 10, 11, 15, 17 | Règle |
| Caméra non sauvegardée | `design/gdd/sauvegarde-automatique.md` | Contenu de la sauvegarde | Règle |
| Tuile ≥ 31 pt ; zoom jusqu'à 2× ; colonnes par défaut ; seuil d'une demi-tuile ; aucun geste à deux doigts obligatoire | `design/ux/hud.md`, `design/accessibility-requirements.md` | Tuning Knobs ; Motor | Valeur, règle |
| Repères blancs, animation de 150 à 300 ms, grappe à contour sombre | `design/art/art-bible.md` | Sections 7 et 8 | Style |
| Pilier 3 « Lisible comme Polytopia », pilier 4 | `design/gdd/game-concept.md` | Game Pillars | Intention |

## Acceptance Criteria

*Preuves : **Logic** = test unitaire automatisé sur fonctions pures, dans
`tests/unit/camera-controles/` (BLOQUANT) ; **Intégration** = test d'intégration ou playtest
documenté (BLOQUANT) ; **UI** = capture conservée dans `production/qa/evidence/`
(BLOQUANT) ; **Appareil** = test manuel sur un vrai téléphone Android. Le comportement
tactile de Godot n'est pas couvert par `docs/engine-reference/` (NOT SOURCEABLE) : les
critères Appareil se jouent au prototype. Les vecteurs de test supposent un rectangle de
carte de 350 × 460 pt en portrait (question ouverte).*

### Règles

- **AC-C1** (Intégration, règle 1) **GIVEN** un contact posé sur la carte, **WHEN** le doigt est encore posé ou glisse, **THEN** zéro commande n'est émise avant le relâchement ; un appui sur un panneau du HUD ne produit aucun appui sur la carte.
- **AC-C2** (Logic, règle 2, formule 4) **GIVEN** `slop_px` = 65,6, **WHEN** le relâchement a lieu à `dist` = 65,6 puis 65,7, **THEN** le premier cas est un APPUI et le second un DÉFILEMENT ; **GIVEN** un contact devenu défilement, **WHEN** le doigt revient à 0 px de la pose, **THEN** il reste un défilement.
- **AC-C3** (Logic + Appareil, règle 3) **GIVEN** un contact débuté sur une unité, **WHEN** il glisse de 3 tuiles, **THEN** le centre de la caméra bouge de 3 tuiles à ±0,01, sans inertie après le relâchement, et l'unité reste sur sa tuile.
- **AC-C4** (Appareil, règle 4) **GIVEN** un pincement actif, **WHEN** un doigt se lève, **THEN** le zoom s'arrête et le doigt restant ne fait pas défiler la carte avant d'avoir été relevé ; **WHEN** un second doigt se pose pendant un appui possible, **THEN** zéro commande.
- **AC-C5** (Logic + UI, règle 5) **GIVEN** `z` = 1 ou `z` = 2, **WHEN** on appuie sur « − » ou « + » respectivement, **THEN** le bouton est grisé, visible, et l'appui est ignoré sans message ; une capture montre les deux états grisés ; zone tactile mesurée ≥ 48 dp.
- **AC-C6** (Intégration, règle 6) **GIVEN** une unité sélectionnée, **WHEN** deux appuis rapprochés tombent sur deux tuiles, **THEN** ce sont deux appuis indépendants ; un double appui, un appui long et un glisser-déposer n'ont aucun effet (3 scénarios scriptés, zéro commande hors appui net).
- **AC-C7** (Appareil, règle 7) **GIVEN** un contact en cours, **WHEN** un geste système, un appel ou une pause l'interrompt, **THEN** ni appui ni défilement (voir « Bloqués » pour l'annulation côté Godot).
- **AC-C8** (Intégration, règle 8) **GIVEN** une unité sélectionnée, **WHEN** la portée s'affiche, **THEN** l'ensemble des tuiles marquées est identique, tuile par tuile, aux validations DÉPLACER « sans appliquer » de 23, et aucune écriture n'a lieu dans l'état.
- **AC-C9** (Intégration, tableau B) **GIVEN** chaque mode (repos, sélection, ciblage, verrouillé) et chaque cible du tableau B, **WHEN** on appuie, **THEN** le résultat correspond à la cellule du tableau : 28 cas, dont 3 cellules « E » qui émettent une commande, le reste sans commande.
- **AC-C10** (Intégration, règle 9) **GIVEN** le ciblage, **WHEN** on défile ou zoome, **THEN** le mode reste CIBLAGE et aucune commande n'est émise.
- **AC-C11** (Intégration, règle 10 — test de la Player Fantasy) **GIVEN** un drone sélectionné et une tuile de portée voisine, **WHEN** un glissement scripté de 0,6 tuile part de ce drone, **THEN** zéro commande est émise ; idem pour un pincement scripté et pour un contact interrompu.
- **AC-C12** (Intégration + UI, règles 8 et 11) **GIVEN** une tuile jamais vue — eau, vide, ou ennemi caché — dans la portée en distance, **WHEN** DÉPLACER est appliqué, **THEN** le point de portée est identique dans les trois cas, l'unité avance, s'arrête avant l'eau ou l'ennemi, et aucun code `CASE_BLOQUÉE` n'est jamais affiché ; **GIVEN** une tuile jamais vue hors de portée en distance, **THEN** le refus est `HORS_DE_PORTÉE` dans les trois cas ; une capture par cas.
- **AC-C13** (Intégration + UI, règle 12) **GIVEN** un déplacement qui a révélé quelque chose, **WHEN** on ouvre le panneau d'unité, **THEN** « Annuler le déplacement » est grisé avec `DÉPLACEMENT_A_RÉVÉLÉ` (une capture par raison, `RIEN_À_ANNULER` et `AUTRE_ACTION_DEPUIS` comprises) ; **WHEN** DÉPLACEMENT_ANNULÉ survient, **THEN** l'unité est resélectionnée et visible.
- **AC-C14** (Logic, règle 13) **GIVEN** `c`, `rc` et une tuile de 36,33 pt, **WHEN** on convertit tuile → écran → tuile, **THEN** le résultat est l'identité à 1e-6.
- **AC-C15** (UI + Appareil, règle 14) **GIVEN** le tour du joueur, **WHEN** on passe de « unité sélectionnée » à « Fin du tour » seul, **THEN** la taille du rectangle de carte reste identique ; captures portrait et paysage.
- **AC-C16** (UI + Appareil, règle 15) **GIVEN** la grappe visible, **WHEN** on défile au maximum, au zoom minimal, **THEN** toute tuile de la carte peut être sortie de dessous la grappe, y compris sur une carte qui tient entière ; captures portrait et paysage.
- **AC-C17** (Logic + UI, règle 16) **GIVEN** `z` = 1, **WHEN** on mesure sur appareil, **THEN** une tuile mesure ≥ 31 pt et la carte 12 × 12 en portrait ne tient jamais entière (372 > 358).
- **AC-C18** (Appareil, règle 17) **GIVEN** deux appareils de densités différentes, **WHEN** on mesure le seuil d'appui en pt, **THEN** il vaut 15,5 à 31 pt sur les deux.
- **AC-C19** (Logic, règle 18) voir AC-C26.
- **AC-C20** (Intégration + Appareil, règles 19 et 20) **GIVEN** chacun des déclencheurs (a) à (e) de la règle 20, **WHEN** il se produit, **THEN** la caméra atteint sa cible en `RECENTER_MS` ± 1 image, sans changer zoom, sélection ni mode ; (a) trois appuis sur la puce de menace cyclent sur trois cibles ; (c) un focus déjà visible ne bouge pas ; (d) la caméra revient à l'état de FINIR_LE_TOUR ; (e) cascade : sélection, dernière sélection, identifiant le plus bas.

### Formules (vecteurs de test, tous Logic)

- **AC-C21** (formule 1) `tile_default` : rw = 350, cols = 8 donne 43,75 ; rw = 436, cols = 12 donne 36,33 ; 14 colonnes sur un rectangle étroit donnent exactement 31 et jamais moins.
- **AC-C22** (formule 2) De 31 avec S = 2^(1/3), trois « + » donnent 39,06 → 49,21 → 62 (±0,01) ; depuis 43,75 : 55,12 puis 62 ; trois « − » depuis 62 reviennent à 31 ; pincement : `z0` = 1,2 et `d/d0` = 3 donne `z'` = 2.
- **AC-C23** (formule 3) Paysage c = (6, 6), tuile 36,33, 100 pt à droite et 50 pt au-dessus de `rc` : tuile (8, 4). Portrait c = (2, 6), 200 pt à gauche : w.x = −2,571, x = −3, fond vide. w.x = −0,3 donne la tuile −1 (et non 0 comme `int()`) ; un bord exact va à la tuile suivante.
- **AC-C24** (formule 4) Densité 3, portrait par défaut : tile_px = 131,25 ; slop = 65,6 px (21,9 pt) ; bornes 15,5 pt à `z` = 1 et 31 pt à `z` = 2.
- **AC-C25** (formule 5) c = (4, 6), `a` à 100 pt de `rc`, tuile 43,75 → 54,69 : c'.x = 4,457 (±0,001) ; le point du monde sous `a` est conservé (6,2857 avant et après) ; avec `a = rc`, c' = c ; si le clamp agit, il l'emporte.
- **AC-C26** (formule 6) Les sept lignes du tableau à ±0,001, dont : 12×12 portrait par défaut x [2,0 ; 10,0], y [3,257 ; 8,743] ; zoom minimal y [5,419 ; 6,581] ; paysage par défaut x [4,0 ; 8,0], y [3,037 ; 8,963] ; 10×10 portrait au zoom minimal cy = 5 verrouillé ; 16×16 portrait au zoom minimal y [5,419 ; 12,581]. Continuité : un intervalle réduit à un point (`W + 2M = 2h`) donne exactement W/2, sans battement.
- **AC-C27** (formule 7) Portrait c = (6, 6), focus (10, 2) : cx = 7,5, cy inchangé. Paysage, focus (3, 11) : cy = 7,463, cx = 6 inchangé. Focus déjà dans la fenêtre : c' = c exactement.
- **AC-C28** (formule 8) Portrait 12×12 : défaut 8,0 × 10,51 ; minimal 11,29 × 14,84 ; maximal 5,65 × 7,42. Paysage : défaut 12,0 × 10,07 ; minimal 14,06 × 11,81.

### Transverses

- **AC-C29** (Intégration, une commande par image) **GIVEN** deux appuis relâchés dans la même image, **WHEN** ils sont traités, **THEN** une seule commande est émise, le second appui est jeté et aucun refus n'est affiché.
- **AC-C30** (Intégration, ÉTAT_CHARGÉ) **GIVEN** une sauvegarde puis un rechargement après un zoom et un défilement, **THEN** le zoom est celui de la formule 1, le centre est sur l'unité d'identifiant le plus bas (ou W/2, H/2 sans unité), le mode est REPOS, aucune unité n'est sélectionnée, et le fichier de sauvegarde ne contient ni centre ni zoom.
- **AC-C31** (Appareil) **GIVEN** une partie de 30 tours, **WHEN** elle est jouée sans jamais pincer ni utiliser deux doigts, **THEN** elle se termine sans point bloquant.
- **AC-C32** (Appareil, performance) **GIVEN** un Android d'entrée de gamme, **WHEN** on défile et zoome en continu 60 s sur une carte 16 × 16, **THEN** la cadence reste ≥ 30 images par seconde (relevé du profileur conservé). *Aucun budget de mémoire n'existe dans les documents : critère non défini, à fixer avant l'ouverture.*
- **AC-C33** (UI + Intégration) **GIVEN** « Réduction des animations » active, **WHEN** on recentre, applique un décalage de la règle 20c ou appuie sur un bouton de zoom, **THEN** le changement est instantané, sans image intermédiaire.
- **AC-C34** (UI + Appareil) **GIVEN** le paysage miroir ou « Panneau à gauche », **THEN** la grappe passe du côté opposé au pouce sans chevaucher le rail ni sortir des insets ; le contact en cours est abandonné et le centre reste inchangé ; captures conservées.

### Bloqués jusqu'à un prototype sur appareil (NOT SOURCEABLE)

- AC-C7 : annulation d'un contact par le système (repli : nouvelle pose du même index de doigt).
- Fusion des événements d'entrée : un aller-retour au-delà de la demi-tuile peut être manqué.
- AC-C18 et AC-C24 : mode d'étirement et densité réelle (`px_per_pt`).
- Précision de `Vector2` en simple précision (erreur attendue < 1e-4 pt, à comparer à `ZOOM_EPS_MICRO`).
- Lecteur d'écran (TalkBack, VoiceOver) : aucun critère écrit.
- AC-C32 : budget de mémoire inexistant.
- Choix du nœud de caméra (projection) : conditionne la lecture « tuile sous le doigt ».

### Règles sans condition testable chiffrée

Règle 17 (renvoyée à un ADR), règle 20b (aucun seuil chiffré pour « ruine hors du rectangle
réduit ») et tolérance de mesure de `RECENTER_MS`. Elles se testent par un playtest documenté
tant qu'un seuil n'est pas fixé.

## Open Questions

| Question | Propriétaire | À résoudre avant | Résolution |
|---|---|---|---|
| Largeur du rectangle de carte en portrait : 358, 350 ou 336 pt ? Elle fixe la tuile par défaut (43,75 ou 44,75 pt). | ux-designer | `/ux-review` de `hud.md` | |
| Le joueur connaît-il le terrain sous le brouillard ? Distinguer « jamais vue » et « vue puis cachée » pour le code de refus et le point de portée. | game-designer (GDD 5) | GDD 5 | |
| Un appui sur une unité ennemie visible en REPOS affiche-t-il une fiche ? `hud.md` n'en décrit aucune. | ux-designer | `/ux-design hud` | Provisoire : aucun effet |
| Peut-on déplacer une seconde fois une unité après un déplacement ? (les points de mouvement sont à 6) | game-designer (GDD 6) | GDD 6 | |
| La portée s'affiche-t-elle à la sélection ou après « Déplacer » ? Si le réglage « Portée de déplacement » est Off, un appui sur une tuile atteignable déplace-t-il quand même ? | ux-designer | `/ux-design hud` | Provisoire : oui, la validation de 23 décide |
| Faut-il plafonner le seuil d'une demi-tuile en pt à zoom maximal (31 pt) ? | ux-designer | Test sur appareil | |
| Caméra orthographique ou perspective ? Détermine l'exactitude de « tuile ≥ 31 pt ». | technical-director | ADR (rendu et caméra) | |
| Un réglage de sensibilité du glissement pour les mains peu précises ? | accessibility-specialist | Test d'utilisateurs | Non prévu au lancement |
| Retour sonore ou haptique d'un appui, d'un refus et d'un recentrage. | audio-director | GDD 20 | |
| Navigation de la carte avec TalkBack ou VoiceOver (unité suivante, tuile par tuile). | accessibility-specialist | Vérification du moteur | NOT SOURCEABLE |
| Reporter dans 23 : `HORS_DE_PORTÉE` unique pour une tuile jamais vue (refus de distance seulement) et l'extension de la règle d'embuscade à l'eau jamais vue. | game-designer | Revue de 23 | |
| Garantir qu'une embuscade ou un obstacle découvert dans le brouillard n'inflige jamais de perte non annoncée (pilier 4). | game-designer | GDD 5 et 6 | |
| Mesurer sur appareil le taux de mauvais appuis sur 31 pt dans le brouillard ; si trop élevé, rouvrir le choix « un appui » pour les tuiles jamais vues. | qa-lead | Test d'utilisateurs | |
| Corriger `hud.md` : « 34 pt » en 36,33 ; remplacer « boutons +/− ou double appui » par les boutons (ligne des colonnes de carte) ; ajouter la grappe et « Annuler le déplacement ». | ux-designer | `/ux-design hud` | |
