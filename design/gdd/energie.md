# Énergie

> **Status**: Designed (pending /design-review)
> **Author**: user + Claude (economy-designer, systems-designer, game-designer)
> **Last Updated**: 2026-10-30
> **Last Verified**: 2026-10-30
> **Implements Pillar**: Pilier 1 « La meute se voit grandir » ; pilier 4 « La puissance se mérite » ; pilier 3 « Lisible comme Polytopia »
> **Creative Director Review (CD-GDD-ALIGN)**: REVISED 2026-10-30 — CONCERNS (alerte de perte au plafond toujours déclenchée par la courbe de base ; courbe sans carte disputée ; tour 7 compté à tort comme un arbitrage ; niveau des nœuds non exigé visible sur la carte) corrigées : alerte limitée aux tours 1 à 20, scénario disputé ajouté, arbitrages réels nommés, niveau visible exigé de 11, puits tardif d'Alpha visible sur la carte

## Summary

L'énergie est la seule monnaie du jeu : chaque faction a un stock, alimenté au début de son tour
par ses nœuds selon leur niveau, et dépensé pour réveiller un drone, rechercher un protocole ou
faire monter un nœud. Le stock se reporte d'un tour à l'autre jusqu'à un plafond de 99, le
joueur et l'IA suivent la même règle, et aucun entretien ne pèse sur les unités au MVP. Ce
système existe pour que chaque tour soit un arbitrage (pilier 4) et que la croissance de la
meute se mesure en nœuds (pilier 1).

> **Quick reference** — Layer: `Feature` · Priority: `MVP` · Key deps: `Modèle d'état de partie, Tours et conditions de victoire`

## Overview

L'énergie est la seule monnaie du jeu. Chaque faction a un **stock** d'énergie, écrit dans la
tranche « Factions » de l'état de partie (`design/gdd/modele-etat-partie.md`), et un
**revenu** versé au début de son tour : la somme de ce que rapportent ses nœuds selon leur
niveau (`design/gdd/tours-conditions-victoire.md`, §2, pour l'ordre du début de tour). Le
revenu est calculé à chaque fois et jamais stocké. Le stock sert à trois choses : réveiller
un drone (7), rechercher un protocole (12) et faire monter un nœud (11). Ce système possède
le stock, le calcul du revenu, la borne du stock, et les deux fonctions d'écriture « dépenser »
et « créditer » ; chaque système qui dépense garde sa propre grille de prix dans ses données.

L'énergie est le goulot d'étranglement qui fait de chaque tour un choix (pilier 4 : la
puissance se mérite) et la mesure de la croissance de la meute (pilier 1) : plus de nœuds,
plus d'énergie, plus de drones. Elle est identique pour le joueur et pour l'IA ; la difficulté
pourra la moduler plus tard. Aucune unité ne coûte d'entretien au MVP
(`design/gdd/unites-drones.md`).

*Cadrage : à la fois la couche de données (stock, borne, fonctions) et son effet pour le
joueur (le goulot de chaque tour). Aucun ADR n'existe encore sur l'énergie.*

## Player Fantasy

*Cadrage : à la fois direct (on lit un stock et un « +n » et l'on choisit) et en dessous (la
carte, elle, montre la croissance). Retenu (`creative-director`, 2026-10-30) : « Qui réveiller
d'abord » comme fantasme central, « Le pouls de la meute » comme règle de retour visuel,
« Manque 1 » comme règle d'interface.*

**Qui réveiller d'abord.** Douze en stock : on réveille un drone tout de suite pour sept, ou
l'on garde tout pour le protocole à douze. Chaque dépense laisse un drone endormi un tour de
plus : on ne paie pas, on arbitre (pilier 4). Chaque tour est un choix, jamais une corvée.

**Le pouls de la meute.** Quand on prend un nœud, la tuile se recolore aussitôt et c'est
seulement au début du tour suivant que le « +n » monte : le gain se voit d'abord sur la carte,
puis dans le chiffre. Le chiffre confirme, il n'annonce rien (pilier 1).

**Manque 1.** Le bouton grisé affiche « manque 1 » avec l'éclair : on sait sans calculer que ce
sera possible au tour suivant, et l'envie de jouer « encore un tour » naît de là (piliers 3 et 4).

**Ton.** Un registre machine, sec et sans métaphore marchande : on écrit « réveiller »,
« rechercher », « faire monter », jamais « acheter », « or » ou « argent ». Les chiffres sont en
JetBrains Mono 700, l'éclair jaune reste dans l'interface et jamais sur la carte, et le « +n »
et le « manque n » sont en blanc contourné ou en gris clair, sans vert ni ambre ni
clignotement.

**Trois échecs à éviter.**
1. *Le tableur* : si le joueur regarde le chiffre au lieu de la carte, le pilier 1 est raté.
2. *L'épargne dominante* : avec un plafond haut, garder doit coûter du rythme — un drone qui
   dort ne rapporte rien, et un nœud non monté non plus.
3. *L'IA qui triche* : le revenu de l'IA se déduit de ses nœuds, visibles sur la carte, avec la
   même règle que celui du joueur ; tant que la difficulté ne module rien (MVP), aucun revenu
   caché.

## Detailed Design

*Décisions du 2026-10-30 : une seule monnaie ; revenu des nœuds seuls, selon leur niveau ;
stock reporté d'un tour à l'autre, avec un plafond de 99 ; même économie pour le joueur et
l'IA ; chaque système qui dépend (7, 11, 12) garde sa grille de prix ; aucune énergie
restante dans le score ; un surplus au plafond est accepté et mesuré, sans puits tardif au
MVP. Les chiffres marqués [PROP] sont des valeurs de départ, à jouer en test.*

### Core Rules

1. **Une monnaie, un stock par faction.** Le stock est un entier de la tranche « Factions »
   (propriétaire : ce système), dans [0, `ENERGIE_MAX`]. Le joueur et l'IA suivent exactement
   les mêmes règles. Aucun entretien d'unité au MVP.
2. **Données.** `assets/data/energie.*` contient `ENERGIE_MAX` = 99, `ENERGIE_DEPART` = 6 [PROP]
   et `REVENU_NIVEAU` = {1 : 3, 2 : 4, 3 : 5} [PROP]. Les grilles de prix restent chez 7
   (réveil), 11 (montée de nœud) et 12 (protocoles).
3. **Le revenu est calculé, jamais stocké.** `revenu(état, faction)` = somme de
   `REVENU_NIVEAU[niveau]` sur les nœuds dont la faction est propriétaire, parcourus par
   identifiant croissant (`design/gdd/modele-etat-partie.md`, règle 8). Un nœud neutre ou
   ennemi ne rapporte rien. Un nœud capturé pendant un tour compte dès le début du tour
   suivant ; la capture et la montée de niveau n'ont aucun effet immédiat sur le stock.
4. **Versement.** Le revenu est versé une fois, au début du tour de la faction, dans
   COMMENCER_LE_TOUR (`design/gdd/tours-conditions-victoire.md`, §2). Ordre : phase et faction
   active, drapeaux remis à zéro (6), **revenu (10)**, avancée de la recherche (12). L'IA est
   payée au début de sa phase, par la même fonction. Une faction éliminée n'est pas payée.
5. **Plafond.** `après = min(avant + revenu, ENERGIE_MAX)`. Le surplus est **perdu** ; le
   versement n'est jamais refusé et ne produit aucun message d'erreur.
6. **Dépenser.** `dépenser(état, faction, montant, raison)` rend `{ok, avant, après}` ou
   `{ok: faux, code: ÉNERGIE_INSUFFISANTE, besoin, disponible}`.
   - `montant` est un entier ≥ 1 ; un prix de 0 n'appelle pas la fonction ; un montant négatif est un bogue (assertion).
   - `raison` ∈ RÉVEIL, RECHERCHE, MONTÉE_NŒUD.
   - Refus si `montant > stock`, sans rien écrire ; un montant égal au stock est permis.
   - Une commande appelle `dépenser` au plus une fois, après toute autre écriture qui peut échouer (commandes, règle 3).
7. **Validation sans écriture.** `disponible(état, faction)` et `peut_dépenser(état, faction, montant)`
   sont en lecture seule : validation des commandes, HUD, IA. Le contrôle d'énergie est la
   **dernière** vérification de RÉVEILLER, RECHERCHER et MONTER_NŒUD, pour que le refus
   structurel passe avant le refus d'énergie. Le HUD affiche « manque n » avec
   n = `besoin − disponible`.
8. **Créditer.** `créditer(état, faction, montant, raison)` est borné par `ENERGIE_MAX` (règle 5).
   Au MVP, **seul le versement de début de tour l'appelle** (raison REVENU). Aucun
   remboursement : une recherche en cours ne se rembourse pas, un réveil ne s'annule pas,
   l'annulation d'un déplacement ne touche pas l'énergie. Le prix est payé à l'application de
   la commande, non à la fin de la recherche.
9. **Stock jamais négatif.** Trois verrous : `dépenser` refuse tout débit supérieur au stock,
   `créditer` n'accepte que des montants ≥ 0, et la validation des invariants (modèle d'état,
   règle 14) vérifie 0 ≤ stock ≤ `ENERGIE_MAX` dans les tests et au chargement. Un stock
   supérieur au plafond au chargement est **rogné** au plafond (trace dans le journal de
   développement).
