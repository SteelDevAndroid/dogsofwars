# Sauvegarde automatique

> **Status**: In Design
> **Author**: user + Claude (systems-designer, engine-programmer)
> **Last Updated**: 2026-10-29
> **Last Verified**: 2026-10-29
> **Implements Pillar**: Pilier 4 « La puissance se mérite » (un arrêt ne relance jamais la punition de l'IA ; une partie reprend à l'identique) ; anti-pilier « pas de récit bloqué par la difficulté » (fragments jamais perdus)
> **Creative Director Review (CD-GDD-ALIGN)**: REVISED 2026-10-29 — CONCERNS (ancrage plus fort que la garantie réelle ; limites de « quitter ne coûte rien » non dites ; cadrage du pilier 4) corrigées : le panneau de fragment attend la fin de l'écriture, limites écrites, AC-09 vérifie le même état final

## Summary

La sauvegarde automatique écrit la partie en cours (une seule par installation) après
chaque action du joueur et aux moments clés du tour, et le profil à chacun de ses
changements, sans jamais laisser un fichier à moitié écrit ni perdre la copie de
secours. Au lancement, elle recharge le profil puis la partie, les vérifie, les migre et
les réconcilie par le journal des lectures de ruine. Pour le joueur, quitter ne coûte
rien : la partie reprend à l'action près et un fragment trouvé reste trouvé.

> **Quick reference** — Layer: `Core` · Priority: `MVP` · Key deps: `Modèle d'état de partie, Profil et données méta`

## Overview

La sauvegarde automatique écrit sur le téléphone, sans que le joueur ait jamais à y
penser, deux choses : **la partie en cours** (l'état de partie,
`design/gdd/modele-etat-partie.md`) et **le profil** (`design/gdd/profil-donnees-meta.md`).
Il n'existe **qu'une partie en cours** par installation (décision du 2026-10-29). La
partie est sauvegardée **après chaque action du joueur**, juste après « Fin du tour », à
la fin de chaque tour et à la fin de la partie (décision du 2026-10-29 ;
`design/gdd/tours-conditions-victoire.md`) ; le profil l'est à chacun de ses changements.
Une écriture ne laisse jamais un fichier à moitié écrit, une copie de secours est
toujours gardée, et le journal des lectures de ruine garde la partie et le profil
cohérents même quand le téléphone tue l'application entre deux écritures. Au lancement,
ce système retrouve la partie et le profil, les vérifie, les migre s'ils viennent d'une
version plus ancienne et les réconcilie. Le joueur ne voit ce système que dans ses
promesses : la partie reprend à l'action près après une fermeture forcée (pilier 4, « le
monde tient parole »), et un fragment trouvé n'est jamais perdu (anti-pilier « pas de
récit bloqué par la difficulté »). Ce système possède les fichiers, le moment des
écritures, l'atomicité, la copie de secours et le chargement ; il ne possède pas le
contenu, qui appartient aux systèmes 1 et 22.

*Le format des fichiers, le mécanisme d'écriture atomique et l'intégration au cycle de vie
d'Android relèvent d'un ADR de persistance, pas de ce document.*

## Player Fantasy

*Système indirect.* Ce système prolonge « Le monde tient parole »
(`design/gdd/modele-etat-partie.md`) et n'a pas de fantasme propre. Sa seule promesse :
**quitter ne coûte rien**. Il n'y a pas de bouton « Sauvegarder » ni de moment à guetter
avant de fermer l'application. Ce qui a été trouvé reste trouvé.

**Émotion visée** : la sérénité, l'absence d'inquiétude (la confiance reste l'émotion du
GDD de l'état de partie).

**Moment d'ancrage.** Le joueur lit une ruine, le fragment apparaît, et le téléphone tue
l'application aussitôt. Au relancement, le fragment est dans la chronique et la partie
reprend à cette action-là, sans doublon et sans perte.

**Test de conception.** Aucun testeur ne cherche un bouton de sauvegarde ni ne demande
« c'est sauvegardé ? ».

**Limites acceptées de la promesse.** Après un rechargement, l'annulation du dernier
déplacement n'est plus possible (`design/gdd/commandes-evenements.md`) ; un arrêt pendant
une écriture peut perdre au plus une ou deux actions (formule 2) — jamais un fragment
déjà affiché (règle 10).

*Cadrage proposé par le creative-director.*

## Detailed Design

### Core Rules

*Conçu avec systems-designer (principal) et engine-programmer (intégration moteur). Les
points marqués NOT SOURCEABLE ne sont pas couverts par `docs/engine-reference/godot/` et
sont renvoyés à l'ADR de persistance.*

#### Les fichiers

1. **Quatre fichiers**, dans le répertoire privé de l'application (`user://`, sa
   résolution sur Android et iOS : NOT SOURCEABLE) : la partie, sa copie de secours, le
   profil, sa copie de secours. **Pas de fichier d'index** : un troisième fichier pourrait
   se désynchroniser des deux autres. Chaque fichier porte son propre en-tête : version
   du schéma, empreinte d'intégrité, révision.
