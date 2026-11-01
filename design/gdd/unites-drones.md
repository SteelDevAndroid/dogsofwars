# Unités drones

> **Status**: Designed (pending /design-review)
> **Author**: user + Claude (game-designer, systems-designer, art-director)
> **Last Updated**: 2026-10-30
> **Last Verified**: 2026-10-30
> **Implements Pillar**: Pilier 3 « Lisible comme Polytopia » (une unité s'explique en une phrase) ; pilier 1 « La meute se voit grandir » ; pilier 4 « La puissance se mérite »
> **Creative Director Review (CD-GDD-ALIGN)**: REVISED 2026-10-30 — CONCERNS (promesse « une action qu'aucun autre n'a » ; capture du Bastion non annoncée contre le pilier 4 ; périmètre de 7 types contre le MVP ; Gardiens absents du concept ; dormants cachés contre le pilier 5 ; Ouvrier point de défaillance unique) corrigées : promesse reformulée en « un rôle », capture de l'IA annoncée comme intention, périmètre et Gardiens inscrits dans le concept, dormants visibles sous le brouillard, mise en place renforcée

## Summary

Les unités drones sont les pièces que le joueur et l'IA déplacent : quatre types pour la meute
(Éclaireur, Assaut, Rempart, Ouvrier) et trois pour les Gardiens de l'IA (Sentinelle, Chasseur,
Bastion), chacun avec ses points de vie, son attaque, sa défense, son mouvement et une phrase
qui l'explique. Une unité se déplace puis agit une fois, ce qui la termine, et se répare au
repos ; la meute grandit en réveillant des drones endormis. Ce système existe pour que chaque
pièce se lise d'un coup d'œil et ait un métier (pilier 3), et pour que la croissance de la
meute se voie sur la carte (pilier 1).

> **Quick reference** — Layer: `Feature` · Priority: `MVP` · Key deps: `Modèle d'état de partie, Carte en tuiles et terrain`

## Overview

Les unités drones sont les pièces que le joueur et l'IA déplacent sur la carte. Ce système
définit les **types** (quatre pour la meute au MVP, un ensemble distinct pour les Gardiens),
leurs **statistiques** (PV, ATQ, DÉF, MVT), ce qu'une unité peut faire dans un tour (se
déplacer, puis agir une fois, ce qui la termine), la façon dont une unité blessée se
**répare au repos**, et la **phrase** qui explique chaque type (pilier 3). Il possède la
tranche « Unités » de l'état de partie (`design/gdd/modele-etat-partie.md`) : type,
faction, position, PV, a bougé, a agi, endormie, avec 60 unités au plus (`MAX_UNITS`) et
une seule par tuile. Il en est le **seul écrivain** : le combat (8) calcule les dégâts mais
passe par sa fonction « modifier les PV » ; le réveil (7) passe par sa fonction
« réveiller » ; les commandes (23) valident les déplacements avec ses points de mouvement.

