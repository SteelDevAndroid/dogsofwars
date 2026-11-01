# HUD (système)

> **Status**: Designed (pending /design-review)
> **Author**: user + Claude (ux-designer, game-designer)
> **Last Updated**: 2026-10-30
> **Last Verified**: 2026-10-30
> **Implements Pillar**: Pilier 3 « Lisible comme Polytopia » ; pilier 4 « Juste mais dure » (chaque perte visible) ; pilier 1 (la meute se voit grandir) ; pilier 2 (fragment et chronique, E27 et E28) ; pilier 5 (ruines et brouillard, E14, E36, E37)
> **Creative Director Review (CD-GDD-ALIGN)**: REVISED 2026-10-30 — CONCERNS (score décisif contredit le GDD 3 non amendé ; score ennemi et vue du joueur ; décompte du budget faux ; animations simultanées à l'ouverture du panneau ; règle des 3 changements par seconde contredit le décompte d'énergie) corrigées ; amendements de 3, 5, `hud.md` et 1 listés en Cross-References
> **System**: 17 — UI, MVP. Spécification visuelle : `design/ux/hud.md` (maquettes et écrans) ; ce GDD fixe la projection de l'état, les sources de données, les événements écoutés et les règles d'affichage.

## Summary

Le HUD est une projection de l'état de la partie : il ne possède aucune donnée de jeu. Il lit les événements publiés par les commandes (23) à son propre rythme, interroge l'état seulement quand la file est vide, et garde le même budget visuel que le spec UX. Ce GDD consolide ce que chacun des 16 autres GDD exige du HUD.

## Overview

Chaque élément du HUD a une source, un événement qui le rafraîchit, une règle d'affichage, une priorité et une valeur nulle (catalogue de la règle 8). La file d'événements est lue lot par lot : un lot est présenté entièrement avant le suivant, et une seule chose bouge à la fois dans le HUD. Perdre la file (chargement, RESYNCHRONISER) ne change jamais la partie : le HUD se reconstruit depuis l'état, à l'exception d'une petite tranche de rappels de présentation sauvegardée pour les pertes du dernier tour ennemi.

## Player Fantasy

**Je vois tout ce qui compte, et rien de plus.** Le joueur sait à tout moment quel est le tour, combien d'énergie il a, ce qui le menace, ce qu'il vient de perdre et où en est la partie, sans fouiller. Rien ne bouge deux fois en même temps ; rien d'important ne disparaît seul.

Trois échecs à éviter : le chiffre qui change avant l'événement qui l'explique ; la perte qu'on ne voit plus après une reprise de partie ; le score affiché qui contredit le résultat final.

## Detailed Design

*Décisions du 2026-10-30 : score décisif exact des deux camps (F = 0) ; puce « Ruine repérée » sans chiffre ; tranche de rappels de présentation dans l'état.*

### Core Rules

*Périmètre : **MVP** = tout sauf la liste suivante. **Lancement** : E05 (fiche de revenu), E25 (chiffres de dégâts, doublés par la jauge), E34 (fiche de tuile), E40 (puce de recherche), croix des intentions annulées dans la tranche de rappels, « Revoir » et son tampon (règle 9), vitesse Instantanée, texte à 150 % (AC-HU40), chemin « Fragments de la partie » (AC-HU42), playtest AC-HU44. À faire chiffrer par le producer.*

**A. Principe : projection de l'état**

1. **Propriété.** Le HUD ne possède que : la table code de refus → phrase (23 ne produit aucun texte), le rythme de présentation, la priorité et la fusion des puces, la machine à états des panneaux, un tampon de présentation (journal), et la lecture des réglages (il ne les écrit pas).
2. **Deux sources, jamais mélangées.** *État présenté* : valeurs portées par le dernier événement consommé (ÉNERGIE_CHANGÉE, UNITÉ_TOUCHÉE, RUINE_LUE). *État interrogé* : lecture directe de l'état, faite seulement quand la file est vide, sur RESYNCHRONISER ou sur ÉTAT_CHARGÉ. Raison : l'état est final quand un lot est publié, mais la file est lue au rythme des animations ; relire l'état trop tôt ferait monter la pastille avant le panneau.
3. **Valeurs sans paramètre d'événement** (revenu, score décisif, `d_ruine`, « létale », `undo_allowed`, états grisés) : interrogées à l'idle uniquement, chacune avec un seul fournisseur.
4. **Vue du joueur seulement** (1, règle 11), à une exception : E07 est le seul agrégat public calculé sur des données hors vue ; aucune décomposition ni aucun delta n'est affiché, et il se met à jour à l'idle de début de tour sans animation de variation.
5. **Rien n'est recalculé** : aperçu de combat par commande sur copie (23, règle 7) ; « létale » par la fonction pure du combat ; portée par validation sans application ; revenu par `revenu` (10) ; score par la formule 1 de 3 ; distance de ruine par la formule 7 de 5.
6. **Aucune commande depuis un auditeur** (23, règle 11) : les boutons ne sont actifs que si la file est idle ; un appui pendant la distribution reçoit COMMANDES_VERROUILLÉES (bouton grisé sans message).
7. **Perdre la file ne change jamais la partie** (23, règle 9). Exceptions : le tampon du journal et la tranche de rappels (règle 22).
8. **Textes** : issus des codes de 23 et des données de 6, 13, 3 (phrase de 90 caractères au plus, 140 pour un fragment), localisables avec 40 % de marge.
9. **Tampon du journal.** « Revoir » rejoue un tampon d'événements côté présentation, pour la phase ennemie courante seulement, jamais sauvegardé. Après chargement ou RESYNCHRONISER, « Revoir » est grisé (« Indisponible après une reprise »).

**B. Catalogue des éléments**

Priorité : P1 jamais masqué (réservé à ce qui sert une décision de ce tour : menace, létale, énergie, tour, Fin du tour, pertes) ; P2 masqué seulement par un état verrouillé ; P3 repliable.