10. **Initialisation.** Le stock reçoit `ENERGIE_DEPART` à la mise en place (tour 0), par une
    fonction d'initialisation de ce système. C'est la seule écriture hors `dépenser` et
    `créditer`, de même nature que le tirage des ruines.
11. **Événement.** `dépenser` et `créditer` **rendent** `{avant, après, raison}` ; l'application
    de la commande construit ÉNERGIE_CHANGÉE(faction, avant, après) et la publie en lot après
    la commande (commandes, règle 8). Aucune émission si `avant = après`. Une copie de
    simulation ne publie jamais.
12. **Aucun effet sur le score.** L'énergie restante n'entre pas dans le score.
13. **Détail du revenu.** `revenu_détail(état, faction)` rend la liste (identifiant de nœud,
    niveau, revenu) pour le HUD, qui l'affiche à l'appui sur l'élément d'énergie. Le « +n » du
    HUD est le revenu brut ; au plafond, le stock affiche « MAX ».

### Courbe économique de départ [PROP]

*Proposée par `economy-designer` ; la carte donne **un** nœud par joueur au départ et quatre
nœuds neutres, six au total (`design/gdd/carte-tuiles-terrain.md`, règle 15).*

| Élément | Valeur de départ | Propriétaire de la grille |
|---|---|---|
| Stock de départ | 6 | 10 |
| Revenu d'un nœud, niveau 1 / 2 / 3 | 3 / 4 / 5 | 10 |
| Réveil (Éclaireur / Ouvrier / Assaut / Rempart) | 4 / 5 / 6 / 8 | 7 |
| Montée de nœud, 1 → 2 / 2 → 3 | 12 / 20 | 11 |
| Protocoles (6 au MVP) | 15, 15, 20, 25, 30, 35 (total 140) | 12 |

**Croquis des dix premiers tours du joueur** (1 nœud de niveau 1 au départ, un Ouvrier dormant
à 2 ou 3 tuiles ; le type de chaque dormant est fixé par la carte) :

