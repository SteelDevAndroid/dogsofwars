# Combat

> **Status**: Designed (pending /design-review)
> **Author**: user + Claude (game-designer, systems-designer, art-director)
> **Last Updated**: 2026-10-30
> **Last Verified**: 2026-10-30
> **Implements Pillar**: Pilier 4 « La puissance se mérite » (l'aperçu est le résultat) ; pilier 3 « Lisible comme Polytopia » ; pilier 1 « La meute se voit grandir »
> **Creative Director Review (CD-GDD-ALIGN)**: REVISED 2026-10-30 — CONCERNS (un soin entre l'annonce et l'exécution d'une attaque de l'IA faussait la lecture « ma unité survit » ; sens de l'avantage du premier coup à renvoyer au GDD de l'IA) corrigées : l'attaquant d'une intention annoncée ne se soigne pas (règle 6 des unités, GDD 6 mis à jour), marqueur « létale » possible, avantage du premier coup renvoyé à 9 et au playtest

## Summary

Le combat résout une attaque entre deux unités : les dégâts sont proportionnels aux PV restants de
l'unité qui frappe, amortis par sa défense et celle de la tuile de la cible, puis la cible qui
survit riposte avec la même formule si l'attaquant est à sa portée. Tout est en entiers et sans
tirage : l'aperçu montré avant le second appui est exactement le résultat. L'IA n'attaque que par
des intentions annoncées au tour précédent. Ce système existe pour que chaque perte soit lisible et
évitable (pilier 4) et que la meute se mesure à ses pertes sur la carte (pilier 1).

> **Quick reference** — Layer: `Feature` · Priority: `MVP` · Key deps: `Carte en tuiles et terrain, Unités drones`

## Overview

Le combat résout une attaque d'une unité contre une autre : il calcule les dégâts, la riposte
éventuelle et les destructions, puis écrit les PV par la fonction « modifier les PV » du
système des unités (`design/gdd/unites-drones.md`). Il ne possède ni les PV ni les statistiques,
seulement la **fonction pure** qui, à partir de l'état, rend la liste ordonnée de ce qui se passe.
Cette fonction est **déterministe** et ne tire aucun hasard (`design/gdd/modele-etat-partie.md`,
règle 7) : l'aperçu que le HUD affiche est la commande appliquée sur une copie
(`design/gdd/commandes-evenements.md`, règle 7), donc le résultat exact.

Les dégâts sont **proportionnels aux PV restants** (décision du 2026-10-30, comme Polytopia) : une
unité blessée frappe plus faiblement, la défense vient du type et de la tuile, et la cible qui
survit riposte avec la même formule si l'attaquant est à sa portée. Tout est entier. Le combat
fournit aussi le compteur « unités détruites » du score. L'IA attaque par les mêmes commandes que
le joueur, et seulement au titre d'une intention annoncée au tour précédent.

*Cadrage : à la fois la fonction pure (couche de données) et son effet pour le joueur (l'aperçu
fiable). Aucun ADR n'existe encore sur le combat.*

## Player Fantasy

*Cadrage : direct. Retenu (`creative-director`, 2026-10-30) : « Le calcul tenu » comme cœur,
« L'intention déjouée » comme écho, « Le gris, c'est la perte » comme coût.*

**Le calcul tenu.** Le joueur lit « Inflige −7 / Riposte −2 », compare avec une autre tuile, puis
confirme au second appui. Le résultat est exactement celui qui était annoncé : la satisfaction
vient d'avoir bien choisi, non de la chance (piliers 4 et 3). *Chaque attaque est un ordre dont on
connaît l'issue avant de le donner.*

**L'intention déjouée.** Le carré hachuré orange-rouge vise un drone ; le joueur l'écarte, l'attaque
annoncée tombe dans le vide et la meute reste entière : « un joueur attentif peut éviter toute
perte annoncée » (pilier 4).

**Le gris, c'est la perte.** Un drone perdu faute d'avoir lu une intention : son unité perd sa
teinte vers le gris puis s'affaisse (art bible, section 5). Ni sang ni débris : une conséquence
visible et méritée (pilier 1).

**Ton.** Sobre, registre machine : *inflige, riposte, détruit, hors de portée*. Aucun vocabulaire
héroïque, aucun gore ; la jauge blanche est le seul signe des dégâts.

**Trois échecs à éviter.**
1. *Le tableur* : l'aperçu tient en deux chiffres, pas en une formule à lire.
2. *La boule de neige* : avec des dégâts proportionnels aux PV, le premier coup peut tout décider ;
   la riposte et la tuile doivent toujours donner une réponse à la cible blessée.
3. *Le soupçon de dés cachés* : toute frappe de l'IA se rattache à une intention publiée ; le
   combat ne tire aucun hasard.

**Tension résolue.** « Attaque et contre-attaque » ne doit pas glisser vers l'échange en chaîne
que refuse l'anti-pilier contre le temps réel : une seule riposte, l'attaquant a fini son tour, et
l'IA agit avec un tour de retard. Le combat reste un échange de coups, non une mêlée.

## Detailed Design

*Décisions du 2026-10-30 : combat déterministe sans tirage ; dégâts **proportionnels aux PV restants** de
l'unité qui frappe, en entiers ; la cible qui survit riposte avec la même formule si l'attaquant est à
sa portée ; attaquer termine l'unité. Les valeurs chiffrées sont des valeurs de départ [PROP], à
jouer en test.*

### Core Rules

**Constantes** (`assets/data/combat.*`, jamais en dur) : `DMG_SCALE` = 2, `DEF_BASE` = 4,
`DMG_MIN` = 1, `DEF_PER_TILE_CLASS` = 1.

1. **Fonction pure.** `résoudre_attaque(état, attaquant_id, cible_id)` lit l'état, n'appelle aucun
   tirage, n'appelle que `modifier_pv` (`design/gdd/unites-drones.md`, règle 9) et la mise à jour du
   compteur, et rend la liste ordonnée d'événements. Mêmes entrées, mêmes sorties, sur tout appareil.
2. **Attaque effective.** `ATQ_eff` = ATQ du type de l'attaquant. La tuile de l'attaquant n'ajoute rien
   à son attaque (voir règle 5).
3. **Défense effective.** `DÉF_eff` = DÉF du type du défenseur + `DEF_PER_TILE_CLASS` × classe de défense
   de la tuile du défenseur (plaine 0, forêt 1, montagne 2, `design/gdd/carte-tuiles-terrain.md`,
   règle 9). `DÉF_eff` va de 0 à 4. Ce système possède la valeur du bonus de tuile.
4. **Dégâts, en entiers, une seule division.**
   - Si `ATQ_eff` = 0 : dégâts = 0 (aucun coup, aucun événement de coup).
   - Sinon : `dégâts = max(DMG_MIN, (DMG_SCALE × DEF_BASE × ATQ_eff × PV_att) // (PV_max_att × (DEF_BASE + DÉF_eff)))`,
     où `PV_att` sont les PV courants de l'unité qui frappe au moment du coup, et `PV_max_att` les PV
     max de son type. Le plancher n'est appliqué qu'une fois, à la fin ; tous les opérandes sont
     positifs.
   - Lecture : `PV_att / PV_max_att` est la proportionnalité décidée ; `DEF_BASE / (DEF_BASE + DÉF_eff)`
     est l'amortissement de la défense (DÉF 0 = 100 %, 2 = 67 %, 4 = 50 %), multiplicatif plutôt que
     soustractif : avec des ATQ de 1 à 3, une soustraction rendrait la plupart des défenses invulnérables.
   - **Minimum 1 si ATQ > 0**, riposte comprise : sans plancher, une unité blessée ou un Éclaireur contre
     une montagne pourrait infliger 0, d'où des unités invulnérables et un « −0 » illisible
     (pilier 3). Le soin au repos (2 PV) ne rend donc jamais une unité inattaquable.
   - Coup maximal : 6 (ATQ 3, PV pleins, `DÉF_eff` 0). Seul l'Éclaireur (6 PV) tombe en un coup, et
     seulement sur plaine à PV pleins.
5. **La tuile de l'attaquant : aucun bonus d'attaque, mais un bonus de défense contre la riposte.** La
   riposte frappe l'attaquant, qui devient défenseur de ce coup : la règle 3 s'applique alors à SA tuile.
   Attaquer depuis une forêt ou une montagne ne renforce pas le coup, mais protège de la riposte. Une
   seule règle (« la défense vient de la tuile du défenseur »), sans second bonus à apprendre.
6. **Ordre d'une attaque** (une commande, application sans échec) :
   1. calculer `d1` sur l'état courant (attaquant, cible, tuile de la cible) ;
   2. `modifier_pv(cible, −d1, source = attaquant)` ;
   3. l'attaquant passe à « a agi » (« a bougé » inchangé) ;
   4. si la cible est détruite : compteur +1 pour la faction de l'attaquant, **aucune riposte**, fin ;
   5. sinon, riposte si `ATQ(cible)` > 0 ET la distance de Chebyshev ≤ la portée de la cible : `d2` calculé
      par la règle 4 sur l'état APRÈS le premier coup (PV courants de la cible, `DÉF_eff` de l'attaquant
      sur sa propre tuile), puis `modifier_pv(attaquant, −d2, source = cible)` ;
   6. si l'attaquant est détruit par la riposte : compteur +1 pour la faction de la cible.
   Une riposte n'est jamais suivie d'une contre-riposte. Recevoir un coup ou une riposte ne change aucun
   drapeau. Une destruction ne retire l'unité qu'après le calcul de ce coup.
