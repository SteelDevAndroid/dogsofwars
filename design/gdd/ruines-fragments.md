# Ruines et fragments

> **Status**: Designed (pending /design-review)
> **Author**: user + Claude (game-designer, narrative-director)
> **Last Updated**: 2026-10-30
> **Last Verified**: 2026-10-30
> **Implements Pillar**: Pilier 2 « Chaque faction a une mémoire » ; pilier 5 « Le brouillard cache une question » ; pilier 1 par le gain de territoire de la zone
> **Creative Director Review (CD-GDD-ALIGN)**: REVISED 2026-10-30 — CONCERNS (score affiché comme butin avant la lecture ; détour affirmé sans être construit ; durée de vie de la question non chiffrée ; ruine occupée par l'IA ; fermeture accidentelle et relecture ; règle 28 qui figeait une hypothèse non testée) corrigées ; séance à profil préchargé au signal 2 portée en question ouverte
> **System**: 13 — Narrative, MVP. Dépend de 2, 5, 11, 15, 22.

## Summary

Trois ruines tirées par partie, visibles sous le brouillard dès le tour 1. Une unité qui s'arrête dessus lit un fragment de la chronique (toujours le suivant, dans l'ordre fixe), recolore une zone de 25 tuiles autour d'elle et rapporte du score. La lecture ne coûte rien ; le prix est le détour. L'IA ne lit pas.

## Overview

Une ruine est un point d'intérêt posé sur une des 9 positions candidates de la carte (3 zones de 3), dont 3 sont tirées à la mise en place. La lecture a lieu automatiquement quand une unité du joueur termine son déplacement sur la tuile : le joueur choisit seulement d'y aller ou non. Elle donne un fragment (140 caractères au plus) pris dans un pool à ordre fixe conservé d'une partie à l'autre par le profil (22), appelle `recolorer_zone` (11) pour une zone de rayon 2, et ajoute 60 points de score plus un point par tuile gagnée. Aucun autre effet : ni énergie, ni vision, ni bonus de combat. La couleur ne code jamais le récit (`recoloration-monde.md`, règle 21) ; c'est le contenu des fragments qui, de partie en partie, change le sens de « allumer ».

## Player Fantasy

**Quelqu'un était là avant nous.** Au tour 1, trois points pâles se devinent sous le brouillard. Le joueur choisit de détourner une unité, parfois au prix d'un nœud : puis un papier court se pose sur la carte, une phrase qui ne dit pas tout. Il ne gagne pas de puissance : il gagne une question, et un morceau de carte qui s'allume autour du lieu.

