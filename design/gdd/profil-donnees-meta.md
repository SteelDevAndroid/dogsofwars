# Profil et données méta

> **Status**: In Design
> **Author**: user + Claude (game-designer, systems-designer)
> **Last Updated**: 2026-10-30
> **Last Verified**: 2026-10-30
> **Implements Pillar**: Pilier 2 « Chaque faction a une mémoire » ; anti-pilier « pas de récit bloqué par la difficulté »
> **Creative Director Review (CD-GDD-ALIGN)**: APPROVED 2026-10-29 (trois remarques de formulation du Player Fantasy appliquées)

## Summary

Le profil est l'unique stockage de ce qui survit à une partie : la chronique des
fragments trouvés, faction par faction et dans l'ordre, les factions débloquées, les
meilleurs scores et les réglages, sur le téléphone et inclus dans la sauvegarde
automatique d'Android. Pour le joueur, c'est une enquête qui n'avance que vers l'avant :
un fragment trouvé n'est jamais perdu, même en cas de défaite, et jamais donné deux
fois. Il est séparé de l'état de partie, et son écriture reste cohérente avec lui grâce
au journal des lectures de ruine.

> **Quick reference** — Layer: `Foundation` · Priority: `MVP` · Key deps: `None`

## Overview

Le profil est tout ce qui survit à une partie : la chronique (les fragments trouvés,
faction par faction, dans l'ordre), la position de chaque faction dans son pool de
fragments, les factions débloquées, les meilleurs scores et les réglages du joueur. Il
y a **un seul profil par installation**, stocké **sur le téléphone** (décisions du
2026-10-29) ; il est séparé de l'état de partie (`design/gdd/modele-etat-partie.md`),
pour que la progression ne dépende jamais de l'issue d'une partie. C'est la promesse de
l'anti-pilier « pas de récit bloqué par la difficulté » : un fragment trouvé pendant une
partie perdue ou abandonnée est gardé. C'est aussi ce qui donne au pilier 2 (« Chaque
faction a une mémoire ») une durée de vie : la chronique se reconstitue sur des dizaines
de parties, et chaque ruine lue fait avancer le pool de sa faction, sans jamais tirer
deux fois le même fragment. Le joueur ne voit pas le profil lui-même ; il voit la
chronique s'allonger, une faction se débloquer, ses réglages retrouvés à chaque
lancement. Sans ce système, ruines, chronique et réglages n'auraient nulle part où
vivre, et la règle « un fragment déjà lu n'est jamais tiré une seconde fois » serait
impossible à tenir d'une partie à l'autre.

*Le format de stockage et l'écriture des fichiers relèvent de la sauvegarde (16) et d'un
ADR ; ce document fixe le contenu et les règles du profil.*

## Player Fantasy

*Système indirect : le joueur ne voit jamais le profil, il voit son enquête avancer.*

**Une enquête qui n'avance que vers l'avant.** Chaque partie ajoute une pièce que vous
n'aviez pas. Jamais deux fois le même fragment, et, en jeu normal, jamais un retour en
arrière (seule exception : la restauration d'un ancien profil par Android, voir Edge
Cases). La chronique se remplit dans l'ordre de la chronique, pièce après pièce : c'est
votre reconstitution, et quatre pièces suffisent pour qu'une autre faction ouvre son
propre dossier.

**L'émotion visée est la curiosité qui progresse** : l'enquête devient la vôtre. Elle
sert les deux moteurs de retour du concept, la curiosité (chroniques incomplètes,
mystère central) et l'investissement (fragments conservés même en cas de défaite).

**Moment d'ancrage.** Une partie vient d'être perdue. Sur l'écran de fin, la chronique
affiche quand même un fragment inédit, à sa place dans l'ordre ; un peu plus tard, le
quatrième fragment d'une faction en débloque une autre (à partir de la deuxième faction :
le palier de lancement n'en a qu'une). La défaite n'a pas arrêté
l'enquête (anti-pilier « pas de récit bloqué par la difficulté »).

Les réglages et les meilleurs scores ne portent pas de fantasme propre : le jeu reprend
simplement comme vous l'aviez laissé.

*Cadrage choisi avec le creative-director. Écartés : « Rien de ce que vous trouvez ne
se perd », trop proche de la promesse de confiance du GDD de l'état de partie ; « La
meute se souvient à votre place », qui emploie le mot « mémoire », réservé par le
pilier 2 à la mémoire du monde (ruines, unités, protocoles). Le profil conserve la
découverte que le joueur fait de cette mémoire, pas la mémoire elle-même.*

## Detailed Design

### Core Rules

*Conçu avec systems-designer (principal) et engine-programmer (faisabilité moteur et
gameplay). Les points marqués NOT SOURCEABLE ne sont pas couverts par
`docs/engine-reference/godot/` et doivent être vérifiés dans un ADR.*

#### Tranches de données

| Tranche | Contenu | Seul écrivain |
|---|---|---|
| Méta | Version du schéma, identifiant de profil (aléatoire, pour une synchronisation future), révision, époque de réinitialisation | 22 |
| Chronique | Par faction : l'ensemble trié des **identifiants stables** des fragments trouvés (entiers ; jamais une position dans une liste) | 22, appelé seulement par Ruines (13) via « enregistrer un fragment » |
| Déblocages | Ensemble des factions jouables (la première l'est d'office) | 22 stocke ; Chronique (14) décide (seuil de 4 sur 12) |
| Meilleurs scores | Par couple (faction, difficulté) : un entier | 22 stocke ; Tours (3) soumet en fin de partie |
| Réglages | Table clé → entier avec valeurs par défaut : échelle du texte (100 à 150), palette daltonienne, animations réduites, panneau à gauche, volumes musique, effets et interface, vitesse du tour ennemi, difficulté préférée | 22 stocke ; Réglages (19) définit les clés et seul les écrit |
| Accueil | Drapeaux de première fois (première partie terminée, etc.) | 22 stocke ; Menus (18) seul les pose |