7. **Événements, dans l'ordre** (publiés en un lot après la commande, `design/gdd/commandes-evenements.md`,
   règle 8) : `ATTAQUE_RÉSOLUE` (attaquant, cible) ; `UNITÉ_TOUCHÉE` (cible, dégâts, PV restants) ; si
   détruite, `UNITÉ_DÉTRUITE` (cible, tuile, par) et fin ; sinon, si riposte, `UNITÉ_TOUCHÉE` (attaquant),
   puis `UNITÉ_DÉTRUITE` si l'attaquant tombe. Le champ « dégâts » porte les **PV réellement perdus**
   (avant − après), non la valeur brute. L'absence d'un second `UNITÉ_TOUCHÉE` se lit « Pas de riposte ».
8. **Mort mutuelle impossible.** La riposte n'a lieu que si la cible a survécu, et seul le second coup peut
   tuer l'attaquant : une attaque détruit au plus UNE unité. L'attaquant PEUT mourir de la riposte (le HUD
   l'annonce « Votre unité sera détruite »).
9. **Compteur « unités détruites ».** Compteur brut par faction, écrit uniquement par le combat : +1 par
   destruction rendue par `modifier_pv` pendant une attaque ou une riposte. Les destructions de
   l'élimination d'une faction (3) ne passent pas par le combat et ne comptent pas. Aucun dormant n'est
   attaquable, donc jamais compté. Le score actuel (U = unités en vie) ne lit pas ce compteur : il sert
   aux statistiques du profil (22) ou disparaîtra (voir Open Questions).
10. **Validation de ATTAQUER** (ordre fixe, premier refus rendu, sur la **vue de la faction émettrice**) :
    PARTIE_TERMINÉE, PAS_VOTRE_TOUR, UNITÉ_INCONNUE (attaquant absent ou d'une autre faction), UNITÉ_ENDORMIE
    (attaquant dormant, code déjà prévu pour DÉPLACER), DÉJÀ_AGI,
    ATTAQUANT_SANS_ATTAQUE* (ATQ = 0, la Sentinelle), CIBLE_NON_VISIBLE (cible hors de la vue de la
    faction, identifiant inexistant compris, pour ne rien révéler), CIBLE_NON_HOSTILE (même faction ou
    dormant), CIBLE_HORS_DE_PORTÉE (distance de Chebyshev > portée de l'attaquant). Un astérisque marque
    un code à ajouter à 23.
    - La visibilité se lit sur la vue de la faction, non sur la vision individuelle de l'attaquant ; au MVP,
      `CIBLE_NON_VISIBLE` est presque inatteignable pour une cible adjacente.
    - On attaque depuis n'importe quelle tuile franchissable. Déplacer puis attaquer est permis ; attaquer
      puis déplacer ne l'est pas. L'attaque en diagonale est permise : la règle « pas de coupe de coin »
      ne vise que le déplacement.
11. **L'IA** émet ATTAQUER à l'exécution d'une intention. Si la cible est détruite ou n'est plus à portée,
    9 annule l'intention avant d'émettre la commande : une cible détruite **ou qui a changé de tuile**
    annule l'attaque, même si elle reste à portée (`design/gdd/game-concept.md`, pilier 4 ; jamais
    redirigée). Les dégâts
    sont calculés à l'**exécution**, sur l'état de ce moment : l'annonce désigne une cible, non un montant.
    **L'attaquant d'une intention annoncée ne se soigne pas** (`unites-drones.md`, règle 6), si bien que
    ses dégâts ne changent pas entre l'annonce et l'exécution ; seul le déplacement de la cible (qui annule
    l'attaque) ou un changement de tuile de l'attaquant ou de la cible les modifie. Le HUD peut donc
    afficher, sur une menace annoncée, un marqueur « létale » calculé par la même fonction sur copie.
12. **Contrat d'aperçu.** L'aperçu est `valider` puis `appliquer` sur une copie (23, règle 7). Le combat ne
    fournit aucune API distincte : le HUD lit la liste de la règle 7 produite par la copie et en déduit
    sans calcul « Inflige −N », « Riposte −M » (ou « Pas de riposte »), les PV restants, « Détruit » et
    « Votre unité sera détruite ». Aucun tirage, aucune modification de l'état réel ; un ordre refusé ne
    produit pas d'aperçu.

### Exemples chiffrés

Formule : `max(1, 8 × ATQ × PV_att // (PV_max_att × (4 + DÉF_eff)))`. La riposte part des PV de la cible
APRÈS le premier coup, avec la `DÉF_eff` de l'attaquant sur sa propre tuile (plaine sauf mention).

| # | Attaquant (PV, tuile) → Cible (PV, tuile) | Coup | Cible après | Riposte | Attaquant après |
|---|---|---|---|---|---|
| 1 | Assaut 8/8 → Rempart 14/14, montagne (`DÉF_eff` 4) | 8×3×8 / (8×8) = 3 | 11 | 8×1×11 / (14×5) = 1 | 7 |
| 2 | Éclaireur 6/6 → Ouvrier 7/7, plaine (0) | 8×1×6 / (6×4) = 2 | 5 | 8×1×5 / (7×4) = 1 | 5 |
| 3 | Chasseur 8/8 → Éclaireur 6/6, plaine (0) | 8×3×8 / (8×4) = 6 | 0, détruit | aucune | 8 |
| 4 | Chasseur 4/8 → Éclaireur 6/6, plaine (0) | 8×3×4 / (8×4) = 3 | 3 | 8×1×3 / (6×4) = 1 | 3 |
| 5 | Chasseur 8/8 → Éclaireur 6/6, forêt (1) | 8×3×8 / (8×5) = 4 | 2 | 8×1×2 / (6×4) = 0, plancher 1 | 7 |
| 6 | Bastion 14/14 → Assaut 8/8, plaine (`DÉF_eff` 1 : DÉF 1 du type, tuile 0) | 8×2×14 / (14×5) = 3 | 5 | 8×3×5 / (8×6) = 2 | 12 |
| 7 | Assaut 8/8 → Chasseur 8/8, forêt (1) | 8×3×8 / (8×5) = 4 | 4 | 8×3×4 / (8×5) = 2 | 6 |
| 8 | Assaut 1/8 → Chasseur 8/8, plaine (0) | max(1, 0) = 1 | 7 | 8×3×7 / (8×5) = 4 | détruit (1 − 4) |
| 9 | Assaut 8/8 → Sentinelle 10/10, plaine (2) | 8×3×8 / (8×6) = 4 | 6 | aucune (ATQ 0) | 8 |
| 10 | Ouvrier 7/7 → Bastion 14/14, montagne (4) | 8×1×7 / (7×8) = 1 | 13 | 8×2×13 / (14×4) = 3 | 4 |
| 11 | Assaut 8/8 → Assaut 8/8, plaine (1) | 8×3×8 / (8×5) = 4 | 4 | 8×3×4 / (8×5) = 2 | 6 |

Lectures : (1) contre le pire cas défensif, l'Assaut fait 3, jamais 0 ; il faut 5 coups d'Assauts à PV pleins pour abattre un Rempart
sur montagne (un même Assaut blessé par la riposte frappe plus faiblement). (3 à 5) le Chasseur ne tue l'Éclaireur en un coup que sur plaine à PV pleins ; blessé de moitié,
non, et en forêt il le laisse à 2. (5) illustre le plancher de 1. (8) illustre la mort par riposte (aperçu
« Votre unité sera détruite »). (7) reproduit « Inflige −4 · Riposte −2 » de la maquette du HUD. (11) montre
l'**avantage du premier coup** (4 contre 2) : risque de boule de neige à jouer en test, atténué par les
intentions annoncées, l'aperçu et le soin au repos.

### States and Transitions

Le combat n'a pas d'état propre ; il agit sur les états des unités :

| Unité | Avant | Après |
|---|---|---|
| Attaquant | Éveillée prête ou A bougé | Terminée (a agi), ou Détruite par la riposte |
| Cible | Éveillée, tous drapeaux | Inchangée (drapeaux inchangés), ou Détruite |
| Endormie ou Terminée | — | Ne peut pas attaquer |

### Interactions with Other Systems

| # | Système | Ce qui circule | Propriétaire de l'interface |
|---|---|---|---|
| 1 | État | Règle 7 : combat déterministe, aucun tirage ; compteur « unités détruites » (tranche Compteurs de score) ; copie sans partage pour l'aperçu | 1 pour la forme, 8 pour le compteur |
| 2 | Carte | Classe de défense de la tuile du défenseur, distance de Chebyshev ; ce système possède `DEF_PER_TILE_CLASS` | 2 |
| 5 | Brouillard | Vue de la faction pour la validation ; recalcul après chaque destruction | 5 |
| 6 | Unités | PV, PV max, ATQ, DÉF, portée ; reçoit `modifier_pv` ; pose « a agi » | 6 |
| 9 | IA | N'attaque que par intention annoncée ; annule sur cible morte ou déplacée ; simule sur copie | 9 |
| 10 | Énergie | Aucune interaction au MVP : attaquer ne coûte rien | — |
| 17 | HUD | Lit la liste d'événements ; ne calcule rien | 17 |
| 23 | Commandes | Valide dans l'ordre de la règle 10 et applique ; publie le lot ; codes de refus | 23 |

## Formulas

*Proposées par systems-designer ; les 11 duels du tableau de la section C ont été recalculés
indépendamment, sans écart de valeur. Les valeurs marquées [PROP] sont des valeurs de départ. Note de
mise en œuvre : en GDScript, la division `/` entre deux `int` est entière ; les valeurs lues dans des
fichiers de données arrivent en `float` et sont converties en `int` à la lecture. Le signe `//` ci-dessous
est la notation mathématique de la division entière.*

### F1. Défense effective

The defense_eff formula is defined as:

`defense_eff = DÉF + DEF_PER_TILE_CLASS × tile_class`

**Variables:**

| Variable | Type | Range | Source | Description |
|---|---|---|---|---|
| DÉF | int | 0..2 | data file (`units.*`) | Défense du type du défenseur |
| DEF_PER_TILE_CLASS | int | 0..2 | data file (`combat.*`) | Bonus par classe de tuile (1) [PROP] |
| tile_class | int | 0..2 | data file (carte, règle 9) | Plaine 0, forêt 1, montagne 2, tuile du défenseur |
| defense_eff | int | 0..4 | calculated | Défense utilisée en F2 |

**Output Range:** 0 (Éclaireur, Ouvrier ou Chasseur sur plaine) à 4 (Rempart ou Bastion sur montagne) ; jamais négatif.
**Example:** Bastion (DÉF 2) sur forêt : 2 + 1 × 1 = 3.

### F2. Dégâts d'un coup

The damage formula is defined as:

`damage = 0 si ATQ = 0, sinon max(DMG_MIN, (DMG_SCALE × DEF_BASE × ATQ × PV_att) // (PV_max_att × (DEF_BASE + defense_eff)))`

**Variables:**

| Variable | Type | Range | Source | Description |
|---|---|---|---|---|
| DMG_SCALE | int | 2 | data file [PROP] | Échelle des dégâts |
| DEF_BASE | int | 3..6 | data file [PROP] | Pivot de l'amortissement (4) |
| DMG_MIN | int | 1 | data file [PROP] | Plancher si ATQ > 0 |
| ATQ | int | 0..3 | data file | Attaque du type qui frappe |
| PV_att | int | 1..14 | calculated | PV courants de l'unité qui frappe, au moment du coup |
| PV_max_att | int | 6..14 | data file | PV max de son type |
| defense_eff | int | 0..4 | calculated (F1) | Défense effective de la cible |
| damage | int | 0..6 | calculated | Dégâts bruts, avant `modifier_pv` |

**Output Range:** 0 si ATQ = 0, sinon 1 à 6 (le maximum vient de ATQ 3, PV pleins, `defense_eff` 0). Les opérandes sont positifs : la division entière tronque comme un plancher.
**Example:** les 11 duels sont recalculés. Cas limite : le duel 10 vaut 56 // 56 = 1 pile, sans le plancher. Assaut contre Rempart sur montagne : 24 // 8 = 3.

### F3. Riposte

The retaliation formula is defined as:

`riposte = (pv_cible_après > 0) ∧ (ATQ_cible > 0) ∧ (cheb(attaquant, cible) ≤ portée_cible)` ; `d2 = damage` (F2) avec `PV_att = pv_cible_après`, l'ATQ et le `PV_max` de la cible, et la `defense_eff` de l'attaquant sur SA tuile

**Variables:**

| Variable | Type | Range | Source | Description |
|---|---|---|---|---|
| pv_cible_après | int | 0..14 | calculated | PV de la cible après le premier coup (effectifs, bornés) |
| ATQ_cible | int | 0..3 | data file | 0 pour la Sentinelle |
| cheb | int | 1 au MVP | calculated (carte, formule 1) | Distance de Chebyshev |
| portée_cible | int | 1 (MVP) | data file | Portée de la cible |
| d2 | int | 0..6 | calculated | 0 sans riposte, sinon 1 à 6 |

**Output Range:** d2 ∈ {0} ∪ [1, 6] ; aucune contre-riposte. Au MVP toutes les portées valent 1 : la condition de portée est vraie si l'attaque était valide, et ne s'active qu'avec le Lancier (portée 2, Alpha).
**Example:** Éclaireur à 3 PV contre un Chasseur sur plaine : 8 × 1 × 3 // (6 × 4) = 24 // 24 = 1.

### F4. Matrice de dégâts à PV pleins

À PV pleins, `damage = 8 × ATQ // (4 + defense_eff)` : la valeur ne dépend que de ATQ et de `defense_eff`.

**Plaine** (ligne = attaquant, colonne = défenseur) :

| Att \ Déf | Éclai. | Assaut | Rempart | Ouvrier | Sentin. | Chass. | Bastion |
|---|---|---|---|---|---|---|---|
| Éclaireur, Rempart, Ouvrier (ATQ 1) | 2 | 1 | 1 | 2 | 1 | 2 | 1 |
| Assaut, Chasseur (ATQ 3) | 6 | 4 | 4 | 6 | 4 | 6 | 4 |
| Bastion (ATQ 2) | 4 | 3 | 2 | 4 | 2 | 4 | 2 |
| Sentinelle (ATQ 0) | 0 | 0 | 0 | 0 | 0 | 0 | 0 |

**Forêt** :

| ATQ (types) | Éclai. | Assaut | Rempart | Ouvrier | Sentin. | Chass. | Bastion |
|---|---|---|---|---|---|---|---|
| 1 (Éclaireur, Rempart, Ouvrier) | 1 | 1 | 1 | 1 | 1 | 1 | 1 |
| 2 (Bastion) | 3 | 2 | 2 | 3 | 2 | 3 | 2 |
| 3 (Assaut, Chasseur) | 4 | 4 | 3 | 4 | 3 | 4 | 3 |

**Montagne (pire cas)**, `defense_eff` : Éclaireur 2, Assaut 3, Rempart 4, Ouvrier 2, Sentinelle 4, Chasseur 2, Bastion 4 :

| ATQ (types) | Éclai. | Assaut | Rempart | Ouvrier | Sentin. | Chass. | Bastion |
|---|---|---|---|---|---|---|---|
| 1 | 1 | 1 | 1 | 1 | 1 | 1 | 1 |
| 2 (Bastion) | 2 | 2 | 2 | 2 | 2 | 2 | 2 |
| 3 | 4 | 3 | 3 | 4 | 3 | 4 | 3 |

**Output Range:** 0 (Sentinelle seule), puis 1 à 6. **Plancher :** aucune cellule ne touche le plancher à PV pleins (la valeur brute est au moins 8 // 8 = 1) ; il n'agit que sur une unité blessée (duels 5 et 8).
**Example:** Assaut contre Rempart sur montagne : 24 // 8 = 3.

### F5. Coups pour tuer (PV pleins, plaine, sans riposte)

The hits_to_kill formula is defined as:

`hits_to_kill = ceil(PV_def / damage)`

**Variables:**

| Variable | Type | Range | Source | Description |
|---|---|---|---|---|
| PV_def | int | 6..14 | data file | PV max du défenseur (Éclaireur 6, Assaut 8, Rempart 14, Ouvrier 7, Sentinelle 10, Chasseur 8, Bastion 14) |
| damage | int | 1..6 | calculated (F4, plaine) | Dégâts d'une attaque à PV pleins |
| hits_to_kill | int | 1..14 | calculated | Nombre d'attaques de l'attaquant |

| Attaquant \ Défenseur | Éclai. | Assaut | Rempart | Ouvrier | Sentin. | Chass. | Bastion |
|---|---|---|---|---|---|---|---|
| Éclaireur, Rempart, Ouvrier | 3 | 8 | 14 | 4 | 10 | 4 | 14 |
| Assaut, Chasseur | 1 | 2 | 4 | 2 | 3 | 2 | 4 |
| Bastion | 2 | 3 | 7 | 2 | 5 | 2 | 7 |

**Output Range:** 1 à 14 ; le maximum suppose un attaquant qui garde ses PV pleins, irréaliste (la riposte l'use).
**Example:** Bastion contre Rempart : ceil(14 / 2) = 7.

### F6. Avantage du premier coup (contrôle de conception, pas une règle)

Duel « chacun attaque à son tour » sur plaine ; A est le premier attaquant ; chaque coup est suivi de la riposte si la cible survit. Chiffres : PV (A / B).

| Duel | Après coup 1 et riposte | Suite | Vainqueur |
|---|---|---|---|
| Assaut | 6 / 4 | B frappe 2, riposte 2 : 4 / 2 ; A frappe 2 : B détruit | A, 4 PV, 3 attaques |
| Chasseur | 7 / 2 | B frappe 1 (A 6), riposte 4 : B détruit par sa propre riposte | A, 6 PV, 2 attaques |
| Bastion | 12 / 12 | −1 chacun par échange (dégâts 2 jusqu'à 11 PV, puis 1) ; arrivé à (1 / 2), B frappe : A détruit | **B**, 2 PV, 12 attaques |
| Rempart | 13 / 13 | −1 chacun à chaque échange ; à (1 / 1), B frappe : A détruit | **B**, 1 PV, 14 attaques |

- **Assaut et Chasseur** : le premier coup décide (avance de PV de +2 et +5).
- **Bastion et Rempart** : le premier coup ne donne aucune avance de PV, et le plancher à 1 rend les échanges symétriques ; à égalité, le **second** à frapper gagne. Ce sont des duels longs (12 à 14 attaques) sans intérêt de tempo : à jouer en test.
- Attaquer en second, blessé, peut être suicidaire : un Chasseur à 2 PV qui frappe meurt de la riposte.

### F7. Bornes et débordement

The damage_numerator formula is defined as:

`numérateur = DMG_SCALE × DEF_BASE × ATQ × PV_att` ; `dénominateur = PV_max_att × (DEF_BASE + defense_eff)`

**Variables:**

| Variable | Type | Range | Source | Description |
|---|---|---|---|---|
| numérateur | int | 8..224 | calculated | Maximum réel : Bastion 8 × 2 × 14 = 224 (Assaut 192, Rempart 112) ; borne théorique 336 (ATQ 3 × PV 14), inexistante dans les données |
| dénominateur | int | 24..112 | calculated | Minimum 6 × 4 (Éclaireur, `defense_eff` 0) ; maximum 14 × 8 |
| damage | int | 1..6 | calculated | Voir F2 |

**Output Range:** même la borne 336 tient très largement dans un `int` de GDScript (64 bits) : aucun débordement possible.
**Example:** Bastion plein contre Éclaireur sur plaine : 224 // (14 × 4) = 4.

| Réglage | Valeur | Plage sûre | Effet |
|---|---|---|---|
| `DMG_SCALE` | 2 | 2 (entier) ; **3 casse** | À 3, ATQ 3 inflige jusqu'à 9 et tue en un coup Assaut, Chasseur et Ouvrier |
| `DEF_BASE` | 4 | 3..6 | Plus bas : défense plus forte |
| `DMG_MIN` | 1 | 1 (fixe) | À 0 : unités invulnérables |
| `DEF_PER_TILE_CLASS` | 1 | 0..2 | À 2, `defense_eff` va jusqu'à 6 et ATQ 1 reste au plancher |

Seul le produit `DMG_SCALE × DEF_BASE` (8) fixe l'échelle absolue ; `DEF_BASE` règle le poids relatif de la défense.

## Edge Cases

*Proposés par systems-designer ; les résolutions du 2026-10-30 sont intégrées.*

- **Si un coup dépasse les PV de la cible** (Chasseur plein, 6, contre un Éclaireur à 2 PV): `modifier_pv` ramène à 0, la cible est détruite, et le champ « dégâts » de `UNITÉ_TOUCHÉE` porte 2 (PV réellement perdus), non 6.
- **Si l'attaquant a ATQ 0** (Sentinelle): refus ATTAQUANT_SANS_ATTAQUE, après DÉJÀ_AGI et avant CIBLE_NON_VISIBLE ; aucun état ne change.
- **Si le défenseur a ATQ 0** (Sentinelle ciblée): pas de riposte, pas de second `UNITÉ_TOUCHÉE` ; le HUD lit « Pas de riposte ».
- **Si le premier coup détruit la cible**: aucune riposte ; événements ATTAQUE_RÉSOLUE, UNITÉ_TOUCHÉE, UNITÉ_DÉTRUITE ; compteur +1 pour la faction de l'attaquant ; l'attaquant passe à « a agi ».
- **Si la riposte détruit l'attaquant**: événements ATTAQUE_RÉSOLUE, UNITÉ_TOUCHÉE (cible), UNITÉ_TOUCHÉE (attaquant), UNITÉ_DÉTRUITE (attaquant, tuile, par = cible) ; compteur +1 pour la faction de la **cible** ; la tuile est libre aussitôt ; terrain, propriétaire de tuile et nœuds inchangés ; les intentions qui visaient l'attaquant sont annulées (« cible détruite ») et celles qu'il avait émises aussi (AUTEUR_DÉTRUIT). Une seule destruction par attaque.
- **Si l'attaquant n'a plus que 1 PV et que la cible survit en étant armée**: la riposte inflige au moins 1 (plancher) et le détruit (duel 8) ; le HUD affiche « Votre unité sera détruite ».
- **Si un attaquant à 1 PV frappe**: il inflige quand même 1 (plancher), même contre un Rempart sur montagne : une unité blessée reste une menace, jamais « −0 ».
- **Si la cible est un dormant**: refus CIBLE_NON_HOSTILE (si elle est visible ; sinon CIBLE_NON_VISIBLE, qui passe avant).
- **Si la cible est de la faction de l'attaquant**: refus CIBLE_NON_HOSTILE.
- **Si la cible est hors de la vue de la faction, y compris un identifiant périmé ou inexistant donné par l'IA**: refus CIBLE_NON_VISIBLE, identique pour « cachée » et « inexistante » (aucune fuite) ; pour l'IA, ce refus compte dans `N_REFUS_MAX`.
- **Si la cible est à distance de Chebyshev 2 et la portée vaut 1**: refus CIBLE_HORS_DE_PORTÉE ; l'attaquant n'a pas agi et peut encore se déplacer.
- **Si les deux tuiles de coin d'une diagonale sont de l'eau**: l'attaque est permise (la règle de coupe de coin ne vise que le déplacement) ; la distance est 1.
- **Si l'attaquant s'est déplacé avant**: l'attaque est permise ; « a bougé » reste vrai, « a agi » passe à vrai.
- **Si l'attaquant a déjà agi et attaque de nouveau**: refus DÉJÀ_AGI.
- **Si l'attaquant a agi et tente de se déplacer**: le déplacement est refusé par le drapeau « a agi » (code exact à confirmer en 23).
- **Si l'attaquant occupe un nœud ou une ruine**: aucun effet ; l'attaque ne capture pas et ne lit pas la ruine.
- **Si, entre l'annonce et l'exécution, la cible a bougé**: l'intention est annulée (« cible déplacée »), même si la cible reste à portée (pilier 4). **Si elle n'a pas bougé mais a été soignée**: les dégâts ne dépendent pas des PV de la cible ; **l'attaquant ne se soigne pas tant qu'il porte une intention annoncée** : les dégâts calculés à l'exécution sont donc ceux qu'une simulation à l'annonce donnait ; l'annonce désigne une cible, jamais un montant.
- **Si deux intentions visent la même cible**: elles s'exécutent dans l'ordre croissant des identifiants d'intention ; la seconde est revalidée sur l'état laissé par la première et, si la cible est détruite, annulée (« cible détruite »).
- **Si l'auteur d'une intention est détruit avant son exécution** (coup du joueur ou riposte): l'intention est annulée, motif AUTEUR_DÉTRUIT (à confirmer avec 9) ; elle n'est jamais exécutée.
- **Si une destruction par riposte a lieu**: le compteur « unités détruites » augmente de 1 ; les destructions de l'élimination d'une faction (3) ne passent pas par le combat et ne comptent pas.
- **Si l'on demande un aperçu**: `valider` puis `appliquer` sur une copie ; l'état réel n'est pas modifié, aucun hasard n'est tiré, la copie ne publie aucun événement, et la liste est identique à celle de l'application réelle.
- **Si l'unité qui donnait la vue de la cible est détruite par la riposte de cette même commande**: la visibilité a été lue à la validation, sur la vue de la faction, avant l'application ; la commande n'est pas invalidée ; 5 recalcule la vue après la destruction.
- **Si les deux unités ont peu de PV** (attaquant 1 PV, cible 1 PV): le premier coup inflige au moins 1, la cible tombe, il n'y a pas de riposte : seule la riposte peut détruire l'attaquant, donc jamais de mort mutuelle.

### Cas à traiter dans d'autres GDD

- **23 Commandes**: ajouter ATTAQUANT_SANS_ATTAQUE ; fixer l'ordre complet des refus ; confirmer que « dégâts » désigne les PV réellement perdus ; préciser le champ « par » de UNITÉ_DÉTRUITE (la cible pour une riposte) ; code d'un déplacement après attaque ; effet d'une attaque sur l'instantané d'annulation.
- **3 Tours**: le compteur « unités détruites » ne remplace pas U (unités en vie) ; une élimination ne l'incrémente pas.
- **9 IA**: motifs d'annulation (« cible détruite », « cible déplacée », AUTEUR_DÉTRUIT) ; une cible qui a bougé annule l'intention même si elle reste à portée (aligner `commandes-evenements.md` et la règle 11 sur le pilier 4) ; une destruction n'est appliquée qu'après la boucle sur les identifiants.
- **17 / `design/ux/hud.md`**: « Inflige −4 » de la maquette est illustratif (il reproduit le duel 7) ; gérer les cas sans riposte ; ne jamais afficher un montant sur une intention annoncée ; remplacer « éclatement 400 ms » par « gris puis affaissement » ; préciser la durée du glyphe de débris d'une unité ennemie (« fin du tour suivant du joueur » contre « fin du tour »).
- **22 Profil**: les statistiques lisent le compteur de destructions ; décider si elles stockent aussi les PV perdus.
- **`unites-drones.md`**: référencer ce système pour `DMG_SCALE`, `DEF_BASE`, `DMG_MIN` et `DEF_PER_TILE_CLASS` ; corriger le coup maximal (6) si `DMG_SCALE` change.

## Dependencies

### En amont (ce système dépend de)

| Système | Nature | Dure ou souple |
|---|---|---|
| 2 Carte en tuiles et terrain | Classe de défense de la tuile, distance de Chebyshev (`design/gdd/carte-tuiles-terrain.md`) | Dure |
| 6 Unités drones | PV, PV max, ATQ, DÉF, portée ; `modifier_pv` ; drapeau « a agi » (`design/gdd/unites-drones.md`) | Dure |

Dépendances de contrat : 1 (aucun tirage, copie pour l'aperçu), 5 (vue de la faction pour la validation), 23 (commandes et événements).

### En aval (systèmes qui dépendent de lui)

| Système | Ce qu'il utilise | Dure ou souple |
|---|---|---|
| 9 IA ennemie | Exécution d'une intention d'attaque ; simulation sur copie | Dure |
| 17 HUD | Liste d'événements de l'aperçu et de la résolution | Dure |
| 22 Profil | Compteur « unités détruites » (statistiques) | Souple |
| 23 Commandes | Validation et application de ATTAQUER | Dure |

### Bidirectionnalité

- `design/gdd/modele-etat-partie.md`, `design/gdd/commandes-evenements.md`, `design/gdd/unites-drones.md` et `design/gdd/carte-tuiles-terrain.md` citent déjà ce système.
- `design/ux/hud.md` doit le citer (aperçu, durée de la résolution, glyphe de débris).
- Les GDD 5, 9 et 22 doivent le citer à leur création ou à leur revue.

### Décisions techniques renvoyées à un ADR

- Représentation de la liste ordonnée d'événements d'une attaque (données pures).
- Exécution de la fonction pure sur une copie légère pour l'IA.

## Tuning Knobs

*Dans `assets/data/combat.*`. Valeurs de départ [PROP], à jouer en test puis à équilibrer au premier
playtest.*

| Paramètre | Valeur | Plage sûre | Trop haut | Trop bas | Interagit avec |
|---|---|---|---|---|---|
| `DMG_SCALE` | 2 | 2 (entier ; 3 casse) | Tout meurt en un ou deux coups ; l'aperçu n'a plus d'intérêt | Combats interminables | `DEF_BASE`, PV des types (6) |
| `DEF_BASE` | 4 | 3..6 | Défense négligeable | Défense dominante, ATQ 1 au plancher | `DEF_PER_TILE_CLASS` |
| `DMG_MIN` | 1 | 1 (fixe) | — | À 0 : unités invulnérables | Soin au repos (6) |
| `DEF_PER_TILE_CLASS` | 1 | 0..2 | La montagne rend invulnérable | Le terrain ne compte plus | Carte (2), pilier 3 |
| Portée de la riposte | portée de la cible (1 pour tous) | 1..2 | Échange en chaîne (anti-pilier) | — | Lancier (Alpha) |

*Le produit `DMG_SCALE × DEF_BASE` (8) fixe l'échelle absolue des dégâts ; les statistiques des types
sont des réglages de 6.*

## Visual/Audio Requirements

*Rédigé d'après la consultation de l'`art-director` du 2026-10-30 et l'art bible (sections 1, 2, 5, 7).
Les durées sont des propositions dans la plage de 150 à 300 ms de la section 7.*

- **Chronologie d'une attaque (environ 1,5 s, sous la limite de 1,6 s ; les phases se chevauchent).**
  - 0 à 200 ms : l'attaquant pivote d'un palier de 45° vers la cible, sans glissement ni rebond.
  - 200 à 350 ms : **trait droit blanc à contour sombre de 1 pt**, de l'attaquant vers la cible (une
    forme, aucune teinte ajoutée ; proposition à valider).
  - À 350 ms (`UNITÉ_TOUCHÉE` de la cible) : « −N » en JetBrains Mono 700, 14 pt, blanc à contour sombre,
    au-dessus de la tuile touchée ; il monte de 12 pt et s'efface en 800 ms ; la jauge de la cible
    descend en 300 ms. Le modèle ne change pas.
  - À 650 ms, si riposte : même trait en sens inverse, un « −M » au-dessus de l'attaquant, sa jauge
    descend en 300 ms ; fin vers 1450 ms. Sans couleur, les deux chiffres se distinguent par la tuile
    qui les porte, l'ordre (la riposte arrive 300 ms plus tard) et le sens du trait ; le journal et le
    panneau reprennent « Inflige / Riposte » en texte. « Pas de riposte » n'a aucune animation.
  - Animations réduites : ni pivot animé ni montée ; chiffre fixe 800 ms ; le trait est un état fixe de
    150 ms ; la jauge passe à sa valeur finale ; l'ordre attaque puis riposte est conservé.
- **Destruction.** Selon l'art bible : l'unité perd sa teinte vers le gris puis s'affaisse (400 ms), le
  modèle reste intact ; un **glyphe de débris gris** reste sur la tuile (hexagone brisé pour le joueur,
  losange brisé pour l'ennemi) jusqu'à la fin du tour suivant du joueur. Animations réduites : passage
  direct au glyphe.
- **Intention exécutée ou annulée.** Exécutée : la hachure orange-rouge et le « ! » tiennent jusqu'au
  départ du coup, puis la séquence ci-dessus se joue. Annulée (cible déplacée ou détruite) : aucun
  événement de combat, donc aucun trait ni chiffre ; la hachure se vide en fondu de 200 ms et laisse
  le contour orange et la croix × sur la tuile : la croix, une forme, sépare l'annulation de la menace.
- **Cibles et aperçu.** Quatre crochets d'angle blancs sur chaque cible valable, plus épais et légèrement
  animés pour la cible choisie (fixes avec les animations réduites) ; contour sombre sur le vert F2 ou le
  violet #C49BEA. Aperçu : panneau sombre, texte et jauges blancs, part perdue hachurée en gris clair,
  aucun ambre, vert ni rouge.
- **Audio.** Aucune information de jeu ne passe par un son. Trois événements méritent un son facultatif :
  le coup, la riposte, la destruction ; chacun a son équivalent visuel. Ambiance : mécanique, sèche et
  droite pour les coups ; un registre de perte, sans éclat, pour la destruction. Aucun son pour une
  intention annulée. Spécifications avec le système 20.

> 📌 **Asset Spec** — Visual/Audio requirements are defined. After the art bible is approved,
> run `/asset-spec system:combat` to produce per-asset visual descriptions, dimensions, and
> generation prompts from this section.

## Game Feel

- **Une seule chose bouge à la fois** : pivot, trait, chiffre, riposte s'enchaînent sans se disputer
  l'attention (art bible, « Animation »).
- **Le coup est une phrase, non une explosion.** Aucun écran qui tremble, aucun effet de particules : le
  poids vient du chiffre qui monte et de la jauge qui descend.
- **Commandes verrouillées `ATTACK_LOCK_MS` = 1 600 ms** (`commandes-evenements.md`, règle 12 ; l'animation dure environ 1,5 s) pendant la résolution (`design/ux/hud.md`, section 11), puis le
  panneau d'unité revient avec les PV à jour.
- **Aucune surprise** : le résultat est exactement celui de l'aperçu ; si l'IA ne tire aucun dé, le
  joueur ne doit jamais se demander pourquoi un coup a porté.
- **Animations réduites** : tout apparaît dans l'état final, l'ordre attaque puis riposte conservé.

## UI Requirements

- **Aperçu de combat** (`design/ux/hud.md`) : deux colonnes (unité du joueur, cible) avec jauges, « Inflige −N » et
  « Riposte −M » (ou « Pas de riposte »), « Détruit » et « Votre unité sera détruite » ; toutes les
  valeurs viennent de la liste d'événements de la copie ; le HUD ne calcule rien.
- **Confirmation en deux appuis** : « Confirmer l'attaque » est le bouton principal, « Annuler » le secondaire.
- **Chiffres de dégâts** sur la carte : signe « − » et texte, jamais la couleur seule.
- **Journal du tour ennemi** : « Votre Éclaireur subit −3 » ; jamais de montant sur une intention seulement
  annoncée.
- **Lecteur d'écran** : PV avant et après, dégâts et riposte sont annoncés comme du texte.

> 📌 **UX Flag — Combat** : ce système a des exigences d'interface (aperçu, confirmation, journal). En phase 4
> (pré-production), lancer `/ux-design` pour l'aperçu de combat **avant** d'écrire les épopées.

## Cross-References

| Ce document cite | Document | Élément précis | Nature |
|---|---|---|---|
| Combat déterministe, aucun tirage, copie pour l'aperçu, entiers | `design/gdd/modele-etat-partie.md` | Règles 6, 7, 9 | Règle |
| ATTAQUER, codes de refus, aperçu = commande sur copie, événements | `design/gdd/commandes-evenements.md` | Table des commandes ; règles 6, 7, 8 | Règle |
| PV, ATQ, DÉF, portée, `modifier_pv`, destruction, soin au repos | `design/gdd/unites-drones.md` | Règles 2, 3, 4, 9, 10 | Valeur, règle |
| Classe de défense de la tuile, distance de Chebyshev | `design/gdd/carte-tuiles-terrain.md` | Règle 9 ; formule 1 | Valeur |
| Élimination, score (U unités en vie) | `design/gdd/tours-conditions-victoire.md` | Règles 10 à 12 ; formule 1 | Règle |
| Aperçu, chiffres de dégâts, glyphe de débris, durée de résolution | `design/ux/hud.md` | Aperçu de combat ; marqueurs de carte | Intention |
| Aucun dégât sur le modèle, destruction = gris, mouvement sans rebond | `design/art/art-bible.md` | Sections 5 et 7 | Style |
| Pilier 4 (aperçu = résultat ; une cible déplacée annule l'attaque), pilier 3 | `design/gdd/game-concept.md` | Game Pillars | Intention |

## Acceptance Criteria

*Étiquettes : **Logic** = test unitaire dans `tests/unit/combat/`, sur un état construit par fabrique ;
**Intégration** = `tests/integration/combat/` ; **Visuel** et **UI** = capture conservée dans
`production/qa/evidence/`, validée par l'art-director ; **Appareil** = sur l'appareil cible. [BLOQUÉ n] =
attend le système n. Une copie d'aperçu **rend** la liste d'événements sans la **publier**. Le total de la
chronologie se mesure du début du pivot à la fin du dernier chiffre de dégâts.*

### Règles

- **AC-CB1** (Logic, règle 1) **GIVEN** un état par fabrique, **WHEN** `résoudre_attaque` est appelée deux fois, **THEN** les listes d'événements sont identiques à l'octet, aucun tirage n'est appelé (doublure du hasard à 0 appel), et seuls `modifier_pv` et le compteur sont écrits (recherche statique).
- **AC-CB2** (Logic, règle 2) **GIVEN** un Assaut sur forêt attaquant un Éclaireur sur plaine, **THEN** les dégâts sont ceux d'un Assaut sur plaine (6 à PV pleins) : la tuile de l'attaquant n'ajoute rien à son attaque.
- **AC-CB3** (Logic, règle 3) **GIVEN** les 7 types × les 3 classes de tuile, **THEN** `DÉF_eff` = DÉF + 1 × classe, dans 0..4 ; Bastion sur forêt = 3.
- **AC-CB4** (Logic, règle 4) **GIVEN** ATQ = 0, **THEN** dégâts 0 et aucun événement de coup ; **GIVEN** un Assaut à 1 PV contre un Rempart sur montagne, **THEN** dégâts 1 (plancher) ; **GIVEN** le duel 10 (56 // 56), **THEN** 1 sans le plancher.
- **AC-CB5** (Logic, règle 5) **GIVEN** le duel 5 avec l'attaquant sur plaine puis sur montagne, **THEN** le premier coup est inchangé et la riposte utilise la `DÉF_eff` de la tuile de l'attaquant (plus faible sur montagne).
- **AC-CB6** (Logic, règle 6) **GIVEN** les duels 3, 7 et 8, **THEN** l'ordre est : coup, `modifier_pv` de la cible, « a agi », puis soit compteur +1 sans riposte, soit riposte calculée sur les PV après coup ; pas de contre-riposte ; les drapeaux de la cible sont inchangés.
- **AC-CB7** (Logic, règle 7) **GIVEN** un kill, une riposte, une riposte mortelle, **THEN** les séquences sont respectivement [ATTAQUE_RÉSOLUE, UNITÉ_TOUCHÉE, UNITÉ_DÉTRUITE], [ATTAQUE_RÉSOLUE, UNITÉ_TOUCHÉE (cible), UNITÉ_TOUCHÉE (attaquant)], et la précédente suivie de UNITÉ_DÉTRUITE (attaquant, tuile, par = cible) ; Chasseur plein contre Éclaireur à 2 PV : « dégâts » = 2 (PV réellement perdus), non 6 ; sans riposte : un seul UNITÉ_TOUCHÉE.
- **AC-CB8** (Logic, règle 8) **GIVEN** les 11 duels et une grille d'états (PV de 1 au maximum), **THEN** au plus un UNITÉ_DÉTRUITE par attaque (propriété).
- **AC-CB9** (Logic, règle 9) **GIVEN** un compteur à 0, **THEN** un kill au premier coup : +1 pour la faction attaquante ; une riposte mortelle : +1 pour la faction de la cible ; l'élimination d'une faction : +0 ; aucune écriture du compteur hors du combat (recherche statique).
- **AC-CB10** (Logic, règle 10) Validation : voir AC-CB29 à AC-CB33. Déplacer puis attaquer : permis, « a bougé » reste vrai ; attaquer puis déplacer : refusé. [BLOQUÉ 23 : code de refus du déplacement]
- **AC-CB11** (Intégration, règle 11) **GIVEN** une intention annoncée au tour T, **WHEN** T + 1, **THEN** exécution avec dégâts recalculés sur l'état courant (attaquant soigné : montant différent de celui d'un calcul à l'annonce) ; une cible détruite ou déplacée (même restée à portée) annule l'intention, sans événement de combat. [BLOQUÉ 9]
- **AC-CB12** (Logic, règle 12) Contrat d'aperçu : voir AC-CB36.

### Vecteurs des 11 duels (Logic, F2 et F3 ; attaquant sur plaine)

*Format : attaquant (PV) → défenseur (PV, tuile) : dégâts, PV restants ; riposte, PV de l'attaquant.*

- **AC-CB13** (duel 1) Assaut 8 → Rempart 14 (montagne) : 3, 11 ; riposte 1, attaquant 7.
- **AC-CB14** (duel 2) Éclaireur 6 → Ouvrier 7 (plaine) : 2, 5 ; riposte 1, attaquant 5.
- **AC-CB15** (duel 3) Chasseur 8 → Éclaireur 6 (plaine) : 6, 0 détruit ; aucune riposte, attaquant 8, compteur +1.
- **AC-CB16** (duel 4) Chasseur 4 → Éclaireur 6 (plaine) : 3, 3 ; riposte 1, attaquant 3.
- **AC-CB17** (duel 5) Chasseur 8 → Éclaireur 6 (forêt) : 4, 2 ; riposte 1 (brut 0, plancher), attaquant 7.
- **AC-CB18** (duel 6) Bastion 14 → Assaut 8 (plaine) : 3, 5 ; riposte 2, attaquant 12.
- **AC-CB19** (duel 7) Assaut 8 → Chasseur 8 (forêt) : 4, 4 ; riposte 2, attaquant 6.
- **AC-CB20** (duel 8) Assaut 1 → Chasseur 8 (plaine) : 1, 7 ; riposte 4, **attaquant détruit** (1 − 4, borné à 0, « dégâts » = 1 PV réellement perdu) ; événements ATTAQUE_RÉSOLUE, TOUCHÉE (cible), TOUCHÉE (attaquant), DÉTRUITE (attaquant) ; compteur +1 pour la faction de la cible.
- **AC-CB21** (duel 9) Assaut 8 → Sentinelle 10 (plaine) : 4, 6 ; aucune riposte, attaquant 8.
- **AC-CB22** (duel 10) Ouvrier 7 → Bastion 14 (montagne) : 1, 13 ; riposte 3, attaquant 4.
- **AC-CB23** (duel 11) Assaut 8 → Assaut 8 (plaine) : 4, 4 ; riposte 2, attaquant 6.

### Formules

- **AC-CB24** (Logic, F4) Plaine : Assaut contre Éclaireur 6, contre Rempart 4. Forêt : Bastion contre Éclaireur 3. Montagne : Bastion contre Éclaireur 2.
- **AC-CB25** (Logic, F4, propriété) **GIVEN** les 7 × 7 paires × 3 tuiles à PV pleins, **THEN** pour ATQ > 0 le calcul brut est au moins 1 : le plancher n'agit jamais à PV pleins (seulement duels 5 et 8).
- **AC-CB26** (Logic, F5) `ceil(PV_def / dégâts)` : Bastion contre Rempart 7 coups ; Éclaireur contre Rempart 14.
- **AC-CB27** (Logic, F6, **script de contrôle de conception, non bloquant en CI**) Duels en miroir alternés sur plaine : Assaut, A gagne avec 4 PV en 3 attaques ; Chasseur, A gagne avec 6 PV en 2 ; Bastion et Rempart, B gagne.
- **AC-CB28** (Logic, F7) **GIVEN** les 7 × 7 paires et tout PV_att ≤ PV_max, **THEN** numérateur ≤ 224 (Bastion plein), dénominateur 24..112 ; recherche statique : aucun flottant ni division non entière dans le module ; valeurs lues du fichier converties en `int`.

### Validation de ATTAQUER (on teste le premier code en échec)

- **AC-CB29** (Logic) Unité ayant déjà agi ET Sentinelle : DÉJÀ_AGI ; Sentinelle prête visant une cible hors vue : ATTAQUANT_SANS_ATTAQUE (après DÉJÀ_AGI, avant CIBLE_NON_VISIBLE) ; attaquant dormant : UNITÉ_ENDORMIE. [BLOQUÉ 23 : codes à ajouter]
- **AC-CB30** (Logic) Identifiant caché ou inexistant : CIBLE_NON_VISIBLE, réponse identique octet pour octet (aucune fuite). [BLOQUÉ 5 : vue de la faction]
- **AC-CB31** (Logic) Dormant visible ou unité de sa propre faction : CIBLE_NON_HOSTILE ; dormant non visible : CIBLE_NON_VISIBLE.
- **AC-CB32** (Logic) Chebyshev 2, portée 1 : CIBLE_HORS_DE_PORTÉE ; l'attaquant n'a pas agi et peut encore se déplacer.
- **AC-CB33** (Logic) Ordre intégral PARTIE_TERMINÉE, PAS_VOTRE_TOUR, UNITÉ_INCONNUE, UNITÉ_ENDORMIE, DÉJÀ_AGI, ATTAQUANT_SANS_ATTAQUE, CIBLE_NON_VISIBLE, CIBLE_NON_HOSTILE, CIBLE_HORS_DE_PORTÉE, un test par paire adjacente ; un refus ne change aucun état. [BLOQUÉ 23 : ordre complet à fixer]

### Cas limites et transversaux

- **AC-CB34** (Logic) Sentinelle : ne peut pas attaquer ; comme cible, aucune riposte et aucun second UNITÉ_TOUCHÉE.
- **AC-CB35** (Logic) Attaque en diagonale avec les deux coins en eau : valide, distance 1.
- **AC-CB36** (Logic) **GIVEN** `valider` puis `appliquer` sur une copie, **THEN** la liste rendue est identique à celle de l'application réelle, l'état réel est inchangé à l'octet (révision incluse), aucun tirage ; un ordre refusé ne produit aucun aperçu.
- **AC-CB37** (Logic) Même état et même commande, deux exécutions : octets identiques.
- **AC-CB38** (Intégration) Intention dont la cible a bougé (restée à portée) : annulée, aucun événement de combat ; deux intentions sur la même cible : exécutées par identifiant d'intention croissant, la seconde annulée si la cible est détruite ; attaquant tué par la riposte : ses intentions annulées (AUTEUR_DÉTRUIT) et celles qui le visaient aussi. [BLOQUÉ 9]
- **AC-CB39** (Logic) Vue donnée par l'attaquant détruit par la riposte : la commande reste valide, puis 5 recalcule la vue. [BLOQUÉ 5]

### Visuel et UI

- **AC-CB40** (Visuel + Appareil) Capture conservée (séquence) d'une attaque avec riposte : durée totale ≤ 1,6 s (cible environ 1,45 s) ; « −N » puis « −M » distinguables en niveaux de gris par la tuile porteuse, l'ordre et le sens du trait ; variante animations réduites : chiffres fixes 800 ms, trait fixe 150 ms, même ordre. [BLOQUÉ 17]
- **AC-CB41** (Visuel) Captures d'une destruction : gris puis affaissement (400 ms), glyphe de débris (hexagone pour le joueur, losange pour l'ennemi) ; variante réduite : passage direct au glyphe. [BLOQUÉ 17 : durée du glyphe]
- **AC-CB42** (UI) Capture de l'aperçu : « Inflige −N / Riposte −M » ou « Pas de riposte », « Détruit », « Votre unité sera détruite » (duel 8). [BLOQUÉ 17]

### Non testable en l'état

- Règle 5 (justification, testée par ses conséquences) ; règle 9 : « le score ne lit pas le compteur » ne se vérifie que par recherche statique ; règle 10 : « CIBLE_NON_VISIBLE presque inatteignable au MVP » est un commentaire.
- Le compteur lu par le profil (22) : aucun critère avant son GDD.
- Code d'un déplacement après attaque, sens de « par » pour une riposte et ordre complet des refus : à fixer en 23.

## Open Questions

| Question | Propriétaire | À résoudre avant | Résolution |
|---|---|---|---|
| Duels Bastion contre Bastion et Rempart contre Rempart : le plancher à 1 donne l'avantage au **second** à frapper ; duels de 12 à 14 attaques sans enjeu de tempo. Garder, ou changer `DMG_MIN`/`DEF_BASE` ? | game-designer, systems-designer | Premier playtest, `/balance-check` | |
| Avantage du premier coup (Assaut, Chasseur) : atténué par les intentions annoncées, l'aperçu et le soin au repos ; à valider au playtest. | game-designer | Premier playtest | |
| Valeurs de `DMG_SCALE`, `DEF_BASE`, `DEF_PER_TILE_CLASS`, `DMG_MIN` (non sourcées). | systems-designer | `/balance-check` | |
| Compteur « unités détruites » : aucun consommateur dans le score (qui lit les unités en vie) ; le garder pour le profil (22), l'ajouter au score ou le retirer. | game-designer | Revue de 3 et 22 | |
| Le trait de coup blanc et les durées (200, 150, 300 ms) : propositions à valider. | art-director | Test de mouvement | |
| Contour orange (annulée) et orange-rouge (menace) en daltonisme : la croix suffit-elle ? | accessibility-specialist | Simulateur Coblis | |
| Codes de refus de l'attaquant (inconnu, d'une autre faction) et ordre complet à fixer. | game-designer | Revue de 23 | |
| Une intention d'attaque dont l'auteur meurt avant l'exécution : motif AUTEUR_DÉTRUIT. | game-designer, ai-programmer | GDD 9 | |
| L'annonce de l'IA affiche-t-elle un montant de dégâts prévu ? Retenu : non ; mais un marqueur « létale » (la cible tomberait) est calculable sur copie, puisque l'attaquant d'une intention annoncée ne se soigne pas : à décider. | ux-designer | `/ux-design hud` | Provisoire : pas de montant, marqueur à décider |
| Direction de l'avantage du premier coup : les camps étant exclusifs, le joueur frappe presque toujours le premier sur un Gardien annoncé (Assaut → Chasseur sur plaine : 6, puis 1 de riposte). Risque pour « juste mais dure » : à traiter dans le GDD de l'IA (9, elle peut attaquer depuis une tuile défensive) et au premier playtest. | game-designer, ai-programmer | GDD 9, premier playtest | |
| Reporter dans 23 : ATTAQUANT_SANS_ATTAQUE, ordre des refus, « dégâts » = PV perdus, « par » ; dans `hud.md` : maquette illustrative, « éclatement » → « gris puis affaissement ». | game-designer, ux-designer | Revue de 23 et `/ux-design hud` | |