| # | Élément | Source (GDD) | Rafraîchi par | Prio | Valeur nulle |
|---|---|---|---|---|---|
| E01 | Compteur « TOUR n / 30 » + barre | Tour, `T_MAX` (3) | TOUR_COMMENCÉ | P1 | « TOUR — / 30 » avant le tour 1 |
| E02 | Derniers tours : chiffre blanc, libellé « DERNIERS TOURS » | Tours restants (3, F3) | TOUR_COMMENCÉ | P1 | Absent au-dessus du seuil de 5 |
| E03 | Énergie : stock, « MAX » à 99 | Stock (10) | ÉNERGIE_CHANGÉE : décompte de 200 ms | P1 | « 0 » |
| E04 | Revenu « +n » | `revenu` (10) | Idle, au début du tour du joueur | P1 | « +0 » |
| E05 | Fiche de revenu par nœud | `revenu_détail` (10) | Idle, à l'ouverture | P3 | « Aucun revenu » |
| E06 | Pastille « n / 3 ruines » | `ruines_lues` (13) | RUINE_LUE au moment où il est présenté | P2 | « 0 / 3 » |
| E07 | Score décisif « Victoire : a contre b » | Formule 1 de 3 avec F = 0 | Idle, début de tour | P1 | Valeurs initiales |
| E08 | Bouton pause | — | — | P1 | — |
| E09 | Bouton « Fin du tour » | Phase (3) | PHASE_CHANGÉE, TOUR_COMMENCÉ | P1 | Remplacé en CIBLAGE ou panneau de fragment |
| E10 | Puce de menace « n attaque(s) annoncée(s) » | Intentions (9) | INTENTION_ANNONCÉE / EXÉCUTÉE / ANNULÉE ; ÉTAT_CHARGÉ | P1 | Absente |
| E11 | Variante « Siège · 1/2 », « 2/2 » | Compte de siège (9, règle 13) | INTENTION_ANNONCÉE | P1 | Absente |
| E12 | Puce « Dernier nœud » | Nœuds (11, règle 16) | NŒUD_CAPTURÉ, ÉTAT_CHARGÉ | P1 | Absente |
| E13 | Puce de perte « Drone perdu » / « Nœud perdu » | Rappels (règle 22) | TOUR_COMMENCÉ du joueur | P1 | Absente |
| E14 | Puce « Ruine repérée » (libellé et glyphe, **sans chiffre**) | Ruines tirées non lues (13) | Idle après UNITÉ_DÉPLACÉE ou NŒUD_CAPTURÉ | P3 | Masquée s'il n'en reste aucune |
| E15 | Puce « Ruine lue · +n tuiles » (pool épuisé) | RUINE_LUE, id 0 | RUINE_LUE présenté | P3 | Absente |
| E16 | Grappe +, −, Recentrer | Zoom (4) | Idle | P1 | +/− grisés aux bornes |
| E17 | Panneau d'unité | Unité (6) | Sélection, UNITÉ_TOUCHÉE, UNITÉ_SOIGNÉE, DÉPLACEMENT_ANNULÉ | P2 | Réduit à E09 |
| E18 | Stats « PV · ATQ · DÉF · MVT » + phrase | Type, PV (6), stat effective (12) | idem | P2 | — |
| E19 | État « prête / a bougé / terminée » | Drapeaux (6) | Idle | P2 | — |
| E20 | Boutons d'action (3 places) | Codes de refus (23), `prix_réveil` (7) | Idle | P2 | Grisés avec raison, jamais cachés |
| E21 | Aperçu de combat | Copie (23, règles 7 et 8) | Chaque cible choisie | P2 | « Aucune cible à portée » |
| E22 | Marqueurs d'intention (hachure, « ! », contour de l'auteur, motif en info-bulle, croix si annulée) | Intentions (9, règle 18) | Événements INTENTION_* | P1 | Absents |
| E23 | Marqueur « létale » (forme distincte) | Fonction pure du combat | Idle, début de tour | P1 | Absent |
| E24 | Jauge de PV | PV (6) | UNITÉ_TOUCHÉE, UNITÉ_SOIGNÉE : 300 ms | P2 | Absente à PV pleins |
| E25 | Chiffres de dégâts « −N » | UNITÉ_TOUCHÉE | 800 ms | P3 | Aucun à 0 dégât |
| E26 | Débris, tuile perdue en liseré pointillé | UNITÉ_DÉTRUITE, COULEUR…, rappels | Événement ; rappels | P1 | — |
| E27 | Panneau de fragment | Fragment (13), chronique (22) | RUINE_LUE présenté | P1 | Voir E15 si id = 0 |
| E28 | Barre de chronique à N segments (N = taille du pool) | 13, 22 | À l'ouverture du panneau | P2 | 0 rempli |
| E29 | Glyphe « lu » sur la carte | `lue` (13) | RUINE_LUE | P3 | Pool épuisé : rien ne s'ouvre |
| E30 | Marqueur de ruine non lue | Ruines tirées (13) | Aucun | P2 | — |
| E31 | Journal du tour ennemi + étiquette « Tour ennemi » | Événements filtrés par la vue (5) | Chaque événement de phase ennemie | P1 | IA passive : « Les Gardiens restent immobiles » |
| E32 | Fiche de nœud + « Monter » | Nœuds (11), énergie (10) | Idle ; NŒUD_MONTÉ (à ajouter à 23) | P2 | « Monter » grisé avec raison |
| E33 | Fiche de dormant | `prix_réveil` (7) | Idle | P2 | Type inconnu : « Drone endormi » |
| E34 | Fiche de tuile (terrain, coût, défense) | Terrain (2) | Idle | P3 | Aucune sous brouillard |
| E35 | Niveau d'un nœud (anneaux) | Niveau (11) | NŒUD_MONTÉ | P2 | Nœud adverse mémorisé : anneaux en contour |
| E36 | États de tuile INCONNUE / EXPLORÉE / VISIBLE | Visibilité (5) | TUILES_RÉVÉLÉES | P2 | — |
| E37 | Marqueur de dormant | `dormant_mémorisé` (5) | TUILES_RÉVÉLÉES, DRONE_RÉVEILLÉ | P2 | — |
| E38 | Fond violet, cadre et voile (≤ 8 %) du tour ennemi | Phase (3) | PHASE_CHANGÉE | P2 | — |
| E39 | Couleur des tuiles (onde) | Octet de couleur (15) | COULEUR_DES_TUILES_CHANGÉE | P1 | Zone sans effet : aucune onde |
| E40 | Puce « Recherche : nom, n t » + notification | Recherche (12) | RECHERCHE_TERMINÉE | P3 | Absente |
| E41 | Écran de fin | Statut (3) | PARTIE_TERMINÉE | — | Relève de `ux-spec` |

**C. File d'événements**

