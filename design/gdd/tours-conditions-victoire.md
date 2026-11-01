# Tours et conditions de victoire

> **Status**: In Design
> **Author**: user + Claude (game-designer, systems-designer)
> **Last Updated**: 2026-10-29
> **Last Verified**: 2026-10-29
> **Implements Pillar**: Pilier 4 « La puissance se mérite » (menaces annoncées un tour à l'avance) ; pilier 5 « Le brouillard cache une question » (les ruines lues comptent au score) ; pilier 1 « La meute se voit grandir » (une faction éliminée disparaît de la carte)
> **Creative Director Review (CD-GDD-ALIGN)**: REVISED 2026-10-29 — CONCERNS (F à préciser ; valeur d'une ruine illisible en partie ; l'IA et les ruines ; plage de D_MAX) corrigées : F compte les ruines lues, valeur affichée sur la puce de ruine, question confiée au GDD de l'IA, plage de D_MAX et notation alignées

## Summary

Ce système fixe le rythme et la fin d'une partie : 30 tours au plus, chacun fait d'une
phase du joueur puis d'une phase ennemie où l'IA exécute les attaques annoncées au tour
précédent avant d'annoncer celles du suivant. La partie s'arrête à la domination (plus
aucun nœud adverse), à l'élimination du joueur, à l'abandon, ou à la fin du 30e tour,
où le meilleur score gagne. Le score composite pèse lourdement les ruines lues, pour
qu'une ruine ne soit jamais un détour perdu ; seule une partie menée à son terme établit
un meilleur score.

> **Quick reference** — Layer: `Core` · Priority: `MVP` · Key deps: `Modèle d'état de partie`

## Overview

Les tours et conditions de victoire donnent à une partie son rythme et sa fin. Une
partie dure **30 tours** au plus. Chaque tour commence par la phase du joueur, puis la
phase ennemie : l'IA exécute ou annule les attaques qu'elle avait annoncées au tour
précédent, joue ses autres coups, puis **annonce ses attaques du tour suivant**, que le
joueur verra pendant tout son prochain tour (pilier 4, « La puissance se mérite »). La
partie s'arrête au **premier** de deux événements : la **domination** — toutes les
factions adverses éliminées, une faction l'étant dès qu'elle ne possède plus aucun nœud
— ou la **fin du 30e tour**. Le **score** de fin de partie additionne le territoire, les
nœuds et leurs niveaux, les protocoles, les unités et, avec un poids fort, les
**ruines lues** : une ruine n'est jamais un détour perdu, même quand on gagne vite par
domination (pilier 5). Seule une partie menée à son terme — domination ou 30e tour — peut
établir un meilleur score ; une partie perdue ou abandonnée garde ses fragments, mais pas
son score (décisions du 2026-10-29). Le joueur vit ce système à chaque appui sur « Fin
du tour », dans le compteur « Tour 7 / 30 » du HUD et sur l'écran de fin. Ce système
possède le numéro de tour, la phase, la faction active, le statut de fin et la formule
du score ; il fait avancer le tour par des commandes internes
(`design/gdd/commandes-evenements.md`).

## Player Fantasy

**La menace qui se lit.** Chaque fin de tour est un pari que vous lisez à voix haute :
vous voyez ce que l'ennemi prépare et vous choisissez ce que cela vous coûte. Trente
tours, une saison courte où rien ne frappe sans prévenir, et où une ruine lue pèse
autant qu'une ville prise.

**L'émotion visée est la tension maîtrisée** : le joueur sait toujours ce qui l'attend et
combien de temps il lui reste. C'est le pilier 4 (« un joueur attentif peut éviter toute
perte annoncée ») rendu vérifiable par le rythme du tour : l'IA annonce, le joueur
répond, l'IA exécute.

**Moment d'ancrage.** Tour 24 : le compteur passe en ambre, deux attaques sont annoncées,
une ruine brille à trois tuiles. Le joueur calcule : esquiver, ou lire la ruine et
accepter une perte ? Il choisit la ruine — au score, elle vaut plus qu'un drone.

*Cadrage proposé par le game-designer. Écarté : « Trente tours pour rendre la couleur au
monde », qui reprend le pilier 1 déjà porté par la recoloration.*

## Detailed Design

### Core Rules

*Conçu avec game-designer (règles du tour) et systems-designer (score, Formulas).*

#### Le déroulé d'un tour

1. **Nouvelle partie.** L'état est CRÉÉE au tour 0, puis la commande interne
   COMMENCER_LE_TOUR (joueur, tour 1) ouvre la partie.