**Ne sont pas dans le profil** : l'état de partie, le journal des lectures de ruine, la
graine, la partie en cours, le **texte** des fragments (c'est du contenu, livré avec le
jeu), les valeurs dérivées (position dans le pool, pourcentage de chronique, score en
cours), les horodatages qui auraient un effet de règle, les chemins ou la résolution de
l'appareil, et toute donnée personnelle ou de télémétrie.

#### Règles

1. **Un profil par installation, sur l'appareil** (décisions du 2026-10-29). Pas de
   choix d'emplacement, pas de synchronisation en ligne au lancement. Le profil est
   **inclus dans la sauvegarde automatique d'Android** : il revient quand le joueur
   installe le jeu sur un nouveau téléphone avec le même compte (le réglage d'export
   correspondant dans Godot est NOT SOURCEABLE ; l'ADR le vérifie).
2. **Un écrivain par tranche.** Chaque tranche n'est écrite que par les fonctions de ce
   système, appelées par le seul système autorisé (tableau ci-dessus). Les autres
   lisent.
3. **Données pures, entiers, version.** Comme l'état de partie : valeurs simples,
   entiers, numéro de version du schéma. Un profil d'une version plus ancienne est
   migré au chargement ; un profil d'une version **plus récente** est ouvert en lecture
   seule, avec un avertissement, et n'est jamais écrasé.
4. **Écrit à chaque changement.** Le profil est écrit dès qu'il change (lecture de
   ruine, déblocage, score, réglage), sans regroupement : les écritures sont petites et
   rares. Une écriture de sécurité a lieu aussi quand l'application passe en arrière-plan
   (notification du cycle de vie Android : NOT SOURCEABLE).
5. **Jamais à moitié écrit.** Après une coupure pendant une écriture, l'ancien profil
   ou le nouveau est toujours lisible, jamais un mélange. Une génération précédente est
   gardée en secours. Le mécanisme (fichier temporaire puis renommage, contrôle
   d'intégrité) appartient à la sauvegarde (16) et à un ADR ; l'atomicité du renommage
   sur Android est NOT SOURCEABLE.
6. **Enregistrer un fragment est idempotent.** « Enregistrer un fragment (faction,
   identifiant) » répond NOUVEAU, DÉJÀ_VU ou REFUSÉ (faction inconnue). Le même
   identifiant enregistré deux fois donne le même profil. Seul
   NOUVEAU fait avancer la révision et déclenche l'évaluation des déblocages par la
   Chronique (14). L'enregistrement modifie le profil en mémoire ; l'**écriture du
   fichier** est une étape distincte (règles 4 et 5) qui rend « réussie » ou « échouée ».
   Après un échec, l'entrée du journal de la partie reste « en attente » et l'écriture
   est retentée au changement suivant, au passage en arrière-plan et au chargement. La
   séquence avec la partie suit la règle 10 de `design/gdd/modele-etat-partie.md`.
7. **La position dans le pool n'est pas stockée.** Les fragments sont tirés dans l'ordre
   de la chronique : le prochain fragment d'une faction est le plus petit identifiant
   de son pool qui n'est pas encore dans la chronique (formule 1). Une chronique est
   complète quand tout son pool est trouvé. Ces deux valeurs sont recalculées, jamais
   enregistrées, ce qui supprime tout écart entre position et chronique.
8. **Les ruines ne lisent ni la graine, ni le profil en cours de partie.** Le fragment
   donné par une ruine vient de la formule 1, pas du hasard. À la création d'une partie,
   la chronique est copiée dans l'état de partie (instantané, règle 10 de
   `design/gdd/modele-etat-partie.md`) ; pendant la partie, la formule 1 s'applique à cet
   instantané plus le journal des lectures, jamais au profil. Le résultat est le même
   qu'un calcul sur le profil, parce que la partie en cours est la seule à l'écrire (un
   profil par installation, une partie à la fois). Le journal de la partie enregistre
   l'identifiant stable du fragment. Deux ruines lues au même tour : la seconde voit le
   journal déjà complété par la première.
