# IA ennemie à intentions

> **Status**: Designed (pending /design-review)
> **Author**: user + Claude (game-designer, ai-programmer)
> **Last Updated**: 2026-10-30
> **Last Verified**: 2026-10-30
> **Implements Pillar**: Pilier 4 « Juste mais dure » ; pilier 3 « Lisible comme Polytopia » ; pilier 5 par les Gardiens qui tiennent leur territoire
> **Creative Director Review (CD-GDD-ALIGN)**: REVISED 2026-10-30 — CONCERNS (la dureté n'était ni conçue ni mesurée ; armée fixe sans escalade sur 30 tours ; budget de pertes acceptables non chiffré ; comparaison hors ruines sans affichage lisible ; siège ambigu ; fantasy des Gardiens non écrite ; périmètre MVP trop large) corrigées ; escalade laissée en crochet par décision de l'utilisateur
> **System**: 9 — Gameplay, MVP. Dépend de 3, 5, 6, 7, 8, 10, 11, 12 (absent au MVP), 23.

## Summary

L'IA joue les Gardiens en deux temps : elle **annonce** à la fin de sa phase ce qu'elle frappera ou capturera au tour suivant, puis **exécute** ces intentions au début de sa phase suivante. Elle planifie sur un état filtré par sa propre vue, de façon déterministe et sans hasard, avec une économie identique à celle du joueur. Toute attaque est annoncée un tour à l'avance : le joueur peut esquiver, frapper en premier ou défendre.

## Overview

Les Gardiens ont trois types (Sentinelle : immobile ; Chasseur : poste puis traque ; Bastion : capture puis tient). Chaque tour d'IA suit six étapes : début de tour, perception (vue filtrée et pistes), exécution des intentions annoncées au tour précédent, coups ordinaires (déplacement, montée de nœud), annonce des nouvelles intentions, sauvegarde. L'IA ne peut ni attaquer ni capturer en dehors d'une intention stockée. Elle choisit ses coups par un score glouton dont les poids sont des données. Elle ne lit pas les ruines, ne réveille rien et ne recherche aucun protocole au MVP.

## Player Fantasy

**Une menace qui se laisse lire.** Le joueur voit un marqueur sur une de ses unités et sait exactement ce qui arrivera : qui frappera, où, avec quels dégâts. La tension vient du choix, pas de la surprise : fuir, frapper l'auteur avant qu'il frappe, ou accepter la perte pour tenir un nœud. Quand le joueur perd quelque chose, il peut dire : « je l'avais vu venir ».

**La menace ne tue pas l'attentif : elle lui coûte du temps et l'oblige à choisir** (fuir, frapper l'auteur, abandonner un nœud). La dureté vient du coût imposé : le tempo perdu à reculer, les fourchettes (deux cibles menacées, une seule réponse), le contrôle de zone autour des nœuds et des dormants.

**Les Gardiens obéissent.** Ils tiennent un poste et gardent ce qu'on leur a confié ; ils ne prennent aucune initiative. Leur prévisibilité est celle d'une machine fidèle à un ordre ancien : une future « IA plus maline » ne doit pas casser cette consonance (le motif en info-bulle reste un état, non un texte, pilier 2).

Trois échecs à éviter : l'IA qui triche (elle voit ce qu'elle ne devrait pas) ; la menace qu'on ne peut pas esquiver ; l'IA qui oscille sans but et ne menace plus rien.

## Detailed Design

*Étiquettes de périmètre : **[Lancement]** = reporté, tout le reste est MVP. Au MVP F1 se réduit à cinq poids (dégâts, létal, exposition, nœud, laisse) ; la dégradation à paliers (règle 20) devient un plafond dur (au-delà du budget, toutes les unités restantes restent) ; `w_raid` et les pistes (règle 9) sont [Lancement] si le prototype ne montre pas une IA amnésique ; le banc de 200 parties est ramené à 20 pour le signal. À faire chiffrer par le producer.*

*Décisions du 2026-10-30 : « siège » en deux annonces pour le dernier nœud du joueur ; comparaison du tour 30 hors points de ruine ; un seul niveau de difficulté plus « IA passive » ; l'IA ne lit pas les ruines. Valeurs [PROP] dans `assets/data/ai.*`.*

### Core Rules

**A. Flux d'un tour d'IA**

1. **Pas de phase d'annonce séparée.** L'annonce est la dernière étape de la phase ennemie du tour n ; le joueur voit les menaces pendant tout son tour n+1 ; elles sont exécutées au début de la phase ennemie du tour n+1.
2. **Début de tour.** Drapeaux remis à zéro, revenu versé. Une unité qui porte une intention d'attaque ne se soigne pas (`unites-drones.md`, règle 6).
3. **Perception.** (ADR-0005, revue du 2026-10-30 : **une perception, `filtered_copy` de l'état réel, avant chaque appel à `plan_next`** ; aucune copie n'est gardée d'un appel à l'autre, donc le run repris après un arrêt fait les mêmes appels que le run sans arrêt.) L'IA fige sa vue et construit l'état filtré (`brouillard-vision.md`, règle 25) : tuiles visibles et explorées, unités visibles seulement. Ses simulations partent d'un état **reconstruit à partir de cette vue** (`modele-etat-partie.md`, règle 11) et appliquent les fonctions de règle sans passer par la couche des commandes, en jetant leurs effets. Elle ne lit aucune information cachée : ni unités hors vue, ni ruines, ni dormants non vus. Elle met à jour ses pistes (règle 9).
4. **Exécution des intentions**, par identifiant d'intention croissant. Avant chaque commande, 9 teste les conditions d'annulation et n'émet ATTAQUER ou CAPTURER que si elles sont toutes bonnes : la commande n'est jamais refusée. Annulation d'une attaque : `AUTEUR_DÉTRUIT`, `CIBLE_DÉTRUITE`, `CIBLE_DÉPLACÉE` (même si la cible reste à portée, jamais redirigée), `HORS_DE_PORTÉE`. Annulation d'une capture : `UNITÉ_ABSENTE`, `UNITÉ_DÉTRUITE`, `NŒUD_DÉJÀ_À_L'IA`. Une unité qui exécute passe en « a agi » et ne bouge plus ce tour.
5. **Coups ordinaires** : DÉPLACER, MONTER_NŒUD ; RECHERCHER n'existe pas au MVP (règle 24).
6. **Annonce** (sauf au tour 30). Calculée sur les positions finales du tour. Une intention d'attaque n'est posée que si l'auteur est déjà à portée de la cible (Chebyshev ≤ portée, soit 1) : l'exécution ne comprend jamais de déplacement. Conséquence voulue : toute attaque de l'IA est retardée d'un tour et le joueur peut frapper l'auteur en premier (avantage de première frappe, `combat.md`, F6) ; l'IA évalue ce risque (terme « exposition »).
7. **Invariant.** 23 refuse ATTAQUER et CAPTURER émis par l'IA hors d'une exécution d'intention (code `AUCUNE_INTENTION`) : aucune attaque sans intention stockée.
8. **Fin de tour.** La partie est sauvegardée après **chaque** commande de l'IA (16, règle 9, décision du 2026-10-30) ; la fin de tour n'ajoute que le passage à la phase du joueur. Un arrêt à n'importe quelle commande reprend à la commande suivante : l'IA décide **à partir de l'état seul** (tranches Intentions, Agents de l'IA, Pistes, drapeaux « a bougé » et « a agi »), sans mémoire hors de l'état. Les coups ordinaires reprennent au `curseur_ia` de la tranche « agents de l'IA » (id de la dernière unité qui a émis une commande ce tour) : une unité qui n'a rien fait avant le curseur n'est pas replanifiée avec un état changé (ADR-0005, §5).