| Tour | Stock avant revenu | Revenu | Disponible | Achat | Reste |
|---|---|---|---|---|---|
| 1 | 6 | +3 | 9 | Réveiller l'Ouvrier (5) | 4 |
| 2 | 4 | +3 | 7 | rien (l'Ouvrier capture un nœud voisin, sans énergie) | 7 |
| 3 | 7 | +6 | 13 | Réveiller l'Éclaireur (4) | 9 |
| 4 | 9 | +6 | 15 | Réveiller l'Assaut (6) | 9 |
| 5 | 9 | +9 | 18 | Monter le nœud de départ au niveau 2 (12) | 6 |
| 6 | 6 | +10 | 16 | **Premier protocole (15)** | 1 |
| 7 | 1 | +10 | 11 | rien : « manque 1 » pour une montée à 12 | 11 |
| 8 | 11 | +10 | 21 | Monter un second nœud au niveau 2 (12) | 9 |
| 9 | 9 | +11 | 20 | Deuxième protocole (15) | 5 |
| 10 | 5 | +11 | 16 | Monter un troisième nœud au niveau 2 (12) | 4 |

Premier réveil au tour 1, premier protocole au tour 6. Les vrais **arbitrages** (deux achats
utiles pour un même stock) sont aux tours 1, 5 et 6 ; le tour 7 est un blocage « manque 1 », qui
fait naître l'envie de « encore un tour », non un arbitrage. Le premier fragment ne dépend pas de l'énergie (lire une
ruine ne coûte rien).

**Rapport revenu / achats possibles.** Revenu cumulé sur 30 tours d'environ 360 à 400 (379 avec
3 nœuds au niveau 3, 399 avec 4 nœuds au niveau 2) ; le catalogue d'achats vaut 259 (3 nœuds),
291 (4 nœuds) ou 355 (6 nœuds), en comptant un drone de chaque type (23). Le goulot est
réel jusqu'au tour 15 environ ; un joueur qui s'étend épuise les achats utiles vers les tours
22 à 27, après quoi le surplus se perd au plafond. **Décision :** accepter et mesurer (le
niveau 3 rapporte 5 plutôt que 6 pour l'atténuer), sans puits tardif au MVP. Métriques de
test : tour du premier achat, tour du premier protocole, nombre de tours bloqués par
« manque n » (cible 3 à 5 sur les tours 1 à 15), stock moyen par tour (alerte au-delà de 60),
part du revenu perdue au plafond **avant le tour 21** (alerte au-delà de 5 % ; la perte des
tours 21 à 30 est attendue et se relève sans alerte).

**Scénario disputé (à jouer en test).** La courbe ci-dessus suppose que le joueur prend trois des
six nœuds avant le tour 5 sans que l'IA les dispute. Si l'IA prend les deux nœuds du centre,
le joueur reste à deux nœuds de niveau 1 (revenu 6 au lieu de 9 au tour 5) : le premier
protocole glisse vers le tour 9 et la montée d'un nœud vers le tour 7. Vérifier que la cible
« manque n » (3 à 5 tours sur les tours 1 à 15) tient aussi dans ce cas, et que la partie
reste jouable sans nœud de niveau 2 avant le tour 10.

**Exigence pour 11 (pilier 1).** Le niveau d'un nœud doit être **visible sur la carte** (forme ou
motif du nœud), pas seulement dans un panneau : le joueur voit sa croissance avant de la lire
dans le chiffre.

### States and Transitions

Le stock n'a pas d'état propre, seulement des valeurs ; il ne change que par les fonctions de
ce système.

| Transition | Déclencheur | Fonction |
|---|---|---|
| Absent → valeur de départ | Mise en place (CRÉÉE) | initialisation (règle 10) |
| stock → min(stock + revenu, `ENERGIE_MAX`) | COMMENCER_LE_TOUR de la faction | créditer (REVENU) |
| stock → stock − montant | RÉVEILLER, RECHERCHER, MONTER_NŒUD appliquées | dépenser |
| stock inchangé | Commande refusée, ou aperçu sur une copie | — |

Tout autre système lit le stock mais ne l'écrit pas (modèle d'état, règle 2).

### Interactions with Other Systems

| # | Système | Ce qui circule | Propriétaire de l'interface |
|---|---|---|---|
| 1 | Modèle d'état | 10 écrit le champ « stock » de la tranche Factions et rien d'autre ; invariant ajouté à la validation : 0 ≤ stock ≤ `ENERGIE_MAX` | 1 pour la forme, 10 pour les écritures |
| 3 | Tours | 3 appelle le versement dans COMMENCER_LE_TOUR, pour le joueur et pour l'IA | 3 |
| 7 | Réveil | 7 possède les prix par type, valide, puis appelle `dépenser` ; il n'écrit jamais l'énergie | 7 pour les prix, 10 pour l'écriture |
| 9 | IA | Lit `disponible` et `revenu` de sa propre vue ; planifie ses dépenses dans son budget | 9 |
| 11 | Nœuds | 11 possède niveau et prix de montée ; 10 lit propriétaire et niveau pour le revenu | 11 pour les niveaux |
| 12 | Protocoles | 12 possède prix et durées ; l'énergie est débitée au démarrage de la recherche | 12 pour les prix |
| 17 | HUD | Lit stock, `revenu`, `revenu_détail` et « manque n » | 17 |
| 23 | Commandes | Appelle `dépenser` à l'application ; ÉNERGIE_INSUFFISANTE (besoin, disponible) est le seul refus de ce système ; MONTER_NŒUD est à ajouter | 23 |

## Formulas

*Proposées par systems-designer. Entiers seulement dans l'état ; les pourcentages et rapports ne
servent qu'aux mesures de test, jamais à une règle. Tous les chiffres de `assets/data/energie.*`
sont des valeurs de départ [PROP].*

### D.1 Revenu

The revenu formula is defined as:

`revenu(état, f) = Σ REVENU_NIVEAU[niveau(n)] pour tout nœud n dont propriétaire(n) = f`

**Variables:**

| Variable | Type | Range | Source | Description |
|---|---|---|---|---|
| f | faction | joueur, IA | calculated | Faction payée |
| niveau(n) | int | 1..3 | calculated (état, 11) | Niveau du nœud n |
| REVENU_NIVEAU | table d'entiers | {1 : 3, 2 : 4, 3 : 5} | data file | Revenu par niveau [PROP] |
| revenu | int | 0..30 | calculated | Revenu brut du tour |

**Output Range:** 0 (aucun nœud) à 30 (6 nœuds de niveau 3). Jamais négatif, jamais stocké ; les nœuds sont parcourus par identifiant croissant.
**Example:** 1 nœud de niveau 1 : 3. Niveaux 2, 1, 1 : 4 + 3 + 3 = 10 (tour 6 du croquis). 6 nœuds de niveau 3 : 30.

### D.2 Créditer avec plafond

The créditer formula is defined as:

`après = min(avant + montant, ENERGIE_MAX)` ; `surplus_perdu = avant + montant − après`

**Variables:**

| Variable | Type | Range | Source | Description |
|---|---|---|---|---|
| avant | int | 0..99 | calculated (état) | Stock avant |
| montant | int | ≥ 0 | calculated (D.1) | Revenu versé |
| ENERGIE_MAX | int | 60..99 | data file | Plafond (99) |
| après | int | 0..99 | calculated | Stock écrit |
| surplus_perdu | int | 0..montant | calculated | Énergie détruite |

