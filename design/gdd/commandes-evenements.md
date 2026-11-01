# Commandes et événements

> **Status**: In Design
> **Author**: user + Claude (systems-designer, gameplay-programmer, engine-programmer)
> **Last Updated**: 2026-10-29
> **Last Verified**: 2026-10-29
> **Implements Pillar**: Pilier 4 « La puissance se mérite » (une seule voie pour les règles, aperçu = résultat) ; pilier 3 « Lisible comme Polytopia » (raison de chaque refus)
> **Creative Director Review (CD-GDD-ALIGN)**: REVISED 2026-10-29 — CONCERNS (bouton d'annulation caché contre « jamais caché » ; règle 6 contre règle 3 pour une unité cachée ; annulation après une ruine non testée) corrigées : bouton grisé avec sa raison, embuscade décidée, AC-15 complété

## Summary

Les commandes et événements sont la seule porte d'entrée des règles en partie : chaque
action du joueur, de l'IA ou du déroulé du tour est une commande validée, appliquée par
les fonctions des systèmes propriétaires, puis traduite en événements que le HUD et
l'audio jouent à leur rythme. Pour le joueur, c'est l'équité : l'IA obéit aux mêmes
règles, chaque refus dit sa raison, l'aperçu est le résultat, et un déplacement raté
s'annule tant qu'il n'a rien révélé. Ce système possède aussi le bus et la liste des
événements.

> **Quick reference** — Layer: `Core` · Priority: `MVP` · Key deps: `Modèle d'état de partie`

## Overview

Les commandes et événements sont la seule porte d'entrée des règles pendant une partie.
Toute action, qu'elle vienne du doigt du joueur ou de l'IA, est une **commande** :
déplacer, attaquer, capturer, réveiller, rechercher, finir le tour, annuler le dernier
déplacement. Une commande est d'abord **validée** (est-elle permise, ici, maintenant,
pour cette faction ?), puis **appliquée** en appelant les fonctions des systèmes
propriétaires des données (`design/gdd/modele-etat-partie.md`, règles 2 et 3), et enfin
elle **publie des événements** (une unité a bougé, une tuile a changé de couleur, une
attaque a été annoncée) que le HUD et l'audio jouent à leur rythme. Le joueur ne voit
jamais une commande ; il en sent trois effets. Un bouton grisé dit pourquoi il l'est
(pilier 3, « Lisible comme Polytopia »). L'aperçu d'une attaque calcule exactement ce
que la commande fera, parce que l'aperçu et la commande passent par la même validation
(pilier 4). Et un déplacement fait par erreur peut être annulé tant qu'il n'a rien
révélé (décision du 2026-10-29). Sans ce système, le joueur et l'IA auraient chacun leur
chemin dans les règles, et un écart entre les deux suffirait à rendre l'IA « tricheuse »
aux yeux du joueur. Il répond aux points 5 (couche de commandes commune) et 8 (un seul
propriétaire du bus d'événements) de TD-SYSTEM-BOUNDARY.

*Le mécanisme technique (signaux de Godot ou file d'attente, objets ou données pour les
commandes) relève d'un ADR, pas de ce document.*

## Player Fantasy

*Système indirect, décrit en un paragraphe : un grand cadrage reprendrait la confiance
du GDD de l'état de partie ou grossirait un système que le joueur ne voit pas.*

Ce système doit rester invisible ; le joueur n'en sent que l'équité. L'IA obéit
exactement aux mêmes règles que lui, et chaque refus dit sa raison. Un faux pas du
doigt se reprend tant qu'il n'a rien révélé : on juge ses choix, pas ses maladresses.

**Émotion visée** : une confiance tranquille. Le joueur ose tenter un coup, sans crainte
d'une règle cachée ni d'un doigt qui glisse.

**Moment d'ancrage.** Le joueur touche « Attaquer » : le bouton est grisé, avec
« Hors de portée : 3 cases ». Il avance un drone ; au tour suivant, il voit l'IA arrêtée
par cette même portée. Moment secondaire : un déplacement raté vers un brouillard vide
s'annule d'un seul appui.

*Cadrage proposé par le creative-director (piliers 4 et 3). Les mots « mémoire » et
« tient parole » sont évités, réservés au pilier 2 et au GDD de l'état de partie.*

## Detailed Design

### Core Rules

*Conçu avec systems-designer (principal) et gameplay-programmer (faisabilité moteur et
gameplay). Le comportement des signaux de Godot (ordre d'appel, réentrance) n'est pas
couvert par `docs/engine-reference/godot/` : NOT SOURCEABLE.*

#### Commandes du MVP

Émetteurs : **J** joueur, **IA** faction de l'IA, **SYS** commande interne émise par
les tours (3) ou l'IA (9), que le joueur ne voit jamais.

| Commande | Émetteur | Paramètres (identifiants et tuiles) | Principales raisons de refus |
|---|---|---|---|
| DÉPLACER | J, IA | unité, tuile d'arrivée | PAS_VOTRE_TOUR, UNITÉ_INCONNUE, UNITÉ_ENDORMIE, DÉJÀ_DÉPLACÉE, HORS_DE_PORTÉE, CASE_BLOQUÉE, PARTIE_TERMINÉE |
| ATTAQUER | J, IA | attaquant, cible | DÉJÀ_AGI, CIBLE_HORS_DE_PORTÉE, CIBLE_NON_VISIBLE, CIBLE_NON_HOSTILE, AUCUNE_INTENTION (émetteur IA hors d'une exécution d'intention : `ia-ennemie.md`, règle 7) |
| MONTER_NŒUD | J, IA | nœud (la commande vaut pour le joueur comme pour l'IA) | six codes de refus du GDD des nœuds (NIVEAU_MAX, DÉJÀ_MONTÉ, NŒUD_ACQUIS_CE_TOUR, ÉNERGIE_INSUFFISANTE…, `noeuds.md`, Edge Cases) ; événement NŒUD_MONTÉ |
| CAPTURER | J, IA | unité | PAS_SUR_UN_NŒUD, NŒUD_DÉJÀ_POSSÉDÉ, DÉJÀ_AGI, AUCUNE_INTENTION (émetteur IA hors d'une exécution d'intention) |
| RÉVEILLER | J, IA | unité qui réveille, drone endormi | AUCUN_DRONE_ADJACENT, ÉNERGIE_INSUFFISANTE (besoin, disponible), MEUTE_COMPLÈTE |
| RECHERCHER | J (l'IA reçoit ses protocoles par un calendrier en données : `arbre-protocoles.md`, règle 15) | protocole | Dans l'ordre : PARTIE_TERMINÉE / PAS_VOTRE_TOUR, PROTOCOLE_INCONNU, PROTOCOLE_ACQUIS, RECHERCHE_EN_COURS, PRÉREQUIS_MANQUANT, ÉNERGIE_INSUFFISANTE (besoin, disponible) |
| FINIR_LE_TOUR | J | — | PAS_VOTRE_TOUR, COMMANDES_VERROUILLÉES |
| ABANDONNER | J | — | PARTIE_TERMINÉE (après confirmation dans le menu pause, 18 ; `design/gdd/tours-conditions-victoire.md`) |
| ANNULER_LE_DÉPLACEMENT | J | — | RIEN_À_ANNULER, DÉPLACEMENT_A_RÉVÉLÉ, AUTRE_ACTION_DEPUIS |
| COMMENCER_LE_TOUR, ANNONCER_LES_INTENTIONS, EXÉCUTER_UNE_INTENTION | SYS | faction ou intention | — (contrôlées par 3 et 9) |
| VALIDER_LA_LECTURE | SYS | id de la ruine, faction | — (contrôlée par 13 : l'entrée du journal doit être « en attente » ; appliquée par la couche des commandes seulement, après une écriture réussie du profil) |

La **lecture d'une ruine n'est pas une commande** : elle a lieu à la fin d'un
DÉPLACEMENT sur la ruine (`design/ux/hud.md`, § 5), dans l'application de cette
commande, avec la séquence de la règle 10 de `design/gdd/modele-etat-partie.md` : l'application rend
l'effet « enregistrer un fragment » ; la couche des commandes l'applique au profil et, si
l'écriture réussit, applique la commande interne VALIDER_LA_LECTURE.

#### Règles

0. **Préfixe commun de refus** (ADR-0004), dans cet ordre fixe : réentrance (COMMANDES_VERROUILLÉES, erreur en développement), PARTIE_TERMINÉE, PAS_VOTRE_TOUR, verrou du joueur (COMMANDES_VERROUILLÉES), puis les vérifications propres à la commande. PARTIE_TERMINÉE et PAS_VOTRE_TOUR sont des lectures d'état, pas du `CommandGate` ; ABANDONNER est permis en phase ennemie. `command_id` d'un lot = la révision de l'état (un seul numéro).
1. **Valider, puis appliquer.** Chaque commande passe par « valider (état, faction,
   commande) », qui rend un résultat, puis, seulement si elle est permise, par
   « appliquer ». Aucune autre fonction ne modifie l'état en partie
   (`design/gdd/modele-etat-partie.md`, règle 3).
2. **Résultat de validation.** Un résultat est « permise », ou « refusée » avec un code
   de raison et des paramètres entiers (par exemple ÉNERGIE_INSUFFISANTE avec le besoin
   et le disponible). Ce système ne produit **aucun texte** : le HUD (17) traduit le
   code en phrase. Les vérifications s'enchaînent dans un ordre fixe et la première qui
   échoue est rendue, pour que le message soit toujours le même dans la même situation.
3. **La validation est complète, l'application ne peut pas échouer.** La validation
   lit sans écrire et vérifie tout ce dont l'application a besoin. Une application qui
   rencontre un problème révèle un bogue (signalé par la validation des invariants de
   l'état, règle 14 du GDD 1), jamais un cas de jeu.
4. **Tout ou rien.** Une commande s'applique entièrement ou pas du tout ; l'état n'est
   jamais observé, sauvegardé ni copié au milieu d'une commande. L'écriture du profil
   qui suit la lecture d'une ruine a lieu après l'application et elle est rejouable
   (règle 10 du GDD 1).
5. **Seules les fonctions des propriétaires écrivent.** L'application appelle les
   fonctions d'écriture des systèmes propriétaires (règle 2 du GDD 1). Ce système
   n'écrit lui-même que sa tranche, le journal des commandes : la révision de l'état.
6. **Une validation par faction, sur sa vue.** Une commande est validée contre la vue
   de la faction qui l'émet, filtrée par le brouillard (règle 11 du GDD 1). **Un refus
   ne révèle jamais une information cachée** : une validation ne peut s'appuyer que sur
   ce que la faction voit. **Embuscade** (décision du 2026-10-29) : un déplacement dont
   le chemin ou l'arrivée rencontre une unité ennemie cachée est **permis** ; à
   l'application, l'unité s'arrête sur la dernière tuile libre avant l'ennemi, qui est
   révélé. Cela compte comme une révélation (pas d'annulation). L'application ne peut
   donc pas échouer (règle 3), et le brouillard garde sa surprise (pilier 5). L'IA est
   validée et prise en embuscade exactement comme le joueur.
7. **L'aperçu est la commande sur une copie.** Un aperçu valide la commande, puis
   l'applique sur une copie de l'état, par le même code. L'application **rend** la
   liste ordonnée de ses événements ; l'aperçu de combat du HUD lit les dégâts, la
   riposte, les PV restants et les destructions dans cette liste. Le combat étant
   déterministe (règle 7 du GDD 1), l'aperçu est le résultat.
8. **Événements après la commande, jamais pendant.** Les événements d'une commande sont
   publiés en un seul lot, après son application complète, et portent la révision de
   l'état. Leur ordre est celui des écritures, collections parcourues par identifiant
   croissant (règle 8 du GDD 1). **Seule la couche des commandes publie** : les fonctions
   de règle rendent leurs événements et leurs effets sous forme de valeurs, et une
   simulation les jette (règles 3 et 9 du GDD 1). L'aperçu construit quand même la liste,
   que le HUD lit (règle 7) ; les simulations de l'IA peuvent ne pas la construire, pour
   rester peu coûteuses.
9. **Les événements ne portent que de la présentation.** Quand un événement est publié,
   l'état est déjà final. Aucun événement ne porte une information absente de l'état :
   perdre tous les événements en attente ne change jamais le cours de la partie.
10. **Une file, lue à son rythme.** Les événements vont dans une file que le HUD (17) et
    l'audio (20) lisent dans l'ordre, au rythme de leurs animations. La file n'est
    **jamais sauvegardée** : après une pause, un arrêt ou un chargement, le HUD se
    reconstruit depuis l'état. La file est bornée (Tuning Knobs) ; si elle déborde, elle
    est remplacée par un seul événement « resynchroniser depuis l'état ».
11. **Pas de commande pendant la distribution.** Un auditeur d'événements n'émet jamais
    de commande : une commande reçue pendant la distribution d'un lot est refusée avec
    COMMANDES_VERROUILLÉES (et signalée comme erreur en version de développement). Les
    commandes du joueur ne viennent que des contrôles (4) ; celles de l'IA et les
    commandes internes, que du déroulé du tour (3, 9).
12. **Verrouillage des commandes du joueur.** Une commande d'une faction est refusée avec
    PAS_VOTRE_TOUR hors de sa phase, et avec PARTIE_TERMINÉE après la fin de la partie.
    Une commande du joueur est refusée avec COMMANDES_VERROUILLÉES pendant le verrou de
    résolution d'une attaque du HUD (durée `ATTACK_LOCK_MS` = 1 600 ms, valeur unique en données,
    propriété de ce document ; l'animation dure environ 1,5 s et le verrou la dépasse de 100 ms) ; ce verrou ne touche ni l'IA ni les commandes internes.
13. **Les changements de tour passent aussi par des commandes.** Le début d'un tour, la
    publication des intentions de l'IA et l'exécution d'une intention sont des
    commandes internes : chacun reçoit une révision et ses événements, comme toute
    autre modification de l'état.
14. **Révision.** La révision de l'état augmente de 1 à chaque commande appliquée,
    interne et annulation comprises ; elle ne recule jamais. Une commande refusée ne la
    change pas. Elle sert aussi d'ordre aux événements et aux tests.
15. **Annulation du dernier déplacement** (décision du 2026-10-29). Avant chaque
    DÉPLACEMENT du joueur, ce système garde un **instantané** de l'état (une copie,
    hors de l'état). L'annulation n'est permise que si les trois conditions suivantes
    sont vraies : le dernier déplacement n'a rien révélé (ni tuile jamais vue, ni unité
    ennemie qui devient visible) et n'a lu aucune ruine ; aucune autre commande n'a été
    appliquée depuis (révision = révision de l'instantané + 1) ; la partie n'a pas été
    rechargée depuis. L'annulation remet l'état à l'instantané, fait avancer la révision
    et publie DÉPLACEMENT_ANNULÉ. Un déplacement qui a révélé quelque chose, toute autre
    commande appliquée (y compris de l'IA ou interne) et un chargement suppriment
    l'instantané **en gardant le motif**, qui donne le code du refus :
    DÉPLACEMENT_A_RÉVÉLÉ, AUTRE_ACTION_DEPUIS ou RIEN_À_ANNULER (aucun déplacement, ou
    chargement). L'instantané n'est jamais sauvegardé.
16. **Rejouable.** Un état initial, sa graine et la liste ordonnée des commandes
    appliquées redonnent toujours un état égal (égalité profonde, règle 13 du GDD 1),
    sur n'importe quel appareil. Cette liste existe dans les tests et les journaux de
    développement, **jamais dans l'état** (règle 12 du GDD 1). Elle porte une version de
    format ; un rejeu d'une liste d'une autre version est refusé avec
    FORMAT_INCOMPATIBLE.
17. **Commandes en données pures.** Une commande est une donnée simple : un type, la
    faction qui l'émet, des paramètres entiers et des identifiants, sans référence à un
    Node, un Callable ou un RID. Elle se sérialise sans perte.

#### Événements du MVP

Paramètres : identifiants et tuiles seulement.

| Événement | Paramètres | Écouté par |
|---|---|---|
| UNITÉ_DÉPLACÉE | unité, départ, arrivée, destination demandée (distincte de l'arrivée en cas d'arrêt par embuscade) | 17, 20 |
| TUILES_RÉVÉLÉES | faction, tuiles | 17 |
| ATTAQUE_RÉSOLUE, puis UNITÉ_TOUCHÉE (cible, puis riposte) | attaquant, cible ; unité, dégâts, PV restants | 17, 20 |
| UNITÉ_DÉTRUITE | unité, tuile, par | 17, 20 |
| NŒUD_CAPTURÉ | nœud, faction, ancien propriétaire | 17, 20 |
| PROPRIÉTAIRE_DES_TUILES_CHANGÉ | tuiles, ancien, nouveau | 17 |
| COULEUR_DES_TUILES_CHANGÉE | cause (CAPTURE, MONTÉE, RUINE, ÉLIMINATION, RÉVÉLATION), tuile source, groupes `(couleur_avant, couleur_après, mode, tuiles)`, source effective (F7) et drapeau VISIBLE par tuile changée ; un seul par commande, jamais vide (`recoloration-monde.md`, règle 18 ; ADR-0001) | 17 |
| DRONE_RÉVEILLÉ | unité, par | 17, 20 |
| ÉNERGIE_CHANGÉE | faction, avant, après | 17 |
| RECHERCHE_COMMENCÉE, RECHERCHE_TERMINÉE | faction, protocole | 17, 20 |
| RUINE_LUE | ruine, faction, identifiant du fragment (0 si le pool est épuisé) | 17, 20 |
| UNITÉ_SOIGNÉE | unité, PV avant, PV après | 17 |
| NŒUD_MONTÉ | nœud, niveau avant, niveau après | 17, 20 |
| SIÈGE_ANNONCÉ (valeur portée par INTENTION_ANNONCÉE) | nœud, compte 1 ou 2 sur 2 (`ia-ennemie.md`, règle 13) | 17 |
| INTENTION_ANNONCÉE, INTENTION_EXÉCUTÉE, INTENTION_ANNULÉE | intention (auteur, cible, tuile de l'auteur, tuile de la cible, type, motif TRAQUE / REPRÉSAILLE / CAPTURE / DÉFENSE), raison d'annulation (AUTEUR_DÉTRUIT, CIBLE_DÉTRUITE, CIBLE_DÉPLACÉE, HORS_DE_PORTÉE, UNITÉ_ABSENTE, UNITÉ_DÉTRUITE, NŒUD_DÉJÀ_À_L'IA) | 17, 20 |
| TOUR_COMMENCÉ, TOUR_TERMINÉ, PHASE_CHANGÉE | tour, faction, phase | 17, 20 ; 16 (TOUR_TERMINÉ) |
| FACTION_ÉLIMINÉE, PARTIE_TERMINÉE | faction ; statut | 17, 20 ; 16, 18 |
| DÉPLACEMENT_ANNULÉ | unité, départ, arrivée | 17, 4 |
| ÉTAT_CHARGÉ (publié par 16) | — | 17, 4 |
| RESYNCHRONISER | — | 17 |

La recoloration (15) et le brouillard (5) ne passent pas par la file : l'application de
la commande appelle directement leurs fonctions, et leurs changements arrivent à la
présentation par les événements ci-dessus.

### States and Transitions

**Une commande**

| État | Depuis | Ce qui se passe |
|---|---|---|
| REÇUE | — | Commande émise par 4, 9 ou 3 |
| REFUSÉE (fin) | REÇUE | Le résultat est rendu ; aucune révision, aucun événement |
| VALIDÉE | REÇUE | La validation a réussi |
| APPLIQUÉE | VALIDÉE | Les fonctions des propriétaires ont écrit ; révision + 1 ; liste d'événements rendue |
| PUBLIÉE (fin) | APPLIQUÉE | Le lot d'événements entre dans la file (jamais pour une simulation ni un aperçu) |

Un aperçu s'arrête à APPLIQUÉE, sur une copie. Il n'existe aucun retour en arrière après
APPLIQUÉE, sauf ANNULER_LE_DÉPLACEMENT, qui est elle-même une nouvelle commande.

**L'instantané d'annulation**

| État | Depuis | Déclencheur |
|---|---|---|
| AUCUN | Début de partie, chargement, ou suppression | — |
| ARMÉ | AUCUN, ARMÉ | DÉPLACEMENT du joueur appliqué sans rien révéler (un nouvel instantané remplace l'ancien) |
| AUCUN (avec motif : révélé, autre action, chargement, annulé) | ARMÉ | Déplacement qui révèle, toute autre commande appliquée, chargement, ou annulation effectuée |

### Interactions with Other Systems

Seul l'état de partie (1) a un GDD : les autres lignes sont des **contrats provisoires**.

| # | Système | Ce que ce système fait avec lui |
|---|---|---|
| 1 | Modèle d'état de partie | Lit tout pour valider ; écrit seulement la révision ; applique les fonctions des propriétaires |
| 3 | Tours et conditions de victoire | Fournit la phase et les règles du tour ; ses changements de tour arrivent en commandes internes |
| 4 | Contrôles tactiles | Émet les commandes du joueur ; reçoit les résultats (pour griser) et les événements |
| 6 | Unités drones | Déplacement, drapeaux, réveil et PV, par ses fonctions |
| 7 | Réveil des drones | Valide RÉVEILLER, puis appelle 6 et « dépenser » de 10 |
| 8 | Combat | Calcule ATTAQUER (fonction pure), puis écrit les PV par 6 |
| 9 | IA à intentions | Émet ses commandes ; ses intentions passent par ANNONCER et EXÉCUTER |
| 10 | Énergie | « Dépenser » pour RÉVEILLER et RECHERCHER |
| 11 | Nœuds | Écriture du territoire pour CAPTURER |
| 12 | Arbre de protocoles | Écritures de RECHERCHER |
| 13 | Ruines et fragments | Lecture d'une ruine à la fin d'un DÉPLACEMENT |
| 15 | Recoloration | Appelée par l'application après un changement de propriétaire |
| 16 | Sauvegarde automatique | Sauvegarde après TOUR_TERMINÉ, jamais au milieu d'une commande ; publie ÉTAT_CHARGÉ |
| 17 | HUD | Résultats de validation (boutons grisés, raison), aperçu, événements |
| 20 | Audio | Événements seulement |

## Formulas

*Proposées par systems-designer. Les dégâts et les coûts d'énergie appartiennent au
combat (8) et à l'énergie (10). Les valeurs marquées « provisoire » sont à mesurer sur
l'appareil de référence.*

### 1. Révision

The revision formula is defined as:

`rev' = rev + (appliquée ? 1 : 0)`

**Variables:**
| Variable | Type | Range | Source | Description |
|----------|------|-------|--------|-------------|
| rev | int | 0..2³¹−1 | calculated (état, journal des commandes) | Révision actuelle |
| appliquée | booléen | — | calculated | La commande a été appliquée (commandes internes et annulation comprises) |

**Output Range:** ne baisse jamais.
**Example:** rev = 41, DÉPLACER refusée → 41 ; appliquée → 42.

### 2. Annulation permise

The undo_allowed formula is defined as:

`undo_allowed = armé ∧ ¬révélé ∧ ¬ruine_lue ∧ (rev = rev_instantané + 1)`

**Variables:**
| Variable | Type | Range | Source | Description |
|----------|------|-------|--------|-------------|
| armé | booléen | — | calculated | L'instantané est ARMÉ (un chargement le supprime) |
| révélé, ruine_lue | booléens | — | calculated | Le dernier déplacement a révélé une tuile ou une unité ennemie, ou a lu une ruine |
| rev_instantané | int | ≥ 0 | calculated | Révision au moment de l'instantané |

**Output Range:** vrai ou faux.
**Example:** rev_instantané = 50, rev = 51 → vrai ; après une attaque, rev = 52 → faux.

### 3. Budget d'une commande pour l'IA

The t_cmd_max formula is defined as:

`t_cmd_max = T_ai × f_cmd / C − t_clone`

**Variables:**
| Variable | Type | Range | Source | Description |
|----------|------|-------|--------|-------------|
| T_ai | int (ms) | 2000 | constant (`design/gdd/modele-etat-partie.md`, formule 5) | Budget d'un tour d'IA |
| f_cmd | int (%) | 30..60 (provisoire : 50) | constant | Part du budget consacrée aux aperçus de commandes |
| C | int | 200..2000 (provisoire : 2000, à mesurer) | calculated | Commandes candidates évaluées par tour d'IA |
| t_clone | ms | à mesurer (provisoire : 0,2) | calculated (GDD 1, formule 5) | Durée d'une copie de l'état |

**Output Range:** durée maximale pour valider puis appliquer une commande sur
l'appareil de référence. Si le résultat est ≤ 0, le budget ne tient pas : l'IA doit
évaluer moins de candidates (C).
**Example:** 2000 × 50 % / 2000 − 0,2 = **0,3 ms** par commande.

### 4. Débordement de la file d'événements

The queue_overflow formula is defined as:

`débordement = (len + B) > Q_max`, avec `Q_max ≥ 2 × B_max`

**Variables:**
| Variable | Type | Range | Source | Description |
|----------|------|-------|--------|-------------|
| len | int | 0..Q_max | calculated | Événements en attente |
| B | int | 1..B_max | calculated | Taille du lot qui arrive |
| Q_max | int | 256 (provisoire) | data file | Borne de la file |
| B_max | int | à mesurer | calculated | Plus gros lot possible (pire cas : une capture qui recolore toute une zone) |

**Output Range:** vrai ou faux. En cas de débordement, la file est vidée et ne contient
plus qu'un événement RESYNCHRONISER (règle 10).
**Example:** len = 250, B = 12 → 262 > 256 → resynchronisation.

### 5. Réponse à un appui

The t_input formula is defined as:

`t_input = t_validate + t_preview + t_clone ≤ T_frame`

**Variables:**
| Variable | Type | Range | Source | Description |
|----------|------|-------|--------|-------------|
| t_validate | ms | à mesurer | calculated | Validation de la commande |
| t_preview | ms | à mesurer | calculated | Application sur la copie (aperçu) |
| t_clone | ms | à mesurer | calculated (GDD 1, formule 5) | Copie de l'état |
| T_frame | ms | 33 | data file | Une image à 30 images par seconde (cible du concept) |

**Output Range:** un aperçu et une raison de refus s'affichent dans l'image qui suit
l'appui.
**Example:** 0,1 + 0,3 + 0,2 = 0,6 ms, très en dessous de 33 ms.

## Edge Cases

*Proposés par systems-designer. « Propriétaire » indique le GDD qui doit reprendre le
cas.*

### Cas propres aux commandes

- **Si une commande désigne une unité détruite plus tôt** : refusée avec UNITÉ_INCONNUE.
  Les identifiants ne sont jamais réutilisés (formule 3 du GDD 1).
- **Si deux commandes arrivent pour la même unité dans la même image** (double appui) :
  elles sont traitées dans l'ordre, et la seconde est validée sur l'état laissé par la
  première, donc refusée avec DÉJÀ_DÉPLACÉE. Le filtrage des doubles appuis appartient
  aux contrôles (4).
- **Si un déplacement rencontre une unité ennemie cachée** (embuscade, règle 6) :
  l'unité s'arrête sur la dernière tuile libre avant l'ennemi, l'ennemi est révélé
  (TUILES_RÉVÉLÉES), l'instantané d'annulation est supprimé avec le motif « révélé ».
  Si aucune tuile libre ne précède l'ennemi, l'unité ne bouge pas, mais l'ennemi est
  quand même révélé et le déplacement est consommé. Le détail (attaque possible ou non
  après une embuscade) appartient au GDD du brouillard (5) et des unités (6).
- **Si une commande est validée sur une vue périmée** (un aperçu affiché, puis l'état
  change) : toute commande est revalidée au moment où elle est soumise ; un aperçu d'une
  révision ancienne est jeté et recalculé (17).
- **Si l'application est mise en pause pendant la présentation** : la file est
  abandonnée et le HUD se reconstruit depuis l'état (règle 10).
- **Si la file déborde** : formule 4 ; l'état de partie n'est pas touché (règle 9).
- **Si un auditeur d'événements échoue** : l'erreur est journalisée, les autres
  auditeurs reçoivent quand même l'événement, et l'état reste ce qu'il est.
- **Si une commande arrive après la fin de la partie** : PARTIE_TERMINÉE, pour toutes les
  factions, commandes internes comprises (3).
- **Si un rejeu utilise une liste de commandes d'une version plus ancienne du jeu** : il
  est refusé avec FORMAT_INCOMPATIBLE quand la version du format diffère ; pas de
  migration des listes au MVP.

### Annulation

- **Si le joueur annule après le tour de l'IA** : AUTRE_ACTION_DEPUIS ; les commandes de
  l'IA ont supprimé l'instantané.
- **Si le joueur annule après avoir lu une ruine** : DÉPLACEMENT_A_RÉVÉLÉ.
- **Si un déplacement n'entre que dans des tuiles déjà découvertes** : l'instantané est
  armé, sauf si une unité ennemie cachée devient visible. Une première vue d'une tuile
  ou d'une unité ennemie compte comme une révélation. La définition exacte de « révéler »
  est confirmée dans le GDD du brouillard (5).

### Cas à reprendre dans un autre GDD

- **Si FINIR_LE_TOUR arrive pendant que des événements sont encore présentés** :
  accepté, sauf pendant le verrou de résolution d'une attaque. L'état est déjà final ; le
  HUD accélère ou saute le reste de la file. Propriétaires : 17 et 3.
- **Si l'IA répète une commande refusée** : les refus ne changent pas la révision. Au
  bout de N_REFUS_MAX refus dans un même tour, les tours (3) terminent le tour de l'IA et
  un message est écrit dans le journal de développement. Propriétaires : 9 et 3.
- **Si la cible d'une intention a bougé au moment de l'exécution** : l'intention est
  annulée, jamais redirigée ; la révision augmente quand même de 1 et
  INTENTION_ANNULÉE est publiée. Propriétaire : 9.

## Dependencies

### En amont (ce système dépend de)

| Système | Nature | Dure ou souple |
|---|---|---|
| 1 Modèle d'état de partie | Les commandes lisent l'état pour valider et l'écrivent en appelant les fonctions des propriétaires ; ce système possède la tranche « Journal des commandes » (numéro de la dernière commande, révision) | Dure (`design/gdd/modele-etat-partie.md`, règles 2, 3, 7, 9) |

### En aval (systèmes qui dépendent de lui)

| Nature | Systèmes | Dure ou souple |
|---|---|---|
| **Émettent des commandes** | 4 Contrôles tactiles (joueur), 9 IA à intentions, 3 Tours (fin de tour) | Dure : aucun autre chemin pour agir |
| **Fournissent la validation et l'écriture de leur commande** | 6 Unités (déplacer), 8 Combat (attaquer), 11 Nœuds (capturer), 7 Réveil (réveiller), 12 Protocoles (rechercher), 13 Ruines (lecture d'une ruine), 10 Énergie (dépense), 15 Recoloration (couleur après un changement de propriétaire) | Dure : chaque règle vit chez son propriétaire, ce système l'appelle |
| **Écoutent les événements** | 17 HUD, 20 Audio | Dure pour l'affichage ; aucune règle n'en dépend |
| **Utilise la validation sans appliquer** | 8 Combat et 17 HUD pour l'aperçu de combat ; 17 HUD pour les boutons grisés | Dure |
| **Sauvegarde** | 16 Sauvegarde automatique (après une commande appliquée, jamais pendant) | Dure |

### Bidirectionnalité

- `design/gdd/modele-etat-partie.md` cite déjà ce système (règle 3, tranche « Journal des
  commandes », interaction 23).
- `design/ux/hud.md` décrit déjà les boutons grisés, l'aperçu de combat et le journal du
  tour ennemi qui consomment ces commandes et événements ; il doit citer ce document.
- Les GDD 3, 4, 6, 7, 8, 9, 10, 11, 12, 13, 15, 16 et 20 n'existent pas encore : chacun
  doit citer ce document et confirmer sa commande, ses raisons de refus et ses
  événements.

### Décisions techniques renvoyées à un ADR

- Représentation d'une commande et d'un événement (données pures, format exact).
- Livraison des événements : file d'attente lue par le HUD et l'audio ; place exacte des
  signaux de Godot (ordre d'appel, réentrance : NOT SOURCEABLE).

## Tuning Knobs

*Dérivés des formules ; dans un fichier de configuration. Valeurs de départ, à mesurer
sur l'appareil de référence.*

| Paramètre | Valeur | Plage sûre | Trop haut | Trop bas | Interagit avec |
|---|---|---|---|---|---|
| EVENT_QUEUE_MAX (Q_max) | 256 | 2 × B_max..1024 | Plus de mémoire, retards de présentation possibles | Resynchronisations fréquentes, animations sautées | Formule 4 ; HUD (17) |
| N_REFUS_MAX | 32 | 8..128 | Une IA bloquée retient le tour plus longtemps | Une IA qui explore légitimement est coupée trop tôt | IA (9), tours (3) |
| F_CMD (part du budget de l'IA pour les aperçus) | 50 % | 30..60 % | Moins de temps pour le reste de la recherche de l'IA | Moins de candidates évaluées, IA plus faible | Formule 3 ; f_clone du GDD 1 |
| C (candidates par tour d'IA) | 2000 | 200..2000 | t_cmd_max devient négatif : budget dépassé | IA moins forte | Formule 3 ; IA (9) |
| T_FRAME (réponse à un appui) | 33 ms | 16..33 ms | Réponse perceptiblement lente | Inutile en dessous de la cadence d'affichage | Formule 5 ; cible de 30 images par seconde |

*systems-designer consulté pour les formules dont ces paramètres sont tirés.*

## Visual/Audio Requirements

Aucune en propre. Ce système publie les événements que la présentation transforme en
image et en son ; le rendu appartient au HUD (17), à la recoloration (15) et à l'audio
(20). Une seule exigence : **chaque événement qui porte une information de jeu a un
équivalent visuel** (`design/accessibility-requirements.md`, Auditory Accessibility) ;
un événement destiné seulement à l'audio n'existe pas.

## Game Feel

Ce système ne doit jamais se faire sentir. Deux exigences mesurables :
- la validation d'une commande, l'aperçu et l'application ne retardent pas la réponse à
  un appui au-delà du budget de Tuning Knobs ;
- l'état est déjà final quand l'animation commence : le joueur peut mettre en pause ou
  fermer l'application pendant une animation sans rien perdre.

## UI Requirements

Le HUD (17) et les contrôles (4) consomment trois choses de ce système :
- **la raison de chaque refus**, sous forme de code, pour griser un bouton et afficher
  une phrase courte (« Hors de portée : 3 cases ») — jamais un bouton caché
  (`design/ux/hud.md`, § 4.2) ;
- **l'aperçu**, qui passe par la même validation que la commande ;
- **l'annulation** du dernier déplacement : un bouton « Annuler le déplacement », présent
  après chaque déplacement du joueur, **grisé avec sa raison** quand l'annulation n'est
  pas permise (« Le déplacement a révélé une tuile ») — jamais caché, comme les autres
  boutons. C'est ainsi que le joueur apprend la règle « pas d'exploration gratuite ».

> **📌 UX Flag — Commandes et événements** : à ajouter à `design/ux/hud.md` (§ 4.2 et
> § 8) avant d'écrire les epics : le bouton « Annuler le déplacement » grisé avec sa
> raison, la liste des messages de refus, l'embuscade (unité arrêtée devant un ennemi
> révélé), et un moyen de voir que l'IA est arrêtée par les mêmes règles (par exemple,
> sa portée visible dans le journal du tour ennemi).

## Cross-References

| Document | Ce qui en est repris ou ce qui y est imposé |
|---|---|
| `design/gdd/modele-etat-partie.md` | Règles 2 (un écrivain par champ), 3 (chemin d'écriture unique), 7 (aucun tirage dans l'aperçu ; combat déterministe), 9 (simulation sans couche des commandes : effets jetés), 11 (vue par faction pour l'IA), 12 (pas d'historique dans l'état) ; tranche « Journal des commandes » |
| `design/gdd/profil-donnees-meta.md` | Règle 15 : l'écriture du profil est un effet appliqué par la couche des commandes seulement ; la lecture d'une ruine rend l'effet « enregistrer un fragment » (règle 10 du GDD 1) |
| `design/gdd/systems-index.md` | Notes TD-SYSTEM-BOUNDARY points 5 et 8 |
| `design/ux/hud.md` | Boutons grisés, aperçu de combat, confirmation de l'attaque en deux appuis, journal du tour ennemi, zones tactiles |
| `design/accessibility-requirements.md` | Protection contre l'appui involontaire (annulation du déplacement) ; équivalent visuel de chaque son |
| `docs/engine-reference/godot/current-best-practices.md` | Ligne 24 : connexion de lambdas à arguments variables (observée sur 4.6.1, non confirmée sur 4.7) |

## Acceptance Criteria

*Rédigés avec qa-lead. Étiquettes : **[U]** test unitaire dans `tests/unit/commands/`,
**[I]** test d'intégration dans `tests/integration/commands/`, **[P]** mesure sur
l'appareil de référence (Google Pixel, modèle à préciser). Les états de test sont
construits par des fonctions de fabrique ; « appliquer » rend ses événements en données,
et des auditeurs doublés enregistrent ce qu'ils reçoivent. Aucun test ne crée de Node.*

### Règles

- **AC-01 (règle 1)** [U] — **GIVEN** une commande refusée, **WHEN** elle est soumise,
  **THEN** « appliquer » n'est jamais appelé et l'état est égal à l'état d'avant.
- **AC-02 (règle 2)** [U] — **GIVEN** une énergie insuffisante (besoin 5, disponible 2),
  **WHEN** on valide RÉVEILLER, **THEN** le résultat est ÉNERGIE_INSUFFISANTE avec [5, 2]
  et ne contient aucun texte ; **GIVEN** un état qui échoue à deux vérifications,
  **WHEN** on le valide 100 fois, **THEN** la même première raison est rendue chaque fois.
- **AC-03 (règle 3)** [U] — **GIVEN** 1 000 commandes permises tirées avec une graine
  fixe, **WHEN** chacune est appliquée, **THEN** les invariants de l'état tiennent après
  chacune, et la validation n'a jamais modifié l'état.
- **AC-04 (règle 4)** [I] — **GIVEN** une demande de sauvegarde ou de copie faite pendant
  une application, **WHEN** elle est traitée, **THEN** elle n'a lieu qu'après la fin de
  l'application.
- **AC-05 (règle 5)** [U] — **GIVEN** une commande quelconque, **WHEN** elle est
  appliquée, **THEN** le seul champ écrit directement par ce système est la révision
  (échantillonné ; la revue de code couvre le reste).
- **AC-06 (règle 6)** [U] — **GIVEN** un déplacement dont le chemin passe par une unité
  ennemie invisible pour la faction qui bouge, **WHEN** il est validé, **THEN** il est
  permis ; **WHEN** il est appliqué, **THEN** l'unité s'arrête sur la dernière tuile
  libre avant l'ennemi, l'ennemi est révélé, et l'annulation est ensuite refusée avec
  DÉPLACEMENT_A_RÉVÉLÉ. Le même scénario donne le même résultat pour le joueur et pour
  l'IA.
- **AC-07 (règle 7)** [U] — **GIVEN** une commande ATTAQUER, **WHEN** on demande son
  aperçu, **THEN** l'état réel ne change pas et la liste d'événements de l'aperçu
  contient les dégâts, la riposte et les PV restants.
- **AC-08 (règle 8)** [U] — **GIVEN** une capture, **WHEN** elle est appliquée, **THEN**
  ses événements arrivent en un seul lot après l'application, portent tous la nouvelle
  révision, et sont dans l'ordre des identifiants croissants.
- **AC-09 (règle 9)** [I] — **GIVEN** 10 commandes appliquées, **WHEN** tous les
  événements en attente sont abandonnés, **THEN** l'état final est inchangé.
- **AC-10 (règle 10)** [U] — **GIVEN** une file non vide, **WHEN** la partie est
  sauvegardée, **THEN** aucun événement n'est sauvegardé.
- **AC-11 (règle 11)** [U] — **GIVEN** un auditeur doublé qui soumet une commande pendant
  la distribution, **WHEN** le lot est distribué, **THEN** la commande est refusée avec
  COMMANDES_VERROUILLÉES et l'état ne change pas.
- **AC-12 (règle 12)** [U] — **GIVEN** le verrou de résolution d'une attaque, **WHEN** le
  joueur et l'IA soumettent une commande, **THEN** celle du joueur est refusée avec
  COMMANDES_VERROUILLÉES et celle de l'IA est permise ; **GIVEN** la phase ennemie,
  **THEN** une commande du joueur est refusée avec PAS_VOTRE_TOUR ; **GIVEN** une partie
  terminée, **THEN** toute commande est refusée avec PARTIE_TERMINÉE.
- **AC-13 (règle 13)** [U] — **GIVEN** un début de tour, **WHEN** COMMENCER_LE_TOUR est
  appliquée, **THEN** la révision augmente de 1 et TOUR_COMMENCÉ est rendu.
- **AC-14 (règle 14)** [U] — voir AC-F1.
- **AC-15 (règle 15)** [U] — **GIVEN** un déplacement du joueur qui ne révèle rien,
  **THEN** l'instantané est ARMÉ ; **GIVEN** un déplacement qui révèle une tuile ou une
  unité ennemie, **THEN** l'annulation est refusée avec DÉPLACEMENT_A_RÉVÉLÉ ; **GIVEN**
  un déplacement qui finit sur une ruine et la lit, **THEN** l'annulation est refusée
  avec DÉPLACEMENT_A_RÉVÉLÉ et le fragment reste dans le profil ; **GIVEN**
  une commande de l'IA depuis, **THEN** avec AUTRE_ACTION_DEPUIS ; **GIVEN** une
  annulation permise, **THEN** l'état est égal à l'instantané sauf la révision, qui
  augmente de 1, et DÉPLACEMENT_ANNULÉ est rendu.
- **AC-16 (règle 16)** [U] — **GIVEN** une graine et 200 commandes, **WHEN** on les
  rejoue deux fois, **THEN** les deux états finaux sont égaux ; **GIVEN** une liste d'une
  autre version de format, **THEN** le rejeu est refusé avec FORMAT_INCOMPATIBLE.
- **AC-17 (règle 17)** [U] — **GIVEN** chaque type de commande, **WHEN** on la sérialise
  puis la recharge, **THEN** elle est égale et ne contient ni Node, ni Callable, ni RID.

### Formules

- **AC-F1** [U] — **GIVEN** rev = 41, **WHEN** un DÉPLACER est refusé, **THEN** rev
  reste 41 ; **WHEN** il est appliqué, **THEN** rev vaut 42 ; une annulation ajoute aussi
  1.
- **AC-F2** [U] — **GIVEN** rev_instantané = 50, **THEN** l'annulation est permise à
  rev = 51 et refusée après une attaque (rev = 52).
- **AC-F3** [P] — **GIVEN** l'état le plus chargé de la fabrique, **WHEN** on valide et
  applique 1 000 commandes, **THEN** la médiane est ≤ t_cmd_max (0,3 ms, provisoire).
- **AC-F4** [U] — **GIVEN** len = 250, B = 12 et Q_max = 256, **WHEN** le lot arrive,
  **THEN** la file contient exactement [RESYNCHRONISER] et l'état est inchangé ;
  **GIVEN** len = 244 et B = 12 (total 256), **THEN** il n'y a pas de débordement.
- **AC-F5** [P] — **GIVEN** un appui sur une action, **WHEN** on mesure 100 appuis,
  **THEN** l'aperçu ou la raison du refus s'affiche dans l'image suivante (≤ 33 ms) dans
  100 cas sur 100.

### Entre systèmes

- **AC-X1** [I] — **GIVEN** une commande ATTAQUER, **WHEN** on affiche son aperçu puis
  qu'on l'applique, **THEN** les dégâts, la riposte, les PV restants et les destructions
  sont identiques.
- **AC-X2** [I] — **GIVEN** une unité cachée à l'IA, **WHEN** les commandes de l'IA sont
  validées sur sa vue, **THEN** aucun paramètre de refus ne désigne jamais cette unité.
- **AC-X3** [I] — **GIVEN** un instantané ARMÉ, **WHEN** la partie est sauvegardée puis
  rechargée, **THEN** l'instantané est AUCUN et l'annulation est refusée avec
  RIEN_À_ANNULER.
- **AC-X4** [I] — **GIVEN** une simulation (fonctions de règle sans couche des commandes),
  **WHEN** une règle y est appliquée, **THEN** les auditeurs doublés reçoivent 0 événement
  et le stockage doublé 0 appel.
- **AC-X5** [I] — **GIVEN** une file abandonnée pendant une pause, **WHEN** la partie
  reprend, **THEN** le modèle du HUD reconstruit depuis l'état est égal à celui obtenu en
  consommant tous les événements.

### Limites connues

- Les règles 5 et 11 ne se prouvent pas entièrement à l'exécution : AC-05 et AC-11 les
  échantillonnent ; la revue de code complète.
- Seuils encore provisoires : t_cmd_max, t_clone et C (prototype de l'IA) ; B_max, donc
  la plage sûre de Q_max (GDD 11 et 15) ; modèle du Pixel de référence.
- N_REFUS_MAX est vérifié dans les GDD des tours (3) et de l'IA (9), pas ici.

## Open Questions

| Question | Owner | Deadline | Resolution |
|---|---|---|---|
| Godot : ordre d'appel des auditeurs d'un signal, réentrance, connexions différées, auditeur libéré pendant l'émission (NOT SOURCEABLE). La règle 10 (file lue dans l'ordre) évite d'en dépendre ; l'ADR choisit le relais entre la file et les nœuds | gameplay-programmer | ADR du bus d'événements | |
| Coût réel de validation et d'application d'une commande sur l'appareil de référence (formule 3, provisoire 0,3 ms) et nombre de candidates par tour d'IA (C) | ai-programmer, performance-analyst | Prototype des intentions de l'IA | |
| Plus gros lot d'événements (B_max) : une capture qui recolore une grande zone ? | game-designer | GDD des nœuds (11) et de la recoloration (15) | |
| Définition exacte de « révéler » pour l'annulation (tuile jamais vue, unité ennemie apparue) ; détail de l'embuscade (l'unité arrêtée peut-elle encore attaquer ?) | game-designer | GDD du brouillard (5) et des unités (6) | |
| Que fait le HUD des événements encore en file quand le joueur finit son tour (accélérer ou sauter) ? | ux-designer | Mise à jour de `design/ux/hud.md` | |
| Bouton « Annuler le déplacement » et messages de refus : place et texte dans le HUD | ux-designer | Mise à jour de `design/ux/hud.md` (§ 4.2, § 8) | |
| Les commandes internes du tour (3) et de l'IA (9) : à confirmer dans leurs GDD | game-designer, ai-programmer | GDD 3 et 9 | |
| La version installée de Godot n'est pas déterminée (`VERSION.md`) | user | `/setup-engine` | |