**B. Pistes et rôles**

9. **Pistes** (le mot « mémoire » est réservé au pilier 2). Tranche propre à 9 : au plus `PISTES_MAX` = 16 entrées (id de l'unité du joueur, tuile, tour de vue, type), durée de vie `PISTES_TTL` = 4 tours. Une entrée n'est mise à jour que par ce que montre la vue de l'IA ; elle n'est retirée que si sa tuile est visible et vide. Elle sert aux déplacements et au terme d'exposition, jamais de cible d'attaque (CIBLE_NON_VISIBLE).
10. **Ordre de planification.** Rang de rôle fixe (Bastion, puis Chasseur), puis identifiant croissant. Chaque Gardien porte un poste (tuile ou dormant gardé) fixé à la mise en place.

| Type | États | Règle |
|---|---|---|
| Sentinelle | IMMOBILE | Aucune commande ; sa vue nourrit celle de l'IA ; ne compte pas comme gardien armé (ATQ 0, MVT 0) |
| Chasseur | POSTE → TRAQUE → RETOUR | POSTE : reste à `LEASH` = 4 tuiles du poste. TRAQUE : cible la mieux scorée, de préférence un drone isolé. RETOUR : après 2 tours sans cible. Un changement d'état exige une marge de score (anti-oscillation) |
| Bastion | CAPTURE → TIENT → RIPOSTE | CAPTURE : rejoint le meilleur nœud non possédé et annonce la capture dès qu'il est dessus. TIENT : reste sur le nœud (repos : +4 PV). RIPOSTE : annonce l'attaque d'une unité adjacente qui menace le nœud |

11. **Dormants gardés.** La couverture d'un dormant est le nombre de Gardiens armés dont `MVT + portée ≥` la distance de Chebyshev au dormant. Chaque dormant du côté de l'IA a une couverture ≥ 1 (à fixer avec la génération de cartes, 21, avec le même calcul). Veto dur : un déplacement du gardien assigné qui ferait tomber la couverture sous 1 est interdit.
12. **Raid.** Une unité du joueur visible à distance ≤ `RAID_RADIUS` = 2 d'un dormant de l'IA, ou un réveil vu, est un raid : le terme `w_raid` s'applique à elle et le gardien à portée annonce une intention contre le raideur (motif REPRÉSAILLE).
13. **Dernier nœud du joueur : siège.** L'IA n'annonce la capture du dernier nœud du joueur qu'après **deux annonces consécutives** sur ce nœud : le joueur dispose de deux tours pour tuer le Bastion. L'élimination reste une défaite possible. (Amende 3 et 11 ; `noeuds.md`, AC-ND28.)

**C. Choix des coups (score glouton, déterministe)**

14. Pour chaque unité, l'IA énumère les couples (tuile atteignable et visible pour l'IA, action : attaque annoncée, capture annoncée, ou rien) et retient le meilleur score (F1). Aucun hasard : le compteur de tirages n'est jamais touché. Ordre total des égalités : score, puis id de l'unité, puis index de tuile, puis ordre fixe des types d'action.
15. **Une intention par unité.** Plusieurs intentions peuvent viser la même cible (tir groupé, paramètre actif / inactif), résolues par id croissant.
16. **Aucune statistique en dur.** L'IA lit les données et l'état (ATQ, PV, coûts) ; les dégâts viennent de la fonction pure du combat (F2), sans copie. Les effets des protocoles (12) passeront par 6 et 8.
17bis. **Escalade : crochet seulement au MVP.** Une étape « renfort » (vide au MVP) est prévue après les coups ordinaires : elle pourra dépenser le surplus d'énergie en un Gardien sur un nœud de l'IA. Question ouverte bloquante : courbe de menace du tour 1 au tour 30 (AC-IA38).
17. **MONTER_NŒUD** : meilleur rapport gain de revenu / coût, puis id croissant. L'IA ne réveille rien ; son surplus d'énergie est plafonné à 99 et perdu, ce qui est accepté.