**Output Range:** `après` ∈ [`avant`, `ENERGIE_MAX`] ; `surplus_perdu` = 0 tant que `avant + montant ≤ 99`.
**Example:** 90 + 15 → 99, surplus 6. 99 + 15 → 99, surplus 15 (`avant = après` : pas d'événement). 60 + 3 → 63, surplus 0.

### D.3 Dépenser, validation et manque

The dépenser formula is defined as:

`peut_dépenser = (montant ≤ stock)` ; `après = stock − montant` (si `peut_dépenser`) ;
`manque = max(0, besoin − disponible)`

**Variables:**

| Variable | Type | Range | Source | Description |
|---|---|---|---|---|
| montant, besoin | int | 1..35 | data file (7, 11, 12) | Prix de la commande (le plus haut au MVP : 35) |
| stock, disponible | int | 0..99 | calculated (état) | `disponible` = `stock` |
| après | int | 0..98 | calculated | Stock après débit |
| manque | int | 0..35 | calculated | Valeur affichée dans « manque n » |

**Output Range:** `après` ≥ 0 garanti par la condition ; `manque` = 0 signifie que la commande est payable et que le HUD n'affiche rien.
**Example:** tour 7 du croquis : disponible 11, besoin 12 (montée) → refus, `manque` = 1. Tour 8 : disponible 21, montant 12 → après 9.
*Contrainte :* `ENERGIE_MAX ≥ max(prix)` (35 aujourd'hui), sinon un prix serait inaccessible.

### D.4 Invariant du stock et rognage au chargement

The invariant formula is defined as:

`0 ≤ stock ≤ ENERGIE_MAX` ; au chargement : `stock' = min(stock_lu, ENERGIE_MAX)` si `stock_lu ≥ 0`, sinon rejet

**Variables:**

| Variable | Type | Range | Source | Description |
|---|---|---|---|---|
| stock_lu | int | tout entier | calculated (fichier) | Valeur lue |
| stock' | int | 0..99 | calculated | Valeur placée dans l'état |

**Output Range:** [0, 99], ou rejet du fichier si `stock_lu < 0` ou non entier.
**Example:** 120 lu → 99 (une trace au journal) ; −3 lu → fichier corrompu.

### D.5 Revenu cumulé sur 30 tours

The cumulative income formula is defined as:

`R30 = Σ_{t=1..30} revenu_t`

**Variables:**

| Variable | Type | Range | Source | Description |
|---|---|---|---|---|
| t | int | 1..30 | constant (`T_MAX`) | Tour de la faction |
| revenu_t | int | 3..30 | calculated (D.1) | Revenu du tour t, selon les nœuds possédés au début de t |

**Output Range:** 90 (1 nœud de niveau 1 tout du long) à 900 (6 nœuds de niveau 3).
**Example:** tours 1 à 10 du croquis : 3 + 3 + 6 + 6 + 9 + 10 + 10 + 10 + 11 + 11 = **79**. Tours 11 à 30 (chronologie
hypothétique, le GDD n'en donne pas) : 3 nœuds au niveau 2 : 20 × 12 = 240, soit R30 = 319 ; 3 nœuds au niveau 3 :
20 × 15 = 300, soit **379** ; 4 nœuds au niveau 2 : 20 × 16 = 320, soit **399** ; 4 nœuds en mélange (14) : 280, soit 359.

### D.6 Part du revenu perdue au plafond (mesure de test, tours 1 à 20)

The ceiling-loss formula is defined as:

`perte_plafond = Σ_{t=1..20} surplus_perdu_t / Σ_{t=1..20} revenu_t`

**Variables:**

| Variable | Type | Range | Source | Description |
|---|---|---|---|---|
| surplus_perdu_t | int | 0..30 | calculated (D.2) | Perte du tour t |
| revenu_t | int | 3..30 | calculated (D.1) | Revenu potentiel du tour t |
| perte_plafond | rapport | 0..1 | calculated | Métrique de test, jamais stockée |

**Output Range:** 0 à moins de 1 ; alerte au-delà de 5 % (plage 3 à 10 %), **sur les tours 1 à 20 seulement** : une perte avant le tour 21 signale un revenu trop généreux. La perte des tours 21 à 30 est relevée à part, sans alerte : elle est attendue (surplus accepté, ratio du catalogue de 1,37 à 1,46).
**Example:** stock 90 → 99 (perte 6) puis 99 → 99 (perte 15) : 21 sur 30 potentiels sur ces deux tours ; si ces deux tours
sont avant le tour 21, avec 199 de revenu potentiel sur les tours 1 à 20 (3 nœuds au niveau 2 : 79 + 120), la perte de 21 donne 10,6 %, soit une alerte ;
si elles tombent aux tours 28 et 29, la perte est relevée sans alerte.

### D.7 Catalogue d'achats et rapport

The catalogue formula is defined as:

`catalogue(n) = P + n × (M12 + M23) + W` ; `ratio(n) = R30 / catalogue(n)`

**Variables:**

| Variable | Type | Range | Source | Description |
|---|---|---|---|---|
| n | int | 3, 4, 6 | constant | Nœuds possédés dans le scénario |
| P | int | 140 | data file (12) | 15 + 15 + 20 + 25 + 30 + 35 |
| M12, M23 | int | 12, 20 | data file (11) | Montées 1→2 et 2→3 (32 par nœud) |
| W | int | 0..60 | data file (7) | Somme des prix de réveil ; référence 4 + 5 + 6 + 8 = 23 |
| R30 | int | 319..399 | calculated (D.5) | Revenu cumulé du scénario |

**Output Range:** catalogue(3) = 259, catalogue(4) = 291, catalogue(6) = 355.
**Example:** avec R30 propre au scénario : 379 / 259 = 1,46 (3 nœuds au niveau 3) ; 399 / 291 = 1,37 (4 nœuds au niveau 2).
Un rapport supérieur à 1 signifie que le surplus finit au plafond : c'est l'effet que ce GDD accepte et mesure.

| Réglage | Valeur | Plage sûre |
|---|---|---|
| `ENERGIE_MAX` | 99 | 60..99 |
| `ENERGIE_DEPART` | 6 | 4..10 |
| `REVENU_NIVEAU` | 3 / 4 / 5 | croissant strict, 2..8 |
| Alerte de stock moyen | 60 | 40..80 |
| Alerte de perte au plafond (tours 1 à 20) | 5 % | 3..10 % |
| Cible « manque n » (tours 1 à 15) | 3 à 5 tours | 2..7 tours |
| W de référence | 23 | 15..38 |

## Edge Cases

*Proposés par systems-designer ; les résolutions du 2026-10-30 sont intégrées.*

- **Si le montant est égal au stock** (stock 9, prix 9): `dépenser` réussit, stock 0, ÉNERGIE_CHANGÉE (9→0) est publié.
- **Si le stock vaut 0 et qu'un prix ≥ 1 est demandé**: refus ÉNERGIE_INSUFFISANTE (besoin = prix, disponible 0), manque = prix, rien d'écrit.
- **Si `dépenser` reçoit un montant de 0**: l'appelant est en faute (un prix de 0 n'appelle pas la fonction, règle 6) ; l'assertion échoue dans les tests ; en version livrée la fonction ne fait rien et ne publie rien.
- **Si `dépenser` ou `créditer` reçoit un montant négatif**: assertion, aucune écriture (règle 9) ; cela empêche de détourner `dépenser` en créditeur, que le plafond ne protège pas. Un `créditer` de 0 donne `avant = après` et aucun événement.
- **Si deux commandes drainent le stock puis qu'une troisième est refusée** (stock 10, réveil à 4): la 1re laisse 6, la 2e laisse 2, la 3e est refusée avec besoin 4, disponible 2, manque 2. Deux ÉNERGIE_CHANGÉE sont publiés, un par commande ; la 3e ne publie rien.
- **Si une commande est refusée** (structure ou énergie): aucune écriture, aucun identifiant consommé, aucun drapeau modifié, aucun événement ; un refus structurel passe avant le refus d'énergie, contrôle final (règle 7).
- **Si le revenu fait dépasser le plafond** (stock 90, revenu 15): le stock vaut 99, 6 sont perdus, le versement n'est pas refusé. À 99 avec un revenu de 15, rien ne change et aucun événement n'est émis.
- **Si une faction n'a aucun nœud**: revenu 0, aucun versement, aucun événement. En pratique l'état est bref : la faction est éliminée dans la commande qui lui prend son dernier nœud.
- **Si un nœud est capturé pendant le tour de la faction**: le stock ne bouge pas ; le nœud rapporte à partir du début du tour suivant de cette faction (règle 3). Un nœud capturé puis repris pendant la phase ennemie n'a jamais rapporté.
- **Si un nœud est perdu pendant la phase ennemie**: le stock courant est conservé ; la perte se voit au versement suivant, qui exclut ce nœud (le « +n » baisse).
- **Si c'est le début de la phase de l'IA**: elle est payée par la même fonction, pour son propre revenu ; l'événement est publié pour la faction IA, mais le HUD (17) ne montre que celle du joueur. Son stock n'est pas affiché ; le joueur déduit son revenu de ses nœuds visibles (le brouillard peut en cacher).
- **Si une faction est éliminée**: elle n'est pas payée ; son stock reste dans l'état et n'a aucun effet (pas dans le score).
- **Si un fichier de sauvegarde a un stock supérieur à `ENERGIE_MAX`**: rogné au plafond avec une trace au journal (D.4) ; la partie se charge.
- **Si un fichier de sauvegarde a un stock négatif ou non entier**: fichier rejeté comme corrompu (la validation de l'état, règle 14, échoue).
- **Si un aperçu s'exécute sur une copie**: `dépenser` ne modifie que la copie et ne publie rien ; le stock réel est identique avant et après.
- **Si un nœud est perdu après le début d'une recherche**: aucun remboursement (le prix a été payé à l'application) ; l'effet de la perte sur la recherche appartient à 12.
- **Si un déplacement est annulé**: aucun effet sur l'énergie, un déplacement ne coûtant rien (règle 8).
- **Si la même commande de réveil est répétée après un refus d'énergie**: même état, même refus tant que le stock n'a pas changé ; au versement suivant elle réussit si `disponible ≥ besoin` ; répétée après un réveil réussi, elle échoue avant le contrôle d'énergie (plus de drone endormi adjacent).
- **Si le besoin vaut stock + 1**: `manque` = 1 et l'on affiche « manque 1 » ; si le besoin ≤ stock, `manque` = 0, aucun message, le bouton est actif.
- **Si une grille de prix change entre la validation et l'application**: impossible — validation et application forment une seule opération atomique, et les grilles sont constantes pendant une partie (fichiers de données chargés à la mise en place).
- **Si un calcul semble demander un arrondi**: il n'y en a aucun, tout est entier (modèle d'état, règle 6) ; les rapports de D.6 et D.7 sont des métriques de test hors état.

### Cas à traiter dans d'autres GDD

- **23 Commandes**: ajouter MONTER_NŒUD (J, IA) avec NIVEAU_MAX et ÉNERGIE_INSUFFISANTE ; ÉNERGIE_CHANGÉE (faction, avant, après) n'a pas de raison : l'ajouter, ou retirer `raison` de la sortie de `dépenser` et `créditer`.
- **1 Modèle d'état**: ajouter l'invariant 0 ≤ stock ≤ `ENERGIE_MAX` à la validation ; documenter l'exception d'initialisation (règle 10) ; ajouter le versement de l'IA au début de sa phase à la table des états.
- **3 Tours**: préciser qu'une faction éliminée n'est pas payée et que l'énergie n'entre pas dans le score.
- **7 Réveil**: 7 possède la liste des prix (somme de référence 23).
- **11 Nœuds**: valider la grille 12 / 20 et le fait que la capture ne crédite rien.
- **12 Protocoles**: trancher si une recherche en cours survit à la perte d'un nœud ; confirmer l'absence de remboursement.
- **17 HUD**: `revenu_détail`, l'affichage « MAX » au plafond, et le filtrage des événements de l'IA.
- **`unites-drones.md`**: « le coût de réveil appartient à 7 et 10 » devrait dire que 7 possède la liste des prix et que 10 ne fait que débiter.
- **Carte (2)**: une chronologie de nœuds au-delà du tour 10 n'est pas donnée ; la courbe suppose 1 nœud de départ et quatre nœuds neutres.

## Dependencies

### En amont (ce système dépend de)

| Système | Nature | Dure ou souple |
|---|---|---|
| 1 Modèle d'état de partie | Tranche « Factions » (stock), entiers, invariants (`design/gdd/modele-etat-partie.md`) | Dure |
| 3 Tours et conditions de victoire | Déclenche le versement au début du tour de chaque faction (`design/gdd/tours-conditions-victoire.md`, §2) | Dure |

Le revenu lit aussi le propriétaire et le niveau des nœuds (11, sans GDD) : contrat provisoire.

### En aval (systèmes qui dépendent de lui)

| Système | Ce qu'il utilise | Dure ou souple |
|---|---|---|
| 7 Réveil | `dépenser`, `disponible` | Dure |
| 11 Nœuds | `dépenser` pour la montée ; son niveau et son propriétaire fondent le revenu | Dure |
| 12 Protocoles | `dépenser` au démarrage d'une recherche | Dure |
| 9 IA | `disponible`, `revenu` de sa vue | Dure |
| 17 HUD | Stock, revenu, `revenu_détail`, « manque n » | Dure |
| 23 Commandes | `dépenser` à l'application ; refus ÉNERGIE_INSUFFISANTE ; événement ÉNERGIE_CHANGÉE | Dure |

### Bidirectionnalité

- `design/gdd/modele-etat-partie.md`, `design/gdd/commandes-evenements.md`, `design/gdd/tours-conditions-victoire.md` et `design/gdd/unites-drones.md` citent déjà ce système.
- `design/ux/hud.md` doit citer ce document (`revenu_détail`, « MAX »).
- Les GDD 7, 9, 11, 12 et 17 doivent le citer à leur création.

### Décisions techniques renvoyées à un ADR

- Format du fichier de données `assets/data/energie.*`.
- Représentation du stock dans l'état (un entier par faction).

## Tuning Knobs

*Dans `assets/data/energie.*`. Valeurs de départ [PROP], à jouer en test.*

| Paramètre | Valeur | Plage sûre | Trop haut | Trop bas | Interagit avec |
|---|---|---|---|---|---|
| `ENERGIE_MAX` | 99 | 60..99 | Épargne dominante, affichage à deux chiffres dépassé | Un prix devient inaccessible (≥ prix le plus haut) | Grilles de prix (7, 11, 12) |
| `ENERGIE_DEPART` | 6 | 4..10 | Premier tour sans choix, trop de réveils d'emblée | Aucun réveil au tour 1 | Prix de réveil (7) |
| `REVENU_NIVEAU` niveau 1 | 3 | 2..4 | Le goulot disparaît (pilier 4) | Partie lente avant le premier nœud | Montée de nœud (11) |
| `REVENU_NIVEAU` niveau 2 | 4 | 3..6 | Montée trop rentable | La montée ne rapporte plus | Idem |
| `REVENU_NIVEAU` niveau 3 | 5 | 4..8 | Surplus perdu au plafond | Le niveau 3 est inutile | Plafond ; puits tardif |
| Alerte de stock moyen | 60 | 40..80 | — (mesure) | — | `ENERGIE_MAX` |
| Alerte de perte au plafond (tours 1 à 20) | 5 % | 3..10 % | — (mesure) | — | Revenu, catalogue |
| Cible « manque n » (tours 1 à 15) | 3 à 5 tours | 2..7 | — (mesure) | — | Prix de réveil et de protocole |

*Les prix (réveil, montée, protocoles) sont des réglages de 7, 11 et 12 ; la courbe de départ
ci-dessus les propose.*

## Visual/Audio Requirements

*Système `Economy` : section facultative, courte. Le rendu de l'élément d'énergie est possédé par
le HUD (`design/ux/hud.md`) et l'art bible (section 7).*

- **Visuel.** Icône d'éclair jaune dans l'interface, jamais sur la carte ; chiffres en JetBrains
  Mono 700 ; « +n » et « manque n » en blanc contourné ou en gris clair, sans vert ni ambre ni
  clignotement (art bible, section 7). Au plafond, le stock affiche « MAX ».
- **Audio.** Aucune information de jeu ne passe par un son (`design/accessibility-requirements.md`).
  Sons possibles et facultatifs : versement de début de tour, dépense, refus ; spécifiés avec le
  système 20.

## Game Feel

- **Le chiffre confirme, il n'annonce rien.** Quand un nœud est pris, la tuile se recolore
  aussitôt ; le « +n » ne monte qu'au début du tour suivant.
- **Décompte court.** Une dépense décompte le stock en 200 ms, sans clignotement (`hud.md`).
- **Un refus est immédiat et silencieux** : le bouton grisé dit « manque n » avant même
  l'appui ; aucune fenêtre d'erreur.

## UI Requirements

- **Élément d'énergie** (`design/ux/hud.md`) : pastille sombre, éclair jaune, stock en mono gras,
  « +n » en gris clair, « MAX » au plafond ; zone tactile de 48 dp ; un appui ouvre le détail du
  revenu par nœud (`revenu_détail`).
- **Boutons d'action** : coût sur le bouton de réveil ; « manque n » avec l'éclair quand
  l'énergie ne suffit pas, en gris clair à 4,5:1 au moins.
- **Lecteur d'écran** : le stock, le revenu et « manque n » sont annoncés comme du texte.

> 📌 **UX Flag — Énergie** : ce système a des exigences d'interface (élément d'énergie, détail du
> revenu, « manque n », « MAX »). En phase 4 (pré-production), lancer `/ux-design` pour ces
> éléments **avant** d'écrire les épopées.