Trois échecs à éviter : la ruine vécue comme un coffre (récompense chiffrée qui efface le mystère) ; le texte long qui arrête le jeu ; le joueur puni pour avoir voulu lire (fragment perdu parce qu'il a perdu la partie ou parce que l'IA l'a pris).

## Detailed Design

*Décisions du 2026-10-30 : gain = score + zone, sans autre effet ; l'IA ne lit ni ne défend ; pool MVP de 5 fragments ; zone de rayon 2 (25 tuiles).*

### Core Rules

**A. La ruine**

1. **Entrée d'état.** Une ruine tirée est une entrée de la tranche Ruines : `id`, `tuile` (une des 9 positions candidates), `zone_id` (3 zones de 3 candidats), `faction_mémoire`, `lue` (booléen), `lue_au_tour` (−1 tant que non lue), `lue_par`. `faction_mémoire` est une donnée du fichier de carte (une seule valeur au MVP).
2. **Nombre.** Seules les 3 ruines tirées existent dans l'état ; les 6 autres n'y figurent pas et ne sont jamais visibles. Le tirage appartient à 2 ; 13 gère les ruines après la mise en place.
3. **Position.** Plaine ou forêt, jamais montagne ni eau, à au moins 3 tuiles (Chebyshev) de tout départ (validé par 2). Un seul point d'intérêt par tuile.
4. **Zone.** Carré de rayon `RAYON_ZONE_RUINE` = 2 centré sur la ruine, soit `Z_RUINE_MAX` = (2R+1)² = 25 tuiles avant découpage par les bords. Le terrain est ignoré (eau et montagne incluses). Seules les tuiles neutres et non-nœud sont écrites ; une tuile ennemie n'est jamais prise.
5. **Ancrage.** Les tuiles écrites portent l'ancrage RUINE (`noeuds.md`, règle 15) : il survit à la perte de nœuds tant que la faction en tient au moins un, repasse à NŒUD si un nœud d'une autre faction couvre la tuile, devient neutre si la faction est éliminée.
6. **Zone sans effet.** Si `recolorer_zone` rend 0 tuile, la lecture a lieu (fragment, score) mais il n'y a ni onde ni événement de couleur ; la ligne « Zone recolorée » du HUD est masquée.

**B. La lecture**

7. **Déclenchement.** Pas une commande : la lecture a lieu dans l'application de DÉPLACER quand une unité **termine** son déplacement sur la tuile. Traverser ou attaquer depuis une tuile voisine ne lit rien.
8. **Coût.** Aucun (ni énergie, ni action) : le prix est le déplacement.
9. **Qui lit.** Toute unité éveillée du joueur, quel que soit son type. Un dormant ne lit pas.
10. **Une fois par ruine et par partie.** `lue` reste vrai jusqu'à la fin de la partie, même si la faction perd ses nœuds.
11. **L'IA ne lit pas et ne défend pas.** Une unité de l'IA qui s'arrête sur une ruine ne déclenche rien ; la ruine n'est pas un objectif de l'IA et n'entre pas dans son état filtré. Sinon l'IA volerait un fragment au joueur (anti-pilier). La comparaison de score au 30e tour se fait hors points de ruine (à porter dans 3).
12bis. **Relecture.** Un appui sur le glyphe « lu » d'une ruine rouvre son fragment en partie (même texte, même lieu) ; une ruine lue sans fragment (pool épuisé) n'ouvre rien.
12. **Annulation.** Un DÉPLACER qui a lu une ruine n'est pas annulable (DÉPLACEMENT_A_RÉVÉLÉ).
13. **Simulations.** Une simulation applique les fonctions de règle sans passer par la couche des commandes et jette leurs effets : elle ne peut ni écrire le profil ni publier d'événement (22, règle 15 ; GDD 1, règles 3 et 9). Elle calcule le fragment suivant sur l'état seul, pour information.
14. **Séquence, dans la même commande :** (a) l'unité arrive ; (b) `lue` = vrai, `lue_au_tour` renseigné ; (c) le fragment suivant est calculé (règle 17) ; (d) une entrée « en attente » est ajoutée au journal (ruine, faction, id du fragment, 0 si aucun) ; (e) `recolorer_zone` ; (f) le compte `ruines_lues` (F) augmente de 1 (il se déduit de la tranche Ruines : aucun compteur stocké) ; (g) l'événement RUINE_LUE et l'effet « enregistrer un fragment » sont **rendus** (ruine, faction, id du fragment, 0 si pool épuisé). Ensuite la partie est écrite (sauvegarde après chaque commande), la couche des commandes (23) applique l'effet au profil (idempotent) et l'écrit ; si cette écriture réussit, elle applique la commande interne « valider la lecture », qui passe l'entrée du journal à « validée » (ADR-0004 et ADR-0006).
15. **Affichage : l'onde d'abord.** Le panneau de fragment apparaît 400 ms après la fin de l'onde de recoloration et de l'écriture (sans onde, 400 ms après l'étape (e)). Il se ferme par « Continuer » (un appui, ignoré avant `DÉLAI_FERMETURE` = 500 ms), n'est pas repliable, bloque les commandes ; la carte reste visible au-dessus.
16. **Deux ruines dans le même tour.** Les panneaux s'enchaînent ; la seconde lecture est calculée sur le résultat de la première.

**C. Pool et ordre**

17. **Ordre fixe.** Le fragment donné est `min(P_f \ (C_f ∪ J_f))` : le plus petit id de la faction qui n'est ni dans l'**instantané de la chronique** copié dans l'état à la création de la partie (`C_f`, tranche « Instantané de la chronique », écrite une seule fois par 13) ni dans le journal de la partie (`J_f`). Le calcul se fait sur l'état seul : aucune règle de partie ne lit le profil. Aucun hasard : c'est l'ordre de lecture qui fait avancer la chronique, pas la position de la ruine.
18. **Curseur.** Non stocké : 22 le dérive de la chronique. 13 est le seul écrivain de la chronique (« enregistrer un fragment », idempotent par id).
19. **Taille.** MVP : 5 fragments (ids 1 à 5), une faction de mémoire. Lancement : 12. Full Vision : 36. Les ids ne sont jamais réutilisés.
20. **Par partie.** Au plus `LECTURES_PAR_PARTIE` = 3 fragments (3 ruines tirées). Parties pour compléter la chronique = ⌈pool ÷ lectures par partie⌉ : 2 au MVP (pool 5), au moins 4 visé au lancement (pool 12). Une chronique complète laisse aux ruines la zone et le score : c'est un arbitrage assumé (concept, Core Mechanics, point 5), qu'aucun GDD ultérieur ne corrige par du texte de remplacement (pilier 2).
21. **Pool épuisé.** La formule rend AUCUN : pas d'enregistrement, profil inchangé, RUINE_LUE avec id 0, la ruine ne donne que la zone et le score (F compte). Affichage : puce « Ruine lue · +n tuiles » sans panneau ; aucun texte de remplacement.
22. **Partie perdue avant lecture.** Rien n'est enregistré ; la partie suivante redonne le même fragment.
23. **Partie perdue ou abandonnée après lecture.** Le fragment reste dans la chronique (anti-pilier). Le score n'est pas établi mais les fragments sont conservés.
24. **Ruine lue puis nœud perdu.** La ruine reste lue et le fragment acquis ; si la faction est éliminée, les tuiles deviennent neutres. Rien n'est annulé.
25. **Reprise après arrêt.** Une entrée « en attente » du journal est rejouée à l'identique au chargement (GDD 1, règle 10).
26. **Contenu qui grandit.** Une chronique complète peut redevenir incomplète après une mise à jour (22, règle 12) ; les ruines redonnent alors des fragments.

**D. Le fragment**

Contenu livré dans `assets/data/`, jamais écrit dans le profil.

27. **Champs.**
    - `id` : entier ≥ 1, stable ; l'ordre de la chronique est l'ordre croissant des ids.
    - `faction` ; `acte` : 1, 2 ou 3 (étiqueté dans les données ; MVP : ids 1-2, 3, 4-5).
    - `titre` : 28 caractères au plus ; `texte` : **140 caractères au plus** (90 à 120 visés) ; `source` : 24 caractères au plus, origine in-world (journal, terminal, ordre archivé), jamais un nom de faction ni un numéro de ruine.
    - `tons` : 1 ou 2 parmi {OBÉISSANCE, USURE, DOUTE, ABSENCE, QUESTION} ; `lien_recoloration` : AUCUN, VERBE (emploie « allumer », neutre) ou QUESTION (« pour qui allume-t-on ? » ou équivalent).
28. **[PROVISOIRE — CD-PLAYTEST]** Les seuils ci-dessous sont des données du pool, pas des constantes du validateur ; le validateur garde seulement l'exigence structurelle de 15 (une part identifiée des derniers fragments reprend le verbe et l'image de la recoloration, sans imposer la formulation) et la liste des tons est extensible. **Exigence de 15 (règle 21).** Acte 3 : au moins la moitié des fragments ont un lien ≠ AUCUN et **le dernier du pool est QUESTION**. Acte 1 : au moins un fragment VERBE. MVP à 5 : le fragment 2 (acte 1) est VERBE et le fragment 3 (acte 2, DOUTE) emploie déjà « allumer ». Un test de données vérifie ces seuils au chargement ; le pool est refusé sinon.
29. **Aucun effet mécanique.** Un fragment ne contient aucun chiffre de jeu et son texte ne dépend ni de l'état de partie ni du profil.
30. **Tons.** Ils servent l'équilibre d'écriture (vérifié par le narrative-director) et un éventuel filtre ; aucun effet de jeu.

**E. Gains et limites**

31. **Gain.** Le gain *perçu* en partie est la zone, jamais un nombre : aucune valeur chiffrée n'est affichée avant la lecture ; le score de ruine apparaît seulement au bilan de fin de partie (ligne « Fragments lus »). Score : `w_f` = +60 plus 1 point par tuile gagnée (`w_t`), au plus 85 par ruine, 255 pour trois. Zone ancrée (règle 5). Rien d'autre : ni énergie, ni vision, ni bonus de combat.
32. **Détour compétitif.** Le coût réel est le tempo d'une unité (les tours passés à aller et revenir) et son exposition à une menace annoncée (pilier 4), non de l'énergie : la ruine ne produit aucun revenu et ne fait pas croître la meute, alors qu'un nœud de niveau 1 donne 3 énergie par tour. Contrainte de placement portée dans le GDD 2 : au moins une des 3 ruines n'est pas sur le plus court chemin entre un départ et le nœud neutre le plus proche, pour qu'au moins une ruine coûte un vrai détour. Le détour est un choix si des ruines sont laissées de côté volontairement : si 100 % des ruines sont lues à chaque partie, c'est un devoir (AC-RF29).
33. **Limites.** Aucune tuile ennemie prise ; `w_f` et `w_d` restent chez 3 ; un gain d'énergie de lecture n'existe pas au MVP.

**F. Rejouabilité**

34. Les positions changent (3 candidats par zone, 27 combinaisons), le contenu non : le fragment suivant est toujours le suivant. Le pilier 5 repose sur « où » et « par où », pas sur « quoi ». Une chronique complète laisse aux ruines la zone et le score.
35. **Limite MVP.** À la partie 2, la 3e ruine est un cas « pool épuisé » qui peut passer pour une récompense vide : à observer au signal 2.
36. **Risque de mesure.** Les testeurs du signal 2 ne jouent qu'une partie : ils voient les fragments 1 à 3, jamais l'acte 3 ni la question. Le seuil d'échec mesure le mystère et la ruine, pas le retournement de sens.

### States and Transitions

| État de la ruine | Événement | État suivant | Effets |
|---|---|---|---|
| Non lue | Une unité du joueur termine son déplacement dessus | Lue | Séquence de la règle 14 |
| Non lue | Une unité de l'IA s'y arrête | Non lue | Aucun |
| Lue | Tout | Lue | Aucun (jusqu'à la fin de la partie) |

### Interactions with Other Systems

| # | Système | Sens | Contrat |
|---|---|---|---|
| 1 État | écrit | Tranche Ruines, journal des lectures, compteur F |
| 2 Carte | lit | 9 candidats, tirage de 3, contraintes de position |
| 3 Tours | écrit pour | F = ruines lues (au plus 3) ; `w_f` appartient à 3 ; score du 30e tour hors ruines |
| 5 Brouillard | lit | Ruines tirées visibles dès le tour 1 ; lecture = « a révélé » ; glyphe « lu » permanent (art-director) |
| 9 IA | aucune | Ne lit ni ne défend (règle 11) |
| 11 Nœuds | appelle | `recolorer_zone(faction, tuiles)` ; 11 écrit propriétaire et ancrage |
| 15 Recoloration | source | Cause RUINE, source = tuile de la ruine ; 15 ne lit jamais fragments ni journal |
| 17 HUD | écoute | Puce « Ruine repérée », panneau de fragment, puce « Ruine lue », pastille « n / ruines » |
| 22 Profil | écrit | Seul écrivain de la chronique ; lit le suivant par la formule 1 complétée du journal |
| 23 Commandes | dans DÉPLACER | RUINE_LUE existe ; id de fragment 0 à ajouter au contrat |

## Formulas

*Entiers uniquement.*

### F1. Fragment suivant

`suivant(f) = min(P_f \ (C_f ∪ J_f))`, AUCUN si l'ensemble est vide.

| Symbole | Description |
|---|---|
| P_f | Ids du pool de la faction f (MVP : {1..5}) |
| C_f | Chronique du profil (22) |
| J_f | Fragments lus dans le journal de la partie en cours |

**Exemple** : P = {1..5}, C = {1, 2}, J = {3} → 4 ; C = {1..5} → AUCUN. Deux lectures dans le même tour, C = {} : 1 puis 2.

### F2. Zone de ruine

`Z_RUINE_MAX = (2 × RAYON_ZONE_RUINE + 1)²` = 25 ; tuiles écrites = zone ∩ grille ∩ neutres non-nœud.

**Exemple** : ruine en (6,6), rayon 2 : 25 tuiles ; en (0,0) : 3×3 = 9. Sur 12×12 (144 tuiles), 3 ruines couvrent au plus 75 tuiles (52 %), en pratique 45 à 60.

### F3. Score d'une lecture

`score_ruine = w_f + n_tuiles × w_t` avec `w_f` = 60, `w_t` = 1, n_tuiles ≤ 25 → 60 à 85. Trois ruines : au plus 255 pour un maximum pratique de 776 (`tours-conditions-victoire.md`).

## Edge Cases

- **Unité qui traverse sans s'arrêter** : aucune lecture (règle 7).
- **Unité qui meurt en arrivant** : une arrivée suppose l'unité vivante à la fin du déplacement ; une riposte n'a pas lieu au déplacement, donc le cas n'existe pas.
- **Deux unités du joueur sur des ruines différentes dans le même tour** : deux commandes, deux séquences, deux panneaux (règle 16).
- **Zone déjà possédée** : lecture sans onde (règle 6).
- **Zone partiellement hors de vue** : les tuiles INCONNUES restent à 0 dans la vue (`recoloration-monde.md`, E8) ; l'exception de la règle 5 du GDD 5 informe de ce qui est gagné.
- **Ruine sur une tuile prise par un nœud adverse** : la lecture a lieu, la zone ne prend que les tuiles neutres non-nœud ; l'ancrage repasse à NŒUD sous un nœud d'une autre faction.
- **Profil en LECTURE_SEULE ou écriture échouée** : le journal de la partie évite de redonner le même fragment (règle 17) ; la reprise rejoue l'entrée « en attente ».
- **Pool épuisé** : règle 21.
- **Chargement d'une sauvegarde à une lecture en attente** : règle 25.
- **IA sur une ruine** : aucun effet (règle 11) ; la tuile est occupée et le joueur doit la libérer. Une unité du joueur qui capture ou tue en entrant et termine son déplacement sur la tuile lit. Justification narrative transmise au narrative-director : les Gardiens obéissent, ils ne lisent pas leur propre mémoire.
- **Dernier nœud perdu après lecture** : élimination ; tuiles neutres ; ruine lue ; fragment acquis.
- **Fichier de pool invalide (seuils de la règle 28)** : pool refusé au chargement, la lecture donne AUCUN et une trace est écrite.

## Dependencies

| Système | Direction | Nature |
|---|---|---|
| 2 Carte | dépend de | dur (candidats, tirage) |
| 5 Brouillard | dépend de | dur (visibilité, « a révélé ») |
| 11 Nœuds | dépend de | dur (`recolorer_zone`) |
| 15 Recoloration | dépend de | dur (couleur de la zone) |
| 22 Profil | dépend de | dur (chronique, journal) |
| 23 Commandes | dépend de | dur (DÉPLACER, RUINE_LUE) |
| 3 Tours | est utilisé par | dur (F, score) |
| 17 HUD | est utilisé par | dur |
| 9 IA | aucune | l'IA ne lit pas |
| 20 Audio | est utilisé par | souple |

## Tuning Knobs

| Réglage | Départ | Plage sûre | Effet si trop haut | Effet si trop bas |
|---|---|---|---|---|
| `RAYON_ZONE_RUINE` | 2 | 1 à 3 | Le gris central disparaît ; (R=3 : 49 tuiles) | Le détour ne se lit plus |
| `w_f` (chez 3) | 60 | 40 à 80 | Ruine plus rentable qu'un nœud | Détour sans intérêt |
| Taille du pool | 5 | 5 à 12 | Plus d'écriture avant la boucle | Chronique finie trop vite |
| `LECTURES_PAR_PARTIE` (= ruines tirées) | 3 | 2 à 3 | Chronique finie plus vite | Moins de détours |
| Parties pour compléter la chronique (dérivé) | 2 au MVP ; 4 visé au lancement | 4 à 8 au lancement | Question qui s'épuise tard | Question qui s'épuise trop tôt |
| Délai minimal avant « Continuer » | 500 ms | 300 à 800 | Attente | Fermeture accidentelle |
| Longueur max du texte | 140 caractères | 100 à 160 | Panneau qui défile | Texte trop pauvre |
| Délai avant le panneau | 400 ms | 300 à 600 | Attente | L'onde est coupée |

## Visual/Audio Requirements

- Ruine repérée : glyphe pâle sous le brouillard ; ruine lue : glyphe « lu » permanent (dessin à valider par l'art-director). Panneau de fragment : papier court, mono pour la source (`hud.md`).
- Audio facultatif (20) : une seule note de papier, même poids pour tout fragment, sans cadence de victoire.

## Game Feel

Le fragment est un temps calme après l'onde : 400 ms de pause, puis un papier qu'on ferme d'un appui. Aucun effet de butin. À valider en prototype : le joueur ressent le détour comme un choix, non comme un devoir.

## UI Requirements

- Puce « Ruine repérée » (glyphe et libellé seulement, aucune valeur chiffrée), panneau de fragment, puce « Ruine lue · +n tuiles » (sans panneau si pool épuisé), pastille « n / 3 ruines » (compte les ruines lues, pas les fragments), barre de chronique à N segments (N = taille du pool, pas toujours 12).
- Le glyphe « lu » est interactif (relecture, règle 12bis). La couleur n'est jamais seule : forme et glyphe.

## Cross-References

- `design/gdd/recoloration-monde.md` : `Z_RUINE_MAX` passe de 49 à 25 ; ordre onde puis fragment tranché (règle 15) ; exigence de contenu (règle 28).
- `design/gdd/noeuds.md` : `Z_RUINE_MAX` ouvert à fermer ; règle 15 à écrire « tant que la faction tient un nœud ».
- `design/gdd/tours-conditions-victoire.md` : score du 30e tour hors ruines ; F ≤ 3.
- `design/gdd/profil-donnees-meta.md` : formule 1 complétée du journal ; vue minimale de la chronique (13 ou 18 ?).
- `design/gdd/commandes-evenements.md` : RUINE_LUE avec id 0.
- `design/ux/hud.md` : barre à N segments, pastille « n / 3 ruines », cas 0 tuile et pool épuisé.
- `design/gdd/modele-etat-partie.md` : tranche Ruines, R figé à 3 ; `design/gdd/carte-tuiles-terrain.md` : champ `faction_mémoire`.

## Acceptance Criteria

*Étiquettes : **Logic** = `tests/unit/ruines/`, état par fabrique, horloge injectée, sans rendu ; **Intégration** = `tests/integration/ruines/` ; **Visuel** et **UI** = capture retenue dans `production/qa/evidence/ruines-fragments/` (nom `ACRF<n>-<scène>-<ms>.png`), prise sur l'appareil cible ; **Playtest** = rapport de séance au même endroit. [BLOQUÉ n] = attend le système n. Valeurs de départ : `RAYON_ZONE_RUINE` 2, `w_f` 60, `w_t` 1, délai du panneau 400 ms, pool MVP 5, texte 140 / titre 28 / source 24 caractères ; si un réglage change, les nombres se recalculent par F2 et F3. Entiers uniquement ; aucune graine ni horodatage dans la logique de 13.*

### A. Position et zone (règles 1 à 6, F2)

- **AC-RF1** (Logic, règles 1 à 3) **GIVEN** la carte de test (9 candidats, 3 zones de 3), **THEN** l'état contient exactement 3 ruines, une par zone, avec `id`, `tuile`, `zone_id`, `faction_mémoire`, `lue` faux, `lue_au_tour` −1 ; les 6 autres candidats n'existent pas dans l'état ; chaque ruine est en plaine ou forêt, à au moins 3 tuiles de tout départ, sans partager de tuile avec une autre ruine ou un nœud. Vrai sur les 27 combinaisons. [BLOQUÉ 2]
- **AC-RF2** (Logic, règle 4, F2) **GIVEN** `RAYON_ZONE_RUINE` = 2 et une zone neutre, **THEN** une ruine en (6,6) écrit 25 tuiles, en (0,0) 9, en (0,6) 15 ; le terrain est ignoré (4 eaux et 3 montagnes incluses : 25) ; avec un rayon de 3 : 49.
- **AC-RF3** (Logic, règles 4 et 33) **GIVEN** une zone de 25 tuiles dont 3 à la faction 2 et 1 nœud, **THEN** 21 tuiles écrites, `n_tuiles` = 21, aucune tuile ennemie ni de nœud modifiée ; sur 1 000 zones de graine fixe, aucune tuile non neutre n'est écrite.
- **AC-RF4** (Logic + UI, règle 6) **GIVEN** une zone déjà entièrement possédée, **THEN** `recolorer_zone` rend 0 tuile ; la lecture a lieu (fragment, `lue` vrai, score +60, `ruines_lues` +1, RUINE_LUE) ; ni événement de couleur ni onde ; la ligne « Zone recolorée » est masquée (capture). [BLOQUÉ 17]
- **AC-RF5** (Logic, règles 5 et 24) **THEN** les tuiles écrites portent l'ancrage RUINE ; il survit à la perte d'un nœud tant que la faction en tient un, repasse à NŒUD sous un nœud d'une autre faction, et devient neutre à l'élimination. [BLOQUÉ 11]

### B. Déclenchement et séquence (règles 7 à 14)

- **AC-RF6** (Logic, règle 7) **GIVEN** un déplacement de 4 tuiles qui traverse la ruine, **THEN** rien n'est lu ; idem pour une attaque depuis une tuile voisine ; **WHEN** l'unité termine sur la tuile, **THEN** une lecture.
- **AC-RF7** (Logic, règles 9 et 10) **THEN** chaque type d'unité éveillée du MVP lit ; un dormant qui termine dessus ne lit pas ; une seconde unité sur une ruine déjà lue, même 20 tours plus tard, n'a aucun effet (état identique octet pour octet).
- **AC-RF8** (Intégration, règle 11) **GIVEN** une unité de l'IA qui s'arrête sur une ruine, **THEN** `lue` reste faux, aucun événement ni score ; l'état filtré de l'IA ne contient aucune ruine (un double d'IA qui lit ce champ échoue) ; le score du 30e tour ne contient aucun point de ruine. [BLOQUÉ 9, 3]
- **AC-RF9** (Logic, règle 8) **THEN** énergie, actions et mouvement diffèrent seulement du coût du déplacement ; la lecture ajoute 0 énergie, 0 action, aucun bonus de combat ni de vision.
- **AC-RF10** (Logic, règle 14) **THEN** l'ordre d'appels d'une commande est (a) arrivée, (b) `lue`, (c) F1 sur l'instantané et le journal, (d) journal « en attente », (e) `recolorer_zone`, (f) `ruines_lues` +1, (g) RUINE_LUE et l'effet « enregistrer un fragment » rendus, chaque étape une fois ; l'application de l'effet au profil est postérieure, faite par la couche des commandes, et idempotente (rejouée deux fois : chronique identique) ; « valider la lecture » n'est appliquée qu'après une écriture réussie du profil.
- **AC-RF11** (Logic, règle 12) **THEN** l'annulation d'un DÉPLACER qui a lu est refusée (DÉPLACEMENT_A_RÉVÉLÉ), état identique avant et après la tentative. [BLOQUÉ 23]

### C. Pool, ordre et profil (règles 16 à 26, F1)

- **AC-RF12** (Logic, règle 17, F1) **THEN** `suivant` vaut : C={1,2}, J={3} → 4 ; C={1..5} → AUCUN ; C={} → 1 ; C={2} → 1 (plus petit id manquant) ; C={1,3}, J={2} → 4 ; identique sur les 27 combinaisons de tirage et quelle que soit la ruine lue en premier.
- **AC-RF13** (Intégration, règle 16) **GIVEN** C={} et deux unités sur deux ruines dans le même tour, **THEN** deux commandes, fragments 1 puis 2, deux panneaux dans cet ordre, `ruines_lues` = 2 ; une troisième lecture donne 3.
- **AC-RF14** (Logic + UI, règle 21) **GIVEN** C={1..5} et n = 25, **THEN** RUINE_LUE porte l'id 0, profil inchangé octet pour octet, `ruines_lues` +1, score 85 ; la puce « Ruine lue · +25 tuiles » apparaît sans panneau ni texte de remplacement (capture). [BLOQUÉ 17, 22]
- **AC-RF15** (Intégration, règle 22) **GIVEN** une partie perdue avec 3 ruines non lues, **THEN** chronique inchangée ; la partie suivante redonne le fragment 1. [BLOQUÉ 22]
- **AC-RF16** (Intégration, règle 23) **GIVEN** un fragment lu puis la partie perdue, **THEN** la chronique contient l'id ; la partie suivante donne l'id suivant ; le score n'est pas établi. [BLOQUÉ 22]
- **AC-RF17** (Logic, règles 10 et 24) **GIVEN** une ruine lue puis le dernier nœud perdu, **THEN** élimination, tuiles neutres, `lue` vrai, fragment conservé, `ruines_lues` inchangé ; une unité qui se tient à nouveau dessus ne relit pas.
- **AC-RF18** (Intégration, règle 25) **GIVEN** une sauvegarde faite entre (d) et la fin de l'enregistrement, **THEN** le chargement rejoue l'entrée une seule fois (pas de doublon, `ruines_lues` non incrémenté deux fois) ; profil en LECTURE_SEULE : le journal évite de redonner le même fragment. [BLOQUÉ 1, 22]
- **AC-RF19** (Logic, règle 13) **GIVEN** 1 000 simulations qui lisent une ruine, **THEN** profil, journal et chronique sont inchangés octet pour octet ; l'effet « enregistrer un fragment » est rendu puis jeté, sans appel au stockage.

### D. Score, absence d'effet, données (règles 27 à 33, F3)

- **AC-RF20** (Logic, règle 31, F3) **THEN** `score_ruine` = 60 (n = 0), 69 (n = 9), 81 (n = 21), 85 (n = 25), jamais hors de 60 à 85 ; trois lectures au plus 255 ; `w_f` = 40 donne 40 à 65 sans changer le code de 13.
- **AC-RF21** (Intégration, règles 29 et 33) **GIVEN** deux parties de même graine, l'une avec C={}, l'autre avec C={1..5}, **THEN** après la même lecture tous les états de partie sont identiques hors chronique, journal et compteur de fragments (énergie, vision, combat, tuiles, score, événements de couleur) ; 15 ne lit ni journal ni chronique ; le texte d'un fragment est identique dans deux états de partie et deux profils différents. [BLOQUÉ 15, 22]
- **AC-RF22** (Logic, règle 28) **THEN** le test de données accepte le pool MVP livré ; refuse un pool dont le dernier fragment n'est pas QUESTION, sans VERBE à l'acte 1, ou dont moins de la moitié de l'acte 3 a un lien ≠ AUCUN ; accepte à la limite exacte ; en cas de refus, la lecture donne AUCUN (id 0), une trace nomme le seuil, rien n'est écrit au profil.
- **AC-RF23** (Logic, règle 27) **THEN** le test de données accepte titre 28, texte 140, source 24 caractères (accents comptés en caractères) et refuse 29, 141, 25 ; refuse `id` < 1 ou en double, `acte` hors {1,2,3}, `tons` vide, à 3 valeurs ou hors liste, `lien_recoloration` hors liste, `source` contenant un nom de faction ou « ruine » suivi d'un numéro ; le pool MVP tient ces limites (ids 1-2 acte 1, 3 acte 2, 4-5 acte 3).

### E. Affichage (règle 15)

- **AC-RF24** (Logic, règle 15) **GIVEN** une horloge injectée et une onde finissant à t, **THEN** le panneau est demandé à t + 400 ms exactement ; délai 300 ou 600 : t + 300 ou t + 600 ; jamais avant la fin de l'écriture ; sans onde (0 tuile), 400 ms après l'étape (e).
- **AC-RF25** (Visuel + UI, règle 15) **THEN** captures de l'onde terminée, de t + 399 ms (pas de panneau) et de t + 400 ms (panneau : titre, texte, source en mono, « Continuer », carte visible, aucun repli) ; toute commande est ignorée tant que le panneau est ouvert ; un appui sur « Continuer » le ferme. [BLOQUÉ 17]
- **AC-RF26** (UI) **THEN** la pastille « n / 3 ruines » compte les ruines lues, pas les fragments : 0 / 3, 1 / 3, 3 / 3 ; une lecture à pool épuisé compte ; une perte de nœud ne la baisse pas (captures). [BLOQUÉ 17]
- **AC-RF27** (UI) **THEN** la barre de chronique a N segments (N = taille du pool : 5 au MVP) ; remplis = |C| ; forme et glyphe distinguent rempli et vide ; captures à C={}, {1,2}, {1..5}. [BLOQUÉ 17, 22]

### F. Déterminisme

- **AC-RF28** (Logic, règles 14 et 17) **THEN** sur 100 exécutions de même graine et mêmes commandes, ids de fragments, événements, scores, tuiles écrites et entrées du journal sont identiques octet pour octet ; la logique de 13 n'appelle aucun générateur aléatoire ni horloge système.

### G. Playtest (signal 2)

- **AC-RF30** (Logic + UI, règle 12bis) **THEN** un appui sur le glyphe « lu » rouvre le fragment lu (même id, même texte) ; sur une ruine lue à pool épuisé, rien ne s'ouvre ; un appui sur « Continuer » avant 500 ms est ignoré, après 500 ms il ferme. [BLOQUÉ 17]
- **AC-RF31** (Logic, Edge Cases) **GIVEN** une unité de l'IA sur la ruine, **THEN** aucune lecture ; **WHEN** une unité du joueur tue l'occupant en entrant et termine sur la tuile, **THEN** elle lit.
- **AC-RF29** (Playtest, règles 34 à 36) **GIVEN** les testeurs du signal 2 (profil vierge, une partie), **THEN** le rapport consigne par testeur : ruines visitées sur 3 et coût du détour ; ruine décrite comme un choix, non comme un coffre ou un devoir ; fragment relu ou cité sans invitation ; zone recolorée remarquée. Seuil de départ [PROP] : au moins la moitié visitent une ruine ou donnent une raison précise de ne pas le faire, aucun ne parle de « récompense vide » ni ne décrit la ruine par ses points, et toutes les ruines ne sont pas lues dans toutes les parties (sinon c'est un devoir). **Ce critère ne mesure pas l'acte 3** : en une partie les testeurs voient au plus les fragments 1 à 3 et ne rencontrent jamais la question « pour qui allume-t-on ? » ; le retournement de sens est vérifié par AC-RF22 et la relecture du narrative-director, et n'est observable qu'à partir de la partie 2. [seuil à remplacer par la feuille de signaux du concept]

### Captures retenues exigées (toutes [BLOQUÉ 17])

AC-RF4 (HUD sans « Zone recolorée »), AC-RF14 (puce sans panneau), AC-RF25 (t, t + 399, t + 400 ms), AC-RF26 (0/3, 1/3, 3/3), AC-RF27 (barre à 5 segments, trois états), AC-RF2 facultatif (zone de 25 au centre, de 9 au coin), AC-RF29 (rapport de séance).

## Open Questions

| Question | Propriétaire | Échéance | Statut |
|---|---|---|---|
| Vue minimale de la chronique : 13 ou 18 avec 14 | creative-director | Revue de 22 | Ouverte |
| Texte des 5 fragments du MVP | narrative-director, writer | Avant le signal 2 | Ouverte |
| Glyphe « lu » permanent | art-director | Art bible §6 | Ouverte |
| Faction de mémoire fixée dans le fichier de carte | level-designer | Revue de 2 | Posé |
| Séance à profil préchargé C = {1, 2, 3} pour 2 testeurs du signal 2, afin de voir les fragments 4 et 5 (sinon la ligne narrative serait verrouillée sans avoir été testée) | creative-director, producer | Feuille de signaux du concept | Ouverte |
| `w_t` double-t-il le score de territoire déjà compté par 3 ? Sinon le mettre à 0 | systems-designer | Revue de 3 | Ouverte |
| Numérotation des tableaux de `systems-index.md` (effort : Énergie 9, Ruines 16, Audio 22) | producer | Prochaine mise à jour de l'index | Ouverte |
| Ruine vide à la partie 2 : lue comme récompense vide ? | game-designer | Signal 2 | À observer |