10. **Consommation.** Lot par lot, dans l'ordre de révision ; un lot est présenté entièrement avant le suivant.
11. **Une seule chose bouge à la fois dans le HUD** (art bible §7) ; le mouvement sur la carte peut se superposer, jamais deux animations de HUD.
12. **Boutons d'action.** Trois places : (1) Déplacer, qui devient « Annuler le déplacement » après un déplacement (grisé avec raison : RIEN_À_ANNULER, DÉPLACEMENT_A_RÉVÉLÉ, AUTRE_ACTION_DEPUIS) ; (2) Attaquer ; (3) Capturer, Réveiller ou rien. Dans l'aperçu de combat, le bouton secondaire s'appelle « Retour » ou « Annuler l'attaque », jamais comme « Annuler le déplacement ».
13. **Une ruine lue** (lot COULEUR_DES_TUILES_CHANGÉE puis RUINE_LUE) : l'onde est jouée ; à sa fin + `DÉLAI_PANNEAU` = 400 ms, le panneau glisse (300 ms) ou la puce E15 apparaît si l'id est 0 ; sans onde (0 tuile), 400 ms après la fin de la lecture, ligne « Zone recolorée » masquée ; la caméra se recentre **avant** l'onde, une seule fois, si la ruine est hors du rectangle (sinon l'onde se jouerait hors écran) ; à l'ouverture du panneau, la pastille E06 et la barre E28 changent sans animation, ou s'animent après la fin du glissement (règle 11) ; « Continuer » est ignoré avant `DÉLAI_FERMETURE` = 500 ms ; le panneau n'est pas repliable et bloque les commandes, la carte reste visible au-dessus ; deux ruines dans le même tour : la seconde seulement après « Continuer ».
14. **Attaque (verrou `ATTACK_LOCK_MS` = 1 600 ms ; animation d'environ 1,5 s).** ATTAQUE_RÉSOLUE, trait (200 à 350 ms), UNITÉ_TOUCHÉE de la cible (350 ms), UNITÉ_TOUCHÉE de l'attaquant (650 ms), UNITÉ_DÉTRUITE (gris puis affaissement de 400 ms). Panneau d'unité affiché, boutons grisés. En animations réduites : mêmes étapes et même ordre, chiffres fixes 800 ms, trait fixe 150 ms.
15. **Tour ennemi.** Un lot par action ennemie ; une ligne de journal par lot, filtrée par la vue (aucune action hors de vue montrée, ou alors générique). Vitesses Normale, Rapide, Instantanée. Le compteur « n / total » compte les lignes visibles, pas les actions réelles.
16. **RESYNCHRONISER.** Animations annulées, tout relu depuis l'état, affichage direct, aucune onde ; un panneau déjà ouvert reste ouvert ; un panneau pas encore ouvert est perdu (le fragment reste accessible par le glyphe « lu » et la chronique) ; « Revoir » grisé.
17. **Chargement (ÉTAT_CHARGÉ).** Aucune onde ; 5 recalcule la vue puis 15 l'octet ; mode REPOS, aucune sélection, aucun panneau ni puce « d'événement » ; caméra par défaut sur l'unité du joueur d'identifiant le plus bas ; « Annuler le déplacement » : RIEN_À_ANNULER ; puces et marqueurs dérivés de l'état reconstruits (menace, dernier nœud, ruine repérée) ; débris et pertes reconstruits depuis la tranche de rappels (règle 22).
18. **Événements à ajouter à 23** : UNITÉ_SOIGNÉE, NŒUD_MONTÉ, la valeur du siège, la destination demandée d'un déplacement arrêté en embuscade ; champ « raison » dans INTENTION_ANNULÉE.

**D. États par contexte**

| État | Panneau de contexte | Commandes | Carte |
|---|---|---|---|
| REPOS | E09 seulement | Actives | Normale |
| SÉLECTION unité | E17 à E20 + E09 | Actives | Portée (si réglage) |
| SÉLECTION nœud | E32 + E09 | « Monter » actif ou grisé | idem |
| SÉLECTION dormant / tuile | E33 ou E34 | Aucune | idem |
| CIBLAGE | E21 (remplace E20 et E09) | « Retour », « Confirmer l'attaque » | Crochets sur les cibles |
| RÉSOLUTION | Panneau d'unité à jour | Verrou `ATTACK_LOCK_MS` = 1 600 ms | Trait, chiffres, jauges |
| LECTURE | E27 (E15 si id 0) | Verrouillées ; défilement et zoom actifs | Visible au-dessus |
| TOUR_ENNEMI | E31 + étiquette | Pause, « Revoir », « À vous » | Cadre violet |
| SUSPENDU | Menu pause | Aucune | — |
| CHARGEMENT | Comme REPOS | Actives | Direct (règle 17) |
| FIN | Écran de fin | — | — |

**E. Budget visuel**

19. **Budget** (hérité de `hud.md` §7) : jusqu'à 9 éléments actifs (tour, énergie avec revenu, ruines, score, pause, 2 puces, panneau, « Fin du tour » ; le passage de 8 à 9 est le prix de E07, à acter dans `hud.md` §7) ; 2 puces visibles avec compteur « +n » pour les repliées ; surface HUD en tour du joueur ≈ 40 % portrait, ≈ 43 % paysage (à remesurer avec E07) ; 55 % pour les états verrouillés ; recouvrement de la carte 0 %, sauf la grappe (3 × 48 dp, écart 8 dp) ; tuile minimale 31 pt ; zones tactiles 48 dp / 44 pt. Largeur du rectangle de carte en portrait : 358 pt (390 − 2 × 16), soit 44,75 pt par tuile ; en paysage 436 / 12 = 36,33 pt. La zone d'alerte garde une hauteur réservée en permanence en portrait (14 % à 76 %), car le rectangle de carte est fixe pendant le tour du joueur.
20. **Priorité des puces** (2 emplacements) : 1 menace (siège compris), 2 dernier nœud, 3 perte, 4 ruine lue ou repérée. « DERNIERS TOURS » vit dans le compteur (E02). Une perte repliée reste visible sur la carte (débris) et dans le journal.
21. **Durées de départ** : glissement du panneau 300 ms ; délai après onde 400 ms ; fermeture ignorée 500 ms ; décompte d'énergie 200 ms ; jauge 300 ms ; chiffre de dégâts 800 ms ; affaissement 400 ms ; réveil 600 ms en une passe, sans toast ; onde 600 / 800 / 1 000 ms ; révélation 150 ms.

**F. Rappels de présentation**

22. **Tranche de rappels** (décision du 2026-10-30), dans l'état, pour la dernière phase ennemie seulement : unités perdues (tuile, camp), tuiles perdues ; les intentions annulées (croix) ne rejoignent la tranche qu'au palier de lancement (le journal du tour en cours les montre déjà). Elle n'a **aucun effet de jeu** : ni le score, ni l'IA, ni la vue ne la lisent (AC-HU29 : octets de la partie identiques hors tranche). Elle est vidée à la fin du tour suivant du joueur. Elle permet, après une reprise de partie, de redessiner débris, liserés, croix et puce de perte (E13, E26). Édite 1, 6 et 11.

**G. Score décisif**

23. **E07** affiche le score exact des deux camps avec F = 0 : les tuiles recolorées par une ruine continuent de compter (vrai territoire), les points de ruine (`w_f`) ne sont pas affichés en jeu ; la pastille « n / 3 » tient ce rôle. Le score ennemi est une information publique, comme dans Polytopia (règle à déclarer dans 3 et 5 : il dit « combien », jamais « où »). Emplacement : une cinquième pastille de la barre ou du rail.

**H. Accessibilité**

24. **Animations réduites** : état final immédiat pour l'onde, le réveil (état éveillé direct, son conservé), l'affaissement, le glissement des panneaux ; chiffres fixes 800 ms ; hiérarchie cible puis riposte conservée ; recentrage instantané ; la pulsation de l'œil au repos est coupée. Au plus 3 **flashs** par seconde au sens de WCAG 2.3.1 (variation forte de luminance, ou de rouge saturé, sur une surface significative) ; les compteurs numériques et les jauges (décompte d'énergie) en sont exemptés ; en vitesse Instantanée du tour ennemi, fusion des lots.
25. **Daltonisme** : la palette alternative remplace faction, ennemi et gris non revendiqué ; menace et ruines ne changent pas ; les formes portent le sens (hexagone / losange ; hachure + « ! » contre arche + lueur) ; « létale » et intention ont des formes distinctes ; le compteur de siège est du texte.
26. **Tactile** : 48 dp (44 pt iOS) avec 8 dp d'écart autour de « Fin du tour » et de la grappe. Le glyphe « lu » (sous 48 dp sur une tuile de 36 pt) a un chemin alternatif : « Fragments de la partie » dans le menu pause ou « Relire » dans le panneau.
27. **Texte** : 12 pt au minimum à 100 %, jusqu'à 150 % (le panneau de fragment défile, la ligne de stats passe sur 2 lignes, les puces s'enroulent) ; citations en Spectral romain 15 pt minimum, sans animation lettre par lettre.
28. **Rien ne disparaît seul** quand une action en dépend (les chiffres de dégâts en sont exemptés : l'information reste dans la jauge et le journal). Les puces durent jusqu'à la fin du tour du joueur. Chaque événement porteur d'information a un équivalent visuel ; le retour haptique est facultatif, jamais seul canal. Noms accessibles donnés à chaque bouton et puce dès maintenant (lecteur d'écran conditionnel).