Au MVP, les drones **s'obtiennent seulement en réveillant des drones endormis** : la meute
grandit en explorant (pilier 1) et il n'y a pas de production aux nœuds, réservée à l'Alpha
(la borne de 60 unités l'autorise déjà). Le joueur agit sur une unité à la fois, par des
commandes ; l'IA joue les siennes exactement de la même façon.

*Cadrage : à la fois la couche de données (tranche de l'état, fonctions d'écriture) et son
effet pour le joueur (ce que chaque pièce sait faire). Aucun ADR n'existe encore sur les
unités.*

## Player Fantasy

*Cadrage : direct. Retenu (`creative-director`, 2026-10-30) : « La réponse qu'elle attendait »
pour l'identité, « Chaque pièce a un métier » pour la texture de chaque tour.*

**La réponse qu'elle attendait.** On touche un drone endormi : son socle se lève, la teinte
monte jusqu'au trait, l'œil s'allume en dernier. La niche de commande, vide depuis le départ
des humains, se remplit : le joueur est l'ordre que la machine attendait. Chaque réveil se
voit sur la carte (pilier 1), et cela prépare la ligne narrative : obéir à un ordre que plus
personne ne donne, jusqu'au jour où l'on comprend que c'est soi qui le donne.

**Chaque pièce a un métier.** Un Rempart à carapace tient une crête boisée pendant que
l'Éclaireur à mât lève le brouillard derrière lui. Le plaisir vient du placement : chaque
type se lit d'un coup d'œil et s'explique en une phrase (pilier 3), et avec une seule
action par unité et par tour, chaque choix compte.

**Ton.** Sobre, mécanique, sans sentimentalité ; les verbes sont ceux de l'ordre et de la
tenue — réveiller, tenir, répondre, éclairer. Pas de prénoms, pas de personnalité affichée :
le récit passe par la pose, la niche vide et le capteur tourné vers le dernier ordre
(pilier 2), jamais par du texte.

**Trois échecs à éviter.**
1. *Des jetons interchangeables* : chaque type a un rôle qu'aucun autre ne joue aussi bien
   (vision, assaut, tenue, capture), lisible dans ses chiffres et sa phrase.
2. *Pleurer une unité que les règles n'ont pas laissé protéger* : toute perte annoncée est
   évitable (pilier 4) ; elle doit se lire « je n'ai pas lu l'intention », jamais comme
   une cruauté du système. Aucun dégât sur le modèle, seulement la jauge blanche : la
   machine reste intacte, et c'est le gris qui dit la perte.
3. *L'attachement par la personnalisation* : c'est un anti-pilier. L'attachement vient du
   réveil, pas d'un réglage.

## Detailed Design

*Décisions du 2026-10-30 : quatre types de meute (Éclaireur, Assaut, Rempart, Ouvrier) ; trois
types de Gardiens (Sentinelle, Chasseur, Bastion) ; les drones ne s'obtiennent que par le
réveil ; déplacer puis agir, et agir termine l'unité ; soin au repos ; tout type éveillé
peut réveiller, l'Ouvrier seul capture ; seule la meute réveille. Toutes les valeurs chiffrées
sont des **valeurs de départ [PROP]**, à jouer en test (voir Tuning Knobs).*

### Core Rules

1. **Tranche et propriété.** Ce système est le seul écrivain de la tranche Unités :
   identifiant, type, faction, tuile, PV, a bougé, a agi, endormie. PV_max, ATQ, DÉF, MVT,
   portée et vision se lisent dans un fichier de données par type (`assets/data/units.*`),
   jamais dans l'état. Les identifiants sont croissants et jamais réutilisés ; au plus 60
   unités (`MAX_UNITS`), dormantes comprises ; une unité par tuile ; toute itération se fait
   par identifiant croissant ; tout est en entiers.
2. **Quatre types de meute.** Un trait par type (`design/art/art-bible.md`, section 5).

   | Type (trait) | PV | ATQ | DÉF | MVT | Portée | Vision (5) |
   |---|---|---|---|---|---|---|
   | Éclaireur (mât) | 6 | 1 | 0 | 4 | 1 | 4 |
   | Assaut (lame) | 8 | 3 | 1 | 3 | 1 | 2 |
   | Rempart (carapace) | 14 | 1 | 2 | 2 | 1 | 2 |
   | Ouvrier (fourche) | 7 | 1 | 0 | 3 | 1 | 2 |

   Le sens de ATQ et de DÉF, et le calcul des dégâts, appartiennent au combat (8). La vision
   est possédée par le brouillard (5) ; la valeur est proposée ici. Le coût de réveil
   appartient à 7 et 10. **Le rôle unique de chaque type :** l'Éclaireur voit le plus loin
   (4 contre 2) ; l'Assaut frappe le plus fort ; le Rempart encaisse le plus (14 PV, DÉF 2) ;
   l'Ouvrier est le seul de la meute à **capturer** les nœuds. Phrase du joueur (90 caractères au plus) :
   - Éclaireur : « Rapide et clairvoyant : il découvre la carte, mais se bat mal. »
   - Assaut : « Frappe fort, encaisse peu : à lancer au contact pour abattre une cible. »
   - Rempart : « Lent et solide : il tient la ligne et encaisse les coups. »
   - Ouvrier : « Capture les nœuds ; faible au combat. »
3. **Trois types de Gardiens** (le camp de l'IA). Un Gardien appartient à la faction de l'IA ;
   un type de la meute n'appartient jamais à un Gardien, ni l'inverse. Ils obéissent aux règles
   1 à 12 comme la meute, sans exception d'état — sauf RÉVEILLER, que les Gardiens ne
   commandent pas (règle 8) — et leurs attaques ne sortent que des
   intentions annoncées (invariant du GDD 1). Les Gardiens sont placés par le fichier de carte
   et **ne grandissent pas** au MVP : ils ne réveillent rien.
   Ils sont l'apparence unique du camp de l'IA (ami et ennemi se distinguent d'un coup d'œil) ;
   leurs ruines et leurs fragments sont ceux de la faction qu'on affronte (`design/gdd/game-concept.md`,
   pilier 2).

   | Type (trait) | PV | ATQ | DÉF | MVT | Portée | Vision (5) |
   |---|---|---|---|---|---|---|
   | Sentinelle (Croc : deux pointes en V ouvert) | 10 | 0 | 2 | 0 | 1 | 3 |
   | Chasseur (Faille : deux ailerons en Λ renversé) | 8 | 3 | 0 | 3 | 1 | 3 |
   | Bastion (Crête : trois à quatre dents de scie sur le dos) | 14 | 2 | 2 | 1 | 1 | 2 |

   Phrase du joueur : Sentinelle : « Immobile et inoffensif : il garde sa tuile et surveille. »
   Chasseur : « Rapide et dangereux : il s'élance sur les drones isolés. » Bastion : « Lent et
   massif : il tient son terrain, capture les nœuds et frappe ce qui s'approche. » La Sentinelle ne bouge ni
   n'attaque jamais : sa vue nourrit l'IA et elle garde un point d'intérêt. Le **Bastion** est
   le seul Gardien qui capture. Le Lancier à distance 2 (trait Dard) est réservé à l'Alpha.
4. **Drapeaux de tour.**
   - « a bougé » passe à vrai quand DÉPLACER est appliquée, y compris si une embuscade arrête
     l'unité en route.
   - « a agi » passe à vrai quand ATTAQUER, CAPTURER ou RÉVEILLER est appliquée.
   - **Une unité qui agit est terminée** : plus de déplacement ni d'autre action. Un
     déplacement avant l'action est permis.
   - Les drapeaux d'une faction sont remis à faux au début de son tour
     (`design/gdd/tours-conditions-victoire.md`, §2). L'annulation du dernier déplacement (23)
     restaure les drapeaux depuis l'instantané. Recevoir un coup ou une riposte ne modifie
     jamais les drapeaux.
5. **Mouvement.** Un seul déplacement par tour, qui consomme les points de mouvement : PM_max =
   MVT ; PM_restants = MVT tant que « a bougé » est faux, sinon 0 ; aucun PM n'est stocké ; les
   PM non dépensés sont perdus (pas de second segment).
   - Le pas toujours possible de la carte (règle 5) s'écrit : « a bougé est faux ET la
     destination est voisine, franchissable et libre ».
   - Traverser une unité amie est **interdit** (valeur par défaut de la carte confirmée), et
     l'on ne s'arrête pas sur une tuile occupée ; la clé `allow_friendly_pass` reste dans les
     données, à faux.
   - Les autres règles de passage sont celles de la carte : eau, bord, unité visible bloquante,
     embuscade, pas de coupe de coin.
   - Une unité endormie ne se déplace pas ; une unité de MVT 0 (la Sentinelle) n'a jamais de
     pas : DÉPLACER est refusée pour elle.
6. **Soin au repos.** Une unité est « au repos » quand ses deux drapeaux étaient faux pendant
   son dernier tour. Le contrôle a lieu au début du tour de sa faction, **avant** la remise à
   zéro des drapeaux : c'est une étape de plus dans l'ordre de `tours` §2. Le soin est de
   `REST_HEAL` = 2 PV, plus `NODE_REST_BONUS` = 2 si la tuile est un nœud possédé par sa faction
   (propriétaire lu chez 11, indépendant du niveau du nœud). Il passe par « modifier les PV »,
   plafonné à PV_max. Une unité endormie ne se soigne pas ; une unité réveillée ce tour-là a
   les deux drapeaux à vrai (règle 8) et ne se soigne donc pas au tour suivant. **Une unité qui porte une
   intention d'attaque annoncée ne se soigne pas** (décision du 2026-10-30, gate du combat) : les
   dégâts d'une attaque annoncée ne dépendent ainsi pas d'un soin survenu entre l'annonce et l'exécution.
7. **Capturer.** Seuls l'**Ouvrier** (meute) et le **Bastion** (Gardiens) peuvent CAPTURER
   (décision du 2026-10-30 : sans cela l'IA ne pourrait jamais s'étendre) ; tout autre type est
   refusé avec `TYPE_NON_CAPABLE` (à ajouter à 23). L'unité doit être sur la tuile du nœud au
   moment de l'action (elle peut s'y déplacer d'abord) ; la règle de la capture est à 11. **Pour l'IA, une capture est annoncée comme une intention**
   (cible : le nœud) et exécutée au tour suivant, sinon le critère du pilier 4 (« un joueur
   attentif peut éviter toute perte annoncée ») ne tient pas : exigence pour 9, 11 et le format
   des intentions (1).
8. **Dormant et réveil.**
   - Un dormant est une unité de la tranche dès la mise en place, avec `endormie` vrai, aucune
     faction (neutre), des PV pleins et un type fixé par le fichier de carte. Il occupe sa tuile
     et bloque le passage comme une unité visible. Il ne se déplace pas, n'agit pas, n'est pas
     hostile : il ne peut être ni attaqué (`CIBLE_NON_HOSTILE`) ni blessé.
   - RÉVEILLER est permise pour une unité **éveillée de la meute, de n'importe quel type**,
     dont « a agi » est faux, avec un dormant à distance de Chebyshev 1. Un déplacement
     préalable est permis.
   - La fonction « réveiller » (6) écrit : `endormie` faux, faction = celle qui réveille,
     PV inchangés (pleins), type et tuile inchangés. L'unité réveillée prend « a bougé » et
     « a agi » à vrai (elle est prête au tour suivant) ; l'unité qui réveille prend « a agi ».
     Elle n'écrit pas l'énergie : 7 appelle `dépenser` (10). Événement : `DRONE_RÉVEILLÉ`.
   - Les Gardiens ne réveillent pas (le champ « J, IA » de la table de 23 vaut pour une IA qui
     jouerait une faction de la meute, hors MVP).
9. **Fonction « modifier les PV ».** `modifier_pv(état, id, delta, source)` rend
   `{pv_avant, pv_après, détruite}`. Le delta est un entier (négatif pour un dégât, positif pour
   un soin) ; le résultat est borné à [0, PV_max] ; un delta sans effet n'écrit rien ; l'appel est
   refusé pour une unité endormie ou inconnue. À 0 PV, la destruction a lieu dans le même appel
   (règle 10). Elle ne calcule jamais de dégâts (c'est le rôle de 8) et ne tire aucun hasard.
10. **Destruction.** L'unité est retirée de la tranche aussitôt : aucune dépouille n'est
    stockée ; son identifiant n'est jamais réattribué ; la tuile est libre. Le terrain, le
    propriétaire de tuile et les nœuds ne changent pas ; les débris sont purement visuels
    (`design/ux/hud.md`). Événement `UNITÉ_DÉTRUITE`. Le compteur « unités détruites » est écrit
    par 8 d'après `détruite`. 5 recalcule la vue ; 9 annule les intentions qui visaient
    l'unité (« cible détruite »). Une destruction survenue pendant une boucle sur les
    identifiants est appliquée après la boucle.
11. **Une seule action de soin visible.** Le soin émet l'événement `UNITÉ_SOIGNÉE` (à ajouter à
    23) : le HUD y lit la variation de la jauge, comme pour un dégât.
12. **Aucune personnalisation.** Les unités n'ont ni nom, ni niveau, ni équipement : deux
    unités du même type sont indiscernables hors position et PV (anti-pilier).

### States and Transitions

L'état d'une unité se **dérive** des drapeaux : il n'y a aucun champ « état » stocké de plus.

| État | Condition | Transitions valides |
|---|---|---|
| Endormie | `endormie` vrai | → Terminée (réveil, règle 8) |
| Éveillée prête | `endormie` faux, a bougé faux, a agi faux | → A bougé (DÉPLACER) ; → Terminée (action) ; → Détruite |
| A bougé | a bougé vrai, a agi faux | → Éveillée prête (ANNULER_LE_DÉPLACEMENT) ; → Terminée (action) ; → Détruite |
| Terminée | a agi vrai | → Éveillée prête (début du tour de sa faction) ; → Détruite |
| Détruite | PV = 0, retirée de la tranche | Aucune (l'identifiant est consommé) |

Une unité endormie ne passe jamais directement à Détruite.

### Interactions with Other Systems

| # | Système | Ce qui circule | Propriétaire de l'interface |
|---|---|---|---|
| 1 | État de partie | 6 écrit seul la tranche ; identifiant attribué par le compteur de l'en-tête ; `MAX_UNITS` | 1 pour la forme, 6 pour les écritures |
| 2 | Carte | Coûts, franchissabilité, classe de défense (2) ; MVT et plancher d'un pas (6) ; tuile et type des dormants lus dans le fichier de carte | 2 |
| 5 | Brouillard | 6 donne tuile, faction et type ; 5 possède la vision (valeurs proposées ci-dessus) | 5 |
| 7 | Réveil | 7 valide RÉVEILLER, appelle `dépenser` (10), puis « réveiller » (6) | 7 |
| 8 | Combat | Calcul pur et déterministe ; 8 appelle `modifier_pv`, lit la portée et met le compteur à jour | 6 pour l'écriture, 8 pour le calcul |
| 9 | IA | Mêmes commandes que le joueur ; annule ses intentions sur « cible détruite » ; ne voit que sa vue | 9 |
| 10 | Énergie | Aucun entretien au MVP ; seulement le coût de réveil, via 7 | 10 |
| 11 | Nœuds | CAPTURER exige un Ouvrier ; le propriétaire du nœud fonde le bonus de soin | 11 |
| 12 | Protocoles | Aucun type n'est débloqué au MVP ; les types viennent seulement du réveil | 12 |
| 23 | Commandes | Valide DÉPLACER avec PM et drapeaux ; rend la liste d'événements | 23 |
| 17 | HUD | Lit type, PV, ATQ, DÉF, MVT, phrase et état ; aucune écriture | 17 |

## Formulas

*Proposées par systems-designer. Les formules 1 à 4 et 6 sont des règles de jeu. La formule 5
est un contrôle de conception, pas une règle. Les nombres marqués [PROP] sont des réglages à
jouer en test (Tuning Knobs).*

### 1. Points de mouvement restants

The pm_restants formula is defined as:

`PM_restants = 0 si a_bougé, sinon MVT`
`pas_garanti = (¬a_bougé) ∧ (MVT ≥ 1) ∧ voisine_franchissable_libre(dest)`

**Variables:**

| Variable | Type | Range | Source | Description |
|---|---|---|---|---|
| MVT | int | 0..4 | data file (`units.*`) | Points de mouvement du type |
| a_bougé | bool | faux/vrai | calculated (tranche Unités) | Drapeau de tour (règle 4) |
| PM_restants | int | 0..4 | calculated | Jamais stocké (règle 5) |
| pas_garanti | bool | faux/vrai | calculated | Pas toujours possible (carte, règle 5), avec la garde `MVT ≥ 1` |

**Output Range:** PM_restants ∈ {0, MVT}, jamais négatif. La garde `MVT ≥ 1` est nécessaire : la
formule 2 de la carte (`PM_restants = PM_max`) est vraie pour MVT 0, puisque 0 = 0, et
autoriserait un pas à la Sentinelle, contre la règle 5.
**Example:** Rempart (MVT 2), a_bougé faux, montagne voisine libre (coût 3). Le chemin coûte
3 > 2, mais `pas_garanti` est vrai, donc DÉPLACER est permis. Ensuite a_bougé = vrai et
PM_restants = 0. La Sentinelle donne PM_restants = 0 et `pas_garanti` faux.

### 2. Modifier les PV

The modifier_pv formula is defined as:

`pv_après = clamp(pv_avant + delta, 0, PV_max)`
`détruite = (pv_après = 0) ∧ (pv_avant > 0)`

**Variables:**

| Variable | Type | Range | Source | Description |
|---|---|---|---|---|
| pv_avant | int | 1..14 | calculated | PV avant l'appel (une unité vivante a au moins 1 PV) |
| delta | int | −∞..+∞ | calculated (8 ou formule 3) | Négatif = dégât, positif = soin |
| PV_max | int | 6..14 | data file | PV du type |
| pv_après | int | 0..PV_max | calculated | Résultat borné |
| détruite | bool | faux/vrai | calculated | Déclenche la règle 10 |

**Output Range:** 0..PV_max. Si `pv_après = pv_avant`, rien n'est écrit et aucun événement n'est
émis (pas d'`UNITÉ_SOIGNÉE` pour un soin nul). Les dégâts effectifs valent `pv_avant − pv_après`.
**Example:** Éclaireur 4/6, delta −9 : pv_après = 0, détruite, dégâts effectifs 4. Assaut 3/8,
delta +2 : pv_après = 5.

### 3. Soin au repos

The rest_heal formula is defined as:

`soin = au_repos ? min(REST_HEAL + NODE_REST_BONUS × sur_nœud_possédé, PV_max − PV) : 0`

**Variables:**

| Variable | Type | Range | Source | Description |
|---|---|---|---|---|
| au_repos | bool | faux/vrai | calculated (formule 4) | Lu avant la remise à zéro des drapeaux |
| REST_HEAL | int | 1..3 | data file [PROP] (2) | Soin de base |
| NODE_REST_BONUS | int | 0..4 | data file [PROP] (2) | Bonus sur un nœud possédé par sa faction |
| sur_nœud_possédé | int | 0 ou 1 | calculated (propriétaire lu chez 11) | 1 si la tuile est un nœud de la faction au moment du soin |
| PV, PV_max | int | 1..14 | calculated / data file | PV courants et maximum |
| soin | int | 0..4 | calculated | Passé à `modifier_pv` comme delta |

**Output Range:** 0..REST_HEAL + NODE_REST_BONUS (4 au départ), jamais négatif car PV ≤ PV_max.
**Example:** Rempart 14/14 sur un nœud possédé : min(4, 0) = 0, rien d'écrit. Assaut 3/8 sur un
nœud possédé : min(4, 5) = 4, soit 7/8. Assaut 7/8 hors nœud : min(2, 1) = 1, soit 8/8.
Éclaireur 1/6 sur un nœud : min(4, 5) = 4, soit 5/6.

### 4. Au repos

The au_repos predicate is defined as:

`au_repos = (¬endormie) ∧ (¬a_bougé) ∧ (¬a_agi) ∧ (¬intention_annoncée)`, évalué au début du tour de la faction,
**avant** la remise à zéro (`tours-conditions-victoire.md`, §2).

**Variables:**

| Variable | Type | Range | Source | Description |
|---|---|---|---|---|
| endormie, a_bougé, a_agi | bool | faux/vrai | calculated | Drapeaux de la tranche, tels que laissés par le tour précédent |

**Output Range:** booléen. Les drapeaux d'une unité réveillée valent vrai/vrai : elle n'est pas au
repos à son premier tour. Une annulation de déplacement restaure a_bougé = faux : l'unité reste
« au repos ».
**Example:** Rempart ayant seulement reçu un coup : faux/faux, donc au repos. Assaut ayant
attaqué : a_agi vrai, donc pas de soin. Au tour 1 toutes les unités sont au repos mais déjà
pleines (soin 0).

### 5. Valeur de stat (contrôle de conception, PAS la formule de combat)

*Le combat appartient au système 8. Cette valeur ne sert qu'à comparer les types entre eux ;
aucun calcul de jeu ne la lit.*

The stat_value formula is defined as:

`valeur = PV + W_ATQ×ATQ + W_DÉF×DÉF + W_MVT×MVT + W_VIS×VIS`

**Variables:**

| Variable | Type | Range | Source | Description |
|---|---|---|---|---|
| PV, ATQ, DÉF, MVT, VIS | int | règles 2 et 3 | data file | Statistiques du type (la portée vaut 1 partout et est exclue) |
| W_ATQ, W_DÉF | int | 2..4 | constant [PROP] (3) | Poids de l'attaque et de la défense |
| W_MVT | int | 1..3 | constant [PROP] (2) | Poids du mouvement |
| W_VIS | int | 0..2 | constant [PROP] (1) | Poids de la vision |

**Output Range:** 18 à 30 pour les sept types.

| Type | PV | ATQ | DÉF | MVT | VIS | Valeur |
|---|---|---|---|---|---|---|
| Éclaireur | 6 | 1 | 0 | 4 | 4 | 21 |
| Assaut | 8 | 3 | 1 | 3 | 2 | 28 |
| Rempart | 14 | 1 | 2 | 2 | 2 | 29 |
| Ouvrier | 7 | 1 | 0 | 3 | 2 | 18 |
| Sentinelle | 10 | 0 | 2 | 0 | 3 | 19 |
| Chasseur | 8 | 3 | 0 | 3 | 3 | 26 |
| Bastion | 14 | 2 | 2 | 1 | 2 | 30 |

**Dominance** (composante par composante, indépendante des poids) : l'**Ouvrier est dominé par
l'Assaut** (8 > 7 PV, 3 > 1 ATQ, 1 > 0 DÉF, MVT et vision égaux). Seule la capture exclusive
(règle 7) le justifie ; c'est voulu et assumé, et l'on n'ajuste pas les poids pour le masquer.
Aucun autre type de meute n'est dominé ; aucun Gardien n'est dominé par un autre. Écart
max/min : 30 / 18 = 1,7.
**Example:** Assaut : 8 + 3×3 + 3×1 + 2×3 + 1×2 = 28.

### 6. Borne d'unités et réveil

The units_bound formula is defined as:

`total = N_meute + N_IA + N_dormantes ≤ MAX_UNITS`
`MEUTE_COMPLÈTE = (N_meute_éveillée ≥ MAX_UNITS)` pour une **création** ; un réveil ne crée pas d'unité.

**Variables:**

| Variable | Type | Range | Source | Description |
|---|---|---|---|---|
| MAX_UNITS | int | 20..60 | constant (GDD 1) | Borne, dormantes comprises |
| N_meute, N_IA, N_dormantes | int | 0..60 | calculated | Unités par faction ; les dormantes sont neutres et comptées dès la mise en place |

**Output Range:** `total` ∈ 0..60. Le réveil laisse `total` inchangé (il ne change que la faction
et `endormie`) : aucune condition liée à la borne ne peut se déclencher sur un réveil, donc
**`MEUTE_COMPLÈTE` est inatteignable au réveil** et ne vaut que pour une création (production,
Alpha). Au MVP, le contrôle utile est la validation de mise en place : `N_départs + N_dormantes ≤ 60`.
**Example:** carte 12 × 12 avec 6 dormantes : si chaque camp démarre à S unités, total = 2S + 6 ≤ 60,
donc S ≤ 27. Le réveil de la 6e dormante laisse total = 2S + 6.

## Edge Cases

*Proposés par systems-designer ; les résolutions du 2026-10-30 sont intégrées.*

- **Si DÉPLACER est appliquée et que l'embuscade se produit au premier pas** (aucune tuile libre avant l'ennemi caché): l'unité ne bouge pas, a_bougé = vrai, a_agi reste faux, l'ennemi est révélé, l'instantané d'annulation est supprimé (motif « révélé »). Conforme à 23 (règle 6). L'unité peut encore attaquer l'ennemi révélé (décision d'expérience à confirmer). `UNITÉ_DÉPLACÉE` n'est pas émise quand départ = arrivée ; `TUILES_RÉVÉLÉES` l'est.
- **Si ANNULER_LE_DÉPLACEMENT est permise**: l'état revient à l'instantané, a_bougé = faux et a_agi = faux : l'unité est de nouveau prête et « au repos ». Une annulation après une embuscade est refusée (`DÉPLACEMENT_A_RÉVÉLÉ`).
- **Si une unité de MVT 0 (Sentinelle) reçoit DÉPLACER**: refusée avec `UNITÉ_IMMOBILE` (code à ajouter à 23). La garde `MVT ≥ 1` de la formule 1 bloque le pas garanti.
- **Si un Ouvrier ou un Bastion demande CAPTURER après s'être déplacé sur le nœud**: permise, car a_agi est faux. L'unité est terminée ensuite (règle 4).
- **Si un autre type demande CAPTURER**: refusée avec `TYPE_NON_CAPABLE`, vérifié avant `PAS_SUR_UN_NŒUD`, pour que le refus ne dépende pas de la tuile.
- **Si le joueur demande RÉVEILLER avec 60 unités**: `MEUTE_COMPLÈTE` n'est pas déclenchée (un réveil ne crée pas d'unité, formule 6) ; le réveil suit ses autres vérifications. Le code ne vaut que pour une création (Alpha).
- **Si l'énergie est insuffisante pour RÉVEILLER**: refusée avec `ÉNERGIE_INSUFFISANTE` (besoin, disponible). Rien n'est écrit, le dormant reste endormi.
- **Si RÉVEILLER désigne un dormant sur une tuile cachée par le brouillard, ou inexistant**: refusée avec le **même code** que pour « aucun dormant adjacent » (`AUCUN_DRONE_ADJACENT`), sans paramètre propre à la tuile. Un dormant adjacent est toujours visible, la vision minimale étant 2. Ordre de vérification proposé : `DÉJÀ_AGI`, `AUCUN_DRONE_ADJACENT` (sur la vue de la faction), `ÉNERGIE_INSUFFISANTE`. Un refus n'apprend jamais plus que ce que la faction voit.
- **Si un dormant est adjacent à un ennemi**: le réveil est permis. Il n'y a pas de zone de contrôle, et le dormant n'est pas hostile.
- **Si deux unités de la meute sont adjacentes au même dormant**: celle que le joueur nomme réveille ; l'autre garde son action (le joueur désigne l'unité, les Gardiens ne réveillent pas).
- **Si une unité est à PV_max au début du tour**: soin = 0, aucun appel d'écriture, aucun `UNITÉ_SOIGNÉE`.
- **Si une unité était sur un nœud perdu pendant la phase ennemie**: le propriétaire est lu au moment du soin ; `sur_nœud_possédé` = 0 et le soin vaut REST_HEAL seul.
- **Si l'IA itère sur les identifiants et qu'une unité est détruite en cours de boucle**: la destruction est appliquée après la boucle (règle 10). L'IA relit les identifiants vivants après chaque commande ; une commande sur un identifiant détruit serait refusée (`UNITÉ_INCONNUE`) et compterait vers `N_REFUS_MAX`.
- **Si la dernière unité d'une faction est détruite alors qu'elle garde un nœud**: la faction n'est pas éliminée (GDD 3 : « aucun nœud »). Une meute sans unité éveillée ne peut plus réveiller ni capturer : la partie continue jusqu'au tour 30. Pour l'éviter, la mise en place garantit au moins deux unités éveillées dont un Ouvrier au départ, et au moins deux Ouvriers dormants atteignables (voir ci-dessous).
- **Si une unité se tient sur une tuile qui devient un nœud perdu**: elle reste, sans effet sur ses drapeaux ; seul le bonus de soin disparaît.
- **Si un drone réveillé est immédiatement attaqué**: impossible au MVP. Un dormant est `CIBLE_NON_HOSTILE`, donc aucune intention ne le vise avant son réveil ; réveil au tour n, annonce de l'IA en fin de phase ennemie du tour n, exécution au tour n + 1 : le joueur voit l'annonce avant l'attaque.
- **Si la tuile d'un dormant est bloquée par le plancher d'un pas**: visible, elle est refusée avec `CASE_BLOQUÉE` ; cachée, elle suit la règle d'embuscade appliquée à un neutre caché (arrêt avant, révélation, a_bougé = vrai).
- **Si DÉPLACER traverse une unité amie**: refusée avec `CASE_BLOQUÉE` ; `allow_friendly_pass` reste faux et l'on ne s'arrête pas sur une tuile occupée.
- **Si un dormant est sur une tuile jamais vue**: il est montré sous le brouillard comme un marqueur (silhouette grise, **type inconnu**), à la manière d'une ruine : c'est la meilleure question du brouillard (pilier 5). Seul le type reste caché jusqu'à ce que la tuile soit vue. Exigence pour 5.
- **Si une unité à 1 PV est soignée sur un nœud**: soin = min(4, PV_max − 1) ; un Éclaireur à 1/6 passe à 5/6.
- **Si le joueur n'a plus d'unité éveillée mais garde un nœud**: aucune commande de jeu n'est possible, hors FINIR_LE_TOUR.

### Cas à traiter dans d'autres GDD

- **Carte (2)**: la formule 2 doit exiger `PM_max ≥ 1`, sinon la Sentinelle (MVT 0) obtient un pas garanti. La règle 13 (« le marqueur disparaît au réveil et l'unité prend sa place ») contredit ce GDD, où le dormant est une unité dès la mise en place, avec son identifiant : le marqueur est visuel, lié à `endormie`. Les fichiers de carte doivent garantir au moins deux Ouvriers dormants atteignables et des unités de départ qui comptent un Ouvrier.
- **Commandes (23)**: ajouter `TYPE_NON_CAPABLE`, `UNITÉ_IMMOBILE`, `UNITÉ_SOIGNÉE` et `DÉJÀ_AGI` pour RÉVEILLER ; l'embuscade doit couvrir un neutre caché ; `UNITÉ_DÉPLACÉE` n'est pas émise quand départ = arrivée ; le « J, IA » de RÉVEILLER vaut pour une IA de meute, hors MVP.
- **État (1)**: « sans identifiant attribué » pour un réveil n'a plus de sens (le dormant a déjà un identifiant) ; la borne de 60 se vérifie à la mise en place.
- **Tours (3) et Nœuds (11)**: CAPTURER est réservée à l'Ouvrier et au Bastion ; la règle de capture d'un nœud déjà possédé par l'adversaire est à 11 (la défaite « aucun nœud » en dépend).
- **Réveil (7)**: `MEUTE_COMPLÈTE` est inatteignable au réveil : la retirer ou la réserver à l'Alpha.
- **Combat (8)**: `UNITÉ_TOUCHÉE` doit porter les dégâts effectifs (`pv_avant − pv_après`), pas le delta brut ; la formule 5 ne sert pas de formule de combat.
- **Brouillard (5)**: affichage d'un dormant dans une tuile découverte ; définition de « révéler » pour un neutre.
- **HUD (`hud.md`)**: lecture de `UNITÉ_SOIGNÉE` (absente si soin nul) ; affichage d'un dormant ; la statistique d'exemple « PV 10/10 · ATQ 2 · DÉF 1 · MVT 2 » ne correspond à aucun type ; le bouton « Capturer » doit s'activer quand l'unité est sur un nœud au moment de l'action, pas au début du tour.

## Dependencies

### En amont (ce système dépend de)

| Système | Nature | Dure ou souple |
|---|---|---|
| 1 Modèle d'état de partie | Tranche Unités (seul écrivain), identifiants, `MAX_UNITS`, ordre d'itération (`design/gdd/modele-etat-partie.md`) | Dure |
| 2 Carte en tuiles et terrain | Coûts d'entrée, franchissabilité, classe de défense, pas toujours possible, fichier de carte pour tuile et type des dormants (`design/gdd/carte-tuiles-terrain.md`) | Dure |

### En aval (systèmes qui dépendent de lui)

| Système | Ce qu'il utilise | Dure ou souple |
|---|---|---|
| 5 Brouillard | Tuile, faction, type, vision par type | Dure |
| 7 Réveil | « réveiller », statut endormi | Dure |
| 8 Combat | `modifier_pv`, ATQ, DÉF, portée, compteur de destructions | Dure |
| 9 IA | Types de Gardiens, stats, commandes, destruction | Dure |
| 11 Nœuds | Qui peut capturer (Ouvrier, Bastion), propriétaire pour le bonus de soin | Dure |
| 12 Protocoles | Aucun type débloqué au MVP ; capacités à définir | Souple |
| 17 HUD | Type, stats, phrase, état, PV | Dure |
| 23 Commandes | Validation de DÉPLACER avec PM et drapeaux ; événements de destruction, de réveil, de soin | Dure |

### Bidirectionnalité

- `design/gdd/modele-etat-partie.md` et `design/gdd/carte-tuiles-terrain.md` citent déjà ce système.
- `design/gdd/commandes-evenements.md` doit le citer pour les codes ajoutés et les événements `UNITÉ_SOIGNÉE`, `DRONE_RÉVEILLÉ`, `UNITÉ_DÉTRUITE`.
- `design/ux/hud.md` doit citer ce document (stats par type, phrases, soin).
- Les GDD 5, 7, 8, 9, 10, 11, 12 et 17 doivent le citer à leur création.

### Décisions techniques renvoyées à un ADR

- Format du fichier de données des types (`assets/data/units.*`) et validation de la mise en place.
- Représentation d'une unité dans l'état (tableau plat indexé par identifiant).

## Tuning Knobs

*Dans un fichier de données (`assets/data/units.*`). Valeurs de départ [PROP], à jouer en test
puis à équilibrer avec le combat (8).*

| Paramètre | Valeur | Plage sûre | Trop haut | Trop bas | Interagit avec |
|---|---|---|---|---|---|
| PV, ATQ, DÉF, MVT par type (règles 2 et 3) | voir tableaux | PV 6..14 ; ATQ 0..4 ; DÉF 0..3 ; MVT 0..4 | Un type écrase les autres | Un type devient inutile | Combat (8), formule 5 (contrôle de dominance) |
| Portée par type | 1 partout | 1..2 | Ruine le contact et les embuscades | — | Combat (8), brouillard (5) ; Lancier en Alpha |
| Vision par type | Éclaireur 4 ; Sentinelle et Chasseur 3 ; autres 2 | 1..5 | La carte se révèle trop vite (pilier 5) | Marche à l'aveugle | Brouillard (5) |
| `REST_HEAL` | 2 PV | 1..3 | Les blessures ne comptent plus (pilier 4) | Une perte est irréparable en pratique | Soin sur nœud, rythme de 30 tours |
| `NODE_REST_BONUS` | 2 PV | 0..4 | Camper sur un nœud domine | Les nœuds ne servent plus de refuge | Nœuds (11) |
| `allow_friendly_pass` | faux | faux / vrai | Les couloirs ne bloquent plus | — | Carte (2), embuscade |
| `MAX_UNITS` | 60 | 20..60 (GDD 1) | IA plus lente, copie plus lourde | La meute ne « grandit » plus (pilier 1) | Réveil (7) |
| Poids de la formule 5 | 3, 3, 2, 1 | 2..4 ; 2..4 ; 1..3 ; 0..2 | — | — | Contrôle de dominance seulement |

## Visual/Audio Requirements

*Rédigé d'après la consultation de l'`art-director` du 2026-10-30 et l'art bible (section 5).*

- **Silhouettes.** Un trait par type, d'au moins 6 pt à 31 pt la tuile, reconnaissable en
  silhouette noire. Meute : mât (Éclaireur), lame (Assaut), carapace (Rempart), fourche
  (Ouvrier). Gardiens, socle en losange et angles aigus, **traits diagonaux ou en dents de
  scie, jamais perpendiculaires au socle** : Croc, deux pointes en V ouvert (Sentinelle) ;
  Faille, deux ailerons en Λ renversé (Chasseur) ; Crête, trois à quatre dents de scie sur le
  dos (Bastion). Le Dard (Lancier, une pointe à 45°) est réservé à l'Alpha.
- **Paires à contrôler en priorité** (test côte à côte à 31 pt) : mât / fourche (imposer au
  moins 2 pt d'écart entre les pointes de la fourche et un mât unique nettement plus haut) ;
  lame / carapace (lame étroite et asymétrique avant / arrière, carapace symétrique et plus
  large que le corps) ; Croc / Faille (V ouvert contre Λ renversé : si trop proches, passer le
  Chasseur à un seul aileron en crochet anguleux).
- **Dormant.** Même silhouette, gris-bleu, contour en pointillés gris, socle enfoncé d'environ
  2 pt, trait replié à mi-course, œil éteint ; le réveil dure environ 0,6 s. Pour un Gardien,
  le trait se replie vers le corps sans changer de direction, et le contour violet reste fixe.
- **Santé.** Aucun dégât ni soin sur le modèle : seule la jauge blanche du HUD porte les PV. À
  la destruction, l'unité perd sa teinte vers le gris puis s'affaisse, et laisse un glyphe de
  débris gris sur la tuile jusqu'à la fin du tour suivant du joueur (`design/ux/hud.md`).
- **Budget.** 150 à 400 triangles par unité, un niveau de détail, un matériau (art bible,
  section 8). Mêmes silhouettes pour toutes les factions de la meute : seuls la palette et le
  motif changent.
- **Audio.** Aucune information de jeu ne passe par un son (`design/accessibility-requirements.md`).
  Sons possibles, facultatifs : réveil, déplacement, destruction, soin ; spécifiés avec le
  système 20.

> 📌 **Asset Spec** — Visual/Audio requirements are defined. After the art bible is approved,
> run `/asset-spec system:unites-drones` to produce per-asset visual descriptions, dimensions,
> and generation prompts from this section.

## Game Feel

- **Obéissance exacte.** Un ordre se voit exécuté sans ambiguïté : rotation par paliers de
  45°, déplacement glissé à vitesse constante, sans balancement ni rebond (art bible,
  « Pose et mouvement »).
- **Le réveil est le moment fort.** Environ 0,6 s en une passe : le socle se lève, la teinte
  de faction monte du socle vers le trait, l'œil s'allume en dernier. Il ne bloque aucune
  commande au-delà de ce délai, et s'affiche directement en fin d'état avec les animations
  réduites.
- **Une perte se lit sans bruit.** La teinte retourne au gris, l'unité s'affaisse : pas de
  secousse d'écran, pas d'effet de particules (pilier 4 : la perte était annoncée).
- **Au repos.** Une seule pulsation lente de l'œil (environ 3 s), désactivée avec les
  animations réduites ; un soin n'ajoute que la montée de la jauge.
- **Un type, un rythme.** L'Éclaireur traverse la carte en une passe, le Rempart avance
  lentement : la vitesse d'animation suit le MVT, dans la plage de 150 à 300 ms par tuile.

## UI Requirements

- **Panneau d'unité** (`design/ux/hud.md`, section 4) : nom du type, PV courants / maximum, ATQ,
  DÉF, MVT, et la phrase du type (90 caractères au plus) ; jamais plus d'une phrase.
- **Phrase de chaque type** : texte localisable ; l'anglais peut dépasser de 40 % (réserver
  le retour à la ligne).
- **Boutons** : « Déplacer » (si a_bougé est faux et MVT ≥ 1), « Attaquer » (ATQ ≥ 1 et a_agi
  faux), « Capturer » (Ouvrier ou Bastion, sur un nœud non possédé, a_agi faux), « Réveiller »
  (dormant adjacent, a_agi faux) ; chacun grisé avec sa raison (le HUD traduit le code de
  refus de 23).
- **Jauge** : barre blanche sous l'unité blessée, repère fixe à 50 % ; elle monte au soin.
- **État affiché** : « prête », « a bougé », « terminée » (dérivé des drapeaux) sans autre
  teinte que la forme et le texte.
- **Dormant** : visible comme une unité grise en pointillés ; un appui affiche sa phrase et
  son coût de réveil (système 7).

> 📌 **UX Flag — Unités drones** : ce système a des exigences d'interface (panneau d'unité,
> boutons conditionnels, phrases). En phase 4 (pré-production), lancer `/ux-design` pour le
> panneau d'unité **avant** d'écrire les épopées.

## Cross-References

| Ce document cite | Document | Élément précis | Nature |
|---|---|---|---|
| Tranche Unités, `MAX_UNITS`, identifiants, entiers, itération par identifiant | `design/gdd/modele-etat-partie.md` | Règles 3, 5, 8 ; tranche Unités | Règle, valeur |
| Coûts d'entrée, pas toujours possible, traversée d'une unité amie, défense par tuile | `design/gdd/carte-tuiles-terrain.md` | Règles 4, 5, 9 ; formules 1 et 2 | Règle |
| Commandes DÉPLACER, ATTAQUER, CAPTURER, RÉVEILLER ; codes de refus ; embuscade ; annulation | `design/gdd/commandes-evenements.md` | Règles 6, 7, 15 ; table des commandes | Règle |
| Ordre du début de tour (soin avant la remise à zéro) | `design/gdd/tours-conditions-victoire.md` | §2 | Règle |
| Statistiques affichées, phrase, jauge | `design/ux/hud.md` | Panneau d'unité ; jauge de PV | Intention |
| Familles de traits, dormant, destruction | `design/art/art-bible.md` | Section 5 | Style |
| Pilier 3, pilier 4, pilier 1 | `design/gdd/game-concept.md` | Game Pillars | Intention |

## Acceptance Criteria

*Étiquettes : **Logic** = test unitaire dans `tests/unit/units/`, sur un état construit par
fabrique (aucun accès fichier) ; **Intégration** = `tests/integration/units/` ; **Visuel** =
capture conservée dans `production/qa/evidence/` et validée par l'art-director ; **UI** =
capture de chaque écran touché ; **Appareil** = sur l'appareil de référence. [BLOQUÉ n] : le
critère attend le GDD du système n. Les seuils de AC-V1 sont proposés, à confirmer.*

### Règles

- **AC-U1** (Logic, règle 1) **GIVEN** une tranche de 3 unités créées puis la 2e détruite, **WHEN** on en crée une 4e, **THEN** les identifiants croissent strictement et celui de la 2e n'est jamais réattribué ; **GIVEN** 60 unités, dormantes comprises, **THEN** la 61e est refusée ; **GIVEN** une unité sur une tuile, **THEN** une seconde sur la même tuile est refusée ; l'itération se fait par identifiant croissant.
- **AC-U2** (Logic, règle 1) **GIVEN** la tranche sérialisée, **THEN** elle ne contient que identifiant, type, faction, tuile, PV, a bougé, a agi, endormie (PV_max, ATQ, DÉF, MVT, portée et vision absents) ; **GIVEN** un fichier de données modifié dans la fabrique (Rempart à 15 PV), **THEN** PV_max suit (preuve qu'aucune valeur n'est en dur).
- **AC-U3** (Logic, règle 2) **GIVEN** `assets/data/units.*`, **THEN** les quatre types de meute ont exactement PV / ATQ / DÉF / MVT / portée / vision du tableau (Éclaireur 6/1/0/4/1/4 ; Assaut 8/3/1/3/1/2 ; Rempart 14/1/2/2/1/2 ; Ouvrier 7/1/0/3/1/2) et chaque phrase compte 90 caractères au plus (accents compris).
- **AC-U4** (Logic, règle 3) **GIVEN** le même fichier, **THEN** Sentinelle 10/0/2/0/1/3, Chasseur 8/3/0/3/1/3, Bastion 14/2/2/1/1/2, phrases de 90 caractères au plus ; aucun type n'est à la fois de la meute et Gardien ; **GIVEN** un Gardien, **WHEN** RÉVEILLER, **THEN** refus.
- **AC-U5** (Logic, règle 4) **GIVEN** une unité prête, **WHEN** DÉPLACER est appliquée, **THEN** a bougé vrai, a agi faux (idem si une embuscade l'arrête) ; **WHEN** ATTAQUER, CAPTURER ou RÉVEILLER, **THEN** a agi vrai et tout autre ordre est refusé ; **WHEN** elle reçoit un coup ou une riposte, **THEN** ses drapeaux sont inchangés ; **WHEN** le tour de sa faction commence, **THEN** ses drapeaux sont faux ; ANNULER_LE_DÉPLACEMENT restaure les drapeaux de l'instantané.
- **AC-U6** (Logic, règle 5) **GIVEN** un Rempart (MVT 2) prêt et une montagne voisine libre (coût 3), **THEN** DÉPLACER est permis (pas garanti) ; **GIVEN** un second DÉPLACER le même tour, **THEN** refus ; **GIVEN** une unité amie sur le chemin ou comme destination, **THEN** `CASE_BLOQUÉE` ; `allow_friendly_pass` vaut faux dans les données. Le pas garanti est défini par `design/gdd/carte-tuiles-terrain.md`, règle 5.
- **AC-U7** (Logic, règle 6) **GIVEN** une unité endormie à PV < PV_max, **WHEN** le tour de sa faction commence, **THEN** aucun soin ; **GIVEN** une unité réveillée ce tour, **THEN** elle ne se soigne pas au tour suivant ; **GIVEN** un nœud possédé par sa faction, **THEN** soin = `REST_HEAL` + `NODE_REST_BONUS` (voir AC-F3). L'ordre de l'étape de soin est celui de `design/gdd/tours-conditions-victoire.md`, §2.
- **AC-U8** (Logic, règle 7) **GIVEN** chacun des sept types sur un nœud, **WHEN** CAPTURER, **THEN** seuls l'Ouvrier et le Bastion passent ; les cinq autres reçoivent `TYPE_NON_CAPABLE` ; **GIVEN** un Ouvrier qui se déplace sur le nœud puis capture, **THEN** permis, a agi vrai. [BLOQUÉ 11 : l'effet de la capture]
- **AC-U9** (Logic, règle 8) **GIVEN** un dormant et un drone éveillé de la meute, de chaque type, à distance 1 (diagonale comprise), **WHEN** RÉVEILLER, **THEN** le dormant : endormie faux, faction = celle du réveilleur, PV, type et tuile inchangés, a bougé et a agi vrais ; le réveilleur : a agi vrai ; `DRONE_RÉVEILLÉ` émis ; **GIVEN** un dormant, **WHEN** ATTAQUER, **THEN** `CIBLE_NON_HOSTILE`, et `modifier_pv` est refusée ; il bloque le passage ; le réveil est permis à côté d'un ennemi. [BLOQUÉ 7 : coût et validation complète ; 10 : énergie]
- **AC-U10** (Logic, règle 9) **GIVEN** `modifier_pv(état, id, delta, source)`, **THEN** elle rend `{pv_avant, pv_après, détruite}` ; un delta nul n'écrit rien ; un identifiant endormi ou inconnu est refusé ; deux appels identiques sur deux états identiques donnent le même résultat et aucun tirage n'est consommé (espion sur le hasard).
- **AC-U11** (Logic, règle 10) **GIVEN** une unité à 0 PV, **THEN** elle est retirée dans le même appel, sa tuile est libre, terrain, propriétaire et nœuds sont inchangés, `UNITÉ_DÉTRUITE` est émis, son identifiant n'est jamais réattribué ; **GIVEN** une boucle sur les identifiants où l'unité 3 est détruite à l'étape 2, **THEN** la suppression n'a lieu qu'après la boucle, et une commande ultérieure sur l'identifiant 3 donne `UNITÉ_INCONNUE`. [BLOQUÉ 8 : compteur ; 9 : intentions annulées ; 5 : vue]
- **AC-U12** (Logic, règle 11) **GIVEN** un soin > 0, **THEN** `UNITÉ_SOIGNÉE` est émis (PV avant et après) ; un soin nul n'émet aucun événement. L'affichage de la jauge relève de AC-V2.
- **AC-U13** (Logic, règle 12) **GIVEN** le schéma de la tranche et du fichier de types, **THEN** il n'existe aucun champ nom, niveau ou équipement.

### Formules (vecteurs déterministes)

- **AC-F1** (Logic, formule 1) Rempart a bougé faux → PM_restants 2 ; a bougé vrai → 0 ; Éclaireur → 4 ; Sentinelle (MVT 0) : PM_restants 0 et `pas_garanti` faux malgré une voisine libre ; DÉPLACER donne `UNITÉ_IMMOBILE`.
- **AC-F2** (Logic, formule 2) Éclaireur 4/6, delta −9 → pv_après 0, détruite vrai, dégâts effectifs 4 ; Assaut 3/8, +2 → 5 ; Assaut 3/8, +20 → 8 ; delta 0 → rien d'écrit ; unité à 0 PV avant → `détruite` faux.
- **AC-F3** (Logic, formule 3) Rempart 14/14 sur nœud possédé → 0, aucun appel d'écriture ; Assaut 3/8 sur nœud possédé → 4, soit 7/8 ; Assaut 7/8 hors nœud → 1, soit 8/8 ; Éclaireur 1/6 sur nœud → 4, soit 5/6 ; nœud perdu pendant la phase ennemie → soin de 2 seulement.
- **AC-F4** (Logic, formule 4) Rempart seulement touché (faux / faux) → au repos ; Assaut ayant attaqué → non ; réveillé (vrai / vrai) → non ; endormie → non ; **GIVEN** une unité a bougé au tour précédent, **WHEN** le début de tour s'exécute, **THEN** le prédicat lit les drapeaux **avant** la remise à zéro (un test qui remet à zéro d'abord doit échouer) ; après ANNULER_LE_DÉPLACEMENT, toujours au repos ; au tour 1, tout le monde au repos, soin 0.
- **AC-F5** (Logic, formule 5) Les sept valeurs valent 21, 28, 29, 18, 19, 26, 30 (poids 3, 3, 2, 1) ; Assaut = 28 ; l'Ouvrier est le seul type dominé (par l'Assaut) ; écart max/min 30/18 ; aucune règle de jeu ne lit cette valeur (recherche statique).
- **AC-F6** (Logic, formule 6) 2S + 6 : S = 27 passe (60), S = 28 est refusé à la validation de mise en place ; le réveil de la 6e dormante laisse le total inchangé ; `MEUTE_COMPLÈTE` n'est jamais produite par un réveil, même à 60 unités. [BLOQUÉ 7 : retrait du code]
- **AC-F7** (Logic, transversal) Aucun flottant dans le module (analyse statique : pas de `float`, de division non entière ni de `randf`) ; mêmes entrées, mêmes sorties, vérifiées par deux exécutions et une comparaison d'octets de l'état.

