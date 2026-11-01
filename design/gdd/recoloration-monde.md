# Recoloration du monde

> **Status**: Designed (pending /design-review)
> **Author**: user + Claude (technical-artist, art-director, game-designer)
> **Last Updated**: 2026-10-30
> **Last Verified**: 2026-10-30
> **Implements Pillar**: Pilier 1 « La meute se voit grandir » ; pilier 3 « Lisible comme Polytopia » ; pilier 2 « Chaque faction a une mémoire » (par le seul contenu des fragments)
> **Creative Director Review (CD-GDD-ALIGN)**: REVISED 2026-10-30 — CONCERNS (« une à une » contredisait l'onde par anneaux ; table de teintes sans la faction du joueur ; cadrage écarté confondu avec le gain de territoire d'une ruine ; texture sonore montante lue comme récompense ; plafond d'ondes qui produisait un saut ; transfert narratif non posé) corrigées ; adversaires multiples et ordre onde / fragment laissés en questions ouvertes

## Summary

La recoloration du monde fait passer les tuiles du gris à la teinte de la faction qui les tient. Une seule valeur par tuile (la couleur affichée pour le joueur) est **déduite** de l'état, jamais stockée (PR #3, 2026-10-30) ; une onde d'anneaux de 600 à 1 000 ms, purement visuelle, l'accompagne. Le sens de la recoloration ne change jamais mécaniquement : seul le contenu des fragments le fait évoluer.

> **Quick reference** — Layer: `Feature` · Priority: `MVP` · Key deps: `Carte en tuiles et terrain, Nœuds`

## Overview

La recoloration est ce que le joueur voit de la conquête : le monde est gris jusqu'à ce que la meute le
touche, et une tuile possédée prend la teinte pleine de sa faction. Ce système ne **décide** rien : il
**lit** le propriétaire et le dernier changement de propriétaire que les nœuds (11) écrivent
(`design/gdd/noeuds.md`, tranche Carte de `design/gdd/modele-etat-partie.md`) et en **déduit** une **couleur** par
tuile, que le rendu affiche ; rien n'est stocké dans l'état.
Il possède cette dérivation, l'**onde de recoloration** qui la fait apparaître, et le lien avec la
mémoire hors de vue (le dernier propriétaire vu, `design/gdd/brouillard-vision.md`). La saturation est
**binaire** (décision du 2026-10-30) : gris, ou teinte pleine de la faction ; la frontière entre deux
territoires est franche.

Le **changement de sens** de la recoloration voulu par la ligne narrative — d'abord la satisfaction d'une
conquête, puis la question « pour qui allume-t-on ? » — passe **par le seul contenu des fragments**, jamais
par une couche mécanique ajoutée (note du directeur créatif, `design/gdd/systems-index.md`, pilier 3) : la
recoloration se comporte de la même façon du premier au dernier fragment lu.

*Cadrage : une fonction pure de l'état (la couleur) et la lecture visuelle de la croissance de la
meute. Le rendu des tuiles est décidé dans ADR-0001.*

## Player Fantasy

*Cadrage : direct. Retenu (`creative-director`, 2026-10-30) : « Là où passe la meute, le monde se rallume »
comme fantasme, « La carte est un miroir » comme récompense de lecture. Le cadrage « La mémoire rallume le
lieu » est écarté au sens où la couleur ne **code** jamais l'état narratif (lectures, profil, nombre de fragments).
Un gain de territoire obtenu sur une ruine (`recolorer_zone` écrit la propriété, non la couleur) est rendu comme
n'importe quelle capture : il n'est pas écarté.*

**Là où passe la meute, le monde se rallume.** Le joueur prend le nœud central : la teinte part du nœud et gagne
la zone anneau par anneau jusqu'à la frontière, qui reste nette. Le joueur voit jusqu'où il porte (pilier 1).

**La carte est un miroir.** Au tour 25, le joueur dézoome et lit d'un coup d'œil qui possède quoi, ce qui a été
perdu (revenu au gris) et ce dont il se souvient (assombri).

**Ton.** Un constat sobre, sans emphase, en verbes d'état : *s'allume, s'étend, s'éteint, se souvient*. Jamais
*victoire, gloire, libérer, purifier*. La perte se dit « revient au gris », jamais en vocabulaire d'alerte.

**Neutralité voulue.** La fantaisie décrit ce que le joueur voit, jamais ce que cela vaut : « le monde se rallume »
est un fait sans jugement. Plus tard, un fragment pourra reprendre le même verbe — « pour qui allume-t-on ? » —
sans qu'aucun pixel change : le sens bascule dans la tête du joueur, par le seul contenu des fragments.

**Trois échecs à éviter.**
1. *L'onde comme feu d'artifice de victoire* (éclat, son triomphal, particules) : elle contredirait plus tard le
   sens de la conquête.
2. *Une couleur qui devient décorative* une fois la carte pleine : chaque tuile continue à dire qui la possède.
3. *Un propriétaire illisible* à la frontière ou hors de vue.

## Detailed Design

*Décisions du 2026-10-30 : saturation binaire ; une seule couleur par tuile, déduite pour la vue de la
faction de référence (le joueur humain) ; l'onde est de la présentation, l'état est final avant elle ; le sens de
la recoloration ne change jamais mécaniquement. Les durées sont des valeurs de départ [PROP].*

### Core Rules

**A. La couleur déduite**

1. **Contenu.** La couleur d'une tuile est **une valeur de 0 à F** : l'indice de la couleur *affichée* (0 = gris ou
   rien, 1..F = faction). Elle ne porte ni saturation ni animation ; la saturation binaire en découle (0 → gris,
   ≥ 1 → teinte pleine). Dans la suite, « octet de couleur » désigne cette valeur déduite (cache hors de l'état), jamais un champ de l'état.
2. **Une seule vue : celle de la faction de référence.** La couleur vaut *la vue de la faction de référence* : le
   joueur humain, dont l'identifiant est conservé dans l'en-tête de l'état (la faction 1 dans les tests sans
   humain). Les mémoires par faction restent dans l'octet 1 de la tranche Visibilité (5). Aucune autre faction n'a
   de couleur, et l'IA ne la lit pas.
3. **Déduite, jamais stockée** (PR #3, 2026-10-30). `couleur(état, vue, P)` est une fonction pure de (propriétaire,
   vision actuelle, octet 1) : l'état ne contient aucun octet de couleur, la sauvegarde ne le porte pas et il ne peut
   donc jamais diverger. Le rendu et le HUD lisent un **cache de couleur** hors de l'état (une valeur par tuile,
   reconstruit au chargement et après `restore_from`) ; l'événement COULEUR_DES_TUILES_CHANGÉE se calcule par
   différence entre la couleur d'avant la commande et celle d'après.