### States and Transitions

Voir le tableau D. Transitions : REPOS → SÉLECTION (appui sur unité ou nœud) → CIBLAGE (« Attaquer ») → RÉSOLUTION (« Confirmer ») → REPOS ; REPOS → LECTURE (RUINE_LUE présenté) → REPOS (« Continuer ») ; REPOS → TOUR_ENNEMI (« Fin du tour ») → REPOS (« À vous » ou fin de phase) ; tout état → SUSPENDU (pause) → état précédent.

### Interactions with Other Systems

| GDD | Exigence du HUD |
|---|---|
| 1 État | Vue du joueur seulement ; tranche de rappels (règle 22) |
| 2 Carte | Fiche de tuile, « Centrer sur mon départ » (distinct de « Recentrer »), aperçu de portée avec coût de terrain |
| 3 Tours | Compteur, derniers tours, score décisif, raison de fin |
| 4 Contrôles | Rectangle de carte, grappe, mode d'interaction ; ajouter à la table B les lignes nœud du joueur, dormant, glyphe « lu », marqueur d'intention |
| 5 Brouillard | États de tuile, puce de ruine, filtre du journal, intentions hors de vue |
| 6 Unités | Panneau d'unité, boutons grisés avec raison, phrase de 90 caractères, états, jauge |
| 7 Réveil | « Réveiller » avec prix et « manque n » ; ciblage par crochets ; aucun toast |
| 8 Combat | Aperçu, deux appuis pour confirmer, chiffres, verrou |
| 9 IA | Marqueurs d'intention, siège, IA passive, « létale » |
| 10 Énergie | Bloc énergie, détail à l'appui, « manque n » |
| 11 Nœuds | Niveau par anneaux, fiche et « Monter », alerte dernier nœud, puce « Nœud perdu » |
| 12 Protocoles | Écran de l'arbre, puce de recherche, stat effective « +1 » |
| 13 Ruines | Pastille « n / 3 », barre à N segments, relecture, puce « Ruine lue » |
| 15 Recoloration | Écoute de l'événement de couleur, liseré, puce de perte hors vue |
| 16 Sauvegarde | Rien dessiné ; reprise sans panneau à moitié ouvert |
| 22 Profil | Réglages, chronique |
| 23 Commandes | Table code → phrase, événements complétés |

## Formulas

*Entiers uniquement.*

### F1. Largeur d'une tuile

`largeur_tuile_centièmes = (100 × largeur_rectangle) div colonnes` (centièmes de point, entiers). **Exemples** : portrait, rectangle 358 pt, 8 colonnes : 35 800 div 8 = 4 475 (44,75 pt) ; paysage, 436 pt, 12 colonnes : 43 600 div 12 = 3 633 (36,33 pt) ; portrait à 12 colonnes : 35 800 div 12 = 2 983 (29,83 pt), sous le minimum de 3 100 (31 pt) : refusé ; au zoom minimal le portrait montre donc au plus 11 colonnes (35 800 div 11 = 3 254).

### F2. Instant d'apparition du panneau de fragment