2. **Début du tour d'une faction**, dans cet ordre : la phase et la faction active
   changent (le numéro de tour augmente quand c'est le joueur qui commence) ; les
   drapeaux « a bougé » et « a agi » de ses unités sont remis à zéro (6) ; son revenu
   d'énergie est versé (10) ; sa recherche avance (12), si bien qu'un protocole terminé
   est utilisable aussitôt.
3. **Ordre d'un tour n** (décision du 2026-10-29) : phase du joueur → « Fin du tour » →
   phase ennemie : l'IA **exécute ou annule** les attaques qu'elle avait annoncées au
   tour n − 1 (jamais redirigées), joue ses autres coups par les commandes ordinaires,
   puis **annonce ses attaques du tour n + 1** → fin du tour (sauvegarde automatique, 16)
   → tour n + 1. La partie est sauvegardée **après chaque commande, celles de l'IA
   comprises** (décision du 2026-10-30, `design/gdd/modele-etat-partie.md`) : un arrêt de
   l'application pendant la phase ennemie ne fait jamais rejouer son tour au joueur ; la
   phase ennemie **reprend à la commande suivante**, l'IA décidant à partir de l'état seul
   (9), et elle donne le même résultat qu'une phase sans interruption. « Intentions publiées » est une étape de la fin de la phase ennemie,
   **pas une phase stockée** (`design/gdd/modele-etat-partie.md`, mis à jour).
4. **Aucune attaque au tour 1.** La phase ennemie du tour 1 n'exécute rien ; elle annonce
   pour le tour 2. Rien ne frappe sans avoir été annoncé.
5. **Tout passe par des commandes.** Le début d'un tour, l'exécution d'une intention et
   l'annonce sont des commandes internes ; « Fin du tour » et « Abandonner » sont des
   commandes du joueur (`design/gdd/commandes-evenements.md`).
6. **Le tour 30.** La phase ennemie du tour 30 exécute les attaques annoncées au tour 29
   (le joueur les a vues pendant son tour 30) et **n'annonce rien**, faute de tour 31.
   Puis la fin du tour sauvegarde et la partie se termine (règle 9). Le compteur
   n'affiche jamais « 31 ».
7. **Coupure du tour de l'IA.** Au bout de N_REFUS_MAX commandes de l'IA refusées dans un
   même tour (32, `design/gdd/commandes-evenements.md`), l'IA arrête ses coups et passe
   directement à l'annonce de ses attaques ; une ligne est écrite dans le journal de
   développement.
8. **Première partie** (accueil du concept) : une partie peut être marquée « IA
   passive » ; ce drapeau est transmis à l'IA (9), le déroulé du tour ne change pas.

#### Fin de partie

9. **La partie s'arrête au premier de ces événements** :
   - **Domination** : toutes les factions adverses sont éliminées. Victoire.
   - **Défaite** : la faction du joueur est éliminée.
   - **Fin du tour 30** : les scores des deux camps sont calculés avec la même formule,
     le **score décisif** (formule 1 avec F = 0 : les points de ruine ne comptent pas,
     l'IA ne lisant aucune ruine) ; le **score le plus haut gagne**, une égalité est un
     match nul (décisions du 2026-10-29 et du 2026-10-30). Les tuiles recolorées par une
     ruine comptent dans T : pour la victoire, une ruine vaut son territoire.
   - **Abandon** : le joueur abandonne depuis le menu pause, après confirmation (18).
10. **Élimination** (décision du 2026-10-29). Une faction qui ne possède plus **aucun
    nœud** est éliminée ; ses unités restantes sont détruites dans la même commande. Sa
    couleur disparaît de la carte.
11. **Contrôle immédiat.** La fin de partie est vérifiée juste après chaque commande qui
    peut changer le propriétaire d'un nœud ou détruire une unité (CAPTURER, ATTAQUER,
    EXÉCUTER_UNE_INTENTION), et à la fin de chaque phase. Si la partie est terminée, les
    commandes suivantes sont refusées avec PARTIE_TERMINÉE et les intentions restantes
    sont abandonnées.
12. **Élimination simultanée** (presque impossible en 1 contre 1) : la faction active
    survit.

#### Score

13. **Score composite** (décision du 2026-10-29) : territoire, nœuds et leurs niveaux,
    protocoles, unités en vie (plafonnées), et **ruines lues pendant la partie** avec un
    poids fort — toute ruine compte, même quand la chronique de sa faction est complète,
    pour que le pilier 5 tienne aussi dans la phase de maîtrise — plus un bonus de domination qui diminue avec les tours restants
    (formules 1 et 2). Une ruine lue rapporte au moins autant que **5 tours** de bonus de
    domination (w_f ≥ 5 × w_d) : elle n'est jamais un détour perdu pour le **meilleur
    score** (pilier 5). **Amendement du 2026-10-30 :** le vainqueur se décide sur le
    **score décisif** (F = 0 ; w_p = 0 au MVP) ; `w_f × F` n'entre que dans le **score de
    profil** de la règle 14. Le HUD affiche en permanence le score décisif des deux camps
    (17, E07), séparé des points de ruine.
14. **Meilleur score** (décision du 2026-10-29). Une partie terminée par **domination ou
    au tour 30** — gagnée, perdue au score ou nulle — soumet son **score de profil** (formule 1
    complète, avec `w_f × F`) au profil (22),
    par couple (faction, difficulté), avec l'identifiant de partie pour ne le compter
    qu'une fois. Une **défaite par élimination** ou un **abandon** ne soumet aucun score ;
    les fragments déjà lus restent dans le profil.
15. **Derniers tours.** Ce système expose le nombre de tours restants (formule 3) ; le
    HUD passe en alerte à 5 tours de la fin (`design/ux/hud.md`).

### States and Transitions

| Valeur stockée | Depuis | Déclencheur | Commandes internes |
|---|---|---|---|
| CRÉÉE (tour 0) | — | Nouvelle partie | — |
| PHASE_JOUEUR (tour n) | CRÉÉE, FIN_DE_TOUR | Début du tour | COMMENCER_LE_TOUR (joueur) |
| EXÉCUTION_ENNEMIE (tour n) | PHASE_JOUEUR | « Fin du tour » | COMMENCER_LE_TOUR (IA), puis une EXÉCUTER_UNE_INTENTION par intention du tour n − 1, puis les coups de l'IA, puis ANNONCER_LES_INTENTIONS (sauf au tour 30) |
| FIN_DE_TOUR (tour n) | EXÉCUTION_ENNEMIE | Fin de la phase ennemie | Sauvegarde automatique (16) ; vers PHASE_JOUEUR (n + 1), ou TERMINÉE si n = 30 |
| TERMINÉE (domination, défaite, 30e tour : victoire, défaite ou nul ; abandon) | toute phase | Contrôle de fin de partie (règle 11) ou abandon | — |

### Interactions with Other Systems

Les lignes vers les systèmes sans GDD sont des **contrats provisoires**.

| # | Système | Ce que ce système fournit | Ce qu'il attend |
|---|---|---|---|
| 1 | Modèle d'état de partie | Tour, phase, faction active, statut de fin, faction éliminée | Stockage, compteurs de score bruts |
| 6 | Unités drones | Remise à zéro des drapeaux au début du tour | Destruction des unités d'une faction éliminée ; nombre d'unités en vie |
| 9 | IA à intentions | Phases où elle peut jouer ; coupure à N_REFUS_MAX ; drapeau « IA passive » | Ses intentions, ses coups |
| 10 | Énergie | Déclenche le revenu au début du tour | Le revenu de chaque faction |
| 11 | Nœuds | Contrôle d'élimination | Nœuds possédés et leurs niveaux |
| 12 | Arbre de protocoles | Déclenche l'avancée de la recherche | Protocoles recherchés |
| 13 | Ruines et fragments | — | Fragments lus pendant la partie |
| 16 | Sauvegarde automatique | Sauvegarde juste après « Fin du tour », à FIN_DE_TOUR et à la fin de partie | — |
| 17 | HUD | Tours restants, phase, raison de fin, scores | — |
| 18 | Menus et écrans | Écran de fin (scores des deux camps, raison) | Confirmation de l'abandon |
| 22 | Profil et données méta | Soumission du score (faction, difficulté, identifiant de partie) | — |
| 23 | Commandes et événements | Commandes internes du tour ; FINIR_LE_TOUR, ABANDONNER | Validation et application |

## Formulas

*Proposées par systems-designer. Les poids sont des valeurs de départ, à vérifier par
simulation et en playtest. Les niveaux de nœud appartiennent aux nœuds (11), le revenu à
l'énergie (10).*

### 1. Score final

The final_score formula is defined as:

`score = w_t·T + w_n·N + w_l·ΣL + w_p·P + w_u·min(U, U_cap) + w_f·F + D`

**Variables:**
| Variable | Type | Range | Source | Description |
|----------|------|-------|--------|-------------|
| T | int | 0..144 | calculated (état) | Tuiles possédées |
| N | int | 0..6 | calculated (état) | Nœuds possédés |
| ΣL | int | N..3N | calculated (nœuds, 11) | Somme des niveaux des nœuds possédés (niveaux de 1 à 3 supposés) |
| P | int | 0..6 | calculated (état) | Protocoles recherchés (MVP) |
| U | int | 0..60 | calculated (état) | Unités en vie |
| F | int | 0..3 | calculated (compteurs de score de l'état) | **Ruines lues** pendant la partie, y compris celles d'une faction dont la chronique est déjà complète (qui ne donnent plus de fragment, seulement la recoloration) — décision du 2026-10-29 |
| D | int | 0..232 | calculated (formule 2) | Bonus de domination |
| w_t, w_n, w_l, w_p, w_u, w_f | int | ≥ 0 | data file | Valeurs de départ : 1, 8, 4, 0 (`w_p`, décision du 2026-10-30 : les protocoles n'entrent pas dans le score au MVP), 2, 60 ; **score décisif = formule 1 avec F = 0 (règle 9), score de profil = formule 1 complète (règle 14)** |
| U_cap | int | 1..60 | data file | Valeur de départ : 20 |

**Output Range:** entier ≥ 0 (tous les termes sont positifs). Maximum pratique
d'environ 776 (144 + 48 + 72 + 60 + 40 + 180 + 232). Les deux camps sont notés avec les
mêmes poids.
**Pourquoi ces poids :** un fragment (60) vaut 60 tuiles, soit 42 % de la carte, et plus
de 7 tours de bonus de domination : une ruine bat tout gain réaliste de territoire.
**Example:** T = 60, N = 5, ΣL = 8, P = 4, U = 15, F = 0, D = 120 → 60 + 40 + 32 + 40 +
30 + 0 + 120 = **322**.

### 2. Bonus de domination

The domination_bonus formula is defined as:

`D = dominé ? w_d × tours_restants : 0`

**Variables:**
| Variable | Type | Range | Source | Description |
|----------|------|-------|--------|-------------|
| dominé | booléen | — | calculated | La partie s'est terminée par domination |
| w_d | int | 0..w_f / 5 | data file | Valeur de départ : 8 |
| tours_restants | int | 0..29 | calculated (formule 3) | 30 − tour de la domination |

**Output Range:** 0 à 232 (domination au tour 1). Une domination au tour 30, ou une fin
au 30e tour, donne 0.
**Contrôle « la ruine n'est jamais perdue »** : domination au tour 15 sans fragment →
322 (exemple 1) ; domination au tour 20 avec 3 fragments (T = 70, N = 6, ΣL = 12, P = 5,
U = 20, D = 80) → 70 + 48 + 48 + 50 + 40 + 180 + 80 = **516**. La partie plus lente,
qui a lu les ruines, gagne de 194 points. Dans cet exemple, l'égalité n'arriverait
qu'à w_d = 36 ; la **règle de conception retenue est plus stricte** : w_d ≤ w_f / 5
(soit 12), pour qu'un fragment vaille toujours au moins 5 tours de bonus.
**Example:** domination au tour 15 → 8 × 15 = 120.

### 3. Tours restants et alerte

The last_turns_warning formula is defined as:

`tours_restants = T_max − t` ; `alerte = en_cours ∧ (tours_restants ≤ W)`

**Variables:**
| Variable | Type | Range | Source | Description |
|----------|------|-------|--------|-------------|
| t | int | 1..30 | calculated (état) | Tour en cours |
| T_max | int | ≥ 1 | data file | Valeur de départ : 30 |
| W | int | 0..T_max | data file | Valeur de départ : 5 |
| en_cours | booléen | — | calculated | La partie n'est pas terminée |

**Output Range:** vrai des tours 25 à 30. Au tour 30 (tours_restants = 0), le HUD
affiche un état distinct « dernier tour ».
**Example:** t = 26 → tours_restants = 4, alerte vraie.

### 4. Avancée du tour

The turn_advance formula is defined as:

`t' = min(t + 1, T_max)` ; `fin_par_les_tours = (t = T_max) ∧ phase_ennemie_terminée`

**Variables:**
| Variable | Type | Range | Source | Description |
|----------|------|-------|--------|-------------|
| t | int | 1..30 | calculated (état) | Numéro du tour |

**Output Range:** 1 à 30 ; jamais 31.
**Example:** au tour 30, une fois la phase ennemie finie, la partie se termine sans bonus
de domination ; une domination plus tôt l'emporte.

### Stratégies dégénérées surveillées

- **Traîner pour le bonus** : D baisse à chaque tour et vaut 0 au tour 30 ; attendre ne
  rapporte jamais.
- **Accumuler des unités** : U_cap = 20 limite le terme à 40 points, moins qu'une ruine.
- **Foncer sans lire de ruine** : D reste sous les 180 points de trois fragments tant que
  w_d ≤ w_f / 5. Une domination au tour 8 sans ruine donne 176 de bonus, juste en
  dessous : si la simulation (AC-X2) montre que cette course domine, plafonner D par
  D_MAX, réglé sous 180.
- **Chronique complète** : une ruine d'une faction dont la chronique est complète compte
  quand même au score (F compte les ruines lues) ; elle n'est donc jamais inutile.
- **Abandonner une partie mal partie** : aucun score n'est enregistré.

## Edge Cases

*Proposés par systems-designer.*

### Fin de partie

- **Si le joueur domine par une capture pendant sa propre phase** : la partie passe à
  TERMINÉE (domination, victoire) juste après CAPTURER (règle 11). Ses actions restantes
  sont refusées avec PARTIE_TERMINÉE et les intentions annoncées par l'IA sont
  abandonnées. Les tours restants se comptent sur le tour en cours : une capture au
  tour 15 donne D = 120.
- **Si l'IA élimine le joueur pendant la phase ennemie** : défaite, juste après la
  commande qui l'élimine ; le reste de la phase est abandonné ; aucun score n'est soumis
  (règle 14).
- **Si les scores sont égaux au tour 30** : match nul ; le score est soumis, car la
  partie est allée à son terme (règle 14).
- **Si le joueur est éliminé pendant la phase ennemie du tour 30** : défaite. Le contrôle
  d'élimination suit chaque commande, avant le décompte du tour 30 ; le premier
  événement l'emporte (règle 9). Aucun score n'est soumis.
- **Si une faction n'a plus d'unités mais possède des nœuds** : elle n'est pas éliminée
  (règle 10) ; son terme d'unités vaut 0.
- **Si une capture laisse une faction avec des unités mais sans nœud** : elle est
  éliminée et ses unités sont détruites dans la même commande (destruction : 6). Si
  c'était la dernière faction adverse, c'est une domination.
- **Si une faction sans nœud devait être notée au tour 30** : impossible ; elle est
  éliminée, ce qui termine une partie à deux avant le décompte.
- **Si un score devait être négatif ou déborder** : impossible ; tous les termes sont
  des entiers positifs ou nuls et le chargement des données refuse un poids négatif ; le
  maximum vaut environ 776.

### Arrêts, abandon, données

- **Si l'application est tuée pendant la phase ennemie du tour n** : la partie reprend
  depuis la sauvegarde qui suit la dernière commande appliquée (règle 3) et la phase
  ennemie continue à la commande suivante, au même résultat ; le joueur ne rejoue pas son
  tour. Propriétaires : 16 (moment des sauvegardes), 9 (IA qui reprend à partir de
  l'état seul).
- **Si le joueur abandonne pendant la phase ennemie** : permis, la pause l'étant
  partout ; ABANDONNER s'applique entre deux commandes de l'IA ; la partie passe à
  TERMINÉE (abandon), sans score. Confirmation : 18.
- **Si une partie sauvegardée est marquée « IA passive »** : le drapeau fait partie de
  l'état, il est sauvegardé et rechargé avec elle et ne change pas en cours de partie.
- **Si T_MAX change dans les données entre une sauvegarde et un chargement** : la partie
  garde la valeur enregistrée dans sa sauvegarde (jamais de tour 31) ; les nouvelles
  parties prennent la nouvelle valeur. Propriétaire : 16.

### Tour 30 et IA

- **Si l'auteur d'une intention du tour 29 est détruit pendant le tour 30 du joueur** :
  son exécution l'annule (jamais redirigée) ; rien n'est annoncé ; la partie se termine
  par le décompte du tour 30. Règle d'annulation : 9.
- **Si N_REFUS_MAX est atteint au tour 30** : l'IA arrête ses coups ; il n'y a pas
  d'annonce au tour 30 ; la phase se termine, puis le décompte. Une ligne de journal est
  écrite.

### Propriétaires des autres cas

6 (destruction des unités), 9 (IA déterministe, annulation des intentions, IA passive),
11 (niveaux et propriétaires des nœuds), 16 (moments de sauvegarde, T_MAX sauvegardé),
18 (confirmation de l'abandon), 22 (une seule soumission par partie).

## Dependencies

### En amont (ce système dépend de)

| Système | Nature | Dure ou souple |
|---|---|---|
| 1 Modèle d'état de partie | Stocke tour, phase, faction active, statut de fin ; fournit les compteurs de score bruts | Dure (`design/gdd/modele-etat-partie.md`) |
| 23 Commandes et événements | Applique les commandes internes du tour ; FINIR_LE_TOUR et ABANDONNER ; compte les refus de l'IA | Dure (`design/gdd/commandes-evenements.md`) |

Le score lit aussi des valeurs possédées par d'autres systèmes, par l'état : niveaux des
nœuds (11), protocoles (12), unités (6), ruines lues (13).

### En aval (systèmes qui dépendent de lui)

| Système | Ce qu'il utilise | Dure ou souple |
|---|---|---|
| 6 Unités drones | Remise à zéro des drapeaux au début du tour ; destruction à l'élimination | Dure |
| 9 IA à intentions | Phases, coupure, drapeau « IA passive », pas d'annonce au tour 30 | Dure |
| 10 Énergie | Déclenchement du revenu | Dure |
| 12 Arbre de protocoles | Déclenchement de la recherche | Dure |
| 16 Sauvegarde automatique | Moments de sauvegarde (FIN_DE_TOUR, fin de partie) | Dure |
| 17 HUD | Tours restants, phase, scores, raison de fin | Dure |
| 18 Menus et écrans | Écran de fin ; confirmation de l'abandon | Dure |
| 22 Profil et données méta | Soumission du meilleur score | Souple |

### Bidirectionnalité

- `design/gdd/modele-etat-partie.md` a été mis à jour (phase INTENTIONS_PUBLIÉES
  retirée ; question ouverte résolue).
- `design/gdd/commandes-evenements.md` a été mis à jour (commande ABANDONNER) ; il cite
  déjà les commandes internes du tour.
- `design/gdd/profil-donnees-meta.md` cite déjà la soumission du score (règle 10) ; ses
  questions ouvertes « défaite ou abandon » et « difficulté dans la clé » sont tranchées
  ici (règle 14).
- Les GDD 6, 9, 10, 11, 12, 13, 16, 17 et 18 doivent citer ce document.

## Tuning Knobs

*Dans un fichier de données. Valeurs de départ, à vérifier par simulation (plusieurs
centaines de parties IA contre IA) et en playtest.*

| Paramètre | Valeur | Plage sûre | Trop haut | Trop bas | Interagit avec |
|---|---|---|---|---|---|
| T_MAX (tours par partie) | 30 | 20..40 | Parties au-delà de 40 minutes | La meute n'a pas le temps de grandir | Durée de session du concept (20 à 40 min) |
| LAST_TURNS_WARNING (W) | 5 | 3..10 | L'alerte perd son sens | Alerte trop tardive pour changer de plan | HUD |
| w_f (poids d'une ruine lue) | 60 | ≥ 5 × w_d | Les ruines écrasent tout le reste du score | Une domination rapide rend les ruines inutiles (pilier 5) | w_d |
| w_d (bonus par tour restant) | 8 | 0..w_f / 5 | Foncer sans lire de ruine devient la meilleure stratégie | Aucun intérêt à finir vite | w_f, T_MAX |
| w_t, w_n, w_l, w_p, w_u | 1, 8, 4, 10, 2 | 0..20 | Un seul axe (territoire, protocoles…) décide du score | Cet axe ne compte plus | Tous les poids |
| U_CAP (unités comptées) | 20 | 10..60 | Accumuler des unités devient rentable | Une grande meute n'est pas récompensée (pilier 1) | w_u ; MAX_UNITS (60) |
| D_MAX (plafond du bonus de domination, option) | aucun | de 5 × w_d à moins de 3 × w_f (sous la valeur des ruines d'une partie, 180) | Le plafond ne protège plus les ruines | Une victoire rapide ne rapporte plus | À activer si la simulation (AC-X2) montre qu'une domination précoce sans ruine domine |

## Visual/Audio Requirements

Aucune en propre ; ce système publie TOUR_COMMENCÉ, TOUR_TERMINÉ, PHASE_CHANGÉE,
FACTION_ÉLIMINÉE et PARTIE_TERMINÉE (`design/gdd/commandes-evenements.md`), que le HUD
(17) et l'audio (20) traduisent. Une exigence : l'élimination d'une faction se voit sur
la carte (sa couleur disparaît, pilier 1), pas seulement dans un message.

## Game Feel

Un tour doit s'enchaîner sans attente : entre l'appui sur « Fin du tour » et le retour
de la main, seul le temps de présentation du tour ennemi compte (budget de l'IA : 2 s de
calcul ; présentation réglable, `design/ux/hud.md` § 10.5). Le passage au tour suivant ne
demande jamais de confirmation.

## UI Requirements

- Compteur « Tour n / 30 » et alerte des derniers tours : déjà dans `design/ux/hud.md`.
- **Écran de fin** (menus, 18) : raison de fin (domination, défaite, 30e tour : victoire,
  défaite ou nul ; abandon), **score des deux camps** au 30e tour, détail du score par
  terme (territoire, nœuds, protocoles, unités, fragments, bonus), meilleur score de la
  faction et de la difficulté, et fragments trouvés pendant la partie.
- **Abandon** : dans le menu pause, avec confirmation, en disant que les fragments sont
  gardés mais que le score ne sera pas enregistré.
- **Valeur d'une ruine pendant la partie** (décision du 2026-10-30, remplace celle du
  2026-10-29) : la puce « Ruine repérée » n'affiche **aucun chiffre** (libellé et glyphe) ;
  le gain perçu est la zone recolorée (13, règle 31). Le score décisif des deux camps est
  affiché en permanence (17, E07), séparé des points de ruine ; le score de profil
  (avec `w_f × F`) apparaît au bilan de fin de partie, ligne « Fragments lus ». Le score
  de l'ennemi est une information publique (il dit « combien », jamais « où »).

> **📌 UX Flag — Tours et conditions de victoire** : l'écran de fin, la confirmation
> d'abandon (menus, 18) et la puce « Ruine repérée » sans chiffre et le score décisif permanent (mise à
> jour de `design/ux/hud.md`, § 4.2 et § 6) sont à spécifier avant d'écrire les epics.

## Cross-References

| Document | Ce qui en est repris ou ce qui y est imposé |
|---|---|
| `design/gdd/game-concept.md` | Session-Level (fin au premier de la domination ou du 30e tour ; le score compte les fragments) ; pilier 4 (IA en deux temps) ; Flow State Design (IA passive pour la première partie) ; Retention Hooks (meilleur score sur 30 tours) |
| `design/gdd/modele-etat-partie.md` | Valeurs stockées de la phase ; compteurs de score ; invariant « aucune attaque sans annonce » ; mis à jour (phase INTENTIONS_PUBLIÉES retirée) |
| `design/gdd/commandes-evenements.md` | Commandes internes du tour ; FINIR_LE_TOUR ; ABANDONNER (ajoutée) ; N_REFUS_MAX ; PARTIE_TERMINÉE |
| `design/gdd/profil-donnees-meta.md` | Règle 10 et formules 4 et 5 (meilleur score par faction et difficulté, idempotent par partie) |
| `design/ux/hud.md` | Compteur de tour, alerte des derniers tours, tour ennemi, état « Fin de partie » |

## Acceptance Criteria

*Rédigés avec qa-lead. Étiquettes : **[U]** test unitaire dans `tests/unit/turns/` (états
construits par des fonctions de fabrique, aucun accès fichier) ; **[I]** test
d'intégration dans `tests/integration/turns/` ; **[P]** simulation à graines fixes ;
**[D]** capture conservée dans `production/qa/evidence/`.*

### Règles

- **AC-01 (règle 1)** [U] — **GIVEN** une nouvelle partie, **WHEN** elle est créée,
  **THEN** l'état est CRÉÉE au tour 0 ; après COMMENCER_LE_TOUR, il est PHASE_JOUEUR au
  tour 1.
- **AC-02 (règle 2)** [U] — **GIVEN** une faction dont les unités ont leurs drapeaux
  posés, un revenu et une recherche à un tour de la fin, **WHEN** son tour commence,
  **THEN** un espion enregistre, dans cet ordre : changement de phase et de faction,
  remise à zéro des drapeaux, revenu versé, recherche avancée ; le protocole terminé est
  utilisable dans la même phase ; le numéro de tour n'augmente qu'au début du tour du
  joueur.
- **AC-03 (règle 3)** [I] — **GIVEN** un tour n, **WHEN** le joueur finit son tour,
  **THEN** les intentions de n − 1 sont exécutées ou annulées (jamais redirigées), puis
  l'IA joue, puis elle annonce pour n + 1, puis la partie est sauvegardée, puis le tour
  n + 1 commence ; aucune phase INTENTIONS_PUBLIÉES n'est jamais stockée.
- **AC-04 (règle 3)** [I] — **GIVEN** une phase ennemie où une unité est détruite,
  **WHEN** l'application est tuée après une commande de l'IA quelconque puis la partie
  rechargée, **THEN** la phase ennemie reprend à la commande suivante, l'état final est
  égal à celui d'une partie sans interruption, et la phase du joueur n'est pas rejouée.
- **AC-05 (règle 4)** [U] — **GIVEN** le tour 1, **WHEN** la phase ennemie s'exécute,
  **THEN** aucune attaque n'est exécutée et les annonces portent sur le tour 2.
- **AC-06 (règle 5)** [U] — **GIVEN** un espion sur les commandes, **WHEN** un tour
  complet se joue, **THEN** chaque modification de l'état vient d'une commande.
- **AC-07 (règle 6)** [U] — **GIVEN** le tour 30, **THEN** les intentions du tour 29 sont
  exécutées, rien n'est annoncé, la partie se termine, et le tour n'atteint jamais 31.
- **AC-08 (règle 7)** [U] — **GIVEN** une IA doublée dont toutes les commandes sont
  refusées, **WHEN** elle atteint N_REFUS_MAX refus, **THEN** elle cesse de jouer, annonce
  une fois et écrit une ligne de journal ; au tour 30, elle n'annonce pas.
- **AC-09 (règle 8)** [I] — **GIVEN** une partie marquée « IA passive », **WHEN** elle est
  sauvegardée puis rechargée, **THEN** le drapeau est conservé et transmis tel quel à
  l'IA.
- **AC-10 (règle 9)** [U] — **GIVEN** la fin du tour 30 avec des scores de 300 contre 290,
  **THEN** le plus haut gagne ; **GIVEN** 300 contre 300, **THEN** match nul.
- **AC-11 (règle 10)** [U] — **GIVEN** une faction avec des unités et un seul nœud,
  **WHEN** ce nœud est capturé, **THEN** dans la même commande la faction est éliminée et
  ses unités détruites ; **GIVEN** une faction sans unités mais avec un nœud, **THEN**
  elle n'est pas éliminée.
- **AC-12 (règle 11)** [U] — **GIVEN** une domination par CAPTURER, par ATTAQUER ou par
  EXÉCUTER_UNE_INTENTION, **THEN** la partie est TERMINÉE juste après cette commande, la
  commande suivante est refusée avec PARTIE_TERMINÉE, et les intentions restantes sont
  abandonnées.
- **AC-13 (règle 12)** [U] — **GIVEN** une commande qui éliminerait les deux factions,
  **THEN** la faction active survit.
- **AC-14 (règle 13)** [U] — **GIVEN** l'exemple 1 de la formule 1, **THEN** le score vaut
  322 ; **GIVEN** le second exemple de la formule 2, **THEN** 516.
- **AC-15 (règle 13)** [U] — **GIVEN** un fichier de données de fabrique aux poids
  modifiés, **THEN** le score suit le fichier ; un poids négatif est refusé au
  chargement des données.
- **AC-16 (règle 14)** [I] — **GIVEN** des fins par domination, par victoire, défaite et
  nul au tour 30, **THEN** chacune soumet un score avec son identifiant de partie, et une
  seconde soumission ne change rien ; **GIVEN** une défaite par élimination ou un abandon
  (y compris pendant la phase ennemie), **THEN** aucun score n'est soumis et les
  fragments déjà lus restent dans le profil.
- **AC-17 (règle 15)** [U] — **GIVEN** t = 24, 25, 26 et 30, **THEN** les tours restants
  valent 6, 5, 4 et 0, l'alerte vaut faux, vrai, vrai, vrai, et le tour 30 est signalé
  « dernier tour ».

### Formules

- **AC-F1** [U] — U = 45 avec U_cap = 20 compte pour 20 unités ; tous les termes à 0
  donnent 0 ; tous les termes au maximum donnent 776.
- **AC-F2** [U] — une domination au tour 15 donne D = 120 ; au tour 30, D = 0 ; une fin
  au 30e tour donne D = 0 ; le chargement refuse w_d > w_f / 5.
- **AC-F3** [U] — voir AC-17.
- **AC-F4** [U] — **GIVEN** T_MAX = 30 dans la sauvegarde et 40 dans les données,
  **THEN** la partie se termine au tour 30.

### Entre systèmes

- **AC-X1** [I] — **GIVEN** le joueur éliminé pendant la phase ennemie du tour 30,
  **THEN** défaite, pas de décompte du tour 30, aucun score soumis.
- **AC-X2** [P] — **GIVEN** 200 parties IA contre IA à graines fixes (*nombre proposé*),
  **WHEN** une politique scriptée « domination rapide, aucune ruine » est comparée à une
  politique « lit au moins 2 ruines », **THEN** le score moyen de la première est
  inférieur d'au moins 10 % (*marge proposée*) et les mêmes graines donnent le même
  résultat à chaque exécution ; en cas d'échec, activer D_MAX.
- **AC-D1** [D] — **GIVEN** une faction éliminée, **THEN** sa couleur a disparu de la
  carte sur une capture.

### Limites connues

- AC-X2 attend l'IA (9) et des politiques scriptées ; le nombre de parties et la marge
  sont à confirmer.
- Le budget de calcul de l'IA (2 s) se vérifie dans le GDD de l'IA (9), sur l'appareil
  de référence.
- AC-04 ne prouve le même résultat que si l'IA ne tire son hasard que dans l'état :
  l'exigence est posée dans le GDD de l'IA (9).

## Open Questions

| Question | Owner | Deadline | Resolution |
|---|---|---|---|
| Les poids du score tiennent-ils en simulation ? Une domination précoce sans ruine domine-t-elle ? (activer D_MAX si oui) | systems-designer | Simulation IA contre IA, après le prototype de l'IA | |
| Niveaux des nœuds (1 à 3 supposés) | game-designer | GDD des nœuds (11) | |
| Le score de l'IA au 30e tour : l'IA joue-t-elle pour le score, et lit-elle les ruines ? | ai-programmer, game-designer | GDD de l'IA (9) | Fermée le 2026-10-30 : l'IA ne lit aucune ruine ; la victoire se décide hors points de ruine (règle 9) |
| Difficultés (3, après le MVP) : changent-elles les poids du score, ou seulement l'IA ? (valeur par défaut : seulement l'IA) | game-designer | Avant le palier de lancement | |
| Report des dates du concept (MVP 14 à 16 semaines) : sans effet ici, mais à faire dans `design/gdd/game-concept.md` | user | Re-review du concept | |