4. **Aucun écrivain.** Personne n'écrit la couleur dans l'état ; ce système possède la fonction et le cache.

**B. Dérivation**

5. Pour la tuile T, avec P la faction de référence :
   - VISIBLE : `couleur(T)` = propriétaire réel de T ;
   - EXPLORÉE : `couleur(T)` = octet 1 de P (le dernier propriétaire vu) ;
   - INCONNUE : `couleur(T)` = 0 toujours (aplat de brouillard, aucune teinte, aucune fuite).
6. **Ordre d'appel, dans la commande, avant la publication du lot.** 11 écrit le propriétaire, puis 5 recalcule la
   vue et rafraîchit l'octet 1, puis 15 recalcule la couleur et dresse la différence avec la couleur d'avant la
   commande (gardée dans le cache de couleur). 15 ne tourne jamais avant 5.
7. **Assombrissement hors de vue.** L'octet ne change pas quand VISIBLE devient EXPLORÉE : l'assombrissement est
   fait par la présentation du brouillard (5, 17), jamais par ce système.
8. **Changement caché.** Si une tuile redevient VISIBLE avec un propriétaire différent de la mémoire, l'octet change
   avec la cause RÉVÉLATION : aucune onde, un fondu de 150 ms.
9. **Couleur de l'adversaire.** L'indice affiché dépend de la relation avec la faction de référence : sa propre
   faction prend la teinte de sa faction ; toute faction adverse prend la teinte « ennemi » (#C49BEA, art bible,
   section 4). Au MVP, un seul adversaire. Une table (faction, relation) → couleur est tenue en données.

**C. Onde de recoloration (présentation, déterministe)**

10. **L'état est final avant l'onde.** L'onde est calculée par la présentation à partir de l'événement ; elle ne
    bloque ni les commandes ni la logique et se perd au chargement (le HUD se reconstruit depuis l'état,
    `design/gdd/commandes-evenements.md`, règle 10).