`t_panneau = fin_onde + DÉLAI_PANNEAU` (400 ms) ; sans onde, `t_panneau = fin_lecture + 400 ms`. « Continuer » est ignoré avant `t_panneau + 500 ms` (`DÉLAI_FERMETURE`, compté depuis l'ouverture). **Exemple** : onde de rayon 2 (800 ms) : panneau à 1 200 ms après le début de l'onde, fermeture possible à 1 700 ms.

### F3. Budget de surface

`surface_HUD % = Σ aires des éléments visibles / aire de l'écran` ≤ 45 % en tour du joueur (cible 40 % portrait) et ≤ 55 % en états verrouillés. Mesurée par capture sur appareil de référence.

## Edge Cases

- **File qui déborde** (`EVENT_QUEUE_MAX` = 256) : RESYNCHRONISER, affichage direct (règle 16).
- **Reprise pendant le tour du joueur** : puces et marqueurs dérivés de l'état reconstruits ; pertes redessinées depuis la tranche de rappels ; aucun panneau ouvert.
- **Ruine lue à pool épuisé** : puce E15, aucun panneau.
- **Zone sans tuile gagnée** : pas d'onde, ligne « Zone recolorée » masquée.
- **Trois puces candidates** : deux visibles par priorité, compteur « +n » pour les autres.
- **Action ennemie hors de vue** : aucune ligne de journal précise ; compteur du journal sur les lignes visibles.
- **IA passive** : « Les Gardiens restent immobiles », aucun marqueur.
- **Texte à 150 %** : défilement du panneau, enroulement des puces.
- **Commande pendant la distribution** : COMMANDES_VERROUILLÉES, bouton grisé.
- **Glyphe « lu » trop petit** : chemin alternatif (règle 26).
- **Score ennemi** : information publique, jamais d'estimation.

## Dependencies

| Système | Direction | Nature |
|---|---|---|
| 1, 2, 3, 4, 5, 6, 7, 8, 9, 10, 11, 12, 13, 15, 16, 22, 23 | dépend de | dur (lit l'état et écoute les événements) |
| 20 Audio | est utilisé par | souple |
| 18 Menus / fin de partie | est utilisé par | dur |

## Tuning Knobs

| Réglage | Départ | Plage sûre | Effet si trop haut | Effet si trop bas |
|---|---|---|---|---|
| `DÉLAI_PANNEAU` | 400 ms | 300 à 600 | Attente | Onde coupée |
| `DÉLAI_FERMETURE` | 500 ms | 300 à 800 | Attente | Fermeture accidentelle |
| Glissement du panneau | 300 ms | 150 à 400 | Lourdeur | Brutalité |
| Chiffre de dégâts | 800 ms | 600 à 1 000 | Encombrement | Illisible |
| Décompte d'énergie | 200 ms | 100 à 300 | — | Chiffre qui saute |
| Seuil « derniers tours » | 5 tours | 3 à 6 | Alerte permanente | Alerte tardive |
| Puces visibles | 2 | 2 à 3 | Surface HUD | Perte masquée |
| Surface HUD cible | 40 % | ≤ 45 % | Carte écrasée | — |

## Visual/Audio Requirements

Teintes de l'art bible §4 : menace orange-rouge `#FF6A3D`, contours ennemis violets, faction teal ; forme et glyphe avant la couleur. Audio facultatif (20) : cues d'annonce, de perte, de fin de recherche, sans information portée par le son seul ; les lignes à ajouter au tableau SFX de `accessibility-requirements.md` : siège annoncé, dernier nœud, attaque résolue, ruine lue en pool épuisé.

## Game Feel

Rien ne bouge deux fois en même temps ; l'onde passe avant le fragment ; les chiffres confirment sans annoncer. Les marqueurs de menace arrivent avant le tour du joueur et durent tout le tour.

## UI Requirements

Ce GDD est le document d'exigences du système ; les écrans sont dans `design/ux/hud.md`. Corrections à reporter dans `hud.md` : grappe de boutons (§3, §4, §7) ; « Annuler le déplacement » distinct de l'annulation de l'aperçu ; 34 pt → 36,33 pt, largeur portrait 358 pt ; éclatement → gris puis affaissement ; réveil 600 ms sans toast ; états de la carte, nœud adverse mémorisé, dormant mémorisé, intention hors de vue, croix d'intention annulée ; puce de ruine sans chiffre ; barre à N segments, « n / 3 ruines » ; score décisif permanent (§2.2 « Score en cours : ALWAYS HIDE » devient « toujours visible ») ; budget de 9 éléments (§7) ; zone d'alerte à hauteur réservée en permanence, à remesurer avant `/ux-review` (repli si vide en repli si AC-HU35 dépasse 45 %) ; menace visible dès le début du tour du joueur ; « Capturer » actif au moment de l'action ; durée d'une action ennemie.

## Cross-References

- `design/ux/hud.md` : corrections listées plus haut.
- `design/accessibility-requirements.md` : lignes SFX, « Énergie insuffisante » résolu, matrice périmée.
- `design/gdd/ia-ennemie.md` : couleur du marqueur d'intention (`#FF6A3D` plutôt que `#B07CE0`), exemple « Mémoire : +6 » à retirer.
- `design/gdd/tours-conditions-victoire.md` : scinder la formule 1 en « score décisif » (F = 0, règle 9) et « score de profil » (avec `w_f × F`, règle 14) ; réécrire la justification de la règle 13 (une ruine vaut ses tuiles pour la victoire, `w_f` pour le meilleur score) ; retirer « +60 au score » des UI Requirements ; déclarer le score ennemi public.
- `design/gdd/brouillard-vision.md` : exception E07 (agrégat public hors vue, sans décomposition).
- `design/gdd/modele-etat-partie.md` : tranche de rappels sans effet de jeu.
- `design/gdd/brouillard-vision.md` : formule 7 (distance de ruine) hors affichage.
- `design/gdd/controles-tactiles-camera.md` : table B complétée, règle 11 contre dormants, rectangle de carte (358 pt).
- `design/gdd/commandes-evenements.md` : événements ajoutés (règle 18).
- `design/gdd/modele-etat-partie.md` : tranche de rappels.
- `design/gdd/systems-index.md` : dépendances de la ligne 17 (1, 7, 12, 16, 22).

## Acceptance Criteria

*Étiquettes : **Logic** = `tests/unit/hud/`, présentateur alimenté par une fausse file d'événements et un double d'état, horloge injectée, sans rendu ; **Intégration** = `tests/integration/hud/` (vrai état, vraies commandes de 23) ; **Visuel** et **UI** = capture retenue dans `production/qa/evidence/hud-systeme/` (nom `ACHU<n>-<scène>-<ms>.png`), appareil de référence, portrait 390 pt sauf mention ; **Playtest** = rapport de séance au même endroit. Le HUD (17) n'existe pas encore : tout critère est [BLOQUÉ 17] (mention non répétée) ; [BLOQUÉ n] ajoute les autres systèmes attendus. Valeurs de départ : `DÉLAI_PANNEAU` 400 ms, `DÉLAI_FERMETURE` 500 ms, glissement 300 ms, décompte d'énergie 200 ms, jauge 300 ms, chiffre de dégâts 800 ms, affaissement 400 ms, seuil « derniers tours » 5, puces visibles 2, `EVENT_QUEUE_MAX` 256, `T_MAX` 30.*

### A. Propriété et sources (règles 1 à 7)

- **AC-HU1** (Logic, règles 1 et 5) **GIVEN** un double d'état dont tout mutateur fait échouer le test, **WHEN** le HUD traite 500 événements de chaque type (E01 à E41) et 200 changements de réglages, **THEN** zéro écriture sur le double ; il n'écrit que ses cinq possessions.
- **AC-HU2** (Logic, règle 2) **GIVEN** un lot COULEUR… puis RUINE_LUE alors que l'état a déjà `ruines_lues` = 1 et que la file est non vide, **THEN** E06 reste « 0 / 3 » jusqu'à la présentation du panneau, puis « 1 / 3 » ; deux ruines dans le même tour : « 1 / 3 » à l'ouverture du premier panneau, « 2 / 3 » à celle du second, jamais avant. [BLOQUÉ 13, 23]
- **AC-HU3** (Logic, règle 2) **GIVEN** l'énergie déjà passée de 12 à 7 dans l'état et ÉNERGIE_CHANGÉE encore dans la file, **THEN** E03 affiche « 12 » jusqu'à la consommation, puis décompte vers « 7 » en 200 ms (« 12 » à t, valeur intermédiaire à t + 100, « 7 » à t + 200) ; « MAX » à 99, jamais « 100 » ; 0 lecture directe file non vide. [BLOQUÉ 10]
- **AC-HU4** (Logic, règle 3) **THEN** revenu, score décisif, `d_ruine`, « létale », `undo_allowed` et états grisés ne sont lus que file vide, sur RESYNCHRONISER ou ÉTAT_CHARGÉ : file de 3 lots → 0 lecture ; file vidée → 1 lecture par valeur ; un seul fournisseur par valeur.
- **AC-HU5** (Logic, règle 4) **GIVEN** un double qui expose, hors l'agrégat E07, aussi une unité ennemie hors de vue, une ruine non repérée, un dormant jamais vu et la valeur de siège d'une intention hors de vue, **THEN** aucun de ces champs n'est lu ni affiché (0 accès hors vue sur 1 000 événements). [BLOQUÉ 1, 5]
- **AC-HU6** (Intégration, règle 6) **GIVEN** la file en distribution, **WHEN** « Fin du tour » est appuyé, **THEN** COMMANDES_VERROUILLÉES, état de partie identique octet pour octet, bouton grisé sans message ; aucun appel de commande dans une fonction abonnée à la file. [BLOQUÉ 23]
- **AC-HU7** (Logic, règle 5) **THEN** aperçu, « létale », portée, revenu et score viennent du fournisseur désigné, 1 appel par affichage, 0 recalcul interne ; état réel identique avant et après un aperçu. [BLOQUÉ 8, 10, 23]

### B. Catalogue des éléments (E01 à E41)

- **AC-HU8** (Logic, catalogue B) Test piloté par table, valeur nulle : E01 « TOUR — / 30 » avant le tour 1 ; E02 absent au-dessus du seuil ; E03 « 0 » ; E04 « +0 » ; E05 « Aucun revenu » ; E06 « 0 / 3 » ; E10 à E13 absentes ; E14 masquée s'il ne reste aucune ruine non lue ; E15 absente ; E16 +/− grisés aux bornes ; E17 réduit à E09 ; E21 « Aucune cible à portée » ; E24 absente à PV pleins ; E25 aucun chiffre à 0 dégât ; E28 0 rempli ; E31 « Les Gardiens restent immobiles » en IA passive ; E32 « Monter » grisé avec raison ; E33 « Drone endormi » ; E34 aucune fiche sous brouillard ; E35 anneaux en contour pour un nœud adverse mémorisé ; E39 aucune onde pour une zone sans effet.
- **AC-HU9** (Logic, E01 à E05) **THEN** E01 « TOUR n / 30 » pour n = 1, 15, 30 ; E02 apparaît à 5 tours restants et pas un tour avant (borne à confirmer), suit le seuil à 3 ou 6 ; E04 « +n » depuis `revenu` au début du tour du joueur seulement ; E05 : 1 lecture à l'ouverture, un revenu par nœud. [BLOQUÉ 3, 10]
- **AC-HU10** (Logic, E10 à E13) **THEN** E10 suit INTENTION_ANNONCÉE (+1), EXÉCUTÉE (−1), ANNULÉE (−1, croix) ; « 1 attaque annoncée » / « 2 attaques annoncées » ; E11 « Siège · 1/2 » puis « 2/2 » d'après l'événement ; E12 sur NŒUD_CAPTURÉ quand il reste 1 nœud et sur ÉTAT_CHARGÉ ; E13 naît de la tranche de rappels au TOUR_COMMENCÉ du joueur. [BLOQUÉ 9, 11, 23]
- **AC-HU11** (Logic, E14 et E15) **THEN** E14 « Ruine repérée » sans aucun caractère numérique (3, 1, 0 ruines repérées), apparaît à l'idle après UNITÉ_DÉPLACÉE ou NŒUD_CAPTURÉ qui repère une ruine ; E15 « Ruine lue · +25 tuiles » naît de RUINE_LUE id 0, sans panneau. [BLOQUÉ 5, 13]
- **AC-HU12** (Logic, E24 et E25) **THEN** jauge mise à jour en 300 ms (intermédiaire à t + 150), absente à PV pleins ; chiffre « −N » présent à t + 799, absent à t + 800 ; « −0 » jamais ; la valeur reste dans la jauge et le journal. [BLOQUÉ 6, 8]
- **AC-HU13** (Logic, E17 à E19, E22, E23, E26, E36 à E38) **THEN** E17/E18 se rafraîchissent une fois par événement (sélection, UNITÉ_TOUCHÉE, UNITÉ_SOIGNÉE, DÉPLACEMENT_ANNULÉ) ; phrase ≤ 90 caractères (refus de donnée à 91) ; E22 expose hachure, « ! », contour, motif en info-bulle, croix si annulée ; E26 débris et liseré pointillé ; E36 INCONNUE → EXPLORÉE → VISIBLE ; E37 ; E38 suit PHASE_CHANGÉE (voile ≤ 8 %). [BLOQUÉ 5, 6, 9, 15]
- **AC-HU14** (Logic, E27 à E30, E32 à E35, E39, E40) **THEN** E27 s'ouvre sur RUINE_LUE présenté (texte ≤ 140) ; E28 a N segments (5 au MVP) dont |C| remplis ; E29 apparaît à RUINE_LUE ; E30 statique, 0 lecture hors idle ; E32 à l'idle et sur NŒUD_MONTÉ ; E35 passe de 1 à 2 anneaux ; E39 rejoue l'onde ; E40 naît de RECHERCHE_TERMINÉE avec notification. [BLOQUÉ 11, 12, 13, 15, 23]
- **AC-HU15** (UI) **THEN** captures : barre E01-E08 initiale et « derniers tours » ; panneau d'unité ; nœud et dormant ; fiche de tuile et états de brouillard ; puces ; jauge et chiffre ; journal avec « Tour ennemi ». Aucun recouvrement de la carte hors grappe, texte ≥ 12 pt. [BLOQUÉ 2, 4]

### C. Boutons d'action (règle 12)

- **AC-HU16** (Logic) **THEN** E20 a toujours 3 places (Déplacer, Attaquer, Capturer / Réveiller / rien) ; un bouton impossible est grisé avec sa raison (« manque n » pour l'énergie), jamais caché, sur 12 contextes ; la place 1 devient « Annuler le déplacement » après un déplacement et redevient « Déplacer » après annulation ou autre action. [BLOQUÉ 6, 7, 23]
- **AC-HU17** (Logic + UI) **THEN** « Annuler le déplacement » est grisé avec RIEN_À_ANNULER, DÉPLACEMENT_A_RÉVÉLÉ ou AUTRE_ACTION_DEPUIS (état identique après appui) ; dans l'aperçu le bouton secondaire est « Retour » ou « Annuler l'attaque », jamais « Annuler le déplacement » ; annuler l'aperçu n'émet aucune commande ; captures des 3 états. [BLOQUÉ 23]

### D. Ordre onde → panneau (règles 13 et 21, F2)

- **AC-HU18** (Logic) **GIVEN** une onde de 800 ms, **THEN** panneau demandé à fin d'onde + 400 ms (1 200 ms après le début), jamais avant la fin ; ondes 600 / 800 / 1 000 ms → 1 000 / 1 200 / 1 400 ms ; délai 300 ou 600 → t + 300 ou t + 600 ; glissement 300 ms ; E06 et E28 inchangés avant l'ouverture. [BLOQUÉ 13, 15]
- **AC-HU19** (Logic) **GIVEN** un panneau ouvert à T, **THEN** « Continuer » à T + 499 ms ignoré, à T + 500 ms il ferme ; bornes 300 et 800 ; pour une onde de 800 ms, fermeture possible à 1 700 ms après le début de l'onde ; panneau non repliable. [BLOQUÉ 13]
- **AC-HU20** (Logic) **GIVEN** une zone sans tuile gagnée, **THEN** aucune onde, panneau 400 ms après la fin de la lecture, ligne « Zone recolorée » masquée ; E15 remplace le panneau si id 0. [BLOQUÉ 13, 15]
- **AC-HU21** (Intégration) **THEN** ruine hors du rectangle : la caméra se recentre une seule fois, avant le début de l'onde (0 fois si dans le rectangle) ; commandes verrouillées en LECTURE, défilement et zoom actifs ; deux ruines dans le même tour : second panneau seulement après « Continuer » du premier ; jamais deux animations de HUD simultanées. [BLOQUÉ 4, 13, 23]
- **AC-HU22** (Visuel + UI) **THEN** captures : onde terminée, t + 399 ms (pas de panneau), t + 400 ms (glissement), t + 700 ms (panneau entier, pastille « 1 / 3 », barre à jour) ; cas sans onde. [BLOQUÉ 13, 15]

### E. Attaque et verrou (règle 14)

- **AC-HU23** (Logic) **THEN** ordre sur horloge injectée : ATTAQUE_RÉSOLUE, trait (200 à 350 ms), UNITÉ_TOUCHÉE cible à 350 ms, attaquant à 650 ms (décalages depuis ATTAQUE_RÉSOLUE), puis UNITÉ_DÉTRUITE (gris puis affaissement 400 ms) ; verrou ≈ 1,5 s (tolérance [PROP] 1,3 à 1,7 s), COMMANDES_VERROUILLÉES pour tout appui, relâché à la fin. [BLOQUÉ 8]
- **AC-HU24** (Visuel) **THEN** captures à t + 200, 350, 650, 1 050, 1 500 ms ; en animations réduites mêmes étapes et ordre, trait fixe 150 ms, chiffres fixes 800 ms. [BLOQUÉ 8]

### F. Journal, reprise, rappels (règles 9, 15 à 17, 22)

- **AC-HU25** (Logic) **GIVEN** 5 actions ennemies dont 2 hors de vue, **THEN** 3 lignes précises, compteur « n / 3 » jamais « n / 5 », aucune action hors de vue ne révèle type, tuile ou acteur ; IA passive : « Les Gardiens restent immobiles ». [BLOQUÉ 5, 9]
- **AC-HU26** (Logic + Intégration) **THEN** un lot par action ennemie, présenté entièrement avant le suivant, aux vitesses Normale > Rapide > Instantanée (0 animation) ; « Revoir » rejoue le tampon de la phase courante seulement ; le tampon n'est jamais sauvegardé (octets identiques avec ou sans). [BLOQUÉ 9, 16]
- **AC-HU27** (Intégration) **GIVEN** 40 événements en cours ou une file > 256, **WHEN** RESYNCHRONISER, **THEN** animations annulées, tout relu depuis l'état, aucune onde, état identique octet pour octet ; un panneau ouvert reste ouvert ; un panneau pas encore ouvert est perdu (fragment accessible par le glyphe « lu » et la chronique) ; « Revoir » grisé. [BLOQUÉ 13, 22, 23]
- **AC-HU28** (Intégration) **GIVEN** une sauvegarde chargée en plein tour du joueur, **THEN** aucune onde ; vue par 5 puis octet de couleur par 15 ; REPOS sans sélection ni panneau ni puce d'événement ; caméra sur l'unité du joueur d'identifiant le plus bas ; « Annuler le déplacement » grisé RIEN_À_ANNULER ; menace, dernier nœud, ruine repérée reconstruits ; « Revoir » grisé. [BLOQUÉ 5, 15, 16]
- **AC-HU29** (Intégration, règle 22) **GIVEN** une phase ennemie où le joueur perd 1 unité, 2 tuiles et voit 1 intention annulée, puis sauvegarde et chargement, **THEN** la tranche de rappels redessine débris, 2 liserés, croix et puce « Drone perdu » ; elle est encore présente pendant le tour du joueur suivant et vidée à la fin de ce tour (pas à son début) ; un chargement au tour d'après ne redessine rien ; captures avant et après chargement identiques. [BLOQUÉ 1, 15, 16]

### G. Score décisif (règle 23)

- **AC-HU30** (Logic) **THEN** E07 « Victoire : a contre b » = formule 1 de 3 avec F = 0 : les tuiles recolorées par une ruine comptent, `w_f` jamais ajouté ni affiché ; a et b exacts pour les deux camps, sans estimation ; mise à jour à l'idle de début de tour. [BLOQUÉ 3, 13]
- **AC-HU31** (Intégration) **GIVEN** 200 parties simulées de graines distinctes, **THEN** le dernier E07 avant la fin désigne le même vainqueur que le résultat final de 3 (0 contradiction sur 200, égalités et ruine lue au dernier tour comprises). [BLOQUÉ 3, 13]

### H. Priorité des puces (règle 20)

- **AC-HU32** (Logic) **GIVEN** 3 puces candidates (menace, perte, ruine repérée), **THEN** les 2 emplacements affichent menace puis perte, compteur « +1 » pour la troisième ; ordre menace (siège compris), dernier nœud, perte, ruine vérifié sur toutes les paires et tous les triplets ; « DERNIERS TOURS » ne prend jamais d'emplacement ; une perte repliée reste visible sur la carte et dans le journal ; une puce dure jusqu'à la fin du tour du joueur. [BLOQUÉ 9, 11, 13]
- **AC-HU33** (UI) **THEN** captures à 0, 1, 2, 3 puces candidates : jamais plus de 2 visibles, compteur « +n » à 3, puce de ruine sans chiffre. [BLOQUÉ 9, 11, 13]

### I. Budget visuel (règle 19, F1, F3)

- **AC-HU34** (Logic, F1) **THEN** portrait 358 pt, 8 colonnes → 4 475 centièmes (44,75 pt) ; paysage 436 pt, 12 colonnes → 3 633 (36,33 pt) ; portrait à 12 colonnes → 2 983, refusé (< 3 100) ; au zoom minimal, au plus 11 colonnes en portrait (3 254). [BLOQUÉ 4]
- **AC-HU35** (UI) **THEN** surface HUD mesurée sur appareil de référence ≤ 45 % en tour du joueur (cible 40 % portrait, ≈ 43 % paysage) et ≤ 55 % en états verrouillés (LECTURE, TOUR_ENNEMI, RÉSOLUTION) ; mesures reportées pour REPOS, SÉLECTION d'unité, CIBLAGE, LECTURE, TOUR_ENNEMI ; ≤ 9 éléments actifs ; zone d'alerte à hauteur réservée en portrait sans déplacer le rectangle de carte ; à refaire avec E07. [BLOQUÉ 4]
- **AC-HU36** (UI) **THEN** « Fin du tour », les puces (zone tactile étendue à 48 dp même si dessinées à environ 30 pt) et la grappe (3 × 48 dp) ≥ 48 dp (44 pt iOS) avec 8 dp d'écart ; seule la grappe recouvre la carte ; captures annotées portrait et paysage. [BLOQUÉ 4]

### J. Accessibilité (règles 24 à 28)

- **AC-HU37** (Logic) **THEN** animations réduites : onde, réveil (état éveillé direct, son conservé), affaissement et glissement affichent l'état final en 0 ms ; recentrage instantané ; pulsation de l'œil coupée ; chiffres fixes 800 ms ; trait 150 ms ; ordre cible puis riposte conservé. [BLOQUÉ 22]
- **AC-HU38** (Logic) **THEN** sur une séquence de 10 s (attaque, onde, tour ennemi de 8 actions, 3 vitesses), aucune fenêtre glissante de 1 s ne contient plus de 3 flashs au sens de WCAG 2.3.1 (échec à 4), décompte d'énergie et jauges exemptés ; en vitesse Instantanée, fusion respectant la limite ou état final direct.
- **AC-HU39** (UI) **THEN** palette alternative : faction, ennemi et gris non revendiqué changent de teinte, menace et ruines inchangées ; le sens passe par la forme (hexagone / losange ; hachure + « ! » contre arche + lueur) ; « létale » et intention de formes distinctes ; compteur de siège en texte ; capture en niveaux de gris lisible. [BLOQUÉ 9, 13]
- **AC-HU40** (UI) **THEN** ≥ 12 pt à 100 % ; à 150 % le panneau de fragment défile, la ligne de stats passe sur 2 lignes, les puces s'enroulent, rien de coupé ni superposé ; citations ≥ 15 pt sans animation lettre par lettre ; chaînes de 90 et 140 caractères tiennent avec 40 % de marge.
- **AC-HU41** (Logic) **THEN** puces présentes jusqu'à la fin du tour du joueur (horloge avancée de 120 s) ; panneau de fragment fermé seulement par « Continuer » ; seul le chiffre de dégâts expire ; chaque événement porteur d'information a un équivalent visuel ; haptique jamais seul canal ; chaque bouton et puce a un nom accessible non vide.
- **AC-HU42** (Logic + UI) **GIVEN** un glyphe « lu » sur une tuile de 36 pt (< 48 dp), **THEN** « Fragments de la partie » (menu pause) et « Relire » (panneau) rouvrent le même fragment (même id, même texte) ; pool épuisé : rien ne s'ouvre ; au plus 2 appuis depuis REPOS ; captures du menu pause et du panneau. [BLOQUÉ 13, 22]

- **AC-HU43** (UI) **THEN** contraste ≥ 4,5:1 mesuré sur chaque fond réel (fond violet du tour ennemi et palette alternative compris) pour tout texte du HUD ; rapport de mesures conservé. [BLOQUÉ 17]

### Captures retenues exigées (toutes [BLOQUÉ 17])

AC-HU15 (sept jeux, portrait 390 pt), AC-HU17 (3 états des places), AC-HU22 (onde terminée, t + 399, t + 400, t + 700 ms, cas sans onde), AC-HU24 (attaque, normal et réduit), AC-HU29 (avant et après chargement), AC-HU33 (0 à 3 puces), AC-HU35 (surfaces mesurées par état), AC-HU36 (zones tactiles annotées), AC-HU39 (palette alternative et niveaux de gris), AC-HU40 (100 % et 150 %), AC-HU42 (menu pause, panneau avec « Relire »). Playtest optionnel (AC-HU44, seuil à définir) : un testeur retrouve sans aide, en moins de 10 s, la raison d'un bouton grisé et la perte du dernier tour ennemi.

## Open Questions

| Question | Propriétaire | Échéance | Statut |
|---|---|---|---|
| Budget de 9 éléments actifs contre 8 de `hud.md` : surface à remesurer avec E07 | ux-designer | `/ux-review` suivant | Ouverte |
| 600 ms par action ennemie (hud.md) contre environ 1,45 s pour une attaque (8) | ux-designer, game-designer | Prototype | Ouverte |
| Revenu « +n » rafraîchi au début du tour (10, Game Feel) ou dès la capture (AC-N3) | game-designer | Revue de 10 | Ouverte |
| Chemin alternatif de relecture (menu pause ou panneau) | ux-designer | Spécification de l'écran | Posé |
| Vue minimale de la chronique : 13 ou 18 | creative-director | Revue de 22 | Ouverte |
| Écran des protocoles : `design/ux/protocoles.md` | ux-designer | Avant l'implémentation de 12 | À créer |