## Cross-References

| Ce document cite | Document | Élément précis | Nature |
|---|---|---|---|
| Tranche « Factions », entiers, invariants, ordre d'itération | `design/gdd/modele-etat-partie.md` | Règles 2, 6, 8, 14 | Règle |
| Ordre du début de tour, `T_MAX` = 30, faction éliminée | `design/gdd/tours-conditions-victoire.md` | §2 ; règle 10 | Règle, valeur |
| ÉNERGIE_INSUFFISANTE, ÉNERGIE_CHANGÉE, validation puis application | `design/gdd/commandes-evenements.md` | Règles 2, 3, 8 | Règle |
| Réveil : prix par type, pas d'entretien | `design/gdd/unites-drones.md` | Règle 8 | Règle |
| Un nœud de départ et quatre nœuds neutres | `design/gdd/carte-tuiles-terrain.md` | Règle 15 | Valeur |
| Élément d'énergie, « manque n » | `design/ux/hud.md` | Énergie ; panneau d'unité | Intention |
| Éclair jaune, sans vert ni ambre | `design/art/art-bible.md` | Section 7 | Style |
| Pilier 1, pilier 3, pilier 4 | `design/gdd/game-concept.md` | Game Pillars | Intention |

## Acceptance Criteria

*Étiquettes : **Logic** = test unitaire dans `tests/unit/energie/`, sur un état construit par
fabrique ; **Intégration** = `tests/integration/energie/` ; **UI** = capture conservée dans
`production/qa/evidence/` ; [BLOQUÉ n] = attend le GDD du système n ; [ADR] = attend le format
de `assets/data/energie.*`. Une valeur non entière passée à `dépenser` ou `créditer` est une
erreur de type (paramètres typés `int`), jamais convertie.*