### Cas limites

- **AC-E1** (Intégration) Embuscade au premier pas : l'unité ne bouge pas, a bougé vrai, a agi faux, ennemi révélé, instantané supprimé, ANNULER → `DÉPLACEMENT_A_RÉVÉLÉ`, `UNITÉ_DÉPLACÉE` non émis, `TUILES_RÉVÉLÉES` émis. [BLOQUÉ 5, 23]
- **AC-E2** (Logic) Un Éclaireur demande CAPTURER → `TYPE_NON_CAPABLE` (et non `PAS_SUR_UN_NŒUD`), que la tuile soit un nœud ou une plaine.
- **AC-E3** (Logic) Énergie insuffisante : `ÉNERGIE_INSUFFISANTE`, rien d'écrit ; ordre des vérifications : `DÉJÀ_AGI`, `AUCUN_DRONE_ADJACENT`, `ÉNERGIE_INSUFFISANTE`. [BLOQUÉ 7, 10]
- **AC-E4** (Logic) Dormant caché, inexistant ou non adjacent : même code `AUCUN_DRONE_ADJACENT`, mêmes champs de réponse (aucun paramètre de tuile), sans fuite.
- **AC-E5** (Logic) À 60 unités, RÉVEILLER ne renvoie pas `MEUTE_COMPLÈTE` ; avec deux drones adjacents au même dormant, seul celui qui est nommé consomme son action.
- **AC-E6** (Logic) Unité sur un nœud perdu : drapeaux inchangés, seul le bonus disparaît ; Éclaireur à 1 PV sur un nœud : 5/6.
- **AC-E7** (Logic) Dormant bloquant : visible → `CASE_BLOQUÉE` ; caché → arrêt avant, révélation, a bougé vrai. [BLOQUÉ 5]
- **AC-E8** (Intégration) Plus aucune unité éveillée : seule FINIR_LE_TOUR est acceptée. [BLOQUÉ 23]