**D. Lisibilité et budget**

18. **Une intention = un auteur, une cible, une tuile cible, un motif** (TRAQUE, REPRÉSAILLE, CAPTURE, DÉFENSE). Le marqueur « létale » est calculé par la même fonction que l'aperçu de combat. Si l'auteur est dans le brouillard, le marqueur est dessiné sur la tuile cible seulement ; une capture de nœud affiche son marqueur sur le nœud même s'il n'est pas visible.
19. **Budget en comptage, jamais en millisecondes** (le tour doit reprendre à l'identique après un arrêt à n'importe quelle commande) : copies ≤ 2 500 par tour (`modele-etat-partie.md`, formule 5), évaluations de formule pures ≤ `EVALS_MAX` = 20 000. La planification n'utilise presque pas de copies (environ une par unité plus K aperçus). La planification d'un appel tourne sur un fil de travail (ADR-0005 §7), une commande à la fois, sur une copie neuve de l'état réel ; le budget est **par appel** (plafond du tour ÷ nombre d'unités de l'IA, en données) et non par tour, pour que la reprise n'ait aucun compteur à retrouver.
20. **Dégradation.** À 70 % du budget : `K_DEST` passe de 6 à 2 ; à 100 % : les unités restantes rejoignent leur poste ou restent. ANNONCER n'est jamais sauté. Coupure `N_REFUS_MAX` = 32 ; avec les pré-contrôles tout refus est un bogue journalisé.

**E. Tour 1, tour 30, ruines**

21. **Tour 1.** La phase ennemie n'exécute rien (3, règle 4). L'IA place ses Gardiens et envoie le Bastion vers le nœud le plus proche.
22. **Tour 30.** Aucune annonce ; elle exécute seulement les intentions du tour 29 ; seul MONTER_NŒUD compte encore. Le contrôle de fin de partie suit chaque exécution ; les intentions restantes sont abandonnées (3, règle 11).
23. **Ruines.** L'IA ne les lit ni ne les défend ; elles n'entrent pas dans son état filtré (`ruines-fragments.md`, règle 11). **La comparaison de score du tour 30 se fait hors points de ruine** ; ils restent dans le profil. Pour qu'aucun joueur ne se croie en tête et perde, le HUD montre en permanence le score qui décide de la victoire, séparé des points de ruine (« Victoire : 42 contre 38 » et, à part, « Mémoire : +6 »). Amende 3, 17 et `hud.md`.
24. **Protocoles (12).** Au MVP, l'IA n'émet aucun RECHERCHER. Crochet prévu : une étape « dépenses » entre les coups ordinaires et l'annonce appelle `choisir_recherche(vue, budget)`, qui lit une liste ordonnée d'ids des données (vide au MVP).
25. **Difficulté.** Un seul niveau « Standard » plus le drapeau « IA passive » (aucune annonce, aucun mouvement, vue recalculée quand même, `brouillard-vision.md`, règle 9) pour la première partie. Les paramètres exposés (`K_DEST`, `LEASH`, `PISTES_TTL`, `PISTES_MAX`, `RAID_RADIUS`, poids de F1, tir groupé) ne changent jamais l'information ni l'économie ; les niveaux suivants ne varient que ces données.

### States and Transitions