11. **Sources (cause de l'événement).** Nœud capturé : la tuile du nœud ; nœud monté : la tuile du nœud ; ruine lue :
    la tuile de la ruine (appel de `recolorer_zone`) ; nœud perdu : la tuile du nœud (cause CAPTURE, l'adversaire capture) ; faction éliminée : la
    tuile du dernier nœud capturé.
12. **Ordre.** Anneau k = distance de Chebyshev à la source ; à anneau égal, ordre croissant de `tile_index`. Si la
    source n'est pas visible pour le joueur, la source effective est la tuile changée *visible* la plus proche
    (égalité : `tile_index` le plus bas), pour ne rien révéler.
13. **Rythme.** L'anneau k démarre à `min(k, K_MAX) × T_ANNEAU_eff` (formule F4 ; `T_ANNEAU_eff` = `T_ANNEAU` aux valeurs de départ) (200 ms, plage 150 à 200) ; chaque tuile se fond en `T_FONDU`
    (400 ms). Tous les anneaux au-delà de `K_MAX` = 3 démarrent ensemble, avec l'anneau `K_MAX` (début à 600 ms). L'ordre par `tile_index` à l'intérieur d'un anneau ne donne aucun décalage temporel : il fixe l'ordre de rendu et le déterminisme. Plafond `T_TOTAL_MAX` = 1 000 ms :
    durée = `min(K_MAX, k_max) × T_ANNEAU + T_FONDU`. Une onde de 49 tuiles (rayon 3, anneaux 0 à 3) dure
    3 × 200 + 400 = 1 000 ms.
14. **Fondu binaire.** Gris → f : saturation de 0 à 1 en `T_FONDU` ; f → gris : de 1 à 0, jamais une couleur d'alerte ;
    f → g (capture) : f descend à 0 pendant la première moitié, g monte pendant la seconde, sans jamais mélanger
    les teintes.
15. **Écriture pendant une onde.** Chaque tuile anime depuis sa valeur affichée *courante* vers la nouvelle cible,
    avec le retard d'anneau de la nouvelle onde : pas de saut. Les ondes de commandes successives se jouent en
    parallèle ; le coût est borné par une seule animation par tuile. Sur RESYNCHRONISER, tout s'affiche directement, sans onde.
16. **Animations réduites.** Affichage direct de l'état final ; un fondu ne dépasse jamais 3 flashs par seconde.

**D. Événements**

17. **PROPRIÉTAIRE_DES_TUILES_CHANGÉ** est émis par 11 (un par couple ancien / nouveau) ; 15 ne l'émet ni ne
    l'écoute : son entrée est l'état.
18. **COULEUR_DES_TUILES_CHANGÉE** est émis par 15, **un seul par commande**, jamais vide. Charge : la cause
    (CAPTURE, MONTÉE, RUINE, ÉLIMINATION, RÉVÉLATION), la tuile source, et une liste de groupes
    `(couleur_avant, couleur_après, mode, tuiles triées par tile_index)`, un groupe par couple de couleurs et par
    mode (ONDE si le propriétaire réel a changé dans la commande, RÉVÉLATION sinon), jamais par tuile. Quand une
    commande mêle les deux, la cause suit la priorité ÉLIMINATION > CAPTURE > MONTÉE > RUINE > RÉVÉLATION. Source
    d'une RÉVÉLATION : le `tile_index` minimal des tuiles changées. **La charge porte aussi la source effective (F7) et, par tuile changée, le drapeau VISIBLE pour la faction de référence au moment de la commande** : la présentation calcule anneaux, débuts et durée à partir de l'événement seul, sans relire l'état (ADR-0001 ; `hud-systeme.md`, règle 2). Seules les tuiles dont l'octet a réellement changé y figurent : `C` reste égal à 1 dans B_max
    (`noeuds.md`, formule 6).
19. **Élimination.** Les tuiles de la faction éliminée passent à 0, y compris hors de vue : 15 demande à 5 d'effacer
    l'octet 1 correspondant chez tous les spectateurs.

**E. Palette daltonienne**

20. L'octet est un indice de faction, non une teinte. Le mode daltonien ne change que la table indice → teinte de la
    présentation (art bible, section 4) ; l'état, l'octet et les ondes sont identiques dans tous les modes ; changer
    de mode en partie n'écrit rien. Motifs et formes inchangés.

**F. Sens de la recoloration**

21. **Le sens de la recoloration ne change jamais mécaniquement.** Elle ne lit ni le profil (22), ni le journal des
    lectures de ruine, ni le nombre de fragments lus. Même état de carte, même octet, mêmes durées, du premier au
    dernier fragment ; le changement de sens passe uniquement par le contenu des fragments. Critère : deux états
    identiques, avec 0 et 12 fragments lus, donnent des octets et des paramètres d'onde identiques.
22. **Tuiles d'ancrage RUINE.** Recolorées comme les tuiles de nœud ; 15 ne lit que le propriétaire (l'ancrage reste
    dans la donnée de 11). Le liseré et le point clairs du HUD ne valent que pour le tour de la lecture.

### States and Transitions (par tuile, octet de couleur)

| De | Vers | Déclencheur | Rendu |
|---|---|---|---|
| 0 (inconnue) | 0 (gris connu) | Tuile découverte et neutre | Le brouillard recule (5) |
| 0 | f | Gain visible de la tuile (capture, montée, ruine) | Onde, fondu 0 → 1 |
| f | g | Capture adverse | Descente puis montée |
| f | 0 | Perte sans nouveau propriétaire, ou élimination | Fondu 1 → 0 |
| f (VISIBLE) | f (mémoire) | Perte de vue | Assombrissement par le brouillard (5) |
| mémoire f | g ou 0 | RÉVÉLATION (la tuile redevient visible avec un autre propriétaire) | Fondu de 150 ms, sans onde |
| 0 (inconnue) | f | Découverte directe d'une tuile déjà possédée | RÉVÉLATION, fondu de 150 ms |
| mémoire f | g ou 0 | Exception de perte ou de gain hors de vue (règle 5 du GDD 5) | Cause CAPTURE ou ÉLIMINATION ; affichage direct s'il n'y a aucune tuile visible |

### Interactions with Other Systems

| # | Système | Sens | Contrat | Propriétaire de l'interface |
|---|---|---|---|---|
| 1 | État | lit | Propriétaire et dernier changement de propriétaire (tranche Carte) ; l'en-tête garde la faction de référence ; aucune couleur n'est écrite dans l'état | 1 |
| 2 | Carte | lit | Dimensions, `tile_index` | 2 |
| 4 | Contrôles | aucun | L'onde ne bloque jamais une commande | — |
| 5 | Brouillard | lit | Visibilité et octet 1 de la faction de référence ; 5 passe avant 15 | 5 |
| 11 | Nœuds | lit | Propriétaire ; 11 appelle 15 après chaque écriture | 11 pour la donnée, 15 pour la couleur |
| 13 | Ruines | lit | Via `recolorer_zone` de 11 ; aucune recoloration au réveil (7) | 11 |
| 17 | HUD | écoute | COULEUR_DES_TUILES_CHANGÉE ; joue l'onde ; marqueurs de perte et de ruine | 17 |
| 20 | Audio | écoute | Facultatif, aucune information de jeu | 20 |
| 23 | Commandes | appelé par | Appelle 15 directement, hors file ; 15 fournit l'événement | 23 |

## Formulas

*Entiers uniquement, durées en ms entiers, divisions entières (plancher). La saturation est en millièmes : 0 = gris, 1000 = teinte pleine. Durées : valeurs de départ [PROP]. Hypothèse : `tile_index = y × largeur + x` (GDD 1).*

### F1. Couleur dérivée d'une tuile

`couleur(T) = proprio_réel(T)` si VISIBLE ; `octet1_P(T)` si EXPLORÉE ; `0` si INCONNUE.

| Symbole | Plage | Description |
|---|---|---|
| T | 0..L×H−1 | `tile_index` |
| P | 1..F | Faction de référence |
| proprio_réel | 0..F | Propriétaire écrit par 11 (0 = neutre) |
| octet1_P | 0..F | Dernier propriétaire vu par P (GDD 5, octet 1) |
| couleur(T) | 0..F | Couleur déduite (cache hors de l'état) |

**Plage** : 0..F. INCONNUE donne toujours 0. **Exemple** : propriétaire réel 2 ; VISIBLE → 2 ; EXPLORÉE avec octet 1 = 1 → 1 (la mémoire, non la réalité) ; INCONNUE → 0. L'octet 1 n'est jamais écrit sur une tuile INCONNUE (GDD 5).

### F2. Indice affiché selon la relation

`indice(c, P) = 0` si c = 0 ; `PROPRE (1)` si c = P ; `ENNEMI (2)` sinon. `teinte = TABLE_TEINTES[mode_daltonien][faction_P][indice]` : la teinte PROPRE dépend de la faction de P (F1 teal #1FA38F, F2 #8FD460, F3 cobalt #3A6FE0), ENNEMI reste #C49BEA.

**Plage** : indice ∈ {0, 1, 2}. La couleur est un identifiant de faction ; la relation ne s'applique qu'à l'affichage. **Exemple** (P = 1) : c = 1 → PROPRE ; c = 2 → ENNEMI (#C49BEA) ; c = 0 → gris. Le mode daltonien change la table, pas c.

### F3. Anneau et ordre

`k(T) = max(|x_T − x_S|, |y_T − y_S|)` ; `ordre(T) = (k(T), tile_index(T))`, lexicographique croissant. Ordre total, sans égalité.

**Exemple** (16×16, S = (6,6) = 102) : (8,5) → k = 2, index 88 ; (7,5) = 87 et (5,7) = 117 sont à k = 1, dans cet ordre. Au bord, S = (0,0) et rayon 3 donnent 16 tuiles (1+3+5+7).

### F4. Début de fondu et durée de l'onde

`T_ANNEAU_eff = min(T_ANNEAU, (T_TOTAL_MAX − T_FONDU) div K_MAX)` ; `début(T) = min(k(T), K_MAX) × T_ANNEAU_eff` ; `fin(T) = début(T) + T_FONDU` ; `durée_onde = min(K_MAX, k_max) × T_ANNEAU_eff + T_FONDU`.

| Variable | Plage | Départ | Rôle |
|---|---|---|---|
| T_ANNEAU | 150..200 | 200 | Retard par anneau |
| T_FONDU | 200..400 | 400 | Durée du fondu d'une tuile |
| K_MAX | 1..5 | 3 | Anneaux au-delà desquels les départs sont simultanés |
| T_TOTAL_MAX | ≥ T_FONDU | 1000 | Plafond d'une onde |
| k_max | 0..15 | — | Plus grand anneau de l'événement depuis la source effective |

**Plage** : de T_FONDU (une tuile : 400 ms) à T_TOTAL_MAX. Une onde plus longue est impossible par construction de `T_ANNEAU_eff` ; si `K_MAX × T_ANNEAU + T_FONDU > T_TOTAL_MAX` au chargement des données, `T_ANNEAU_eff` est réduit et une trace est écrite.

| Rayon R (source au centre) | Tuiles | Par anneau k = 0..3 | Débuts (ms) | Durée |
|---|---|---|---|---|
| 1 | 9 | 1, 8 | 0, 200 | **600 ms** |
| 2 | 25 | 1, 8, 16 | 0, 200, 400 | **800 ms** |
| 3 | 49 | 1, 8, 16, 24 | 0, 200, 400, 600 | **1000 ms** |

**Exemple hors centre** : zone 7×7 avec une source de coin, k_max = 6 ; les anneaux 4 à 6 démarrent à 600 ms ; durée = 3×200 + 400 = 1000 ms. **Révélation** : début 0, durée `T_REV` = 150 ms, sans onde ; pour un événement mêlant les deux modes, la durée est `max(durée_onde, T_REV)`.

### F5. Saturation d'une tuile à l'instant t

`u = clamp(t − début(T), 0, D)` ; D = T_FONDU (ou T_REV en révélation) ; `H1 = D div 2` ; `H2 = D − H1`.

| Fondu | Saturation s (0..1000) |
|---|---|
| gris → f | `(1000 × u) div D` |
| f → gris | `1000 − (1000 × u) div D` |
| f → g | si u ≤ H1 : `1000 − (1000 × u) div H1` (teinte f) ; sinon `(1000 × (u − H1)) div H2` (teinte g) |

**Plage** : 0..1000, jamais de mélange de teintes (s = 0 au milieu de f → g). **Exemples** (D = 400) : gris → f à u = 100 → 250, à 200 → 500 ; f → g à u = 100 → 500 (f), à 200 → 0, à 300 → 500 (g) ; tuile d'anneau 2 dans une onde de rayon 3 : début 400, à t = 500 → u = 100 → s = 250. Révélation (D = 150) à u = 75 → 500.

**Réécriture en cours de fondu** (règle 15) : la tuile part de (teinte, s_c) courants. Cible gris : descente en `(D × s_c) div 1000` ms. Même teinte : montée en `(D × (1000 − s_c)) div 1000` ms. Autre teinte : descente en `(H1 × s_c) div 1000` ms puis montée en H2 ms. Exemple : g à s_c = 600 vers f → 120 + 200 = 320 ms (≤ 400).

### F6. Taille de l'événement

`N = Σ n_g` ; `G ≤ 6 couples × 2 modes = 12` au MVP ; `E = 3 + 4 × G + N` entiers. Le nombre d'événements C reste 1 par commande, donc `B_max` (`noeuds.md`, formule 6) est inchangé.

| Cause | N maximal |
|---|---|
| CAPTURE, MONTÉE | 49 (zone de rayon 3 ; la vue du nœud la couvre) |
| RUINE | `Z_RUINE_MAX` = 25 (fixé par 13, rayon 2) |
| ÉLIMINATION | L×H (256 en 16×16) |
| RÉVÉLATION | 49 |

**Exemple** : capture d'un nœud de niveau 3, 49 tuiles de ENNEMI à PROPRE : G = 1, N = 49, E = 3 + 4 + 49 = 56. **Pire cas** : élimination en 16×16, E = 3 + 48 + 256 = 307.

### F7. Source effective

`S_eff = S` si VISIBLE(S) ; sinon la tuile de V = {tuiles changées VISIBLES} minimisant `(cheb(S, X), tile_index(X))` ; si V est vide, pas de source, donc pas d'onde (affichage direct). Jamais une tuile INCONNUE.

**Exemple** : S = (6,6) non visible ; changées et visibles : (4,5) à cheb 2, index 84 ; (8,7) à cheb 2, index 120 ; (9,9) à cheb 3 → S_eff = (4,5) (84 < 120). L'anneau de (8,7) devient max(4,2) = 4, début = min(4,3)×200 = 600 ms.

## Edge Cases

*« P » est la faction de référence.*

- **E1. Deux captures aux zones qui se chevauchent.** Chaque commande émet son événement sur son seul différentiel d'octet (avant/après la commande entière : une tuile qui revient à sa valeur n'y figure pas). Une tuile du chevauchement figure dans les deux ; elle part de sa valeur affichée courante (F5), sans saut. Aucun plafond d'ondes : la réécriture en cours de fondu (F5) borne le coût à une animation par tuile.
- **E2. Zone entièrement hors de vue.** Capture par P : impossible, la vue du nœud couvre sa zone. Perte d'un nœud de P : l'exception de la règle 5 du GDD 5 met l'octet 1 à jour, donc l'octet change ; V est vide, l'événement (cause CAPTURE) est émis, l'affichage est direct, sans onde, et le HUD affiche la puce « Nœud perdu » (17). Une capture adverse qui ne touche aucune tuile de P n'émet rien.
- **E3. VISIBLE → EXPLORÉE pendant une onde.** L'octet ne change pas ; le fondu continue ; l'assombrissement du brouillard se compose en multiplication, sans redémarrage.
- **E4. RESYNCHRONISER pendant une onde.** Les animations sont annulées, chaque tuile affiche immédiatement son octet courant ; aucun événement, aucune onde.
- **E5. Chargement d'une sauvegarde.** Aucune onde. 5 recalcule la vue, puis 15 recalcule l'octet ; l'animation en cours et la file sont perdues (non sauvegardées). Voir E14.
- **E6. Animations réduites.** Affichage direct de l'état final, durée 0 ; l'état logique est identique. Les changements consommés dans un même créneau de `T_CRENEAU_RÉDUIT` = 334 ms [PROP] sont fusionnés (dernier octet de chaque tuile) : au plus 2 changements visibles par seconde, jamais plus de 3.
- **E7. Faction éliminée hors de vue.** Ses tuiles passent à 0, y compris EXPLORÉES (octet 1 effacé) ; un événement ÉLIMINATION, source = dernier nœud capturé, puis F7. Les tuiles INCONNUES ne changent pas. Si P est lui-même éliminé : calcul normal, affichage direct [PROP].
- **E8. Ruine lue sur une zone partiellement inconnue.** Les tuiles INCONNUES restent à 0 (aucune fuite) et n'entrent pas dans le différentiel ; les EXPLORÉES changent si P gagne la zone (octet 1 mis à jour), pas si c'est l'adversaire. Les anneaux comptent la géométrie des tuiles inconnues, qui ne sont pas animées. Plus tard, une tuile INCONNUE possédée qui devient VISIBLE passe de 0 à f en RÉVÉLATION (150 ms).
- **E9. Eau, montagne et bord de carte.** Ces tuiles suivent la même dérivation (`noeuds.md`, règle 14) ; la distance de Chebyshev ignore le terrain ; leur teinte est rendue par l'art (17), à valider. Une tuile cachée derrière une montagne est EXPLORÉE et s'anime selon E3 ; la règle 23 du GDD 5 est à vérifier contre `bloquée`. Au bord, l'ensemble est tronqué à la grille (F3).
- **E10. Mode daltonien changé en pleine onde.** La table change aussitôt ; chaque tuile garde son u et son s, seule la teinte change ; aucune écriture, aucun événement.
- **E11. Capture et révélation dans la même commande.** Un seul événement ; cause par priorité (règle 18) ; champ `mode` par groupe ; les tuiles en RÉVÉLATION ne comptent ni dans k_max ni dans la source effective.
- **E12. Égalité de `tile_index`.** Impossible entre deux tuiles distinctes ; les listes sont triées puis dédoublonnées avant l'émission, un doublon lève une assertion en développement.
- **E13. Onde plus longue que `T_TOTAL_MAX`.** Impossible (F4) ; une réécriture dure au plus D.
- **E14. Cache de couleur ≠ couleur recalculée.** Le cache est jeté et reconstruit depuis l'état, trace au journal de développement, aucun événement, affichage direct. Une incohérence de l'octet 1 est l'affaire de 5.
- **E15. 16×16 avec beaucoup d'ondes.** Une seule animation par tuile (au plus 256) ; l'affichage atteint l'état final au plus `T_TOTAL_MAX` après le dernier événement consommé ; si la file déborde (`EVENT_QUEUE_MAX` = 256), 23 émet RESYNCHRONISER (E4).

## Dependencies

| Système | Direction | Nature | Contrat |
|---|---|---|---|
| 1 État de la partie | dépend de | dur | Tranche Carte (propriétaire, dernier changement) ; faction de référence dans l'en-tête |
| 2 Carte et terrain | dépend de | dur | Dimensions, `tile_index` |
| 5 Brouillard | dépend de | dur | Visibilité et octet 1 ; 5 passe avant 15 |
| 11 Nœuds et territoire | dépend de | dur | Propriétaire des tuiles ; appel de 15 après chaque écriture |
| 23 Commandes et événements | dépend de | dur | Appel direct, un événement par commande, file et RESYNCHRONISER |
| 13 Ruines et fragments | est utilisé par | souple | `recolorer_zone` ; 15 ne lit jamais l'état des fragments |
| 17 HUD | est utilisé par | dur | Joue l'onde, marqueurs de perte et de ruine |
| 20 Audio | est utilisé par | souple | Habillage facultatif de l'onde |
| 7 Réveil des drones | aucune | — | Le réveil ne recolore pas |

## Tuning Knobs

| Réglage | Départ | Plage sûre | Effet si trop haut | Effet si trop bas | Lié à |
|---|---|---|---|---|---|
| `T_ANNEAU` | 200 ms | 150 à 200 | Onde lente, joueur attend | Onde illisible | F4 |
| `T_FONDU` | 400 ms | 200 à 400 | Teinte tardive | Clignotement | F4, F5 |
| `K_MAX` | 3 | 1 à 5 | Onde trop longue | Anneaux lointains simultanés | F4 |
| `T_TOTAL_MAX` | 1 000 ms | 600 à 1 200 | Onde gênante | Réduit `T_ANNEAU_eff` | F4 |
| `T_REV` | 150 ms | 100 à 250 | Révélation traînante | Apparition sèche | F4 |
| `T_CRENEAU_RÉDUIT` | 334 ms | 334 à 500 | Retard visible | Plus de 3 flashs/s | E6 |
| `TABLE_TEINTES` | art bible §4 | données | — | — | F2 |

Aucun réglage n'agit sur la logique : tous sont de présentation, validés en développement par le chargement des données.

## Visual/Audio Requirements

- **Visuel.** Saturation binaire : gris `#4E5862` ou teinte pleine de la faction ; jamais de demi-teinte stable. Territoire adverse en `#C49BEA` (art bible §4). Hors de vue, la tuile garde sa dernière teinte connue, assombrie par le brouillard (5, 17).
- **Rendu (avis du technical-artist, à confirmer par prototype).** Donnée par instance (vec4) : indice affiché, indice précédent, état de brouillard, instant de début de fondu ; l'onde est calculée dans le shader à partir de cet instant et d'un temps de jeu global ; la table de teintes est un tableau uniforme. Environ 16 octets par tuile, 4 Ko pour 256 tuiles. Non vérifié dans la source : données personnalisées de MultiMesh, uniformes globaux, rendu Mobile, version de Godot installée. Un ADR sur le rendu des tuiles et le prototype de rendu (art bible §8) sont requis.
- **Audio (facultatif, 20).** Une seule texture sonore par onde, durée liée à `durée_onde`, **même texture et même poids pour un gain et pour une perte du joueur** : pas de montée résolutive ni de cadence de victoire, le son accompagne l'onde sans la juger (à valider par l'audio-director) ; aucune information de jeu n'est portée par le son seul.

## Game Feel

- **Intention.** « Là où passe la meute, le monde se rallume » : la prise du nœud est le moment fort du tour, l'onde doit se lire comme une conséquence du geste, non comme un effet décoratif.
- **Durées.** Onde de rayon 1 : 600 ms ; rayon 2 : 800 ms ; rayon 3 : 1 000 ms (F4). Révélation : 150 ms. Les commandes restent possibles pendant l'onde.
- **Ressenti à valider en prototype.** Anneaux perceptibles comme une vague et non comme un fondu global ; pas de fatigue après plusieurs captures de suite.
- **Réduit.** Animations réduites : état final immédiat, au plus 3 changements visibles par seconde.

## UI Requirements

- Le HUD (17) écoute COULEUR_DES_TUILES_CHANGÉE, joue l'onde et la perd au chargement ; il se reconstruit depuis l'état.
- Marqueurs : liseré et point clairs pour le tour de la lecture d'une ruine ; puce « Nœud perdu » quand la perte est hors de vue (E2).
- La couleur n'est jamais seule : motifs et formes inchangés dans tous les modes daltoniens (art bible §4, `design/accessibility-requirements.md`).
- Aucune donnée de recoloration n'est affichée en chiffres.

## Cross-References

- `design/gdd/brouillard-vision.md` : règles 5 et 9 amendées (gain hors de vue ; MONTER_NŒUD recalcule la vue) ; octet 1.
- `design/gdd/noeuds.md` : `recolorer_zone`, B_max (formule 6), appel de 15 après chaque écriture.
- `design/gdd/commandes-evenements.md` : ajouter COULEUR_DES_TUILES_CHANGÉE (groupes avec mode), RESYNCHRONISER.
- `design/gdd/modele-etat-partie.md` : propriétaire et dernier changement de propriétaire dans la tranche Carte (6 octets par tuile), faction de référence en en-tête ; aucune couleur stockée.
- `design/art/art-bible.md` §4 et `design/ux/hud.md` : teintes, onde, marqueurs.
- **Exigence vers le GDD 13 et le narrative-director** : une part identifiée des fragments, notamment dans le dernier tiers de la chronique, reprend le verbe et l'image de la recoloration (« pour qui allume-t-on ? »), sans qu'aucun paramètre de rendu ne change (règle 21). Sans cela, la promesse du concept n'a aucun support.

## Acceptance Criteria

*Étiquettes : **Logic** = `tests/unit/recoloration/`, état construit par fabrique, sans rendu ; **Intégration** = `tests/integration/recoloration/` ; **Visuel** = capture retenue dans `production/qa/evidence/recoloration/` (nom `ACRC<n>-<scène>-<ms>.png`), validée par l'art-director, prise sur l'appareil cible. [BLOQUÉ n] = attend le système n. Valeurs de départ [PROP] : `T_ANNEAU` 200 ms, `T_FONDU` 400 ms, `K_MAX` 3, `T_TOTAL_MAX` 1 000 ms, `T_REV` 150 ms ; si un réglage change, les nombres se recalculent par F4 et F5. Entiers uniquement, aucune tolérance flottante. « P » est la faction de référence.*

### A. Octet de couleur et dérivation (règles 1 à 9, F1, F2)

- **AC-RC1** (Logic, règles 1 et 5, F1) **GIVEN** une tuile de propriétaire réel 2 et P = 1, **THEN** la couleur vaut 2 si VISIBLE, 1 si EXPLORÉE avec octet 1 de P = 1 (la mémoire l'emporte), 0 si INCONNUE ; **GIVEN** des tuiles INCONNUES de propriétaire réel 0, 1 et 2, **THEN** les trois couleurs valent 0. L'état ne contient aucun champ de couleur.
- **AC-RC2** (Logic, règle 3, E14) **GIVEN** une carte 16×16, **WHEN** l'état est chargé, **THEN** le cache de couleur est reconstruit et égal à `couleur(état, vue, P)` sur les 256 tuiles ; **GIVEN** un cache corrompu volontairement (2 au lieu de 1), **THEN** il est jeté et reconstruit (1), une trace est écrite au journal de développement, aucun événement n'est émis et l'affichage est direct.
- **AC-RC3** (Logic, règles 2 et 4) **GIVEN** 2 factions, **THEN** l'en-tête conserve l'identifiant de la faction de référence (1 dans un test sans humain), la couleur n'est déduite que pour cette vue, et aucun champ de couleur n'existe dans l'état (le cache de couleur est hors de l'état).
- **AC-RC4** (Logic, règle 7) **GIVEN** une tuile VISIBLE qui passe EXPLORÉE sans changement de propriétaire, **THEN** l'octet est inchangé, le différentiel est vide, aucun événement.
- **AC-RC5** (Logic, règle 8) **GIVEN** une tuile EXPLORÉE d'octet 1 dont le propriétaire réel est devenu 2 hors de vue, **WHEN** elle redevient VISIBLE, **THEN** l'octet passe de 1 à 2, cause RÉVÉLATION, groupe en mode RÉVÉLATION, fondu de `T_REV` = 150 ms, sans onde.
- **AC-RC6** (Logic, règle 9, F2) **GIVEN** P = 1, **THEN** `indice(0)` = 0, `indice(1)` = PROPRE, `indice(2)` = ENNEMI ; avec 3 factions, 2 et 3 donnent ENNEMI ; ENNEMI = #C49BEA lu depuis les données, pas depuis le code.
- **AC-RC6b** (Logic, règle 9, F2) **GIVEN** P = 2, **THEN** PROPRE vaut #8FD460 ; **GIVEN** P = 3, **THEN** PROPRE vaut #3A6FE0 ; dans les deux cas ENNEMI reste #C49BEA.

### B. Ordre d'appel (règle 6)

- **AC-RC7** (Intégration, règle 6) **GIVEN** une commande qui change un propriétaire, **THEN** l'ordre enregistré est 11, puis 5, puis 15, puis publication du lot ; un appel de 15 avant 5 échoue ou lève une assertion en développement.

### C. Onde : ordre, rythme, plafond (règles 10 à 13, F3, F4, F7)

- **AC-RC8** (Logic, règle 12, F3) **GIVEN** 16×16 et S = (6,6) (index 102), **THEN** (8,5) est à l'anneau 2, index 88 ; (7,5) (index 87) précède (5,7) (index 117), tous deux à l'anneau 1 ; l'ordre est total et identique sur 100 exécutions ; **GIVEN** S = (0,0) et rayon 3, **THEN** 16 tuiles (1+3+5+7).
- **AC-RC9** (Logic, règle 13, F4) **GIVEN** une source au centre, **THEN** rayon 1 : 9 tuiles, débuts 0 et 200, durée 600 ms ; rayon 2 : 25 tuiles, débuts 0, 200, 400, durée 800 ms ; rayon 3 : 49 tuiles (1, 8, 16, 24), débuts 0, 200, 400, 600, durée 1 000 ms. Chaque `fin` = `début` + 400.
- **AC-RC10** (Logic, règle 13, F4, E13) **GIVEN** une zone 7×7 de source en coin (k_max = 6), **THEN** les anneaux 3 à 6 démarrent à 600 ms, durée 1 000 ms ; **GIVEN** `T_ANNEAU` = 200 et `K_MAX` = 4, **THEN** `T_ANNEAU_eff` = min(200, (1000−400) div 4) = 150, une trace est écrite, et aucune onde ne dépasse 1 000 ms sur 1 000 événements générés.
- **AC-RC11** (Logic, règle 13) **GIVEN** deux tuiles du même anneau, **THEN** leurs débuts sont égaux et l'ordre de rendu suit `tile_index`.
- **AC-RC12** (Logic, règle 12, F7) **GIVEN** S = (6,6) non visible et des tuiles changées visibles en (4,5) (index 84, Chebyshev 2), (8,7) (index 120, Chebyshev 2), (9,9) (Chebyshev 3), **THEN** S_eff = (4,5), l'anneau de (8,7) devient 4 et son début 600 ms ; **GIVEN** S visible, **THEN** S_eff = S.
- **AC-RC13** (Logic, règle 12, F7, E2) **GIVEN** aucune tuile changée VISIBLE, **THEN** l'événement existe, sans source effective, sans onde (affichage direct), et aucune tuile INCONNUE n'est source.
- **AC-RC14** (Logic, règle 18, E11) **GIVEN** une capture mêlée à une révélation, **THEN** les tuiles RÉVÉLATION ne comptent ni dans k_max ni dans S_eff, et la durée de l'événement est `max(durée_onde, 150)`.

### D. Fondu binaire et saturation (règles 14 et 15, F5)

- **AC-RC15** (Logic, F5) **GIVEN** gris → f (D = 400), u = 0, 100, 200, 400 → s = 0, 250, 500, 1000 ; f → gris → 1000, 750, 500, 0 ; tuile d'anneau 2 dans une onde de rayon 3 (début 400), à t = 500 → u = 100, s = 250.
- **AC-RC16** (Logic, règle 14, F5) **GIVEN** f → g (D = 400), u = 100, 200, 300 → s = 500 (teinte f), 0, 500 (teinte g) ; sur u = 0..400 par pas de 1 ms, f n'apparaît jamais après 200, g jamais avant, s = 0 à 200 : jamais de mélange ; aucune teinte d'alerte dans f → gris.
- **AC-RC17** (Logic, F5) **GIVEN** une révélation (D = 150), gris → f à u = 75 → s = 500 ; f → g (H1 = H2 = 75) à u = 75 → s = 0.
- **AC-RC18** (Visuel, règle 14) **GIVEN** une capture ENNEMI → PROPRE sur l'appareil, **THEN** la teinte de départ s'éteint jusqu'au gris à mi-fondu puis la nouvelle monte, sans teinte intermédiaire ; captures à 100, 200 et 300 ms. [BLOQUÉ 17]
- **AC-RC19** (Logic, règle 15, F5) **GIVEN** une tuile g à s_c = 600 réécrite vers f, **THEN** départ à 600, sans saut, durée 120 + 200 = 320 ms (≤ 400) ; vers gris : 240 ms ; même teinte : 160 ms.
- **AC-RC20** (Logic, règle 15, E1) **GIVEN** deux captures aux zones qui se chevauchent, **THEN** une tuile du chevauchement figure dans les deux événements avec ses valeurs avant et après, la seconde onde la fait partir de sa valeur affichée ; une tuile qui revient à sa valeur dans la même commande n'y figure pas.
- **AC-RC21** (Logic, règle 15, E1, E15) **GIVEN** trois ondes consécutives sur des zones qui se chevauchent, **THEN** chaque tuile porte une seule animation (au plus 256), aucune tuile ne saute (valeur affichée continue), et l'état final est affiché au plus 1 000 ms après le dernier événement consommé.
- **AC-RC22** (Logic, règle 10, E3) **GIVEN** une onde et une tuile VISIBLE → EXPLORÉE en plein fondu, **THEN** l'octet est inchangé, le fondu ne redémarre pas, et l'assombrissement se compose en multiplication.

### E. Événement (règles 17 à 19, F6)

- **AC-RC23** (Logic, règles 17 et 18) **THEN** 11 émet un PROPRIÉTAIRE_DES_TUILES_CHANGÉ par couple ancien / nouveau ; 15 n'en émet ni n'en écoute ; 15 émet exactement 1 COULEUR_DES_TUILES_CHANGÉE par commande ; aucun événement quand l'octet d'aucune tuile ne change (capture adverse hors tuiles de P).
- **AC-RC24** (Logic, règle 18, E12) **GIVEN** 49 tuiles ENNEMI → PROPRE et 3 tuiles 0 → 2 en révélation, **THEN** deux groupes : `(2, 1, ONDE)` de 49 tuiles et `(0, 2, RÉVÉLATION)` de 3, listes triées sans doublon ; un doublon forcé lève une assertion en développement.
- **AC-RC25** (Logic, règle 18, E11) **THEN** la priorité est ÉLIMINATION > CAPTURE > MONTÉE > RUINE > RÉVÉLATION, vérifiée sur les combinaisons ÉLIMINATION+CAPTURE, CAPTURE+MONTÉE, MONTÉE+RUINE, RUINE+RÉVÉLATION, CAPTURE+RÉVÉLATION ; une RÉVÉLATION seule a pour source le `tile_index` minimal.
- **AC-RC26** (Logic, F6) **GIVEN** la capture d'un nœud de niveau 3 (49 tuiles), **THEN** G = 1, N = 49, E = 3 + 4 + 49 = 56 ; élimination en 16×16, pire cas G = 12, N = 256 : E = 307 ; C reste 1 par commande, B_max de `noeuds.md` inchangé.
- **AC-RC27** (Logic, règle 19, E7) **GIVEN** une faction éliminée aux tuiles VISIBLES, EXPLORÉES et INCONNUES, **THEN** les deux premières passent à 0 (octet 1 effacé chez tous les spectateurs), les INCONNUES restent à 0 hors différentiel, cause ÉLIMINATION, source = dernier nœud capturé puis F7 ; si P est éliminé : calcul normal, affichage direct.
- **AC-RC28** (Logic, règle 11, E8) **GIVEN** une ruine lue sur une zone partiellement INCONNUE, **THEN** les INCONNUES restent à 0 hors différentiel, les EXPLORÉES changent seulement si P gagne la zone, la source est la tuile de la ruine, les anneaux comptent la géométrie des tuiles inconnues sans les animer.

### F. Palette daltonienne, sens de la recoloration, animations réduites (règles 16, 20 à 22, E6, E10)

- **AC-RC29** (Logic, règle 20) **GIVEN** deux parties de même graine, l'une en mode normal, l'autre dans chaque mode daltonien, **THEN** état, octets, durées (600, 800, 1 000 ms), débuts et listes d'événements sont identiques octet pour octet ; seule `TABLE_TEINTES` diffère ; changer de mode n'écrit rien et n'émet rien.
- **AC-RC30** (Logic, E10) **GIVEN** une onde de rayon 3 à t = 300 ms et un changement de mode, **THEN** chaque tuile garde u et s, seule la teinte change, sans écriture ni événement.
- **AC-RC31** (Logic, règles 21 et 22) **GIVEN** deux états de carte identiques, l'un avec 0 fragment lu, l'autre avec 12, **THEN** octets et paramètres d'onde (anneaux, débuts, durées, groupes, cause, source) sont identiques ; le module 15 ne lit ni le profil, ni le journal des lectures, ni le nombre de fragments (un double échoue à toute lecture).
- **AC-RC32** (Logic, règle 22) **GIVEN** une tuile d'ancrage RUINE capturée, **THEN** elle est recolorée comme une tuile de nœud et 15 ne lit que le propriétaire. [BLOQUÉ 13, 17]
- **AC-RC33** (Logic, règle 16, E6) **GIVEN** « animations réduites », **THEN** une capture de rayon 3 s'affiche directement (durée 0), l'état logique est identique ; les changements d'un même créneau de 334 ms sont fusionnés ; jamais plus de 3 changements visibles par seconde sur 10 commandes en 1 s.

### G. Chargement, RESYNCHRONISER, fuites, déterminisme (règles 5 et 10, E4, E5, E15)

- **AC-RC34** (Intégration, règle 10, E4, E5) **GIVEN** une sauvegarde chargée, **THEN** aucune onde, 5 recalcule la vue puis 15 l'octet, animations et file perdues ; **GIVEN** RESYNCHRONISER (ou débordement de `EVENT_QUEUE_MAX` = 256) pendant une onde, **THEN** les animations sont annulées, chaque tuile affiche son octet courant, aucun événement, aucune onde.
- **AC-RC35** (Logic, règle 5, E8) **GIVEN** une carte 16×16 partiellement INCONNUE avec des tuiles adverses cachées, **WHEN** on exécute les 5 causes, une onde et une élimination sur 1 000 événements générés, **THEN** (a) aucune tuile INCONNUE n'a un octet ≠ 0 ni n'apparaît dans un groupe, une source ou un anneau animé, (b) aucune source effective n'est INCONNUE, (c) deux exécutions identiques produisent les mêmes événements, le même ordre de groupes et de tuiles, les mêmes débuts, sans horodatage ni graine aléatoire.

### Captures retenues exigées (toutes [BLOQUÉ 17])

AC-RC9 (rayon 3 à 0, 200, 400, 600, 1 000 ms) ; AC-RC10 (source en coin à 600 ms) ; AC-RC18 (f → g à 100, 200, 300 ms) ; AC-RC12 et AC-RC13 (source non visible, V vide, puce « Nœud perdu », aucun indice de tuile inconnue) ; AC-RC29 et AC-RC30 (onde figée à 300 ms dans chaque palette, ENNEMI = #C49BEA en palette normale) ; AC-RC5 (révélation de 150 ms) ; AC-RC33 (animations réduites avant / après) ; AC-RC22 (assombrissement pendant une onde).

## Open Questions

| Question | Propriétaire | Échéance | Statut |
|---|---|---|---|
| Rayon et forme d'une zone de ruine (`Z_RUINE_MAX`) | game-designer | GDD 13 | Fixé : rayon 2, 25 tuiles |
| Teinte des tuiles d'eau et de montagne possédées | art-director | Revue de l'art bible | Ouverte |
| Marque permanente d'une ruine lue (ancrage) | art-director | GDD 13, 17 | Ouverte |
| Donnée par instance ou uniforme : coût réel sur Mobile | technical-artist | Prototype de rendu, ADR | Ouverte |
| Fondu de révélation 150 ms ou apparition instantanée | ux-designer | Prototype | Posé à 150 ms |
| Tranche Carte de 4 octets (GDD 1) et octet de couleur | systems-designer | Revue de 1 | Résolue le 2026-10-30 : PR #3, tranche Carte de 6 octets, couleur déduite |
| Plusieurs adversaires : un violet commun rend la carte illisible ; teinte propre à chaque adversaire, ou violet commun plus motif de faction sur la lisière (art bible §4) | art-director | Avant tout mode multi-IA | Ouverte, ne bloque pas le MVP |
| Palette daltonienne à trois factions : valider la ligne F1 #3A8EE6, F2 #A9D6F5, F3 #24408F | art-director | Revue de l'art bible | Ouverte |
| Ordre d'affichage quand une ruine est lue : onde avant le fragment, après sa fermeture, ou fragment hors de la zone | ux-designer, HUD (17) | GDD 17 | Ouverte |
| Stockage redondant de l'octet ou dérivation à la volée | technical-director | ADR sur le rendu des tuiles | Résolue le 2026-10-30 : dérivation (PR #3), cache hors de l'état (ADR-0001) |
| Simplification possible pour le palier de 5 mois : priorité à 5 causes, réduction automatique de `T_ANNEAU_eff` (rejet au chargement suffirait) | systems-designer, technical-artist | Prototype | Ouverte |