### Transitions d'état

- **AC-S1** (Logic) L'état se dérive des drapeaux (aucun champ « état ») ; seules les transitions du tableau sont acceptées : Endormie → Terminée ; Prête → A bougé, Terminée ou Détruite ; A bougé → Prête (annulation), Terminée ou Détruite ; Terminée → Prête (début de tour) ou Détruite ; toute autre est refusée, dont Endormie → Détruite et Détruite → quoi que ce soit.

### Visuel et appareil

- **AC-V1** (Visuel) **GIVEN** les sept silhouettes noires côte à côte à 31 pt, **WHEN** cinq personnes qui ne connaissent pas le jeu nomment le type de chacune, **THEN** au moins 95 % de réponses justes ; capture conservée dans `production/qa/evidence/unites-silhouettes-31pt.png`, validée par l'art-director. Contrôles prioritaires : Croc / Faille, mât / fourche, lame / carapace.
- **AC-V2** (Visuel + UI) La jauge de PV lors d'un soin et lors d'un dégât, une capture par cas. [BLOQUÉ 17]
- **AC-A1** (Appareil) Les sept silhouettes sur l'appareil de référence, en portrait. [BLOQUÉ : appareil de référence non fixé]

### Non testable en l'état

- Règle 12 : « indiscernables » se réduit à un contrôle de schéma (AC-U13).
- « L'unité peut encore attaquer l'ennemi révélé » après une embuscade au premier pas, et « un dormant n'est montré qu'une fois sa tuile visible » : décisions encore provisoires (Open Questions) ; aucun critère n'est écrit avant qu'elles soient prises.
- La garantie d'un Ouvrier au départ et d'un Ouvrier dormant atteignable relève du fichier de carte (2) et se teste là-bas.