| État du Gardien | Événement | État suivant |
|---|---|---|
| Chasseur POSTE | Cible scorée au-dessus du seuil + marge | TRAQUE |
| Chasseur TRAQUE | 2 tours sans cible | RETOUR |
| Chasseur RETOUR | Poste atteint | POSTE |
| Bastion CAPTURE | Nœud atteint | TIENT (capture annoncée) |
| Bastion TIENT | Unité adjacente qui menace le nœud | RIPOSTE |
| Bastion RIPOSTE | Menace écartée | TIENT |
| Bastion TIENT | Dernier nœud du joueur en vue | SIÈGE (compte 1 / 2, 2 / 2) |
| Bastion SIÈGE | Bastion tué, nœud quitté ou repris | TIENT, compte à zéro |
| Bastion SIÈGE | Deuxième annonce exécutée | Capture, élimination |
| Intention annoncée | Une raison d'annulation vraie à l'exécution | Annulée (raison journalisée) |
| Intention annoncée | Conditions bonnes | Exécutée |

**Siège (règle 13), cas :** l'annonce « 1 / 2 » occupe l'unique intention du Bastion ; il ne peut pas annoncer d'autre attaque ce tour-là, mais il peut exécuter une intention déjà stockée. Le compte repart à zéro si le Bastion est tué, quitte le nœud, ou si le joueur reprend la possession du nœud. Le joueur dispose exactement de ses deux tours (celui qui suit chaque annonce). Au tour 29 ou 30, un siège qui ne peut pas aboutir avant la fin de la partie n'est pas annoncé.

### Interactions with Other Systems