### Règles

- **AC-N1** (Logic, règle 1) **GIVEN** une fabrique à deux factions, **WHEN** on lit la tranche, **THEN** le stock est un entier dans [0, 99] pour chacune, sans champ d'entretien ; **GIVEN** les mêmes commandes pour le joueur et l'IA, **THEN** les mêmes résultats.
- **AC-N2** (Logic, règle 2) **GIVEN** `assets/data/energie.*`, **THEN** `ENERGIE_MAX` = 99, `ENERGIE_DEPART` = 6, `REVENU_NIVEAU` = {1 : 3, 2 : 4, 3 : 5} ; **GIVEN** `REVENU_NIVEAU[1]` = 4 dans la fabrique, **THEN** le revenu suit (aucune valeur en dur). [ADR]
- **AC-N3** (Logic, règle 3) **GIVEN** des nœuds de niveaux 2, 1, 1 à la faction, un neutre et un ennemi, **THEN** revenu = 10 ; **GIVEN** un nœud capturé pendant le tour, **THEN** le stock est inchangé et le revenu du tour suivant l'inclut ; deux appels de `revenu` donnent 10 sans écrire. [BLOQUÉ 11]
- **AC-N4** (Intégration, règle 4) **GIVEN** COMMENCER_LE_TOUR, **THEN** l'ordre est phase et faction, drapeaux à zéro, revenu, recherche ; le revenu est versé une seule fois ; l'IA est payée au début de sa phase par la même fonction ; une faction éliminée n'est pas payée. [BLOQUÉ 9, 12]
- **AC-N5** (Logic, règle 5) **GIVEN** un stock de 90, **WHEN** créditer 15, **THEN** le stock vaut 99 sans erreur ni refus.
- **AC-N6** (Logic, règle 6) **GIVEN** un stock de 10, **WHEN** dépenser 4, **THEN** `{ok, avant 10, après 6}` ; un montant supérieur au stock donne `{ok: faux, ÉNERGIE_INSUFFISANTE, besoin, disponible}` sans écriture ; un montant égal au stock est permis ; un montant négatif déclenche une assertion. [BLOQUÉ 23 : un appel au plus par commande]
- **AC-N7** (Logic, règle 7) **GIVEN** `disponible` et `peut_dépenser`, **THEN** l'état est identique avant et après (comparaison d'octets) ; **GIVEN** un RÉVEILLER structurellement invalide et sans énergie, **THEN** le refus est structurel, non `ÉNERGIE_INSUFFISANTE`. [BLOQUÉ 7, 12, 23]
- **AC-N8** (Logic, règle 8) **GIVEN** le code de jeu, **THEN** le versement de début de tour est le seul appelant de `créditer` (recherche statique, raison REVENU) ; **GIVEN** un déplacement annulé, **THEN** le stock est inchangé ; aucun remboursement après une perte de nœud. [BLOQUÉ 12]
- **AC-N9** (Logic, règle 9) **GIVEN** créditer −1 ou dépenser −1, **THEN** assertion, aucune écriture ; **GIVEN** un état à stock −1 ou 100, **THEN** la validation des invariants échoue.
- **AC-N10** (Logic, règle 10) **GIVEN** la mise en place, **THEN** chaque faction a un stock de 6, posé par la fonction d'initialisation ; recherche statique : aucune autre écriture du stock hors `dépenser` et `créditer`.
- **AC-N11** (Logic, règle 11) **GIVEN** créditer 90 + 15, **THEN** ÉNERGIE_CHANGÉE (90, 99) est construit par la commande et publié après elle ; **GIVEN** avant = après, **THEN** aucun événement ; **GIVEN** une copie de simulation, **THEN** rien n'est publié. [BLOQUÉ 23 : la `raison` de l'événement]
- **AC-N12** (Logic, règle 12) Recherche statique : le module de score ne lit pas le stock ; **GIVEN** deux états identiques à l'énergie près, **THEN** le score est identique.
- **AC-N13** (Logic + UI, règle 13) Logic : `revenu_détail` rend (identifiant, niveau, revenu) par identifiant croissant, de somme égale à `revenu`. UI : capture conservée du « +n » brut et du détail à l'appui. [BLOQUÉ 17]