2. **Contenu.** La partie : l'état de partie complet, dont l'identifiant de partie,
   l'époque de réinitialisation du profil au moment de sa création, le terrain et les
   points d'intérêt, T_MAX, le drapeau « IA passive » et le journal des lectures de
   ruine. Le profil : le contenu défini par `design/gdd/profil-donnees-meta.md`. **Jamais
   sauvegardés** : la file d'événements et l'instantané d'annulation
   (`design/gdd/commandes-evenements.md`).
3. **Une seule partie en cours** par installation (décision du 2026-10-29).

#### Écrire

4. **Jamais à moitié écrit.** La sauvegarde sérialise l'état sur le fil principal,
   **entre deux commandes**, jamais au milieu d'une. Elle écrit un fichier temporaire, le
   vérifie, fait passer le fichier courant en copie de secours **seulement s'il est
   lui-même valide** (un fichier abîmé n'écrase jamais une bonne copie), puis remplace le
   fichier courant par le fichier temporaire. Chaque écriture vérifie son résultat
   (`FileAccess.store_*` renvoie un booléen, `breaking-changes.md`). L'atomicité du
   remplacement sur Android : NOT SOURCEABLE.
5. **Une écriture à la fois.** Au plus une écriture est en cours ; les commandes qui
   arrivent pendant ce temps marquent l'état « à sauvegarder », et une seule écriture
   suivante capture le dernier état. La garantie réelle est donc **la dernière écriture
   terminée**, en général à une action près.
6. **Un échec ne bloque jamais le jeu.** Une écriture échouée (stockage plein, erreur)
   laisse intacts le fichier courant et sa copie, garde l'état en mémoire, est retentée au
   déclencheur suivant, et affiche un avertissement qui ne bloque pas.
7. **Budget.** Une sauvegarde ne coûte pas plus de SAVE_MAIN_THREAD_BUDGET sur le fil
   principal (Tuning Knobs) ; si l'écriture du fichier peut se faire sur un autre fil,
   l'ADR le vérifie (NOT SOURCEABLE).

#### Quand la partie est sauvegardée

8. **Déclencheurs** (décision du 2026-10-29) :
   - après **chaque commande du joueur** appliquée, annulation et abandon compris ;
   - juste après « Fin du tour », **avant** la première commande de l'IA ;
   - après **chaque commande de l'IA** et chaque commande interne appliquée pendant la
     phase ennemie (décision du 2026-10-30, `design/gdd/modele-etat-partie.md`) ;
   - à FIN_DE_TOUR, **après** la commande COMMENCER_LE_TOUR du joueur suivante, pour que
     le fichier se recharge directement sur la main du joueur ;
   - à la fin de la partie (une seule écriture, y compris au tour 30) ;
   - au mieux, au passage en arrière-plan (notification du cycle de vie Android : NOT
     SOURCEABLE).
9. **Phase ennemie : une sauvegarde par commande.** Les commandes de l'IA et les
   commandes internes déclenchent la sauvegarde comme celles du joueur (règle 8) ;
   l'écriture coalescée de la règle 5 limite le coût quand l'IA enchaîne ses ordres. Si
   l'application est tuée pendant la phase ennemie, le chargement **reprend la phase à la
   commande suivante** (`design/gdd/tours-conditions-victoire.md`, règle 3) : l'IA décide
   à partir de l'état seul (`design/gdd/ia-ennemie.md`). Un abandon pendant la phase
   ennemie est une commande du joueur : il sauvegarde la partie terminée. *Remplace la
   règle « rien pendant la phase ennemie » du 2026-10-29 ; le budget de la règle 7 doit
   tenir à ce rythme (AC-F1 à mesurer sur l'appareil, ADR-0006).*
10. **Lecture d'une ruine** (séquence de la règle 10 de `design/gdd/modele-etat-partie.md`) :
    la commande s'applique avec l'entrée du journal « en attente » ; la partie est
    sauvegardée ; le profil enregistre le fragment et est écrit ; l'entrée passe à
    « validée » en mémoire. **Le panneau de fragment n'apparaît qu'une fois l'écriture
    de la partie terminée** (CD-GDD-ALIGN) : le joueur ne voit jamais un fragment qu'un
    arrêt pourrait effacer. (GDD SYNC, ADR-0006 : l'écriture de la partie est **synchrone** sur le fil principal ; ces 20 ms ne sont masquées par le délai de 400 ms qu'en asynchrone, et en synchrone ils retardent le début de l'onde et dépassent le budget de 8 ms de la règle 7 : à mesurer, AC-F1.) Aucune écriture supplémentaire de la partie n'est nécessaire :
    la réconciliation au chargement est idempotente. L'ordre « partie d'abord » est le
    seul sûr : « profil d'abord » laisserait un arrêt faire relire la ruine.
11. **Fin de partie.** La partie terminée est sauvegardée, puis le score est soumis au
    profil (idempotent par identifiant de partie). Le fichier reste jusqu'à ce que le
    joueur quitte l'écran de fin, puis il est supprimé ; un arrêt entre les deux rouvre
    l'écran de fin.
12. **Nouvelle partie alors qu'une partie existe.** Les menus (18) demandent confirmation
    (abandon de la partie en cours) ; ce système supprime **d'abord la copie de secours,
    puis le fichier courant** — l'ordre inverse permettrait à un arrêt de ressusciter
    l'ancienne partie depuis sa copie — puis écrit la nouvelle partie. Exception : une
    partie d'une version plus récente du jeu n'est jamais supprimée, elle est mise de côté
    (règle 16).
13. **Réinitialisation de la progression** (`design/gdd/profil-donnees-meta.md`,
    règle 11) : la partie est supprimée d'abord, puis le profil est réinitialisé ; un
    arrêt entre les deux laisse un profil intact, sans danger.

#### Charger

14. **Ordre au lancement** : le profil d'abord (les réglages existent avant le premier
    écran), puis la partie, puis la réconciliation du journal avec le profil, puis le jeu
    est prêt.
15. **Fichier abîmé** (empreinte ou lecture en échec) : la copie de secours est utilisée
    **automatiquement**, avec un avertissement. Si les deux sont abîmées, le fichier est
    mis de côté (renommé, jamais supprimé) et le jeu démarre sans partie, ou avec un
    profil neuf et un avertissement ; le journal d'une partie valide remplit quand même
    un profil neuf.
16. **Version plus récente** : la partie est refusée, son fichier n'est pas modifié et sa
    copie n'est pas essayée ; commencer une nouvelle partie demande alors de confirmer la
    mise de côté de l'ancienne. Le profil passe en lecture seule (règle 3 du GDD 22) ; les
    lectures de ruine restent « en attente ».
17. **Version plus ancienne** : la migration s'applique, le résultat est validé puis
    réécrit, l'ancien fichier devenant la copie de secours.
17bis. **Partie en cours quand une mise à jour change le format** (décision du 2026-10-30).
    Tout changement de la table des colonnes de l'état (GDD 1, règle 13) ou du contenu
    d'une tranche incrémente le numéro de schéma ; l'enveloppe, elle, garde son préfixe
    figé (ADR-0006). Ce qui arrive aux parties en cours dépend du moment :
    - **Avant le premier build du test fermé** : aucune migration n'est exigée. Une partie
      d'un schéma plus ancien sans migration est **mise de côté** (renommée, jamais
      supprimée, `BAD_FILE_CAP` respecté) avec le message « une mise à jour a changé le
      format de la partie, elle ne peut pas être reprise » ; le jeu propose une nouvelle
      partie. Le profil n'est pas touché (il a sa propre version, GDD 22, règle 3).
    - **À partir du premier build du test fermé** : chaque incrément de schéma livre une
      **migration du schéma précédent vers le nouveau**, pure et déterministe, testée sur
      un fichier de l'ancienne version conservé comme fixture ; les migrations s'enchaînent
      (N → N + 1 → …). Un build sans migration pour un incrément de schéma échoue en CI.
    - **Migration en échec** (validation des invariants refusée) : la partie est mise de
      côté comme ci-dessus, avec le même message et une nouvelle partie proposée ; jamais de
      réparation silencieuse ni de perte du fichier.
    - **Valeurs d'équilibrage** (données hors schéma, `assets/data/`) : leur changement
      n'incrémente pas le schéma ; une partie en cours reprend avec les valeurs de la
      nouvelle version. Les identifiants stockés dans l'état (fragments, protocoles) ne
      sont jamais réutilisés ni renumérotés : retirer un contenu qu'une partie référence
      est un changement de schéma.
    - **Jamais de reprise au milieu d'une phase ennemie sur un schéma migré** : une partie
      migrée reprend à sa dernière commande comme toute autre ; si la migration ne peut
      pas garantir la reprise de la phase ennemie (changement de règles de l'IA), la
      partie est ramenée à l'état d'après FINIR_LE_TOUR du tour courant, qui est toujours
      valide.

#### Sauvegarde automatique d'Android

18. **Le profil est inclus, la partie en cours est exclue** de la sauvegarde automatique
    d'Android (`design/gdd/profil-donnees-meta.md`, règle 1). Une sauvegarde Android n'est
    pas prise au même instant pour les deux fichiers : une ancienne partie restaurée avec
    un profil réinitialisé rejouerait des fragments effacés, et la règle « une seule
    partie » serait contournée. Le réglage d'export de Godot qui permet d'exclure un
    fichier : NOT SOURCEABLE. **Garde-fou** si l'exclusion est impossible : une partie
    dont l'époque de réinitialisation est inférieure à celle du profil est écartée, avec
    un avertissement. Équivalent iOS (sauvegarde iCloud des documents) : NOT SOURCEABLE.

### States and Transitions

**Écriture** (partie et profil, chacun de son côté)

| État | Déclencheur | État suivant |
|---|---|---|
| AUCUNE_SAUVEGARDE | Première écriture | SAUVEGARDÉE |
| SAUVEGARDÉE | Déclencheur (règle 8) | ÉCRITURE |
| ÉCRITURE | Réussite | SAUVEGARDÉE |
| ÉCRITURE | Échec | À_SAUVEGARDER (nouvel essai au déclencheur suivant) |
| SAUVEGARDÉE | Fin de partie, puis sortie de l'écran de fin | AUCUNE_SAUVEGARDE (partie seulement) |

**Chargement**

| État | Condition | État suivant |
|---|---|---|
| CHARGEMENT | Empreinte et lecture valides | VALIDÉE |
| CHARGEMENT | Fichier abîmé | Copie de secours, sinon AUCUNE_SAUVEGARDE (état RÉCUPÉRÉ, avertissement) |
| CHARGEMENT | Version plus récente | REFUSÉE (partie) ou LECTURE_SEULE (profil) |
| VALIDÉE | Version plus ancienne | MIGRÉE (réécrite, l'ancien fichier devient la copie) |
| VALIDÉE ou MIGRÉE | Réconciliation du journal | PRÊTE |

Les états de contenu du profil (NEUF, ACTIF…) appartiennent à
`design/gdd/profil-donnees-meta.md` et sont indépendants de ceux-ci.

### Interactions with Other Systems

| # | Système | Ce qu'il fournit à la sauvegarde | Ce que la sauvegarde fait pour lui |
|---|---|---|---|
| 1 | Modèle d'état de partie | Sérialisation, validation, journal des lectures de ruine | Déclenche les écritures ; réconcilie au chargement |
| 3 | Tours et conditions de victoire | Moments de sauvegarde (chaque commande, « Fin du tour », FIN_DE_TOUR, fin de partie) | Sauvegarde ; fait reprendre la phase ennemie à la commande suivante au chargement |
| 13 | Ruines et fragments | Séquence de lecture d'une ruine | Partie d'abord, puis profil |
| 18 | Menus et écrans | Continuer, nouvelle partie, réinitialisation | Suppression ordonnée ; avertissements |
| 19 | Réglages | — | Profil chargé avant le premier écran |
| 22 | Profil et données méta | Contenu, version, époque | Écrit à chaque changement ; supprime la partie lors d'une réinitialisation |
| 23 | Commandes et événements | Commande appliquée (déclencheur) | Ne sauvegarde jamais la file ni l'instantané ; l'annulation n'est plus possible après un chargement |

## Formulas

*Proposées par systems-designer. Ce sont des budgets techniques, pas des valeurs de jeu ;
les durées sont des mesures (nombres à virgule permis), à faire sur l'appareil de
référence.*

### 1. Budget d'une sauvegarde

The save_budget_ok formula is defined as:

`save_budget_ok = (t_serialize + t_verify + t_io_main) ≤ SAVE_MAIN_THREAD_BUDGET`

**Variables:**
| Variable | Type | Range | Source | Description |
|----------|------|-------|--------|-------------|
| t_serialize | ms | ≥ 0 | calculated (mesure) | Sérialisation de l'état sur le fil principal |
| t_verify | ms | ≥ 0 | calculated (mesure) | Vérification d'intégrité du fichier temporaire |
| t_io_main | ms | ≥ 0 | calculated (mesure) | Écriture restée sur le fil principal (0 si l'ADR la déplace sur un autre fil, NOT SOURCEABLE) |
| SAVE_MAIN_THREAD_BUDGET | ms | 4..16 | data file | **Provisoire : 8 ms**, à mesurer |

**Output Range:** vrai ou faux.
**Example:** 3,1 + 0,4 + 2,0 = 5,5 ≤ 8 → vrai.

### 2. Actions perdues au pire

The loss_bound formula is defined as:

`loss_bound = 1 + ceil(t_write / t_action_min)`

**Variables:**
| Variable | Type | Range | Source | Description |
|----------|------|-------|--------|-------------|
| t_write | ms | > 0 | calculated (mesure) | Durée d'une écriture |
| t_action_min | ms | > 0 | constant (provisoire : 250 ms, à mesurer en playtest) | Plus court délai entre deux commandes du joueur |
| loss_bound | int | ≥ 1 | calculated | Actions qu'un arrêt peut perdre au plus : l'écriture en cours et les commandes arrivées pendant elle |

**Output Range:** 1 ou plus ; non borné si les écritures sont plus lentes que les appuis.
**Example:** 20 ms / 250 ms → 1 + 1 = **2** au pire, 1 dans le cas courant (règle 5).

### 3. Volume écrit par partie

The flash_per_match formula is defined as:

`flash_per_match = B_save × W_amp × N_saves`

**Variables:**
| Variable | Type | Range | Source | Description |
|----------|------|-------|--------|-------------|
| B_save | octets | 6,5 à 26 Ko | calculated | Taille d'une sauvegarde (estimation de l'engine-programmer) |
| W_amp | nombre | ~3 | constant | Amplification d'écriture de la mémoire flash (estimation) |
| N_saves | int | ~300 | calculated | Sauvegardes par partie (règle 8) |

**Output Range:** environ 6 à 24 Mo par partie : négligeable pour l'endurance de la
mémoire. La rotation en copie de secours est un renommage, sans octet en plus.
**Example:** 26 Ko × 3 × 300 = 23,4 Mo.

### 4. Empreinte d'intégrité

The integrity formula is defined as:

`integrity = SHA-256(préfixe ‖ payload_bytes)` (32 octets, `HashingContext`, ADR-0006 ; l'empreinte est **en fin d'enveloppe**, pas dans l'en-tête)

**Variables:**
| Variable | Type | Range | Source | Description |
|----------|------|-------|--------|-------------|
| payload_bytes | octets | 0 à 26 Ko | calculated | Tout ce qui suit l'en-tête |
| integrity | int | 0..4 294 967 295 | calculated | Stockée dans l'en-tête, comparée au chargement |

**Output Range:** un entier de 32 bits. Détecte une corruption accidentelle, pas une
modification volontaire. `HashingContext` n'offre pas de CRC32 : l'ADR-0006 retient SHA-256, algorithme normalisé (46 µs pour 8 Ko sur PC) ; l'ADR choisit,
mais l'empreinte ne doit pas dépendre d'une fonction dont la stabilité entre versions du
moteur n'est pas garantie.
**Example:** une charge utile donne 0x9AE0DAAF ; elle est stockée, relue et comparée ; un
écart signale un fichier abîmé (règle 15).

### 5. Budget de chargement

The load_ok formula is defined as:

`load_ok = (k_p × t_profile + k_m × t_match + t_reconcile) ≤ SAVE_LOAD_BUDGET`, avec
`t_profile ≤ PROFILE_LOAD_BUDGET`

**Variables:**
| Variable | Type | Range | Source | Description |
|----------|------|-------|--------|-------------|
| t_profile, t_match | ms | > 0 | calculated (mesure) | Lecture, vérification et décodage d'un fichier |
| k_p, k_m | int | 1..2 | calculated | 2 quand un fichier abîmé renvoie à sa copie de secours |
| t_reconcile | ms | ≥ 0 | calculated (mesure) | Réconciliation du journal |
| PROFILE_LOAD_BUDGET | ms | 50 | data file (`design/gdd/profil-donnees-meta.md`) | Profil seul |
| SAVE_LOAD_BUDGET | ms | — | data file | **Provisoire : 150 ms** |

**Output Range:** vrai ou faux.
**Example:** pire cas, 2 × 20 + 2 × 40 + 2 = 122 ≤ 150 → vrai.

## Edge Cases

*Proposés par systems-designer.*

### Arrêts pendant une écriture

- **Si l'application est tuée pendant l'écriture du fichier temporaire** : le fichier
  courant et sa copie sont intacts ; le fichier temporaire partiel est ignoré ; perte au
  plus loss_bound (formule 2).
- **Si elle est tuée entre la rotation en copie de secours et le remplacement** : il n'y
  a plus de fichier courant ; la copie (la sauvegarde précédente, valide) est chargée avec
  un avertissement et le fichier temporaire est jeté ; perte : une sauvegarde. Un fichier
  temporaire n'est jamais promu, même s'il se vérifie : la règle reste simple et
  testable.
- **Si les deux fichiers sont valides mais de révisions différentes** : le fichier
  courant l'emporte toujours ; la copie ne sert que si le courant échoue.
- **Si la copie de secours est plus récente que le fichier courant** : impossible par la
  règle 4 (une copie naît toujours d'un courant valide, aussitôt remplacé par la
  révision suivante) ; seulement par une restauration externe, et le courant l'emporte.

### Stockage et données

- **Si le stockage est plein à la sauvegarde qui suit « Fin du tour »** : avertissement,
  le jeu continue. Le fichier sauvegardé est celui de la dernière commande du joueur : un
  arrêt ramène au tour du joueur, avant « Fin du tour » ; le joueur appuie de nouveau et
  la phase ennemie se rejoue. Propriétaire : 3 (et 9 pour le déterminisme de l'IA).
- **Si le joueur efface les données de l'application** : les quatre fichiers
  disparaissent ; démarrage avec un profil neuf, sans partie, sans avertissement (comme
  une première installation).
- **Si des fichiers mis de côté s'accumulent** : au plus BAD_FILE_CAP par type ; le plus
  ancien est supprimé.
- **Si l'horloge ou le fuseau horaire change** : aucun effet ; aucune règle n'utilise
  l'heure ; l'ordre vient de la révision et de l'époque.

### Cycle de vie et sauvegarde Android

- **Si l'application passe en arrière-plan pendant la phase ennemie** : la dernière
  commande appliquée est déjà sauvegardée (règle 9) ; après un arrêt, la phase ennemie
  reprend à la commande suivante ; sans arrêt, la partie reprend depuis la mémoire.
- **Si Android ne restaure que le profil sur un nouveau téléphone** : pas de partie, pas
  de « Continuer » ; c'est le cas normal.
- **Si un fichier de partie est restauré malgré l'exclusion** : une partie dont l'époque
  est inférieure à celle du profil est mise de côté avec un avertissement (règle 18) ;
  une époque égale est acceptée, la réconciliation étant idempotente. Propriétaire de
  l'époque : 22.

### Autres

- **Si une sauvegarde a lieu pendant le verrou de résolution d'une attaque** : permise ;
  la commande est déjà appliquée, la sauvegarde tombe entre deux commandes.
- **Si l'application est tuée après la soumission du score mais avant la suppression du
  fichier de partie** : l'écran de fin rouvre ; une nouvelle soumission ne change rien
  (idempotente par identifiant de partie) ; le fichier est supprimé quand le joueur quitte
  l'écran de fin. Propriétaires : 18 et 22.

## Dependencies

### En amont (ce système dépend de)

| Système | Nature | Dure ou souple |
|---|---|---|
| 1 Modèle d'état de partie | Le contenu de la partie, sa sérialisation, sa validation, son schéma, le journal des lectures de ruine | Dure (`design/gdd/modele-etat-partie.md`, règles 10, 13, 14) |
| 22 Profil et données méta | Le contenu du profil, sa version, son époque de réinitialisation | Dure (`design/gdd/profil-donnees-meta.md`) |

### En aval (systèmes qui dépendent de lui)

| Système | Ce qu'il utilise | Dure ou souple |
|---|---|---|
| 3 Tours et conditions de victoire | Sauvegardes aux moments du tour ; reprise de la phase ennemie au chargement | Dure |
| 13 Ruines et fragments | Ordre partie puis profil pour une lecture de ruine | Dure |
| 18 Menus et écrans | Continuer, nouvelle partie, réinitialisation, avertissements | Dure |
| 19 Réglages et accessibilité | Profil chargé avant le premier écran | Dure |
| 23 Commandes et événements | Une sauvegarde après chaque commande du joueur | Dure |

### Bidirectionnalité

- `design/gdd/modele-etat-partie.md` a été mis à jour : en-tête complété (époque, T_MAX,
  IA passive) ; copie de secours utilisée automatiquement en cas d'état invalide.
- `design/gdd/profil-donnees-meta.md`, `design/gdd/tours-conditions-victoire.md`,
  `design/gdd/commandes-evenements.md` et `design/gdd/carte-tuiles-terrain.md` citent déjà
  ce système.
- Les GDD 13, 18 et 19 doivent citer ce document.

### Décisions techniques renvoyées à un ADR (persistance)

- Format des fichiers, empreinte d'intégrité, mécanisme de remplacement atomique.
- Cycle de vie Android (notification avant la mise en arrière-plan), fil d'écriture,
  exclusion d'un fichier de la sauvegarde automatique d'Android, équivalent iOS : NOT
  SOURCEABLE.

## Tuning Knobs

*Budgets techniques dans un fichier de configuration ; valeurs provisoires, à mesurer.*

| Paramètre | Valeur | Plage sûre | Trop haut | Trop bas | Interagit avec |
|---|---|---|---|---|---|
| SAVE_MAIN_THREAD_BUDGET | 8 ms | 4..16 ms | Une sauvegarde peut faire sauter une image (33 ms à 30 i/s) | Impossible à tenir : l'écriture doit sortir du fil principal | Formule 1 ; T_FRAME (`design/gdd/commandes-evenements.md`) |
| SAVE_LOAD_BUDGET | 150 ms | 100..500 ms | Lancement perceptiblement lent | Impossible à tenir avec une copie de secours à relire | Formule 5 ; PROFILE_LOAD_BUDGET (22) |
| BACKUP_GENERATIONS | 1 | 1 au MVP (davantage changerait le nombre de fichiers de la règle 1) | Plus de place, plus d'écritures | Sous 1, plus de repli | Formule 3 ; `design/gdd/profil-donnees-meta.md` |
| BAD_FILE_CAP | 2 par type | 1..5 | Fichiers abîmés qui encombrent le stockage | Plus de trace pour analyser une corruption | — |

## Visual/Audio Requirements

Aucune. Pas d'icône « sauvegarde en cours » : le joueur ne doit jamais penser à la
sauvegarde (Player Fantasy).

## Game Feel

Invisible : une sauvegarde ne fait jamais sauter une image ni retarder une réponse à un
appui (règle 7, formule 1). Au lancement, la partie reprend sans écran de chargement
perceptible au-delà du budget de la formule 5.

## UI Requirements

Ce système ne dessine rien ; il impose aux menus (18) :
- **« Continuer »** sur l'écran d'accueil quand une partie existe ;
- **« Nouvelle partie »** avec confirmation d'abandon quand une partie existe ;
- trois **avertissements** non bloquants : sauvegarde reprise de la copie de secours ;
  sauvegarde illisible mise de côté ; écriture impossible (stockage plein) ;
- un message quand une partie vient d'une version plus récente du jeu et ne peut pas être
  chargée.

Ces messages suivent `design/accessibility-requirements.md` (pas de disparition
automatique, texte ≥ 14 pt).

> **📌 UX Flag — Sauvegarde automatique** : écran d'accueil (« Continuer », « Nouvelle
> partie ») et avertissements à spécifier avec `/ux-design` (menus, 18).

## Cross-References

| Document | Ce qui en est repris ou ce qui y est imposé |
|---|---|
| `design/gdd/game-concept.md` | Technical Considerations (état en données pures, sauvegarde automatique, reprise sans perte après un arrêt) ; MVP Definition point 8 |
| `design/gdd/modele-etat-partie.md` | Règles 10 (journal), 12 (instantané hors de l'état), 13 (schéma, égalité profonde), 14 (validation) ; mis à jour |
| `design/gdd/profil-donnees-meta.md` | Règles 1 (sauvegarde automatique d'Android), 3 (version), 4 à 6 (écriture), 11 (réinitialisation) |
| `design/gdd/tours-conditions-victoire.md` | Règle 3 (sauvegarde après chaque commande, reprise de la phase ennemie) ; fin de partie |
| `design/gdd/commandes-evenements.md` | Règles 4 (jamais au milieu d'une commande), 10 (file jamais sauvegardée), 15 (instantané d'annulation) |
| `design/gdd/carte-tuiles-terrain.md` | Une sauvegarde garde son propre terrain |
| `docs/engine-reference/godot/breaking-changes.md` | `FileAccess.store_*` renvoie un booléen |

## Acceptance Criteria

*Rédigés avec qa-lead. Étiquettes : **[U]** test unitaire dans `tests/unit/save/` ;
**[I]** test d'intégration dans `tests/integration/save/` ; **[P]** mesure sur l'appareil
de référence ; **[D]** test manuel sur appareil. Le stockage est une interface injectée ;
sa doublure en mémoire sait échouer après N octets, rater un remplacement, renvoyer
« faux » à une écriture, se déclarer pleine et servir des fichiers tronqués, abîmés ou
absents. Aucun accès fichier dans les tests [U].*

### Règles

- **AC-01 (règle 1)** [U] — **GIVEN** une sauvegarde faite, **WHEN** on liste le
  stockage, **THEN** il existe exactement 4 fichiers, aucun index, et chaque en-tête porte
  une version, une empreinte et une révision.
- **AC-02 (règle 2)** [U] — **GIVEN** une partie avec des événements en file et un
  instantané d'annulation, **WHEN** elle est sérialisée, **THEN** le contenu porte
  l'identifiant, l'époque, le terrain, les points d'intérêt, T_MAX, le drapeau « IA
  passive » et le journal, et ne contient ni la file ni l'instantané.
- **AC-03 (règle 3)** [U] — **GIVEN** une partie existante, **WHEN** une seconde est
  créée (après confirmation), **THEN** il n'y a toujours qu'une partie.
- **AC-04 (règle 4)** [U] — **GIVEN** un fichier courant abîmé, **WHEN** on sauvegarde,
  **THEN** la copie de secours n'est pas touchée ; **GIVEN** une écriture qui renvoie
  « faux » ou un remplacement raté, **THEN** le courant et la copie restent identiques à
  l'octet près.
- **AC-05 (règle 5)** [U] — **GIVEN** 5 commandes pendant une écriture, **WHEN** elle se
  termine, **THEN** exactement une écriture suit, et elle contient l'état de la 5e.
- **AC-06 (règle 6)** [U] — **GIVEN** un stockage plein, **WHEN** on sauvegarde,
  **THEN** les fichiers ne changent pas, l'état reste en mémoire, un avertissement non
  bloquant s'affiche et le déclencheur suivant réessaie.
- **AC-07 (règle 7)** — voir AC-F1.
- **AC-08 (règle 8)** [U] — **GIVEN** chaque déclencheur (commande, annulation, abandon,
  « Fin du tour », FIN_DE_TOUR après COMMENCER_LE_TOUR, fin de partie au tour 30),
  **THEN** une écriture chacun, et un rechargement retombe sur la main du joueur.
- **AC-09 (règle 9)** [I] — **GIVEN** une phase ennemie de N commandes de l'IA, **WHEN**
  elles s'exécutent, **THEN** la partie est écrite après chacune (écritures coalescées
  comprises, la dernière écriture reflétant la dernière commande) ; **GIVEN** un arrêt
  après la commande k, **WHEN** on recharge, **THEN** la sauvegarde de la commande k est
  chargée, la phase ennemie reprend à la commande k + 1 et
  atteint le même état final qu'une partie sans interruption
  (`design/gdd/tours-conditions-victoire.md`, AC-04).
- **AC-10 (règle 10)** [I] — **GIVEN** la lecture d'une ruine, **WHEN** l'application est
  tuée après l'écriture de la partie et avant celle du profil, **THEN** le rechargement
  enregistre le fragment une seule fois ; l'ordre des écritures est partie, puis profil ;
  **GIVEN** une écriture de la partie encore en cours, **THEN** le panneau de fragment
  n'est pas encore affiché.
- **AC-11 (règle 11)** [I] — **GIVEN** un arrêt après la soumission du score, **WHEN** on
  recharge, **THEN** l'écran de fin rouvre, le profil ne change pas, et le fichier est
  supprimé à la sortie de l'écran.
- **AC-12 (règle 12)** [U] — **GIVEN** une nouvelle partie confirmée, **THEN** l'ordre est
  : supprimer la copie, supprimer le courant, écrire ; un arrêt après la première étape ne
  ressuscite jamais l'ancienne partie ; **GIVEN** une partie d'une version plus récente,
  **THEN** elle est mise de côté, pas supprimée.
- **AC-13 (règle 13)** [U] — **GIVEN** une réinitialisation, **THEN** la partie est
  supprimée avant le profil ; un arrêt entre les deux laisse le profil intact.
- **AC-14 (règle 14)** [I] — **GIVEN** un lancement, **THEN** l'ordre est profil, partie,
  réconciliation, prêt ; les réglages s'appliquent avant le premier écran.
- **AC-15 (règle 15)** [U] — **GIVEN** un courant abîmé, **THEN** la copie se charge avec
  un avertissement ; **GIVEN** les deux abîmés, **THEN** ils sont renommés, jamais
  supprimés, le jeu démarre sans partie, et le journal d'une partie valide remplit un
  profil neuf.
- **AC-16 (règle 16)** [U] — **GIVEN** une version plus récente, **THEN** 0 écriture, la
  copie n'est pas lue, le profil passe en lecture seule et les entrées du journal restent
  « en attente ».
- **AC-17 (règle 17)** [U] — **GIVEN** une version plus ancienne, **THEN** elle est
  migrée, validée et réécrite, et les anciens octets deviennent la copie de secours.
- **AC-17bis (règle 17bis)** [U] — **GIVEN** une partie du schéma N − 1 et un build sans
  migration avant le test fermé, **THEN** elle est mise de côté (fichier conservé), le
  message est affiché et une nouvelle partie est proposée, profil intact ; **GIVEN** un
  build du test fermé ou postérieur avec un schéma incrémenté sans migration, **THEN** la
  CI échoue ; **GIVEN** une migration dont le résultat viole un invariant, **THEN** la
  partie est mise de côté sans écrasement ; **GIVEN** un changement de valeur
  d'équilibrage seul, **THEN** le schéma est inchangé et la partie reprend.
- **AC-18 (règle 18)** [U] — **GIVEN** une partie dont l'époque est inférieure à celle du
  profil, **THEN** elle est mise de côté avec un avertissement ; une époque égale est
  acceptée. [D] — une restauration Android ne rend que le profil.
- **AC-19 (états)** [U] — chaque transition des tableaux d'écriture et de chargement est
  exercée au moins une fois.

### Formules

- **AC-F1** [P] — **GIVEN** la plus grande partie de la fabrique, **WHEN** on la
  sauvegarde 100 fois, **THEN** le 95e centile de t_serialize + t_verify + t_io_main est
  ≤ 8 ms.
- **AC-F2** [D] — **GIVEN** 200 arrêts aléatoires pendant des écritures, **THEN** chaque
  rechargement donne un état valide et perd au plus loss_bound actions (2 avec les
  valeurs provisoires).
- **AC-F3** [U] — **GIVEN** la plus grande partie, **THEN** une sauvegarde fait au plus
  26 Ko et la rotation n'écrit aucun octet.
- **AC-F4** [U] — **GIVEN** une charge utile dont un octet est modifié ou qui est
  tronquée, **THEN** l'empreinte ne correspond plus et la règle 15 s'applique.
- **AC-F5** [P] — **GIVEN** les deux fichiers courants abîmés (k = 2), **WHEN** on fait
  100 chargements à froid, **THEN** le 95e centile est ≤ 150 ms et le profil ≤ 50 ms.

### Entre systèmes

- **AC-X1** [I] — **GIVEN** un rechargement, **THEN** l'annulation du dernier déplacement
  n'est pas disponible (`design/gdd/commandes-evenements.md`).
- **AC-X2** [I] — **GIVEN** un arrêt entre la rotation et le remplacement, **THEN** la
  copie se charge et le fichier temporaire est jeté ; **GIVEN** deux fichiers valides,
  **THEN** le courant l'emporte.
- **AC-X3** [U] — **GIVEN** BAD_FILE_CAP + 1 fichiers mis de côté, **THEN** le plus
  ancien est supprimé.

### Limites connues

- Non vérifiables avant l'ADR : atomicité du remplacement et chemin `user://` sur
  Android (AC-04, AC-F2), déclencheur d'arrière-plan (AC-08, AC-09), exclusion de la
  sauvegarde Android et équivalent iOS (AC-18), écriture hors du fil principal (AC-F1),
  stabilité de SHA-256 (`HashingContext`) sur les cibles.
- Valeurs provisoires : t_action_min (250 ms), budgets de 8 et 150 ms, modèle de
  l'appareil de référence ; la forme de l'avertissement « non bloquant » appartient aux
  menus (18).
- La formule 3 (volume écrit) n'a pas de seuil : elle sert d'estimation, pas de critère.

## Open Questions

| Question | Owner | Deadline | Resolution |
|---|---|---|---|
| Godot : atomicité du remplacement d'un fichier sur Android, résolution de `user://`, écriture hors du fil principal, vidage sur disque (NOT SOURCEABLE) | engine-programmer | ADR de persistance | |
| Godot : exclusion d'un fichier de la sauvegarde automatique d'Android ; équivalent iOS (NOT SOURCEABLE) | engine-programmer | ADR de persistance | |
| Notification du cycle de vie Android avant la mise en arrière-plan (NOT SOURCEABLE) | engine-programmer | ADR de persistance | |
| Temps réel d'une sauvegarde et d'un chargement sur l'appareil de référence (formules 1 et 5, provisoires) | performance-analyst | Prototype de persistance | |
| Modèle exact du Pixel de référence | user | Avant le prototype | |