| # | Système | Sens | Contrat |
|---|---|---|---|
| 1 État | écrit | Tranche Intentions (auteur, cible, tuile de l'auteur, tuile de la cible, type, motif, tours, statut, raison) et tranche Pistes |
| 3 Tours | lit | Phases, tour 1 et 30, abandon des intentions, comparaison hors ruines, siège |
| 5 Brouillard | lit | État filtré par la vue de l'IA (règle 25) |
| 6 Unités | lit | Stats, rôles, soin au repos |
| 7 Réveil | lit | Dormants du côté de l'IA gardés ; l'IA ne réveille rien |
| 8 Combat | lit | Fonction pure des dégâts, aperçu, létale, première frappe |
| 10 Énergie | lit | Même économie, plafond 99 |
| 11 Nœuds | écrit | MONTER_NŒUD, capture annoncée, siège |
| 12 Protocoles | lit (plus tard) | `choisir_recherche` |
| 13 Ruines | aucune | Ne lit ni ne défend |
| 17 HUD | est lu par | Marqueurs, motif, létale |
| 21 Cartes | contrainte | Couverture des dormants |
| 23 Commandes | appelle | ATTAQUER et CAPTURER seulement via une intention ; `AUCUNE_INTENTION` |

## Formulas

*Entiers uniquement.*

### F1. Score d'un couple (tuile, action)

`S = w_dég × D_inf + w_létal × [létal] − w_perte × Riposte − w_danger × Exposition + w_noeud × Valeur_nœud + w_raid × [raideur] − w_laisse × max(0, dist(poste) − LEASH) + w_prog × gain_distance_objectif`

| Poids [PROP] | Valeur |
|---|---|
| `w_dég` | 10 |
| `w_létal` | 30 |
| `w_perte` | 8 |
| `w_danger` | 6 |
| `w_noeud` (par niveau) | 12 |
| `w_raid` | 25 |
| `w_laisse` (par tuile) | 3 |
| `w_prog` (par tuile) | 2 |

D_inf : dégâts infligés (F2 de `combat.md`), Riposte : dégâts reçus en riposte, Exposition : somme des dégâts potentiels des unités visibles du joueur sur l'auteur à la tuile finale (première frappe au joueur), pondérée par l'âge pour les pistes. **Exemple** : un Chasseur peut infliger 5 dégâts non létaux, recevoir 3 en riposte, subit une exposition de 4 et ne dépasse pas sa laisse : S = 10×5 − 8×3 − 6×4 = 2. Un déplacement vers son poste qui réduit la distance de 2 tuiles : S = 4 : il préfère l'attendre. (Valeurs de départ à équilibrer en prototype.)

### F2. Budget d'un tour

`copies ≤ 2 500` ; `évaluations ≤ EVALS_MAX = 20 000` ; palier 1 à `0,7 × budget` (K_DEST 6 → 2) ; palier 2 à `1,0 × budget`. **Exemple** : 8 Gardiens × K_DEST 6 × 8 actions = 384 évaluations par passe : très loin de 20 000.

### F3. Couverture d'un dormant

`couverture(D) = nombre de Gardiens armés g tels que MVT(g) + portée(g) ≥ cheb(g, D)` ≥ 1 requis. **Exemple** : Chasseur (MVT 3, portée 1) à 4 tuiles d'un dormant : couvre ; une Sentinelle (ATQ 0) ne compte pas.

## Edge Cases

- **Cible déplacée mais encore à portée** : annulée (`CIBLE_DÉPLACÉE`), jamais redirigée.
- **Auteur détruit entre annonce et exécution** : `AUTEUR_DÉTRUIT`, rien n'est exécuté.
- **Cible soignée au repos entre annonce et exécution** : le marqueur « létale » est recalculé à l'affichage de chaque tour du joueur ; l'issue reste exactement l'aperçu du jour (à reporter dans `combat.md`, règle 11, qui promet des dégâts constants).
- **Cible sans tuile libre adjacente** : la seule réponse est de tuer l'auteur. Budget de pertes inévitables [PROP] : au plus 1 pour 10 parties chez le joueur attentif, et seulement si la situation est née d'un choix du joueur au tour précédent. L'IA ne pose jamais d'annonce létale à plusieurs auteurs sur une cible sans issue qu'elle a elle-même encerclée en un tour.
- **Plusieurs intentions sur la même cible** : résolues par id croissant ; si la cible meurt, les suivantes sont annulées (`CIBLE_DÉTRUITE`).
- **Dormant du côté de l'IA attaqué** : raid (règle 12) ; le gardien en portée annonce contre le raideur.
- **Gardien assigné qui devrait quitter son poste** : veto dur si la couverture tombe sous 1.
- **Unité de l'IA posée sur une ruine** : sans effet ; le joueur doit libérer la tuile.
- **Pistes périmées** : retirées après `PISTES_TTL` tours ou si la tuile est visible et vide ; une destruction cachée ne purge rien.
- **Budget dépassé** : dégradation en deux paliers, ANNONCER jamais sauté (règle 20).
- **Refus de commande par 23** : bogue journalisé ; coupure à 32 refus.
- **Reprise après sauvegarde en cours de tour d'IA** : le tour est rejoué à l'identique (aucun hasard, budgets en comptage).
- **Tour 30** : pas d'annonce ; intentions restantes abandonnées si la partie finit.
- **IA passive** : aucune annonce ni mouvement ; vue recalculée.

## Dependencies

| Système | Direction | Nature |
|---|---|---|
| 1, 3, 5, 6, 8, 10, 11, 23 | dépend de | dur |
| 7 Réveil | dépend de | souple (garde des dormants) |
| 12 Protocoles | dépend de | souple, absent au MVP |
| 17 HUD | est utilisé par | dur (marqueurs, motifs) |
| 21 Cartes | est utilisé par | dur (couverture des dormants) |
| 13 Ruines | aucune | l'IA ne lit ni ne défend |

## Tuning Knobs

| Réglage | Départ | Plage sûre | Effet si trop haut | Effet si trop bas |
|---|---|---|---|---|
| `K_DEST` | 6 | 2 à 8 | Budget | IA myope |
| `LEASH` | 4 | 2 à 6 | Chasseurs trop loin du poste | Chasseurs passifs |
| `PISTES_TTL` | 4 tours | 2 à 6 | IA qui poursuit un fantôme | IA amnésique |
| `PISTES_MAX` | 16 | 8 à 32 | Données | Pistes perdues |
| `RAID_RADIUS` | 2 | 1 à 3 | Représailles trop larges | Raid impuni |
| `w_dég`, `w_létal`, `w_perte`, `w_danger`, `w_noeud`, `w_raid`, `w_laisse`, `w_prog` | F1 | à calibrer | Voir F1 | Voir F1 |
| `EVALS_MAX` | 20 000 | 10 000 à 40 000 | Tour long | Dégradation précoce |
| Marge d'état du Chasseur | [À FIXER] | — | Chasseur figé | Oscillation |
| Tir groupé | actif | actif / inactif | Menaces concentrées | Menaces dispersées |
| Siège | 2 annonces | 2 à 3 | Défaite impossible | Défaite brutale |

## Visual/Audio Requirements

- Marqueur d'intention sur la cible (forme distincte du marqueur « létale »), motif en info-bulle (« Représailles : vous avez réveillé un drone »). Couleur ennemie `#B07CE0` (art bible §4). Audio facultatif (20) : un cue d'annonce, un cue d'exécution, sans information portée par le son seul.

## Game Feel

L'annonce doit tomber comme un avertissement lisible, non comme un piège : un tour entier pour répondre. L'exécution est brève (les intentions s'enchaînent par id croissant). L'IA ne doit jamais sembler hésiter : une unité qui change d'avis à chaque tour est un défaut (anti-oscillation).

## UI Requirements

- Marqueurs d'intention (auteur, cible, tuile cible, létale), motif, annonce de siège sur le dernier nœud (compte « 1 / 2 »), état de l'IA passive en première partie. Détails au GDD 17 et dans `hud.md`.

## Cross-References

- `design/gdd/tours-conditions-victoire.md` : siège (règle 13), comparaison hors ruines (règle 23), hasard de l'IA (ligne 83 : zéro tirage).
- `design/gdd/noeuds.md` : AC-ND28 et le siège.
- `design/gdd/modele-etat-partie.md` : tranche Intentions complétée, tranche Pistes, `INTENT_CAP` = une intention par unité.
- `design/gdd/commandes-evenements.md` : `AUCUNE_INTENTION` ; budget de copies unifié (formule 3 contre formule 5).
- `design/gdd/combat.md` : règle 11 (soin de la cible entre annonce et exécution).
- `design/gdd/reveil-drones.md` : règle 10 (la Sentinelle ne compte pas ; mesure de « un tour »).
- `design/gdd/carte-tuiles-terrain.md` et GDD 21 : couverture des dormants.

## Acceptance Criteria

*Étiquettes : **Logic** = `tests/unit/ia/`, état par fabrique, graine fixe, sans rendu ; **Intégration** = `tests/integration/ia/` ; **UI** = capture retenue dans `production/qa/evidence/ia-ennemie/` (nom `ACIA<n>-<scène>.png`), sur l'appareil cible ; **Playtest** = rapport de séance au même endroit. [BLOQUÉ n] = attend le système n. Valeurs de départ : `PISTES_MAX` 16, `PISTES_TTL` 4, `LEASH` 4, `RAID_RADIUS` 2, `K_DEST` 6 (2 au palier 1), `EVALS_MAX` 20 000, copies 2 500, siège 2 annonces, `N_REFUS_MAX` 32. Entiers uniquement ; aucune graine ni horloge système dans la logique de 9. Un « double d'IA » est un test qui lit un champ interdit : il doit échouer.*

### A. Flux d'un tour, annonce et exécution (règles 1 à 8)

- **AC-IA1** (Logic, règles 1 à 8) **THEN** les étapes d'un tour d'IA s'appellent dans l'ordre : début de tour, perception, exécution, coups ordinaires, annonce, sauvegarde, chacune une fois ; la permutation de deux étapes fait échouer le test. [BLOQUÉ 3]
- **AC-IA2** (Intégration, règle 1) **THEN** une intention annoncée à la fin de la phase ennemie du tour n est visible pendant tout le tour n+1 du joueur et exécutée une seule fois, au début de la phase ennemie du tour n+1. [BLOQUÉ 3]
- **AC-IA3** (Logic, règle 6) **THEN** un auteur déjà à portée (Chebyshev ≤ 1) pose l'intention ; à distance 2, 3 ou 4, aucune intention d'attaque ; l'exécution n'émet aucun DÉPLACER (test sur les 8 voisines).
- **AC-IA4** (Logic, règle 18) **THEN** chaque intention a un auteur, une cible, une tuile cible et un motif parmi {TRAQUE, REPRÉSAILLE, CAPTURE, DÉFENSE} (un motif hors liste est refusé), et au plus une intention par unité. [BLOQUÉ 1]
- **AC-IA5** (Logic, règle 2) **THEN** une unité porteuse d'une intention d'attaque ne se soigne pas au début du tour ; sans intention, elle se soigne. [BLOQUÉ 6]

### B. Invariant et annulations (règles 4 et 7)

- **AC-IA6** (Intégration, règle 7) **GIVEN** un double d'IA qui émet ATTAQUER ou CAPTURER hors exécution d'intention, **THEN** 23 répond `AUCUNE_INTENTION` dans 100 % des cas, état identique avant et après ; le même ordre émis depuis une exécution valide est accepté. [BLOQUÉ 23]
- **AC-IA7** (Logic, règle 4) **THEN** auteur détruit → `AUTEUR_DÉTRUIT`, aucune commande émise.
- **AC-IA8** (Logic, règle 4) **THEN** cible détruite → `CIBLE_DÉTRUITE` ; avec trois intentions (ids 1, 2, 3) sur la même cible dont la première la tue, les ids 2 et 3 sont annulés dans cet ordre.
- **AC-IA9** (Logic, règle 4) **THEN** cible déplacée sur une tuile encore à portée → `CIBLE_DÉPLACÉE` ; l'intention n'est ni redirigée ni transformée (0 commande émise).
- **AC-IA10** (Logic, règle 4) **THEN** `HORS_DE_PORTÉE` quand la cible n'a pas bougé et que l'auteur est hors de portée, `CIBLE_DÉPLACÉE` quand elle a bougé ; une seule raison journalisée par intention.
- **AC-IA11** (Logic, règle 4) **THEN** capture annoncée : `UNITÉ_ABSENTE`, `UNITÉ_DÉTRUITE`, `NŒUD_DÉJÀ_À_L'IA` selon le cas ; conditions bonnes : CAPTURER émis une fois. [BLOQUÉ 11]
- **AC-IA12** (Intégration, règles 4 et 20) **GIVEN** 200 parties IA contre IA de graines fixes avec un joueur scripté, **THEN** 0 refus de commande, et toute annulation journalise exactement une raison de la liste. [BLOQUÉ 23]
- **AC-IA13** (Logic, règle 4) **THEN** une unité qui vient d'exécuter est « a agi » et ne peut plus se déplacer ce tour.

### C. Perception, état filtré et pistes (règles 3 et 9)

- **AC-IA14** (Intégration, règle 3) **GIVEN** une unité du joueur hors vue, un dormant jamais vu et une ruine, **THEN** l'état filtré de l'IA n'en contient aucun ; un double qui lit l'un d'eux échoue. [BLOQUÉ 5]
- **AC-IA15** (Logic, règle 9) **GIVEN** 17 unités du joueur vues, **THEN** au plus 16 pistes.
- **AC-IA16** (Logic, règle 9) **THEN** une piste vue au tour t est conservée au tour t+3 et retirée au tour t+4 ; retirée plus tôt si sa tuile est visible et vide ; conservée si sa tuile est hors vue, même si l'unité y a été détruite.
- **AC-IA17** (Logic, règle 9) **THEN** aucune intention d'attaque ne prend une piste pour cible (0 commande `CIBLE_NON_VISIBLE` sur 200 parties) ; elle alimente déplacements et exposition.

### D. Choix des coups, rôles et égalités (règles 10 à 17, F1)

- **AC-IA18** (Logic, règle 10) **GIVEN** 2 Bastions (ids 7, 3), 2 Chasseurs (ids 9, 5), 1 Sentinelle, **THEN** l'ordre est Bastion 3, Bastion 7, Chasseur 5, Chasseur 9 ; la Sentinelle n'émet rien et ne compte pas comme gardien armé.
- **AC-IA19** (Logic, F1) **GIVEN** l'exemple du GDD (D_inf 5, Riposte 3, Exposition 4), **THEN** S = 2 ; le déplacement vers le poste (2 tuiles) donne S = 4 et est choisi ; poids lus dans `assets/data/ai.*`.
- **AC-IA20** (Logic, règle 14) **THEN** quatre couples de score égal se départagent par id de l'unité, index de tuile, ordre fixe des actions ; identique sur 1 000 permutations de l'énumération.
- **AC-IA21** (Logic, règle 10) **THEN** un Chasseur en POSTE reste en POSTE sous le seuil plus la marge, passe en TRAQUE au-dessus, en RETOUR après 2 tours sans cible, en POSTE à l'arrivée ; sur 100 tours avec une cible qui oscille autour du seuil, au plus 2 changements d'état ; en POSTE il reste à `LEASH` ≤ 4. [marge à fixer]
- **AC-IA22** (Logic, règle 10) **THEN** Bastion : CAPTURE → TIENT dès l'arrivée (capture annoncée le même tour) ; TIENT → RIPOSTE devant une unité adjacente qui menace le nœud (motif DÉFENSE ou REPRÉSAILLE) ; RIPOSTE → TIENT menace écartée ; +4 PV au repos en TIENT. [BLOQUÉ 6, 11]
- **AC-IA23** (Logic, règle 17) **THEN** MONTER_NŒUD : meilleur rapport revenu / coût puis id ; 0 RÉVEILLER et 0 RECHERCHER sur 200 parties ; surplus plafonné à 99. [BLOQUÉ 7, 10]
- **AC-IA24** (Logic, règle 15) **THEN** tir groupé actif : 3 Chasseurs à portée de la même cible posent 3 intentions résolues par id croissant ; inactif : jamais 2 intentions sur une cible quand une autre est atteignable.

### E. Dormants, raid, représailles, siège (règles 11 à 13, F3)

- **AC-IA25** (Logic, règle 11, F3) **THEN** un Chasseur (MVT 3, portée 1) à 4 tuiles d'un dormant couvre (1), à 5 tuiles non (0) ; une Sentinelle ajoute 0 ; tout dormant du côté de l'IA a une couverture ≥ 1 sur les cartes de test. [BLOQUÉ 21, 7]
- **AC-IA26** (Logic, règle 11) **THEN** un déplacement du gardien assigné qui ferait tomber la couverture sous 1 est exclu même s'il a le meilleur score ; autorisé si un second gardien couvre.
- **AC-IA27** (Intégration, règle 12) **THEN** une unité du joueur visible à distance 2 d'un dormant de l'IA (ou un réveil vu) reçoit `w_raid` = 25 et le gardien à portée annonce un motif REPRÉSAILLE ; à distance 3 sans réveil : pas de raid. [BLOQUÉ 7]
- **AC-IA28** (Intégration, règle 13) **THEN** sur le dernier nœud du joueur, la première annonce affiche « 1 / 2 » sans capture annoncée, la seconde consécutive « 2 / 2 » ; l'exécution a lieu au plus tôt au tour suivant (deux tours pour tuer le Bastion) ; si le Bastion meurt entre les deux, le compte repart à zéro ; un nœud non dernier se capture après une annonce. [BLOQUÉ 11, 3]
- **AC-IA29** (UI, règle 18) **THEN** captures : marqueur d'attaque, capture d'un nœud non visible (marqueur sur le nœud), auteur dans le brouillard (marqueur sur la tuile cible), motif en info-bulle, siège « 1 / 2 » puis « 2 / 2 » ; forme du marqueur différente de celle de « létale », couleur `#B07CE0`. [BLOQUÉ 17]
- **AC-IA30** (Logic + UI, règle 18) **THEN** « létale » est calculée par la fonction pure du combat, identique à l'aperçu sur 100 couples ; recalculée à chaque tour du joueur si la cible est soignée. [BLOQUÉ 8, 17]

### F. Déterminisme, budget et reprise (règles 14, 19, 20)

- **AC-IA31** (Logic, règle 14) **THEN** sur 100 exécutions de même état et même graine, les intentions sont identiques octet pour octet ; compteur de tirages à 0 avant et après ; aucun générateur aléatoire ni horloge système.
- **AC-IA32** (Logic, règles 19 et 20, F2) **THEN** copies ≤ 2 500 et évaluations ≤ 20 000 sur tout tour type (8 Gardiens, `K_DEST` 6 : 384 évaluations par passe) ; au MVP, plafond dur (ADR-0005 §4) : à 100 % du budget d'un appel ou du tour les unités restantes rejoignent leur poste ou restent (les paliers à 70 % et `K_DEST` 6 → 2 sont [Lancement]) ; ANNONCER est toujours appelé ; budget compté, jamais mesuré en ms.
- **AC-IA33** (Intégration, règle 19) **THEN** un arrêt après la commande k d'un tour d'IA (la partie est sauvegardée après chaque commande ; le système des tours reprend la phase à la commande k + 1) donne le même tour qu'un tour sans arrêt (intentions, pistes, agents, statuts, raisons, journal) sans exécution doublée, pour tout k. [BLOQUÉ 1]

### G. Tour 1, tour 30, ruines, difficulté (règles 21 à 25)

- **AC-IA34** (Intégration, règles 21 et 22) **THEN** tour 1 : 0 intention exécutée, le Bastion va vers le nœud le plus proche ; tour 30 : aucune annonce, seules les intentions du tour 29 s'exécutent avec contrôle de fin de partie après chacune, les restantes sont abandonnées ; seul MONTER_NŒUD compte. [BLOQUÉ 3]
- **AC-IA35** (Intégration, règle 23) **GIVEN** un tour 30 avec des points de ruine d'écart, **THEN** la comparaison se fait hors points de ruine ; le HUD affiche en permanence le score décisif séparé des points de ruine, de sorte qu'aucun résultat ne contredise ce qui est affiché (capture retenue) ; les points de ruine restent dans le profil ; l'IA ne lit, ne défend aucune ruine, ne réveille rien, n'émet aucun RECHERCHER ; une unité de l'IA sur une ruine est sans effet. [BLOQUÉ 3, 13]
- **AC-IA36** (Intégration, règle 25) **THEN** « IA passive » : 0 annonce, 0 mouvement, 0 commande, vue recalculée ; changer les paramètres exposés ne change ni l'état filtré ni les revenus. [BLOQUÉ 5, 10]

### H. Playtest (signal d'équité)

- **AC-IA37** (Playtest, règle 6) **GIVEN** 200 parties IA contre IA avec un joueur scripté attentif, **THEN** il perd 0 unité sur menace annoncée (les cas « cible sans tuile libre adjacente » sont comptés à part) ; **GIVEN** 200 parties avec un joueur inattentif, **THEN** il subit au moins une attaque exécutée par partie. Le rapport consigne menaces par partie, annulations par raison, changements d'état par Chasseur, refus (0 attendu). Seuils [PROP], à recaler quand poids et marge sont fixés. [BLOQUÉ 17]

- **AC-IA38** (Playtest, Player Fantasy) **THEN** le rapport de pression [PROP] consigne, pour le joueur attentif : au moins N menaces annoncées par partie au contact ; au moins une fourchette (deux cibles menacées, une seule réponse) par partie ; au moins un tour où une unité a dû fuir ou frapper à cause d'une annonce ; la menace au tour 20 (Gardiens armés) au moins égale à X ; et pour un joueur scripté qui s'étend sans couvrir ses nœuds, au moins un nœud pris par l'IA. Le joueur attentif déclare avoir été « obligé de choisir » au moins une fois par partie. [BLOQUÉ 17 ; N et X à fixer au prototype]
- **AC-IA39** (Playtest, Edge Cases) **THEN** au plus 1 perte inévitable (cible sans issue) pour 10 parties chez le joueur attentif, chacune née d'un choix du joueur au tour précédent.

### Captures retenues exigées (toutes [BLOQUÉ 17])

AC-IA29 (marqueur d'attaque ; nœud non visible ; auteur dans le brouillard ; motif REPRÉSAILLE ; siège « 1 / 2 » puis « 2 / 2 »), AC-IA30 (« létale » comparée à l'aperçu, avant et après un soin), AC-IA36 (IA passive en première partie), AC-IA37 (rapport de séance).

## Open Questions

| Question | Propriétaire | Échéance | Statut |
|---|---|---|---|
| Poids de F1 et marge d'état du Chasseur | ai-programmer, game-designer | Prototype du flux d'intentions (une semaine, voir l'index) | Ouverte |
| Budget unique de tour (2 000 ms, 2 500 copies, 750 ms de vue) | technical-director | ADR | Ouverte |
| Soin de la cible entre annonce et exécution : « létale » recalculée ? | game-designer | Revue de 8 | Ouverte |
| Nombre de protocoles au MVP (6) contre IA qui n'en recherche aucun | game-designer | GDD 12 | Ouverte |
| Palier « Facile » avant le lancement | game-designer | Alpha | Reporté |
| Courbe de menace tour 1 → 30 : renfort de Gardien avec le surplus d'énergie (crochet posé, règle 17bis) | game-designer, economy-designer | Avant le premier playtest du prototype | Ouverte, bloquante |
| Corriger la phrase du concept (« publie ses intentions à la fin du tour du joueur ») : les intentions sont annoncées à la fin de la phase ennemie et visibles pendant tout le tour du joueur | creative-director | Prochaine révision du concept | Ouverte |