### Formules (vecteurs déterministes)

- **AC-F1** (Logic, D.1) Un nœud de niveau 1 → 3 ; niveaux 2, 1, 1 → 10 ; six nœuds de niveau 3 → 30 ; aucun nœud → 0.
- **AC-F2** (Logic, D.2) 90 + 15 → 99, surplus 6 ; 99 + 15 → 99, surplus 15, aucun événement ; 60 + 3 → 63, surplus 0 ; 0 + 0 → aucun événement.
- **AC-F3** (Logic, D.3) Stock 9, prix 9 → après 0 ; stock 0, prix 1 → refus, manque 1 ; disponible 11, besoin 12 → refus, manque 1 ; disponible 21, montant 12 → après 9 ; besoin ≤ disponible → manque 0.
- **AC-F4** (Logic, D.4) Chargement de 120 → 99 avec une trace au journal ; 99 → 99 sans trace ; 0 → 0 ; −3 → rejet ; 5,5 → rejet.
- **AC-F5** (Logic, D.5) Revenus 3, 3, 6, 6, 9, 10, 10, 10, 11, 11 → 79 ; R30 = 319, 379, 399 et 359 pour les quatre scénarios du GDD.
- **AC-F6** (Logic, D.6) 21 de perte sur 199 de revenu potentiel (tours 1 à 20) : comparaison en entiers (21 × 100 > 5 × 199) → alerte ; la même perte aux tours 21 à 30 → relevée, sans alerte ; 0 de perte → pas d'alerte.
- **AC-F7** (Logic, D.7) catalogue(3) = 259, (4) = 291, (6) = 355 ; 379 / 259 → 1,46 et 399 / 291 → 1,37 à deux décimales (mesure hors état).
- **AC-F8** (Intégration, croquis) Jeu de commandes scripté : revenus 3, 3, 6, 6, 9, 10, 10, 10, 11, 11 et achats 5, 0, 4, 6, 12, 15, 0, 12, 15, 12 ; stock avant achat 9, 7, 13, 15, 18, 16, 11, 21, 20, 16 ; stock après chacun des dix tours **4, 7, 9, 9, 6, 1, 11, 9, 5, 4**. En attendant les systèmes 7, 11, 12 et 23, le test débite par `dépenser` direct.
- **AC-F9** (Logic, transversal) Aucun flottant dans le module (pas de `float`, de division non entière ni d'arrondi) ; mêmes états et mêmes commandes, même stock, par deux exécutions et comparaison d'octets.

### Cas limites

- **AC-E1** (Logic) Stock 9, prix 9 → stock 0 et ÉNERGIE_CHANGÉE (9, 0).
- **AC-E2** (Logic) Stock 0, prix ≥ 1 → refus (besoin = prix, disponible 0), rien d'écrit.
- **AC-E3** (Logic) Montant 0 → assertion dans les tests ; en version livrée, ni écriture ni événement ; créditer 0 → aucun événement.
- **AC-E4** (Intégration) Stock 10, réveil à 4 : première commande → 6, deuxième → 2, troisième refusée (besoin 4, disponible 2, manque 2) ; deux événements publiés, aucun pour la troisième. [BLOQUÉ 7, 23]
- **AC-E5** (Logic) Une commande refusée n'écrit rien : état identique octet pour octet, aucun identifiant consommé, aucun drapeau changé, aucun événement ; le refus structurel passe avant le refus d'énergie. [BLOQUÉ 7, 23]
- **AC-E6** (Logic) Faction sans nœud : revenu 0, aucun événement ; nœud perdu pendant la phase ennemie : stock conservé, le versement suivant exclut ce nœud ; nœud capturé puis repris pendant la phase ennemie : jamais payé. [BLOQUÉ 11]
- **AC-E7** (Intégration) L'IA est payée au début de sa phase, l'événement porte la faction IA ; une faction éliminée garde son stock inchangé. [BLOQUÉ 9 ; 17 pour le filtrage du HUD]
- **AC-E8** (Logic) Sauvegarde : stock 120 → 99 ; −3 ou non entier → rejet.
- **AC-E9** (Logic) Aperçu sur une copie : `dépenser` ne modifie que la copie ; le stock réel est identique et rien n'est publié.
- **AC-E10** (Intégration) Nœud perdu après le début d'une recherche : aucun crédit. [BLOQUÉ 12]
- **AC-E11** (Logic) Réveil répété après un refus : même état et même refus ; après un versement suffisant, réussite ; répété après réussite, échec structurel avant l'énergie. [BLOQUÉ 7]
- **AC-E12** (Logic) Besoin = stock + 1 → manque 1 ; besoin ≤ stock → manque 0.

### Propriété

- **AC-P1** (Logic) Graine fixe (constante du fichier de test), 1 000 séquences aléatoires de `créditer` et `dépenser` : 0 ≤ stock ≤ 99 après chaque opération, et un refus laisse l'état intact.

### UI

- **AC-UI1** (UI) Captures conservées de « manque 1 » (éclair, bouton grisé), de « manque n » avec n > 1 et de « MAX » au plafond (voir `design/ux/hud.md`). [BLOQUÉ 17]

### Non testable en l'état

- Règle 2 : la forme du fichier attend l'ADR. Règle 4 : l'ordre complet dépend de 12. Règle 11 : la `raison` de l'événement n'est pas définie en 23.
- Le fantasme « Le pouls de la meute » et le ton (JetBrains Mono 700, ni vert ni clignotement) relèvent de l'UI du HUD (17).
- Les mesures de playtest (cible « manque n », alerte de stock moyen) ne sont pas des critères d'acceptation.
- Tests Logic à écrire en premier, déjà débloqués : N1, N5, N9, N10, F1 à F7, F9, E1 à E3, E8, E9, E12, P1.

## Open Questions

| Question | Propriétaire | À résoudre avant | Résolution |
|---|---|---|---|
| Combien de niveaux de nœud (3 supposés) et un code de refus pour le niveau maximal ? | game-designer, economy-designer | GDD 11 | |
| Prix de réveil, de montée et de protocoles : la courbe de départ les propose, 7, 11 et 12 les possèdent. | economy-designer | GDD 7, 11, 12 | |
| Le « +n » du HUD affiche-t-il le brut ou le réellement versé au plafond ? | ux-designer | `/ux-design hud` | Provisoire : brut, « MAX » sur le stock |
| Une recherche en cours survit-elle à la perte d'un nœud ? | game-designer | GDD 12 | |
| Un puits tardif d'énergie (score, réparation) pour le surplus après le tour 22, **visible sur la carte** (pilier 1) et non un simple chiffre. | game-designer | Alpha | Accepté au MVP, mesuré |
| Le niveau d'un nœud est visible sur la carte (forme ou motif). | game-designer, art-director | GDD 11 | Exigence posée ici |
| Un scénario de carte disputée (l'IA prend les nœuds du centre) tient-il la cible « manque n » ? | economy-designer | Prototype | |
| Nombre d'unités de départ et type exact de chaque dormant (dépendent de la carte). | level-designer | Fichiers de cartes du MVP | |
| Le fragment avant le tour 5 dépend de la distance d'une ruine au départ, pas de l'énergie. | level-designer | GDD 13 | |
| Reporter dans 23 : MONTER_NŒUD ; `raison` de ÉNERGIE_CHANGÉE. | game-designer | Revue de 23 | |
| Reporter dans 1 : invariant du stock, exception d'initialisation, versement de l'IA dans la table des états. | lead-programmer | Revue de 1 | |
| Reporter dans 3 : une faction éliminée n'est pas payée ; l'énergie n'est pas dans le score. | game-designer | Revue de 3 | |
| Reporter dans `unites-drones.md` : 7 possède la liste des prix de réveil. | game-designer | Revue de 6 | |
