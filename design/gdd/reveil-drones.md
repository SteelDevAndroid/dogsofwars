# Réveil des drones

> **Status**: Designed (pending /design-review)
> **Author**: user + Claude (game-designer, systems-designer, art-director)
> **Last Updated**: 2026-10-30
> **Last Verified**: 2026-10-30
> **Implements Pillar**: Pilier 1 « La meute se voit grandir » ; pilier 5 « Le brouillard cache une question » ; pilier 3 « Lisible comme Polytopia »
> **Creative Director Review (CD-GDD-ALIGN)**: REVISED 2026-10-30 — CONCERNS (la composition fixe retirait le Rempart que le fantasme citait ; croissance de la meute épuisée aux premiers tours sans courbe énoncée ; disposition fixe apprise dès la deuxième partie ; dormants du côté de l'IA gratuits pour le joueur) corrigées : types des deux dormants tirés par zone à la mise en place, courbe de croissance énoncée, garde des dormants de l'IA posée en exigence bloquante pour 9 et 21

## Summary

Le réveil est la manière dont la meute grandit au MVP : un drone éveillé de la meute, posé à côté d'un
drone endormi, le réveille pour un prix en énergie fixe selon son type (Éclaireur 4, Ouvrier 5, Assaut 6,
Rempart 8), et le dormant rejoint sa faction, prêt au tour suivant. Le réveilleur est « terminé » ; aucune
tuile ne se recolore ; les Gardiens ne réveillent pas. Ce système existe pour que la croissance de la meute
soit un choix visible sur la carte (pilier 1) et que le brouillard cache une question (le type du dormant,
le chemin pour l'atteindre) plutôt qu'un piège (pilier 5).

> **Quick reference** — Layer: `Feature` · Priority: `MVP` · Key deps: `Unités drones, Énergie`

## Overview

Le réveil est la manière dont la meute grandit au MVP : un drone éveillé de la meute, posé à côté
d'un drone endormi, le **réveille** pour un prix en énergie, et le dormant rejoint la faction du
réveilleur. Ce système possède la **validation de la commande RÉVEILLER**, la **grille de prix** (par
type, fixe pendant toute la partie), l'événement `DRONE_RÉVEILLÉ` et la séquence visuelle de 0,6 s. La croissance de la meute par réveil est
voulue entre les tours 1 et 8 environ (règle 11) ; après, la croissance se lit en nœuds et en territoire.
Il appelle `dépenser` (`design/gdd/energie.md`) puis la fonction « réveiller »
(`design/gdd/unites-drones.md`, règle 8), qui reste l'unique écrivain de la tranche des unités :
`endormie` passe à faux, la faction devient celle du réveilleur, les PV, le type et la tuile ne
changent pas, et le drone réveillé est prêt au tour suivant.

Il n'y a **aucune recoloration de tuiles** au réveil (décision du 2026-10-30) : le territoire reste
écrit par les nœuds (11) et les ruines (13) ; la croissance de la meute se voit à la nouvelle unité
teintée de sa faction. Les Gardiens ne réveillent pas.

*Cadrage : à la fois la règle d'une commande (couche de données) et le moment fort du jeu pour le
joueur. Aucun ADR n'existe encore sur le réveil.*

## Player Fantasy

*Cadrage : direct. Retenu (`creative-director`, 2026-10-30) : « Qui répondra ? » comme identité,
« La silhouette sous le brouillard » comme texture d'un tour. Le moment du premier contact appartient
au Player Fantasy de `design/gdd/unites-drones.md` (« La réponse qu'elle attendait ») et au tutoriel.*

**Qui répondra ?** Il reste 9 d'énergie et deux dormants sont à portée : l'Éclaireur (4) et l'Ouvrier
(5) ce tour-ci, ou l'on garde tout pour le Rempart (8). Réveiller n'est pas acheter une unité : on choisit
la forme que prend la meute. Le drone réveillé n'agit qu'au tour suivant, donc réveiller engage le tour
d'après (piliers 1 et 3).

**La silhouette sous le brouillard.** Une marque de dormant apparaît sous le brouillard, sans type connu.
L'Éclaireur s'approche, la tuile se découvre : une carapace, un Rempart, non le mât espéré. La question
vient avant le choix (pilier 5), et l'on voit toujours le type avant de payer, la tuile étant découverte
dès qu'une unité est adjacente.

**Ton.** Sobre et mécanique. Verbes de l'ordre : *réveiller, rallier, tenir*. Aucun chiffre en grand,
aucune fanfare, aucun lexique d'achat (« acheter », « recruter », « coût ») : le prix est une dépense
d'énergie lue dans le HUD, non une boutique.

**Trois échecs à éviter.**
1. *Le menu d'achat* : la commande se donne sur la carte, à partir d'une unité adjacente, jamais depuis
   une liste.
2. *La loterie* : on ne paie jamais un type inconnu ; le hasard porte sur ce que cache le brouillard, non
   sur ce que l'on achète.
3. *La punition du dormant cher* : 8 pour un Rempart se lit « un tour à tenir pour l'avoir », non comme une
   taxe ; attendre est un choix, et le dormant ne part pas.

## Detailed Design

*Décisions du 2026-10-30 : seule la meute réveille, par n'importe quel type éveillé à distance 1 ; prix **fixe
par type** pendant toute la partie ; aucune recoloration au réveil ; le réveillé est prêt au tour suivant. Les
prix sont des valeurs de départ [PROP].*

### Core Rules

1. **Données.** `assets/data/reveil.*` contient `REVEIL_PRIX` = {Éclaireur : 4, Ouvrier : 5, Assaut : 6,
   Rempart : 8} [PROP]. Les prix sont des entiers ≥ 1, fixes pendant toute la partie, sans montée ni remise : le
   type du dormant donne le prix, et le joueur choisit quel dormant réveiller et quand, non un type. Contrôles au
   chargement : les quatre types sont présents, chaque prix est inférieur ou égal à `ENERGIE_MAX`, et tout
   dormant d'un fichier de carte est un type de la meute. Le prix est lu par `prix_réveil(état, faction, type)`,
   afin que 12 puisse un jour y poser un modificateur sans casser la règle « fixe pendant la partie ».
2. **Ordre de validation de RÉVEILLER** (paramètres : l'unité qui réveille, le drone endormi). Le premier échec
   est rendu ; tout se lit sur la vue de la faction (`design/gdd/commandes-evenements.md`, règle 6).

   | # | Code | Condition d'échec | Propriétaire |
   |---|---|---|---|
   | 1 | PARTIE_TERMINÉE | partie finie | 23 |
   | 2 | PAS_VOTRE_TOUR | hors de la phase de la faction | 23 |
   | 3 | UNITÉ_INCONNUE | l'émetteur n'a aucune unité de cet identifiant (un dormant, neutre, est inconnu) | 23 |
   | 4 | TYPE_NON_CAPABLE | l'unité n'est pas de la meute (un Gardien) | 7 |
   | 5 | DÉJÀ_AGI | « a agi » vrai | 6 |
   | 6 | AUCUN_DRONE_ADJACENT | la cible n'est pas, sur la vue de la faction, une unité visible, endormie, à Chebyshev 1 (diagonales comprises) | 7 |
   | 7 | ÉNERGIE_INSUFFISANTE (besoin, disponible) | `peut_dépenser` faux | 10 pour la lecture, 7 pour le prix |

   - **Cas du contrôle 6** : un identifiant inexistant, une unité non dormante, un dormant caché et un dormant à
     distance ≥ 2 donnent le **même code**, sans paramètre de tuile. Un dormant adjacent est toujours visible
     (vision minimale 2).
   - **DÉJÀ_AGI avant AUCUN_DRONE_ADJACENT** : il ne dépend que de l'émetteur et ne peut rien révéler
     (`unites-drones.md`, `energie.md` règle 7, `combat.md`).
   - MEUTE_COMPLÈTE est retiré de la ligne RÉVEILLER : un réveil ne crée pas d'unité, le total reste inchangé
     (`unites-drones.md`, formule 6).
3. **Application, atomique.** La validation a tout vérifié, donc l'application ne peut pas échouer :
   1. `dépenser(état, faction, prix_réveil, RÉVEIL)` ;
   2. « réveiller » (6) : `endormie` faux, faction = celle de l'émetteur, PV, type et tuile inchangés, **et** les
      drapeaux (le réveillé : « a bougé » et « a agi » vrais ; le réveilleur : « a agi » vrai), tous écrits dans
      cet appel, qui est l'unique écrivain de la tranche des unités ;
   3. `recalculer_vue` pour **les deux factions** : le bit 2 du dormant est effacé là où la tuile est visible ;
   4. événements en un lot, révision + 1 : ÉNERGIE_CHANGÉE, DRONE_RÉVEILLÉ (unité, par), puis TUILES_RÉVÉLÉES
      s'il y a lieu.
   Il n'y a ni recoloration, ni création, ni nouvel identifiant (le dormant en a déjà un). Un aperçu applique la
   même séquence sur une copie.
4. **Choix de la cible.** La commande **nomme** le dormant ; aucun choix automatique. Avec deux dormants adjacents,
   le joueur en nomme un : le réveilleur n'a qu'une action et l'autre reste endormi. Avec deux réveilleurs possibles
   pour un même dormant, celui qui est nommé agit ; l'autre garde son action, mais une commande ultérieure sur ce
   dormant donne AUCUN_DRONE_ADJACENT.
5. **Contextes permis.** Le terrain du réveilleur est sans effet (montagne et forêt permises) ; un dormant
   adjacent à un ennemi est réveillable (aucune zone de contrôle, le dormant n'est pas hostile) ; un déplacement
   préalable est permis. Le réveil **supprime l'instantané d'annulation** (motif AUTRE_ACTION_DEPUIS) : déplacer
   puis réveiller est définitif.
6. **Pas d'enchaînement.** Le réveillé a « a agi » vrai : il ne réveille pas dans le même tour, ce qui évite la
   boule de neige et borne le rythme à l'énergie et au nombre de réveilleurs.
7. **Un dormant sur un passage étroit** reste bloquant après le réveil (traverser une unité amie est interdit) ;
   le réveillé peut libérer le passage au tour suivant en se déplaçant.
8. **Aucun réveil par l'IA au MVP.** Les Gardiens ne réveillent jamais et l'IA n'émet jamais RÉVEILLER ; la colonne
   « J, IA » de la table de 23 vaut pour une IA qui jouerait une faction de la meute (hors MVP). Si un Gardien
   l'émettait malgré tout, la validation le refuserait au contrôle 4. L'énergie de l'IA trouve ses puits dans
   la montée de nœud (11) et les protocoles (12).
9. **Composition de la carte du MVP : un Ouvrier fixe, deux types tirés** (décision du 2026-10-30). Chaque camp a
   3 dormants, par symétrie de rotation de 180° : un **Ouvrier** fixe près du départ (garantie de capture), et deux
   autres — l'un près des nœuds disputés, l'autre derrière un terrain — dont le type est **tiré à la mise en place**
   parmi Éclaireur, Assaut et Rempart, avec la fonction de hasard de l'état (`design/gdd/modele-etat-partie.md`,
   formule 2), zone après zone dans l'ordre, avec remise. Le tirage est reproduit par la symétrie : les deux camps
   ont les mêmes types. Le fichier de carte donne donc, pour ces deux zones, la liste des types possibles et non un
   type fixe. Coût d'un camp : de 13 (Ouvrier 5, deux Éclaireurs 4) à 21 (Ouvrier 5, deux Rempart 8), soit de 15,3 %
   à 24,7 % de l'énergie disponible en dix tours (85). La variété vient du tirage, non d'un type imposé : le Rempart
   peut sortir, et la disposition change d'une partie à l'autre (pilier 5).
10. **Exigence bloquante pour 9 et 21 : les dormants du côté de l'IA sont gardés.** L'IA ne réveillant rien, ses
    trois dormants seraient un cadeau pour le joueur. Chaque dormant du côté de l'IA a donc au moins un Gardien à
    portée d'attaque d'un tour (à fixer avec la génération des cartes, 21) ; le GDD de l'IA (9) fait défendre ou
    punir un raid sur eux. Sans cela, le « juste mais dure » du pilier 4 ne tient pas.
11. **Courbe de croissance voulue.** La meute grandit par réveil seulement : de ses unités de départ à ces unités plus
    les dormants atteints, essentiellement entre les tours 1 et 8 (un camp dépense 13 à 21 énergie, soit jusqu'aux
    trois premiers revenus). Ensuite la croissance se lit en **nœuds et en territoire** (11, 13), non en unités ;
    sans production, la meute ne peut que diminuer après les réveils. La production aux nœuds est réservée à l'Alpha.

### States and Transitions

| État du dormant | Condition | Transition |
|---|---|---|
| Endormie | `endormie` vrai, neutre, PV pleins, ni attaquable ni soignable | → Terminée (RÉVEILLER appliquée) |
| Terminée (réveillée) | faction du réveilleur, « a bougé » et « a agi » vrais | → Éveillée prête au début du tour suivant de sa faction (remise à zéro des drapeaux) |

- Le dormant ne passe jamais directement à Détruite.
- Au tour suivant, l'unité peut DÉPLACER, ATTAQUER, CAPTURER (Ouvrier) ou RÉVEILLER (tout type, énergie permettant) ;
  elle ne se soigne pas ce tour-là (drapeaux vrais, `unites-drones.md`, règle 6).
- Pendant la phase ennemie intermédiaire, elle est une cible ordinaire ; aucune intention n'a pu la viser avant
  son réveil (CIBLE_NON_HOSTILE), si bien que le joueur voit toute annonce avant son exécution.
- Le réveilleur suit sa propre transition : → Terminée.

### Interactions with Other Systems

| # | Système | Ce qui circule | Propriétaire de l'interface |
|---|---|---|---|
| 1 | État | Écrit seulement via 6 et 10 ; le total d'unités reste inchangé ; à la mise en place, `N_départs + N_dormantes ≤ 60` et au moins deux Ouvriers dormants atteignables | 1 |
| 5 | Brouillard | Le réveillé devient source de vision dès l'étape 3 (Éclaireur 4, les autres 2) ; les tuiles INCONNUES de son champ passent à VISIBLE et TUILES_RÉVÉLÉES est émis ; l'autre faction garde le marqueur jusqu'à ce que la tuile soit visible pour elle | 5 |
| 6 | Unités | « réveiller » est l'unique écrivain de la tranche | 6 |
| 8 | Combat | Le dormant est CIBLE_NON_HOSTILE (CIBLE_NON_VISIBLE passe avant s'il est caché) | 8 |
| 9 | IA | Aucun réveil ; elle voit un réveil adverse seulement si la tuile est visible pour elle | 9 |
| 10 | Énergie | 7 possède la grille, 10 débite | 10 pour l'écriture, 7 pour le prix |
| 12 | Protocoles | Un protocole pourrait réduire les prix ou étendre le rayon de réveil (ouvert) ; passage par `prix_réveil` | 12 |
| 13 | Ruines | Aucun lien : une tuile porte un seul point d'intérêt | — |
| 17 | HUD | Bouton « Réveiller » (coût sur le bouton, « manque n », grisé avec le code traduit) ; pas de fenêtre de confirmation ; pas de toast | 17 |
| 23 | Commandes | Codes UNITÉ_INCONNUE, TYPE_NON_CAPABLE, DÉJÀ_AGI à ajouter, MEUTE_COMPLÈTE à retirer de la ligne RÉVEILLER | 23 |

### Courbe des prix (vérification de cohérence sur papier, non une mesure)

*Aucune donnée n'existe encore dans `assets/data/` : les chiffres viennent de `design/gdd/energie.md` [PROP].*

| Type | Prix | PV | Tours de revenu d'un nœud de niveau 1 | Lecture |
|---|---|---|---|---|
| Éclaireur | 4 | 6 | 1,3 | bon marché, vision 4 |
| Ouvrier | 5 | 7 | 1,7 | au-dessus de l'Éclaireur malgré des statistiques plus faibles : il est la clé de l'expansion (seul à capturer) |
| Assaut | 6 | 8 | 2,0 | le plus fort au combat |
| Rempart | 8 | 14 | 2,7 | meilleur rapport PV / prix (1,75 PV par énergie) |

- **Tour 1** : stock 6 + revenu 3 = 9, donc les quatre prix (≤ 8) sont payables ; deux réveils le même tour
  exigent deux réveilleurs, deux dormants accessibles et 9 au plus (Ouvrier 5 + Éclaireur 4 = 9 exactement).
- Sans revenu au tour 1, 6 suffit encore pour Éclaireur, Ouvrier et Assaut mais pas pour le Rempart ; avec
  `ENERGIE_DEPART` = 4 (borne basse), l'Ouvrier serait inabordable au tour 1 : contrainte croisée avec 10.
- Aucune dominance stricte entre les quatre types de la grille.

## Formulas

*Proposées par systems-designer ; tous les chiffres sont des valeurs de départ [PROP].*

### D.1 Prix de réveil

The prix_réveil formula is defined as:

`prix_réveil(type) = REVEIL_PRIX[type]`, avec le contrôle au chargement `1 ≤ REVEIL_PRIX[t] ≤ ENERGIE_MAX` pour les quatre types.

**Variables:**

| Variable | Type | Range | Source | Description |
|---|---|---|---|---|
| type | enum | {Éclaireur, Ouvrier, Assaut, Rempart} | data file (carte) | Type du dormant |
| REVEIL_PRIX | int | 1..99 | data file (`assets/data/reveil.*`) | Éclaireur 4, Ouvrier 5, Assaut 6, Rempart 8 [PROP] |
| ENERGIE_MAX | int | 99 | constant (`energie.md`) | Plafond du stock |
| prix | int | 4..8 | calculated | Montant passé à `dépenser` |

**Output Range:** entier de 1 à 99 ; un prix hors de cet intervalle fait échouer le chargement (un prix supérieur à 99 serait un refus permanent). La formule n'a pas d'autre entrée : le prix est fixe pendant la partie.
**Example:** Rempart → 8 ; Éclaireur → 4.

### D.2 Validité du réveil

The wake_validity formula is defined as:

`valide = c1 ∧ c2 ∧ c3 ∧ c4 ∧ c5 ∧ c6 ∧ c7` ; `code = code(min{ i : ci = faux })`

**Variables:**

| Variable | Type | Range | Source | Description |
|---|---|---|---|---|
| c1 | bool | {0, 1} | calculated | Partie non terminée (sinon PARTIE_TERMINÉE) |
| c2 | bool | {0, 1} | calculated | Phase de la faction (sinon PAS_VOTRE_TOUR) |
| c3 | bool | {0, 1} | calculated | L'émetteur est une unité de la faction (sinon UNITÉ_INCONNUE) |
| c4 | bool | {0, 1} | calculated | Type de la meute (sinon TYPE_NON_CAPABLE) |
| c5 | bool | {0, 1} | calculated | « a agi » faux (sinon DÉJÀ_AGI) |
| c6 | bool | {0, 1} | calculated | Cible visible sur la vue de la faction, endormie, Chebyshev = 1 (sinon AUCUN_DRONE_ADJACENT) |
| c7 | bool | {0, 1} | calculated | `peut_dépenser`, c'est-à-dire prix ≤ disponible (sinon ÉNERGIE_INSUFFISANTE, besoin, disponible) |

**Output Range:** booléen ; sinon exactement un code, le premier de l'ordre 1 à 7. Aucune écriture ; aucun refus ne dépasse la vue de la faction.
**Example (un refus par contrôle):** (1) victoire déclarée → PARTIE_TERMINÉE ; (2) commande émise en phase ennemie → PAS_VOTRE_TOUR ; (3) identifiant 99 absent → UNITÉ_INCONNUE ; (4) Gardien → TYPE_NON_CAPABLE ; (5) Ouvrier ayant déjà agi, dormant adjacent, stock 9 → DÉJÀ_AGI ; (6) dormant à distance 2 → AUCUN_DRONE_ADJACENT ; (7) Rempart (8), stock 6 → ÉNERGIE_INSUFFISANTE (8, 6).

### D.3 Énergie après réveil

The energy_after_wake formula is defined as:

`après = stock − prix` si `prix ≤ stock` ; `manque = max(0, prix − stock)`

**Variables:**

| Variable | Type | Range | Source | Description |
|---|---|---|---|---|
| stock (= disponible) | int | 0..99 | calculated (état) | Énergie de la faction avant la dépense |
| prix | int | 1..99 | data file | D.1 |
| après | int | 0..98 | calculated | Stock après la dépense |
| manque | int | 0..99 | calculated | Valeur de « manque n » |

**Output Range:** `après` ≥ 0 toujours ; `manque` = 0 si et seulement si le réveil est payable.
**Example:** Rempart 8, stock 6 → refus, manque 2, stock inchangé ; stock 9 → après 1. Deux réveils au même tour, stock 9 : Ouvrier 5 → 4, puis Éclaireur 4 → 0 (4 ≤ 4 réussit) ; un troisième réveil donne ÉNERGIE_INSUFFISANTE (besoin = prix, disponible 0). Même résultat dans l'ordre inverse (9 → 5 → 0).

### D.4 Coût de réveil par camp

The side_wake_cost formula is defined as:

`C = Σ prix(type_i)` sur les dormants du camp ; `part = C / B`, avec `B = Σ revenu(tours 1..10) + ENERGIE_DEPART`

**Variables:**

| Variable | Type | Range | Source | Description |
|---|---|---|---|---|
| C | int | 0..480 | calculated | Coût de tous les dormants d'un camp |
| Σ revenu | int | 79 | calculated (`energie.md`, D.5) | 3+3+6+6+9+10+10+10+11+11 |
| ENERGIE_DEPART | int | 4..10 | data file | 6 par défaut |
| B | int | 85 | calculated | Énergie totale disponible en 10 tours |

**Output Range:** 0 à 1 pour un camp raisonnable ; au-delà, la carte est impayable en dix tours.
**Example:** défaut 5 + 6 + 4 = 15 → 15 / 85 = 17,6 % (15 / 79 = 19,0 % sur le revenu seul). Variante 5 + 6 + 8 = 19 → 22,4 %. Les achats de réveil du croquis de `energie.md` (5 + 4 + 6 = 15) concordent.

### D.5 Invariant du total d'unités

The units_total_invariant formula is defined as:

`total = N_meute + N_IA + N_dormantes` ; réveil de la faction F : `N_F' = N_F + 1`, `N_dormantes' = N_dormantes − 1`, donc `total' = total`

**Variables:**

| Variable | Type | Range | Source | Description |
|---|---|---|---|---|
| N_meute, N_IA, N_dormantes | int | 0..60 | calculated | Unités par camp |
| MAX_UNITS | int | 60 | constant (`unites-drones.md`) | Borne |

**Output Range:** `total` ≤ 60 à la mise en place et pendant toute la partie ; un réveil ne le fait jamais bouger.
**Example:** 59 → 59 après un réveil ; 60 → 60 (accepté).

### D.6 Premier tour de réveil

The earliest_wake_turn formula is defined as:

`tour_min = max(1, ⌈C_chemin / MVT⌉)`, où `C_chemin` est le coût de déplacement jusqu'à une tuile adjacente au dormant

**Variables:**

| Variable | Type | Range | Source | Description |
|---|---|---|---|---|
| C_chemin | int | 0..∞ | calculated | Plaine = 1 par pas, diagonales permises ; tuile adjacente = distance − 1 |
| MVT | int | 1..3 | data file | Ouvrier 3 |
| tour_min | int | 1..30 | calculated | Tour du réveil, déplacement et réveil le même tour |

**Output Range:** ≥ 1 ; ne tient pas compte de l'énergie (D.3).
**Example:** dormant à distance 2 → C = 1 → tour 1 ; à distance 3 → C = 2 → tour 1. Le tour 1 est donc réalisable pour l'Ouvrier proche (stock 6 + 3 = 9 ≥ 5). Pour les deux autres dormants, aucune distance n'est fixée : à titre d'illustration, distance 7 → tour 2 ; distance 10 → tour 3 (le croquis les réveille aux tours 3 et 4). **Conflit carte :** `carte-tuiles-terrain.md`, règle 11, impose les dormants à au moins 3 tuiles de tout départ, tandis que la règle 15 et `energie.md` disent 2 ou 3 (voir Open Questions).

## Edge Cases

*Proposés par systems-designer ; les résolutions du 2026-10-30 sont intégrées.*

- **Si le stock est exactement égal au prix** (stock 5, Ouvrier 5): réveil accepté, stock 0, ÉNERGIE_CHANGÉE (5 → 0) ; le contrôle est `prix ≤ stock`, non strict.
- **Si le stock vaut prix − 1** (stock 7, Rempart 8): ÉNERGIE_INSUFFISANTE (8, 7), « manque 1 », rien d'écrit, le dormant reste endormi.
- **Si le dormant nommé est adjacent mais caché, ou si l'identifiant n'existe pas**: AUCUN_DRONE_ADJACENT, même code et sans paramètre ; un dormant adjacent est toujours visible (vision ≥ 2).
- **Si l'unité a déjà agi et que la cible est cachée ou lointaine**: DÉJÀ_AGI (contrôle 5 avant 6) ; il ne dépend que de l'émetteur et ne peut rien révéler.
- **Si le réveilleur est un Gardien**: TYPE_NON_CAPABLE (contrôle 4), même s'il a déjà agi.
- **Si l'émetteur est l'identifiant d'un dormant**: UNITÉ_INCONNUE (contrôle 3) ; un dormant est neutre, donc inconnu de la faction.
- **Si deux dormants sont adjacents**: seul le dormant nommé est réveillé ; le réveilleur a agi, l'autre reste endormi.
- **Si deux réveilleurs touchent le même dormant**: celui qui est nommé agit, l'autre garde son action ; une seconde commande sur ce dormant donne AUCUN_DRONE_ADJACENT (il n'est plus endormi).
- **Si un ennemi est adjacent au dormant**: réveil permis ; ni zone de contrôle ni hostilité du dormant.
- **Si le réveilleur est sur une montagne ou une forêt**: réveil permis ; le terrain est sans effet.
- **Si le réveilleur se déplace puis réveille**: l'instantané d'annulation est supprimé (motif AUTRE_ACTION_DEPUIS) ; le déplacement devient définitif, même s'il n'a rien révélé.
- **Si le joueur annule après le réveil**: ANNULER refusé avec AUTRE_ACTION_DEPUIS ; un réveil ne s'annule jamais et l'énergie n'est pas remboursée.
- **Si le réveillé reçoit un ordre le même tour**: DÉJÀ_AGI (« a agi » vrai) ; il ne réveille pas non plus.
- **Si le réveillé commence son premier tour**: prêt (drapeaux remis à zéro), tous les ordres permis ; aucun soin ce tour-là (drapeaux lus avant la remise à zéro), ses PV étant déjà pleins.
- **Si le réveillé bloque un passage étroit**: il bloque encore (une unité amie ne se traverse pas) et libère le passage au tour suivant en se déplaçant.
- **Si le réveil se fait au bord du brouillard**: le réveillé devient source de vision (Éclaireur 4, autres 2) ; TUILES_RÉVÉLÉES et, si un ennemi devient visible, son apparition sont publiés dans le même lot (ÉNERGIE_CHANGÉE, DRONE_RÉVEILLÉ, TUILES_RÉVÉLÉES) ; pour l'annulation, « a révélé » ne compte pas, l'instantané étant déjà supprimé.
- **Si l'autre faction réveille un dormant hors de la vue du joueur**: le marqueur (bit 2) du joueur reste affiché, dessiné comme un souvenir, jusqu'à ce que la tuile soit VISIBLE ; RÉVEILLER vers cet identifiant donne AUCUN_DRONE_ADJACENT. Aucune fuite.
- **Si une intention d'attaque a visé la tuile d'un dormant**: impossible, le dormant est CIBLE_NON_HOSTILE (CIBLE_NON_VISIBLE s'il est caché) ; aucune intention n'existe avant le réveil.
- **Si le total est 59 ou 60 au réveil**: réveil permis, le total ne change pas ; MEUTE_COMPLÈTE n'est jamais produite.
- **Si la partie est sauvegardée puis chargée juste après un réveil**: la tranche est identique (faction, `endormie` faux, drapeaux vrais, stock, révision) ; l'instantané n'est pas sauvegardé, donc l'annulation donne RIEN_À_ANNULER.
- **Si la même séquence de commandes est rejouée**: état identique à l'octet, révision + 1 par réveil, aucun tirage consommé.
- **Si l'IA a de l'énergie**: elle n'émet jamais RÉVEILLER ; son stock monte jusqu'à 99 (surplus perdu) et elle la dépense en montées de nœud et en protocoles. Ses dormants restent neutres : ceux de son côté sont à portée du joueur (voir Open Questions).

### Cas à traiter dans d'autres GDD

- **23 Commandes**: ligne RÉVEILLER à corriger (UNITÉ_INCONNUE, TYPE_NON_CAPABLE, DÉJÀ_AGI ajoutés ; MEUTE_COMPLÈTE retiré) ; événement DRONE_RÉVEILLÉ (unité, par) ; ordre des sept contrôles.
- **2 Carte**: règle 11 (au moins 3 tuiles) contre règle 15 (2 ou 3) ; règle 13 (le marqueur est remplacé) contredit le dormant-unité dès la mise en place.
- **6 Unités**: les drapeaux (réveillé : a bougé et a agi ; réveilleur : a agi) sont écrits dans « réveiller » ; la règle 8 doit citer ce périmètre.
- **10 Énergie**: le cas « réveil répété » renvoie à un échec structurel ; « `ENERGIE_DEPART` = 4 rend l'Ouvrier inabordable au tour 1 » n'est vrai que sans revenu (4 + 3 = 7 ≥ 5).
- **12 Protocoles**: modificateurs de `prix_réveil`, à garder dans 1 ≤ prix ≤ 99.
- **17 / `hud.md`**: bouton « Réveiller » avec coût et « manque n », sans toast ni confirmation ; 800 ms contre 0,6 s.
- **21 Générateur**: un dormant jamais voisin d'un nœud ; au moins deux Ouvriers dormants atteignables ; dormants du côté de l'IA exploitables par le joueur.

## Dependencies

### En amont (ce système dépend de)

| Système | Nature | Dure ou souple |
|---|---|---|
| 6 Unités drones | Fonction « réveiller », drapeaux, types, dormants (`design/gdd/unites-drones.md`) | Dure |
| 10 Énergie | `dépenser`, `disponible` (`design/gdd/energie.md`) | Dure |

Dépendances de contrat : 1 (tranche), 5 (vue de la faction, source de vision du réveillé), 23 (commande et événements).

### En aval (systèmes qui dépendent de lui)

| Système | Ce qu'il utilise | Dure ou souple |
|---|---|---|
| 9 IA | N'émet jamais RÉVEILLER au MVP ; lit les marqueurs de sa vue | Souple |
| 12 Protocoles | Modificateur éventuel de `prix_réveil` | Souple |
| 17 HUD | Bouton « Réveiller », coût, « manque n » | Dure |
| 21 Génération | Composition et placement des dormants | Dure |
| 23 Commandes | Validation et application de RÉVEILLER | Dure |

### Bidirectionnalité

- `design/gdd/unites-drones.md`, `design/gdd/energie.md`, `design/gdd/commandes-evenements.md` et `design/gdd/brouillard-vision.md` citent déjà ce système.
- `design/ux/hud.md` doit le citer (bouton, durée de 600 ms, absence de toast).
- Les GDD 9, 12, 17 et 21 doivent le citer à leur création.

### Décisions techniques renvoyées à un ADR

- Format du fichier de données `assets/data/reveil.*` et chargement avec contrôles.

## Tuning Knobs

*Dans `assets/data/reveil.*`. Valeurs de départ [PROP], à jouer en test.*

| Paramètre | Valeur | Plage sûre | Trop haut | Trop bas | Interagit avec |
|---|---|---|---|---|---|
| Prix d'un Éclaireur | 4 | 3..6 | Éclairer la carte devient un luxe | Trop de vision d'emblée (pilier 5) | Énergie départ, revenu (10) |
| Prix d'un Ouvrier | 5 | 4..7 | L'expansion tarde, la capture aussi | Aucun arbitrage au tour 1 | Capture (11), `ENERGIE_DEPART` |
| Prix d'un Assaut | 6 | 5..8 | Meute sans force offensive | Offensive trop précoce | Combat (8) |
| Prix d'un Rempart | 8 | 6..10 | Jamais réveillé | Tenue trop facile | Combat (8) |
| Composition des dormants par carte | Ouvrier fixe + 2 types tirés (Éclaireur, Assaut, Rempart) par camp | 3 par camp ; coût 13 à 21 | Meute trop vite grande (pilier 1) | Croissance étouffée | Carte (2), 21 |
| Durée de la séquence de réveil | 600 ms | 450..750 ms | Le tour traîne | Le moment fort passe inaperçu | Animations réduites (direct) |

*Les prix sont lus par `prix_réveil`, point d'entrée d'un éventuel modificateur de 12.*

## Visual/Audio Requirements

*Rédigé d'après la consultation de l'`art-director` du 2026-10-30 et l'art bible (sections 1, 2, 5, 7, 8).*

- **Séquence de 600 ms, en une passe.** 0 à 200 ms : le socle se lève de 2 pt et le trait se déplie ; 150 à 500 ms :
  la teinte de faction monte du socle vers le trait par le shader de saturation existant ; 500 à 600 ms : l'œil
  s'allume en dernier. Si le réveillé lève le brouillard, la lisière (200 ms) démarre à 400 ms et finit avec
  l'œil : la vision est la conséquence du réveil. **La caméra ne bouge pas** (ni recadrage, ni zoom, ni secousse).
  Les 800 ms de `design/ux/hud.md` (lignes 426 et 510) sont à corriger en 600 ms, une passe, sans « pulsation »
  que l'art bible exclut ; en animations réduites, l'état éveillé s'affiche directement.
- **« Terminé » puis « prêt ».** À la fin des 600 ms, l'œil reste allumé mais fixe et le contour est plein ; au
  début du tour suivant, l'unité retrouve l'état « prêt » ordinaire. Le réveillé n'a aucun état spécial et aucune
  nouvelle teinte.
- **Ciblage avant confirmation.** Des crochets blancs marquent le dormant nommé (la forme distingue le blanc
  « cible » ; l'hexagone reste réservé à la sélection du réveilleur) ; le contour pointillé gris du dormant est
  conservé ; des crochets discrets marquent les candidats quand deux dormants sont adjacents, pleins quand un seul
  l'est. C'est une marque, non un choix automatique, à valider par le ux-designer. Le bouton « Réveiller » porte
  l'icône d'énergie et le prix du dormant nommé ; grisé, il dit « manque n » (≥ 4,5:1) ; un appui suffit.
- **Le réveilleur.** « A agi » s'applique à t = 0 sans animation propre ; le compteur d'énergie est le seul élément
  du HUD qui bouge, au même moment ; pas de toast.
- **L'autre faction.** Hors de vue, elle ne voit rien et son marqueur de dormant reste un souvenir grisé ; si la
  tuile était visible, elle voit la même animation, à la teinte de la faction qui a réveillé ; à la redécouverte
  d'une tuile, l'état réel s'affiche sans rejouer l'animation.
- **Audio.** Un seul événement mérite un son : le réveil, en trois temps (montée mécanique, tonalité qui monte, petit
  allumage final), joué seulement s'il est visible pour le joueur et conservé en animations réduites. Ni l'énergie
  dépensée ni les refus n'ont de son. Aucune information de jeu ne passe par un son.

> 📌 **Asset Spec** — Visual/Audio requirements are defined. After the art bible is approved,
> run `/asset-spec system:reveil-drones` to produce per-asset visual descriptions, dimensions, and
> generation prompts from this section.

## Game Feel

- **Le moment fort du jeu.** Le réveil est court (600 ms), net, sans fanfare : la teinte monte, l'œil s'allume.
- **Réponse immédiate.** Un appui sur « Réveiller » lance la séquence sans fenêtre de confirmation.
- **Une seule chose bouge à la fois** dans le HUD : le compteur d'énergie, au moment du réveil.
- **Animations réduites** : l'état éveillé s'affiche directement, le son est conservé.

## UI Requirements

- **Bouton « Réveiller »** (`design/ux/hud.md`) : remplace « Capturer » quand un dormant est adjacent ; coût affiché
  sur le bouton ; grisé avec la raison (« manque n » ou le code traduit) ; un seul appui.
- **Dormant** : marqueur gris sous le brouillard, type inconnu jusqu'à la découverte de la tuile ; un appui affiche
  sa phrase et le prix de son réveil.
- **Aucun toast, aucune fenêtre de confirmation, aucun menu d'achat.**
- **Lecteur d'écran** : « dormant à n tuiles », le type quand il est connu, le prix et « manque n » sont annoncés comme
  du texte.

> 📌 **UX Flag — Réveil** : ce système a des exigences d'interface (bouton « Réveiller », ciblage par crochets,
> marqueur de dormant). En phase 4 (pré-production), lancer `/ux-design` pour ces éléments **avant** d'écrire les épopées.

## Cross-References

| Ce document cite | Document | Élément précis | Nature |
|---|---|---|---|
| « réveiller », dormants, drapeaux, total d'unités | `design/gdd/unites-drones.md` | Règles 1, 4, 8 ; formule 6 | Règle |
| `dépenser`, `disponible`, courbe de départ, `ENERGIE_MAX` | `design/gdd/energie.md` | Règles 6 et 7 ; D.3, D.5 | Règle, valeur |
| RÉVEILLER, codes de refus, annulation d'un déplacement | `design/gdd/commandes-evenements.md` | Table des commandes ; règles 6 et 15 | Règle |
| Marqueur de dormant, vue de la faction, refus identique | `design/gdd/brouillard-vision.md` | Règles 15 à 19 | Règle |
| Dormants : placement, nombre, distances | `design/gdd/carte-tuiles-terrain.md` | Règles 10, 11, 13, 15 | Valeur |
| Dormant non hostile | `design/gdd/combat.md` | Règle 10 | Règle |
| Séquence de réveil de 0,6 s, dormant | `design/art/art-bible.md` | Section 5 | Style |
| Bouton « Réveiller » | `design/ux/hud.md` | Panneau d'unité | Intention |
| Pilier 1, pilier 3, pilier 5 | `design/gdd/game-concept.md` | Game Pillars | Intention |

## Acceptance Criteria

*Étiquettes : **Logic** = `tests/unit/reveil/` sur un état construit par fabrique ; **Intégration** =
`tests/integration/reveil/` ; **UI** et **Visuel** = capture conservée dans `production/qa/evidence/`, validée par
l'art-director ; **Appareil** = sur l'appareil cible. [BLOQUÉ n] = attend le système n. AC-RV1 à RV9 suivent les
règles 1 à 9.*

### Règles

- **AC-RV1** (Logic, règle 1) **GIVEN** `assets/data/reveil.*`, **WHEN** il est chargé, **THEN** `prix_réveil` rend 4 (Éclaireur), 5 (Ouvrier), 6 (Assaut), 8 (Rempart), tous entiers ≥ 1 ; **GIVEN** un type absent, un prix > `ENERGIE_MAX`, ou un dormant de carte hors des quatre types de la meute, **THEN** le chargement échoue. (Format et clés de `reveil.*` à fixer.)
- **AC-RV2** (Logic, règle 2) voir AC-RV10 à RV16.
- **AC-RV3** (Logic, règle 3) voir AC-RV17 à RV22.
- **AC-RV4** (Logic, règle 4) **GIVEN** deux dormants adjacents au réveilleur, **WHEN** il en nomme un, **THEN** seul celui-là se réveille, l'autre reste endormi et neutre ; **GIVEN** deux réveilleurs possibles pour un dormant, **WHEN** l'un est nommé, **THEN** il a agi, l'autre garde son action, et une seconde commande sur ce dormant donne AUCUN_DRONE_ADJACENT.
- **AC-RV5** (Logic, règle 5) **GIVEN** un réveilleur en montagne, puis en forêt, **THEN** le réveil est permis ; **GIVEN** un dormant adjacent à un ennemi, **THEN** il est réveillable ; **GIVEN** un déplacement puis le réveil, **THEN** l'instantané d'annulation est supprimé et ANNULER donne AUTRE_ACTION_DEPUIS.
- **AC-RV6** (Logic, règle 6) **GIVEN** un dormant réveillé ce tour, **WHEN** il émet RÉVEILLER, DÉPLACER, ATTAQUER ou CAPTURER, **THEN** DÉJÀ_AGI ; **GIVEN** le tour suivant de sa faction, **THEN** ses drapeaux sont remis à zéro, il peut agir et ses PV sont inchangés (aucun soin).
- **AC-RV7** (Logic, règle 7) **GIVEN** un dormant seul dans un couloir d'une tuile, **THEN** il bloque le passage avant et après son réveil, et le libère quand il se déplace au tour suivant.
- **AC-RV8** (Logic, règle 8) **GIVEN** un Gardien qui émet RÉVEILLER, **THEN** TYPE_NON_CAPABLE ; **GIVEN** une partie du MVP sur graine fixe, **THEN** l'IA n'émet aucun RÉVEILLER sur 20 tours. [BLOQUÉ 9 pour la partie IA]
- **AC-RV9** (Logic, règle 9) **GIVEN** la carte par défaut et une graine fixe, **THEN** 3 dormants par camp, symétriques par rotation de 180° ; un Ouvrier près de chaque départ ; les deux autres de chaque camp ont un type de {Éclaireur, Assaut, Rempart}, identique des deux côtés ; le coût d'un camp est compris entre 13 et 21 ; **GIVEN** la même graine deux fois, **THEN** les mêmes types ; **GIVEN** des graines différentes, **THEN** au moins deux dispositions distinctes sur 20 graines.
- **AC-RV9b** (Logic, règle 10) **GIVEN** une carte du MVP, **THEN** chaque dormant du côté de l'IA a au moins un Gardien à portée d'attaque d'un tour ; **GIVEN** un raid du joueur sur l'un d'eux, **THEN** l'IA annonce une intention contre le raideur. [BLOQUÉ 9, 21]

### Ordre de validation (premier échec rendu)

- **AC-RV10** (Logic, règle 2) **GIVEN** partie finie ET hors tour, **THEN** PARTIE_TERMINÉE (et non PAS_VOTRE_TOUR).
- **AC-RV11** (Logic, règle 2) **GIVEN** hors tour ET émetteur inconnu, **THEN** PAS_VOTRE_TOUR.
- **AC-RV12** (Logic, règle 2) **GIVEN** un émetteur dormant (neutre) ou un identifiant inexistant, **THEN** UNITÉ_INCONNUE, avant TYPE_NON_CAPABLE. [BLOQUÉ 23 : code à ajouter]
- **AC-RV13** (Logic, règle 2) **GIVEN** un Gardien ayant déjà agi, **THEN** TYPE_NON_CAPABLE (et non DÉJÀ_AGI). [BLOQUÉ 23]
- **AC-RV14** (Logic, règle 2) **GIVEN** un réveilleur « a agi » ET une cible invisible, **THEN** DÉJÀ_AGI avant AUCUN_DRONE_ADJACENT. [BLOQUÉ 23]
- **AC-RV15** (Logic, règle 2) **GIVEN** un dormant caché, un identifiant inexistant, une unité non dormante, ou un dormant à distance 2, **THEN** AUCUN_DRONE_ADJACENT, sans paramètre de tuile, avec une réponse identique à l'octet dans les quatre cas ; un dormant adjacent est visible (vision minimale 2) et passe ce contrôle.
- **AC-RV16** (Logic, règle 2) **GIVEN** une cible valide ET énergie < prix, **THEN** ÉNERGIE_INSUFFISANTE (besoin = prix, disponible = stock), et l'état, la révision et les événements sont inchangés ; **GIVEN** stock = prix (4, 5, 6, 8), **THEN** le réveil est accepté.

### Application atomique

- **AC-RV17** (Logic, règle 3) **GIVEN** un réveil valide d'un Ouvrier (5) avec stock 9, **THEN** stock 4 ; `endormie` faux ; faction du réveilleur ; PV pleins, type et tuile inchangés ; « a bougé » et « a agi » vrais pour le réveillé ; « a agi » vrai pour le réveilleur.
- **AC-RV18** (Logic, règle 3) **THEN** l'instantané d'annulation est supprimé (AUTRE_ACTION_DEPUIS) et la révision augmente de 1 exactement.
- **AC-RV19** (Logic, règle 3) **THEN** `recalculer_vue` est appelée une fois par faction (doublure = 2) ; le réveillé devient source de vision (Éclaireur 4, autres 2) ; ses tuiles INCONNUES passent à VISIBLE.
- **AC-RV20** (Logic, règle 3) **THEN** un seul lot : ÉNERGIE_CHANGÉE, DRONE_RÉVEILLÉ (unité, par), puis TUILES_RÉVÉLÉES seulement si des tuiles sont révélées. [BLOQUÉ 23 : format des événements]
- **AC-RV21** (Logic, règle 3) **THEN** le total d'unités est inchangé, aucun nouvel identifiant, y compris à 59 et 60 unités ; MEUTE_COMPLÈTE n'est jamais produit. [BLOQUÉ 23 : retrait de la ligne RÉVEILLER]
- **AC-RV22** (Logic) **THEN** aucune tuile ne change de propriétaire (territoire inchangé, aucune recoloration).

### Comportements

- **AC-RV23** (Logic) **GIVEN** un dormant éveillé par A hors de vue de B, **THEN** le bit 2 de B reste posé jusqu'à ce que la tuile soit VISIBLE pour B, puis il est effacé (voir AC-BR37).
- **AC-RV24** (Logic) **GIVEN** tour 1, stock 6 + revenu 3 = 9, deux réveilleurs et deux dormants, **THEN** Ouvrier (5) + Éclaireur (4) est accepté, stock 0, et un troisième réveil donne ÉNERGIE_INSUFFISANTE ; **GIVEN** stock 6 sans revenu, **THEN** Rempart refusé (besoin 8, disponible 6), Éclaireur, Ouvrier et Assaut acceptés.
- **AC-RV25** (Logic) **GIVEN** une partie complète, **THEN** `prix_réveil` rend les mêmes valeurs à chaque tour (aucune montée ni remise).
- **AC-RV26** (Logic) Même état et même commande, deux exécutions : octets identiques ; recherche statique : aucun flottant dans le module.
- **AC-RV27** (Logic) Réveil, sauvegarde, chargement, resérialisation : état identique à l'octet.
- **AC-RV28** (Intégration) Un Éclaireur se déplace vers un dormant puis le réveille : la chaîne vue, énergie, unités, événements est cohérente sur la vue du joueur.

### Visuel, UI, Appareil

- **AC-RV29** (Visuel) Capture conservée de la séquence de 0,6 s (début, milieu, fin) : la base monte, la teinte de faction monte, l'œil s'allume en dernier ; animations réduites : l'état éveillé s'affiche directement.
- **AC-RV30** (UI) Captures du bouton « Réveiller » : (a) actif, coût affiché ; (b) grisé avec « manque n » (stock 3, Ouvrier : « manque 2 ») et le code traduit ; (c) ni fenêtre de confirmation ni toast. [BLOQUÉ 17]
- **AC-RV31** (Appareil) Durée d'un RÉVEILLER appliqué, deux recalculs de vue compris, dans le budget du brouillard (AC-BR47). (Budget à mesurer.)

### Non testable en l'état

- Règle 4 (pas d'automatisme, vérifié par ses deux cas), règle 8 (négation sur l'IA, échantillon de tours) et règle 9 (proposition au level-designer, non contraignante).
- Systèmes 12 (prix et rayon « ouverts ») et 21 (lien non établi) : aucun critère avant leurs GDD.
- Codes manquants en 23 : UNITÉ_INCONNUE, TYPE_NON_CAPABLE, DÉJÀ_AGI (RV12 à RV14), format du lot (RV20), retrait de MEUTE_COMPLÈTE (RV21).

## Open Questions

| Question | Propriétaire | À résoudre avant | Résolution |
|---|---|---|---|
| Dormants à 2 ou 3 tuiles d'un départ : `carte-tuiles-terrain.md` règle 11 (au moins 3) contre règle 15 et `energie.md` (2 ou 3). | level-designer | Revue de 2 | |
| Fichier de carte : pour les deux zones à type tiré, liste des types possibles à la place d'un type fixe (`carte-tuiles-terrain.md`, règle 14) ; ordre et symétrie du tirage. | level-designer | Revue de 2 et GDD 21 | Posé |
| Dormants du côté de l'IA : gardés par au moins un Gardien à portée d'un tour (règle 10) ; comment l'IA punit un raid (intention contre le raideur). | game-designer, ai-programmer | GDD 9 et 21 (bloquant) | Posé |
| Nombre et types des unités de départ de chaque camp (au moins un Ouvrier). | level-designer | Fichiers de cartes du MVP | |
| Modificateurs de prix par les protocoles (12) ou rayon de réveil étendu. | game-designer | GDD 12 | Provisoire : aucun |
| Ciblage : crochets sur les candidats, pleins quand un seul dormant est adjacent. | ux-designer | `/ux-design hud` | Proposition |
| Événement DRONE_RÉVEILLÉ de l'autre faction hors de vue : omis ou générique (brouillard, règle 20). | game-designer | Revue de 23 | |
| Reporter dans 23 : codes UNITÉ_INCONNUE, TYPE_NON_CAPABLE, DÉJÀ_AGI, retrait de MEUTE_COMPLÈTE ; dans `hud.md` : 600 ms au lieu de 800 ms, pas de toast. | game-designer, ux-designer | Revue de 23 et `/ux-design hud` | |