## Open Questions

| Question | Propriétaire | À résoudre avant | Résolution |
|---|---|---|---|
| Les statistiques des sept types sont des propositions : équilibrage avec le combat. | game-designer, systems-designer | GDD 8, puis `/balance-check` | |
| Quel est le coût de réveil par type (échelle d'énergie) ? | economy-designer | GDD 7 et 10 | |
| Les fichiers de carte placent-ils au moins deux Ouvriers dormants atteignables et des unités de départ qui comptent un Ouvrier ? (sans Ouvrier, plus de capture ni de domination) | level-designer | Fichiers de cartes du MVP | |
| Que se passe-t-il si tous les Ouvriers de la meute meurent ? Un autre type peut-il capturer ? | game-designer | GDD 11 | |
| Une capture de l'IA est annoncée comme une intention (cible : un nœud) : format des intentions, durée d'annonce, annulation si la capture devient impossible. | game-designer, ai-programmer | GDD 9, 11, 1 | |
| Le périmètre de 7 types (4 meute + 3 Gardiens) dépasse « 4 types » du MVP : chiffrage du producer, recensé dans le concept. | producer | PR-SCOPE suivant | |
| Que devient un nœud d'une faction qui n'a plus aucune unité éveillée (et peut-elle être éliminée) ? | game-designer | GDD 11 et revue de 3 | |
| Quelle règle de capture d'un nœud déjà possédé par l'adversaire ? | game-designer | GDD 11 | |
| Un dormant est montré sous le brouillard comme un marqueur à type inconnu : forme exacte (silhouette, lueur) et règle de visibilité. | game-designer, art-director | GDD 5 | Provisoire : marqueur gris, type inconnu |
| Le Chasseur et l'Éclaireur doivent-ils attaquer après une embuscade au premier pas ? | game-designer | Playtest | Provisoire : oui |
| Une portée de 2 (Lancier, Dard) en Alpha : quelle règle de riposte ? | game-designer | Alpha | |
| Test de silhouette : Croc / Faille, mât / fourche, lame / carapace à 31 pt. | art-director, technical-artist | Premier modèle de test | |
| Reporter dans 23 : `TYPE_NON_CAPABLE`, `UNITÉ_IMMOBILE`, `UNITÉ_SOIGNÉE`, `DÉJÀ_AGI` pour RÉVEILLER, embuscade sur un neutre caché. | game-designer | Revue de 23 | |
| Reporter dans 2 : `PM_max ≥ 1` pour le pas garanti ; règle 13 (le dormant est une unité dès la mise en place). | level-designer | Revue de 2 | |
| Reporter dans `hud.md` : statistiques d'exemple, bouton « Capturer » à l'action et non au début du tour, lecture de `UNITÉ_SOIGNÉE`. | ux-designer | `/ux-design hud` | |