9. **Rien ne recule.** La chronique (union d'ensembles), les déblocages et les drapeaux
   d'accueil (une fois vrais, toujours vrais) et les meilleurs scores (maximum) ne
   reculent jamais, sauf réinitialisation. Seuls les réglages vont dans les deux sens.
   Un déblocage accordé n'est jamais retiré, même si le pool d'une faction s'agrandit.
10. **Meilleur score.** « Soumettre un score » ne garde que le maximum par (faction,
    difficulté). Il est idempotent par identifiant de partie : le profil garde les 8
    derniers identifiants de partie soumis, pour qu'un rechargement d'une partie
    terminée ne soumette pas deux fois. Le GDD des tours (3) décide si une défaite ou
    un abandon donne un score.
11. **Réinitialisation de la progression.** Elle efface la chronique, les déblocages,
    les meilleurs scores et les drapeaux d'accueil, **garde les réglages**, et fait
    avancer l'époque de réinitialisation (pour qu'une synchronisation future ne
    ressuscite pas l'ancien profil). Elle n'est proposée que depuis le menu principal,
    avec une double confirmation (18), et **supprime la partie sauvegardée** (16) :
    sinon une lecture de ruine en attente rejouerait un fragment effacé.
12. **Contenu qui grandit.** Une mise à jour peut ajouter des fragments au pool d'une
    faction : les identifiants sont stables et ajoutés à la fin, rien n'est migré, et la
    position recalculée avance seule. Une chronique complète peut redevenir
    incomplète ; ses ruines redonnent alors des fragments. Un identifiant retiré du
    contenu reste dans la chronique, ignoré des comptes ; un identifiant inconnu est
    conservé, jamais supprimé. Un identifiant ne change jamais de sens.
13. **Synchronisable plus tard.** Le profil définit une opération de **fusion** de deux
    profils : union pour la chronique, maximum pour les meilleurs scores et l'anneau des
    parties soumises, « ou » pour les déblocages et les drapeaux, et l'époque de
    réinitialisation la plus élevée l'emporte. Cette fusion donne le même résultat dans
    les deux sens et ne change rien quand on fusionne un profil avec lui-même. Il porte
    un identifiant de profil et une époque de réinitialisation. Les **réglages** ne sont
    pas fusionnés : comme le profil ne contient aucun horodatage, leur règle de fusion
    (réglages propres à chaque appareil, ou partagés) sera décidée avec la
    synchronisation en ligne (Open Questions).
14. **Réglages disponibles au démarrage.** Les réglages se lisent avant le premier
    écran. Une tranche Réglages manquante ou illisible prend les valeurs par défaut sans
    bloquer le lancement.
15. **Aucune écriture depuis une simulation.** En partie, une écriture du profil est un
    effet rendu par une fonction de règle et appliqué seulement par la couche des
    commandes (23) ; une simulation de l'IA ne passe pas par elle et jette ses effets
    (règles 3 et 9 de `design/gdd/modele-etat-partie.md`). Le profil n'a donc pas à
    reconnaître une copie de simulation.
16. **Taille bornée.** Le profil ne contient que des identifiants et des entiers ; il
    reste sous le plafond de Tuning Knobs.

### States and Transitions

| État du profil | Depuis | Déclencheur | Ce qui se passe |
|---|---|---|---|
| ABSENT → NEUF | Premier lancement, ou après effacement des données de l'application | Démarrage (22) | Profil créé avec les valeurs par défaut, aucun drapeau |
| NEUF → ACTIF | NEUF | Drapeau « première partie terminée » posé (18) | Fin de l'accueil |
| ACTIF → RÉCUPÉRÉ | Chargement | Profil principal illisible (22, 16) | Repli sur la génération de secours ; si elle est illisible aussi, le fichier est mis de côté et un profil neuf est créé ; le joueur est averti |
| tout état → LECTURE_SEULE | Chargement | Version du schéma plus récente que celle du jeu (22) | Rien n'est écrit ; avertissement |
| ACTIF → NEUF (réglages gardés) | ACTIF | Réinitialisation confirmée (18) | Règle 11 |

L'accueil n'est pas une machine à états : c'est un ensemble de drapeaux.

### Interactions with Other Systems

Aucun de ces systèmes n'a encore de GDD, sauf l'état de partie (1) : les autres lignes
sont des **contrats provisoires**.

| # | Système | Lit | Écrit (par les fonctions de 22) |
|---|---|---|---|
| 1 | Modèle d'état de partie | Chronique, une fois à la création de la partie (instantané) | Rien ; son journal des lectures de ruine rend l'enregistrement rejouable (règle 10 du GDD 1) |
| 3 | Tours et conditions de victoire | Meilleurs scores | « Soumettre un score » en fin de partie |
| 13 | Ruines et fragments | Chronique, à la création de la partie (copiée dans l'instantané de l'état) | « Enregistrer un fragment » (seul écrivain de la chronique), effet rendu par la lecture d'une ruine et appliqué par les commandes (23) |
| 14 | Chronique et progression méta | Chronique, déblocages | « Accorder un déblocage » ; la vue minimale de la chronique du MVP ne fait que lire |
| 16 | Sauvegarde automatique | Version du schéma | Écritures de fichier, génération de secours ; supprime la partie sauvegardée lors d'une réinitialisation |
| 18 | Menus et écrans hors partie | Tout (écran de chronique, scores, accueil) | Drapeaux d'accueil ; réinitialisation |
| 19 | Réglages et accessibilité | Réglages | Réglages (seul écrivain) |

## Formulas

*Proposées par systems-designer. Le seuil de déblocage (4 fragments sur 12) appartient
à la Chronique (14) : il lit la formule 3, il n'est pas défini ici.*

### 1. Prochain fragment d'une faction

The next_fragment formula is defined as:

`next_fragment(f) = min(P_f \ (C_f ∪ J_f))`, ou AUCUN si `P_f ⊆ C_f ∪ J_f`

**Variables:**
| Variable | Type | Range | Source | Description |
|----------|------|-------|--------|-------------|
| P_f | ensemble d'entiers | 1 à ~12 identifiants | data file (pool de fragments, contenu) | Pool actuel de la faction f |
| C_f | ensemble d'entiers | 0 à non borné | calculated (profil, tranche Chronique) | Identifiants trouvés, y compris retirés ou inconnus |
| J_f | ensemble d'entiers | 0 à 3 | calculated (journal des lectures de la partie, GDD 1) | Fragments déjà lus dans la partie en cours (vide hors partie) |
| résultat | entier ou AUCUN | un identifiant de P_f | calculated | Fragment que donnera la prochaine ruine de f |

**Output Range:** toujours un identifiant du pool actuel ; AUCUN quand le pool est
complet. Jamais enregistré (règle 7).
**Example:** P = {1..12}, C = {1, 2, 3, 5}, J = {} → 4 ; avec J = {4} → 6. MVP : P = {1..5} (5 fragments), complet à la partie 2.

### 2. Chronique complète

The chronicle_complete formula is defined as:

`chronicle_complete(f) = (|P_f \ C_f| = 0)`

**Variables:**
| Variable | Type | Range | Source | Description |
|----------|------|-------|--------|-------------|
| P_f, C_f | comme formule 1 | | | |
| résultat | booléen | vrai, faux | calculated | La chronique de f est complète |

**Output Range:** vrai ou faux ; peut repasser de vrai à faux quand une mise à jour
agrandit le pool (règle 12).
**Example:** P = {1..12}, C = {1..12, 40} → vrai (40 est un identifiant retiré, sans effet).

### 3. Progression de la chronique

The chronicle_progress formula is defined as:

`progress(f) = |C_f ∩ P_f|`

**Variables:**
| Variable | Type | Range | Source | Description |
|----------|------|-------|--------|-------------|
| C_f, P_f | comme formule 1 | | | L'intersection exclut les identifiants retirés |
| résultat | entier | 0 à \|P_f\| | calculated | Fragments trouvés dans le pool actuel |

**Output Range:** de 0 à |P_f|, jamais au-delà.
**Example:** C = {1, 2, 3, 99} (99 retiré), P = {1..12} → 3. La Chronique (14) compare
cette valeur à son seuil de déblocage.

### 4. Meilleur score

The best_score formula is defined as:

`best'(f, d) = max(best(f, d), s)`, sans effet si `m ∈ R` ; `s` est le **score de profil** de `tours-conditions-victoire.md` (formule 1 complète, avec `w_f × F` ; `w_p` = 0 au MVP), distinct du score décisif qui désigne le vainqueur (décision du 2026-10-30)

**Variables:**
| Variable | Type | Range | Source | Description |
|----------|------|-------|--------|-------------|
| best(f, d) | entier | ≥ 0, ou absent | calculated (profil) | Meilleur score enregistré pour (faction, difficulté) |
| s | entier | ≥ 0 | calculated (GDD des tours, 3) | Score soumis |
| m | identifiant de partie | — | calculated (état de partie) | Partie qui soumet |
| R | liste | formule 5 | calculated (profil) | Identifiants des dernières parties soumises |

**Output Range:** ne baisse jamais (règle 9).
**Example:** best = 340, s = 410 → 410 ; puis s = 200 → reste 410.

### 5. Anneau des parties soumises

The submitted_ring formula is defined as:

`R' = R` si `m ∈ R`, sinon `les N derniers de (R + [m])`

**Variables:**
| Variable | Type | Range | Source | Description |
|----------|------|-------|--------|-------------|
| R | liste d'identifiants | longueur 0 à N | calculated (profil) | Dernières parties soumises |
| N | entier | 8 | constant (Tuning Knobs, plage sûre 4 à 32) | Taille de l'anneau |
| résultat | liste | longueur ≤ N | calculated | |

**Output Range:** longueur de 0 à N ; le plus ancien identifiant sort en premier.
**Example:** R = [a..h] (plein), m = i → [b..i].

### 6. Taille du profil

The profile_size formula is defined as:

`size = H + B × (Σ_f |C_f| + n_unlock + n_score + n_set + n_flag + N)`

**Variables:**
| Variable | Type | Range | Source | Description |
|----------|------|-------|--------|-------------|
| H | entier (octets) | ~200 | constant (estimation) | En-tête et structure |
| B | entier (octets) | ≤ 48 | constant (estimation ; le format est fixé par l'ADR) | Octets par entrée, au pire |
| Σ\|C_f\| | entier | 36 | calculated | 3 factions × 12 fragments |
| n_unlock, n_score, n_set, n_flag | entiers | 3, 9, 10, ~10 | data file | Déblocages, scores (3 factions × 3 difficultés supposées), réglages, drapeaux |
| PROFILE_SIZE_CAP | entier | 256 Ko | constant (Tuning Knobs) | Plafond strict |

**Output Range:** maximum réaliste 200 + 48 × (36 + 3 + 9 + 10 + 10 + 8) ≈ 3,8 Ko, soit
1,5 % du plafond. Dépasser le plafond demanderait environ 5 400 entrées : c'est le signe
d'une corruption, l'écriture est refusée et signalée. Ces octets sont à mesurer quand
l'ADR aura fixé le format.
**Example:** 3 factions complètes (36 fragments), 3 déblocages, 9 scores, 10 réglages,
10 drapeaux, anneau plein → environ 3,8 Ko.

## Edge Cases

*Proposés par systems-designer. « Propriétaire » indique le GDD qui doit reprendre le
cas ; ce document fixe le contrat côté profil.*

### Cas propres au profil

- **Si « enregistrer un fragment » reçoit un identifiant absent du pool actuel**
  (retiré, inconnu, ou venu d'une version plus récente du contenu) : l'identifiant est
  enregistré (réponse NOUVEAU s'il est nouveau), ne compte pas dans les formules 2 et 3
  et n'est jamais supprimé. C'est ce qui permet au rejeu d'un journal venu d'une version
  plus récente de survivre. Une faction inconnue donne REFUSÉ.
- **Si l'écriture du fichier échoue** (stockage plein) alors qu'une lecture de ruine est
  en attente : l'ancien fichier reste intact, l'entrée du journal reste « en attente »,
  le profil en mémoire garde le fragment, et l'écriture est retentée (règle 6). Le
  joueur voit un avertissement qui ne bloque pas le jeu. Propriétaire des fichiers : 16.
- **Si les deux fichiers (principal et secours) sont illisibles** : le fichier est mis
  de côté, un profil neuf est créé avec les réglages par défaut, et le joueur est averti
  (état RÉCUPÉRÉ).
- **Si le profil chargé vient d'une version plus récente du jeu** : il passe en
  LECTURE_SEULE, avec avertissement, et n'est jamais écrasé (règle 3). Les ruines
  calculent toujours le prochain fragment, mais rien n'est enregistré ; les entrées du
  journal restent « en attente ».
- **Si le même score de partie est soumis deux fois** : la partie est déjà dans
  l'anneau, rien ne change (formule 5).
- **Si une clé de réglage est inconnue** (venue d'une version plus récente) : elle est
  conservée telle quelle et n'est pas lue. **Si une valeur est hors plage** : elle est
  ramenée dans la plage définie par les Réglages (19), par exemple l'échelle du texte
  entre 100 et 150. Si la tranche est illisible, les valeurs par défaut s'appliquent
  (règle 14). Propriétaire des plages : 19.
- **Si c'est le premier lancement, hors ligne** : le profil est NEUF et n'a besoin
  d'aucun réseau (règle 1). Le besoin éventuel d'une permission de stockage pour
  `user://` sur Android n'est pas couvert par la référence du moteur (NOT SOURCEABLE) :
  l'ADR le vérifie.
- **Si une mise à jour réduit le pool d'une faction** : les identifiants retirés restent
  dans la chronique mais sortent de la formule 3 ; la progression peut baisser ou
  atteindre « complète ». Un déblocage déjà accordé n'est jamais retiré (règle 9).
  Propriétaire de l'évaluation des déblocages : 14.

### Sauvegarde automatique d'Android et réinitialisation

- **Si la sauvegarde automatique restaure un profil plus ancien que la partie
  sauvegardée** : au chargement, chaque entrée du journal de la partie, validée
  comprise, est rejouée (règle 10 du GDD 1). **Limite acceptée** : les fragments trouvés
  dans des parties déjà terminées ne sont plus dans aucun journal et sont perdus ; le
  joueur retrouve la chronique de la date de la sauvegarde Android.
- **Si une réinitialisation a lieu alors qu'une partie est sauvegardée** : la partie
  sauvegardée est supprimée (règle 11). Propriétaires : 16 (suppression), 18
  (confirmation).
- **Si la sauvegarde automatique restaure, après une réinitialisation, le profil
  d'avant** : sur l'appareil, rien ne permet de le distinguer ; le profil restauré est
  accepté tel quel. L'époque de réinitialisation ne sert qu'à une future synchronisation
  en ligne, où l'époque la plus élevée gagne et les données d'une époque inférieure sont
  écartées (règle 13).

### Cas à reprendre dans un autre GDD

- **Si deux ruines de la même faction sont lues au même tour** : la seconde calcule la
  formule 1 sur l'instantané et le journal déjà complété par la première, et donne donc l'identifiant
  suivant, jamais le même (règle 8). Propriétaire : 13.
- **Si le pool d'une faction est complet et qu'une de ses ruines est lue** : la formule 1
  donne AUCUN, « enregistrer un fragment » n'est pas appelé, et le profil ne change pas.
  Ce que la ruine donne à la place (seulement la recoloration, d'après le concept) :
  13.

## Dependencies

### En amont (ce système dépend de)

**Aucun système.** C'est la couche Foundation de `design/gdd/systems-index.md`. Il
dépend du **contenu** livré avec le jeu (les pools de fragments par faction et leurs
identifiants stables, écrits par la narration) pour calculer le prochain fragment et la
complétude, et du moteur pour les types de base.

### En aval (systèmes qui dépendent de lui)

| Système | Nature | Dure ou souple |
|---|---|---|
| 13 Ruines et fragments | Copie la chronique à la création de la partie ; seul à enregistrer un fragment | Dure : sans profil, une nouvelle partie ne sait pas quels fragments sont déjà trouvés |
| 14 Chronique et progression méta | Lit la chronique et les déblocages ; accorde les déblocages | Dure |
| 16 Sauvegarde automatique | Écrit les fichiers du profil et la génération de secours ; réconcilie avec le journal de la partie | Dure |
| 19 Réglages et accessibilité | Lit et écrit les réglages | Dure : les réglages n'ont pas d'autre stockage |
| 3 Tours et conditions de victoire | Soumet le score de fin de partie | Souple : la partie se joue sans meilleur score |
| 18 Menus et écrans hors partie | Lit tout ; pose les drapeaux d'accueil ; lance la réinitialisation | Souple |
| 1 Modèle d'état de partie | Lien de cohérence : son journal rend l'enregistrement d'un fragment rejouable | Dure (règle 10 du GDD 1, mise à jour le 2026-10-29 pour ce document) |

### Bidirectionnalité

- `design/gdd/modele-etat-partie.md` cite déjà ce système (journal, règle 10 ; tranche
  « hors de l'état ») ; il a été mis à jour pour enregistrer l'identifiant stable du
  fragment et pour réconcilier aussi les entrées validées.
- Les GDD 3, 13, 14, 16, 18 et 19 n'existent pas encore : chacun doit citer ce document
  dans ses Dependencies et confirmer la fonction qu'il appelle.

### Décisions techniques renvoyées à un ADR

- Format du fichier, écriture atomique et contrôle d'intégrité (avec la sauvegarde, 16).
- Inclusion dans la sauvegarde automatique d'Android et réglage d'export de Godot (NOT
  SOURCEABLE).
- Moment exact de l'écriture de sécurité lors du passage en arrière-plan (NOT
  SOURCEABLE).

## Tuning Knobs

*Dérivés des formules ; dans un fichier de configuration, pas dans le code. Aucune
valeur d'équilibrage du jeu ici : le seuil de déblocage appartient à la Chronique (14),
la taille des pools au contenu narratif.*

| Paramètre | Valeur | Plage sûre | Trop haut | Trop bas | Interagit avec |
|---|---|---|---|---|---|
| SUBMITTED_RING_SIZE (N) | 8 | 4..32 | Profil un peu plus gros, sans gain | Un rechargement très tardif d'une partie terminée pourrait soumettre deux fois (sans effet sur le maximum) | Formules 4, 5 et 6 |
| PROFILE_SIZE_CAP | 256 Ko | 64 Ko..1 Mo | La corruption est détectée plus tard | Un profil légitime pourrait être refusé ; garder au moins 10 fois le maximum réaliste (formule 6) | Formule 6 ; sauvegarde (16) |
| PROFILE_LOAD_BUDGET | 50 ms | 20..200 ms | Lancement plus lent avant le premier écran | Difficile à tenir sur un Android d'entrée de gamme | Règle 14 ; à mesurer sur l'appareil de référence |
| BACKUP_GENERATIONS | 1 | 1..3 | Plus de place et d'écritures | Sous 1, plus de repli en cas de fichier abîmé (règle 5) | Sauvegarde (16) |

*systems-designer consulté pour les formules dont ces paramètres sont tirés.
PROFILE_LOAD_BUDGET est une valeur de départ, à confirmer sur l'appareil de référence.*

## Visual/Audio Requirements

Aucune. Ce système n'a ni rendu ni son. L'apparition d'un fragment inédit et d'un
déblocage relève des Ruines (13), de la Chronique (14) et des Menus (18).

## Game Feel

Sans objet : le joueur n'agit jamais directement sur le profil. Sa contribution au
ressenti est d'être invisible : le lancement n'attend pas le profil plus que le budget
de Tuning Knobs, et une écriture ne bloque jamais une action de jeu perceptible.

## UI Requirements

Ce système ne dessine rien, mais il impose une vue et trois messages aux écrans qui le
lisent (18, avec 14 pour la chronique) :

- **Vue minimale de la chronique (MVP)** : la liste des fragments trouvés, par faction,
  dans l'ordre, en lecture seule (Creative Director Note de `design/gdd/systems-index.md`).
- **Réinitialisation** : proposée seulement depuis le menu principal ; double
  confirmation ; le texte dit clairement que la chronique, les déblocages et les scores
  seront effacés, que les réglages sont gardés et que la partie en cours sera supprimée.
- **Profil récupéré** : un message unique au lancement quand le profil a été repris de
  la génération de secours, ou recréé.
- **Profil en lecture seule** : un bandeau permanent quand le profil vient d'une version
  plus récente du jeu ; rien n'est enregistré tant qu'il est affiché.
- Ces messages suivent `design/accessibility-requirements.md` (texte ≥ 14 pt dans les
  menus, pas de disparition automatique, zones tactiles de 48 dp sur Android).

> **📌 UX Flag — Profil et données méta** : ce système a des exigences d'interface. En
> pré-production, lancer `/ux-design` pour l'écran de chronique (avec 14) et les écrans
> de menu (18) **avant** d'écrire les epics. Les stories d'interface citeront
> `design/ux/[écran].md`, pas ce GDD.

## Cross-References

| Document | Ce qui en est repris ou ce qui y est imposé |
|---|---|
| `design/gdd/game-concept.md` | Core Mechanics point 5 (règles du pool de fragments, fragments gardés même en cas de défaite, chronique sans texte ajouté) ; Long-Term Progression (déblocage à 4 sur 12) ; Retention Hooks (curiosité, investissement, meilleur score sur 30 tours) |
| `design/gdd/modele-etat-partie.md` | Règle 10 (instantané de la chronique et journal des lectures de ruine) ; règles 3 et 9 (écritures du profil rendues comme effets, jamais appliquées par une simulation) ; règle 13 (version de schéma) |
| `design/gdd/systems-index.md` | Place du système (22, Foundation, MVP) ; note TD-SYSTEM-BOUNDARY point 1 ; Creative Director Note sur la vue minimale de la chronique dans le MVP |
| `design/accessibility-requirements.md` | Liste des réglages à stocker ; règles de texte et de zones tactiles des messages |
| `design/ux/hud.md` | Les réglages lus par le HUD (§ 10.5) sont ceux stockés ici |
| `docs/engine-reference/godot/breaking-changes.md` | `FileAccess.store_*` renvoie `bool` : chaque écriture du profil doit vérifier son résultat (à reprendre dans le GDD 16) |

## Acceptance Criteria

*Rédigés avec qa-lead. Étiquettes : **[U]** test unitaire dans `tests/unit/profile/`,
**[I]** test d'intégration dans `tests/integration/profile/`, **[P]** mesure sur
l'appareil de référence (Google Pixel, modèle à préciser), **[D]** test manuel sur
appareil. Les profils de test sont construits par des fonctions de fabrique ; le
stockage est une interface injectée dont la doublure en mémoire sait simuler une
écriture échouée, une écriture coupée, un fichier principal ou de secours abîmé, et un
fichier absent. Aucun accès fichier dans les tests unitaires.*

### Règles

- **AC-01 (règle 1)** [U] — **GIVEN** une installation neuve et un stockage vide,
  **WHEN** le profil se charge sans réseau, **THEN** un seul profil existe, aucune
  fonction ne prend d'emplacement en paramètre, et aucun appel réseau n'est fait.
  [D] — **GIVEN** un profil contenant 5 fragments, **WHEN** le jeu est installé sur un
  second appareil avec le même compte, **THEN** les 5 fragments sont présents.
- **AC-02 (règle 2)** [U] — **GIVEN** chaque tranche, **WHEN** un appelant autre que
  celui autorisé appelle sa fonction d'écriture, **THEN** l'appel est refusé et la
  tranche ne change pas.
- **AC-03 (règle 3)** [U] — **GIVEN** un profil d'une version de schéma plus ancienne,
  **WHEN** il se charge, **THEN** les migrations s'appliquent et le profil est valide ;
  **GIVEN** une version plus récente, **THEN** l'état est LECTURE_SEULE, un avertissement
  est émis et le stockage enregistre 0 écriture.
- **AC-04 (règle 4)** [U] — **GIVEN** un changement de chaque sorte (fragment, déblocage,
  score, réglage), **WHEN** chacun est appliqué, **THEN** il y a exactement 1 écriture
  par changement. [D] — **GIVEN** un changement en attente d'écriture, **WHEN**
  l'application passe en arrière-plan, **THEN** une écriture a lieu avant la suspension.
- **AC-05 (règle 5)** [U] — **GIVEN** une écriture coupée, **WHEN** le profil se
  recharge, **THEN** il est égal à l'ancien ou au nouveau, jamais à un mélange ;
  **GIVEN** un fichier principal abîmé, **THEN** le secours se charge et l'état est
  RÉCUPÉRÉ. [D] — 100 fermetures forcées pendant une écriture ne laissent aucun profil
  illisible.
- **AC-06 (règle 6)** [U] — **GIVEN** un profil, **WHEN** on enregistre deux fois le
  fragment (f, 4), **THEN** les réponses sont NOUVEAU puis DÉJÀ_VU, le profil est
  identique après les deux, et la révision augmente d'exactement 1 ; une faction inconnue
  donne REFUSÉ. **GIVEN** une écriture de fichier échouée, **THEN** l'écriture rend
  « échouée », le fragment reste en mémoire, et l'écriture est retentée au changement
  suivant, au passage en arrière-plan et au chargement.
- **AC-07 (règle 7)** [U] — **GIVEN** un profil sérialisé, **WHEN** on liste ses champs,
  **THEN** aucun ne stocke de position dans le pool ni d'état « complet ».
- **AC-08 (règle 8)** [U] — **GIVEN** deux ruines de la faction f lues au même tour,
  **WHEN** les deux sont résolues, **THEN** elles donnent deux identifiants consécutifs,
  et le compteur de tirages de la partie ne change pas.
- **AC-09 (règle 9)** [U] — **GIVEN** des suites d'opérations aléatoires sans
  réinitialisation, **WHEN** on les applique, **THEN** la chronique, les déblocages, les
  drapeaux et les meilleurs scores ne baissent jamais ; un pool qui grandit garde tous
  les déblocages accordés.
- **AC-10 (règle 10)** [U] — **GIVEN** une partie m, **WHEN** son score s est soumis deux
  fois, **THEN** le profil ne change qu'une fois.
- **AC-11 (règle 11)** [U] — **GIVEN** un profil plein, **WHEN** il est réinitialisé,
  **THEN** la chronique, les déblocages, les scores et les drapeaux sont vides, les
  réglages sont inchangés, et l'époque de réinitialisation augmente de 1.
- **AC-12 (règle 12)** [U] — **GIVEN** un pool {1..12} et une chronique {1..12}, **WHEN**
  le pool devient {1..13}, **THEN** la chronique n'est plus complète et le prochain
  fragment est 13 ; un identifiant retiré (40) et un inconnu (99) sont conservés après
  sauvegarde et rechargement.
- **AC-13 (règle 13)** [U] — **GIVEN** deux profils A et B, **WHEN** on les fusionne,
  **THEN** fusion(A, B) = fusion(B, A) et fusion(A, A) = A pour la chronique, les
  déblocages, les scores et les drapeaux ; l'époque la plus élevée l'emporte.
- **AC-14 (règle 14)** [U] — **GIVEN** une tranche Réglages illisible, **WHEN** le jeu
  démarre, **THEN** les valeurs par défaut s'appliquent et le démarrage se termine.
- **AC-15 (règle 15)** [U] — **GIVEN** une simulation de l'IA qui lit une ruine, **WHEN**
  elle se termine, **THEN** le stockage enregistre 0 appel et le profil en mémoire est
  inchangé.
- **AC-16 (règle 16)** [U] — **GIVEN** un profil au-dessus de PROFILE_SIZE_CAP, **WHEN**
  on tente de l'écrire, **THEN** l'écriture est refusée, une erreur est signalée et le
  fichier précédent est intact.
- **AC-17 (états)** [U] — **GIVEN** un profil NEUF, **WHEN** le drapeau « première
  partie terminée » est posé, **THEN** le profil est ACTIF, et il ne redevient NEUF que
  par une réinitialisation.

### Formules

- **AC-F1** [U] — **GIVEN** P = {1..12} et C = {1, 2, 3, 5}, **WHEN** on calcule le
  prochain fragment, **THEN** le résultat est 4 ; **GIVEN** C ⊇ P, **THEN** le résultat
  est AUCUN et l'enregistrement n'est pas appelé.
- **AC-F2** [U] — **GIVEN** C = {1..12, 40}, **THEN** la chronique est complète ;
  **GIVEN** C = {1..11}, **THEN** elle ne l'est pas.
- **AC-F3** [U] — **GIVEN** C = {1, 2, 3, 99} et P = {1..12}, **THEN** la progression vaut
  3 ; elle ne dépasse jamais |P|.
- **AC-F4** [U] — **GIVEN** un meilleur score de 340, **WHEN** on soumet 410 puis 200,
  **THEN** le meilleur score vaut 410.
- **AC-F5** [U] — **GIVEN** N = 8 et R = [a..h], **WHEN** on soumet i, **THEN** R vaut
  [b..i] ; soumettre une partie déjà dans R ne change pas R.
- **AC-F6** [U] — **GIVEN** le profil le plus chargé construit par la fabrique, **WHEN**
  on le sérialise, **THEN** il fait au plus 3,8 Ko (*bloqué jusqu'à l'ADR du format*).
  [P] — **GIVEN** ce profil, **WHEN** on mesure 100 chargements à froid, **THEN** la
  médiane est ≤ 50 ms (PROFILE_LOAD_BUDGET, provisoire).

### Entre systèmes

*Avec un journal doublé conforme à `design/gdd/modele-etat-partie.md`, règle 10.*

- **AC-X1** [I] — **GIVEN** une entrée « en attente » et un profil sans le fragment,
  **WHEN** la partie se recharge, **THEN** le fragment est enregistré et l'entrée passe à
  « validée » ; deux rechargements donnent exactement un fragment.
- **AC-X2** [I] — **GIVEN** une entrée « validée » et un profil plus ancien sans le
  fragment, **WHEN** la partie se recharge, **THEN** le fragment est ajouté. [D] — même
  test avec un profil restauré par la sauvegarde automatique d'Android.
- **AC-X3** [I] — **GIVEN** une partie sauvegardée, **WHEN** une réinitialisation est
  confirmée, **THEN** la sauvegarde de partie est supprimée avant le chargement suivant
  et aucun fragment n'est rejoué.
- **AC-X4** [I] — **GIVEN** une échelle de texte réglée à 150, **WHEN** le jeu démarre,
  **THEN** le premier écran s'affiche à 150, sans aucune image à 100.
- **AC-X5** [I] — **GIVEN** un profil LECTURE_SEULE et une ruine lue, **WHEN** la ruine
  est résolue, **THEN** le prochain fragment est quand même calculé, l'entrée du journal
  reste « en attente » et il y a 0 écriture.

### Limites connues

- La règle 2 ne se prouve pas entièrement à l'exécution : AC-02 l'échantillonne ; une
  revue de code ou une analyse statique la complète.
- Les parties [D] d'AC-01, AC-04 et AC-05 dépendent de points NOT SOURCEABLE (réglage
  d'export de la sauvegarde Android, notification du cycle de vie, atomicité du
  renommage) jusqu'à l'ADR de persistance.
- Seuils encore manquants : plages des réglages de volume, de vitesse et de difficulté
  (19) ; délai de l'écriture en arrière-plan ; forme de l'avertissement « non bloquant »
  (18) ; emplacement des fichiers mis de côté (16).

## Open Questions

| Question | Owner | Deadline | Resolution |
|---|---|---|---|
| Comment Godot règle-t-il l'inclusion des données dans la sauvegarde automatique d'Android, et le renommage de fichier est-il atomique sur Android ? (NOT SOURCEABLE) | engine-programmer | ADR de persistance | |
| Notification du cycle de vie Android pour l'écriture de sécurité en arrière-plan (NOT SOURCEABLE) | engine-programmer | ADR de persistance | |
| Une défaite ou un abandon donne-t-il un score enregistré ? La difficulté fait-elle partie de la clé du meilleur score ? | game-designer | GDD des tours (3) | **Résolu le 2026-10-29** (`design/gdd/tours-conditions-victoire.md`, règle 14) : seule une partie finie par domination ou au 30e tour soumet un score ; la clé est (faction, difficulté) |
| Langue de l'interface : réglage à stocker ici ? (aucun système de localisation n'est prévu) | user | Avant `/ux-design` des menus | |
| Réglages par appareil ou partagés le jour d'une synchronisation en ligne ? | ux-designer | Avant la synchronisation en ligne (après le lancement) | |
| Synchronisation en ligne (Google Play Games, iCloud) : à réévaluer après le lancement ; prise en charge par Godot NOT SOURCEABLE | producer | Après le palier de lancement | |
| La version installée de Godot n'est pas déterminée (`VERSION.md`) | user | `/setup-engine` | |
