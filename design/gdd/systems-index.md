# Systems Index: La Meute Orpheline

> **Status**: Draft
> **Created**: 2026-10-29
> **Last Updated**: 2026-10-30
> **Source Concept**: design/gdd/game-concept.md
> **Gates**: TD-SYSTEM-BOUNDARY : CONCERNS (point 1 appliqué ; points 2 à 8 notés pour les GDD) · PR-SCOPE : OPTIMISTIC (ajustements appliqués) · CD-SYSTEMS : CONCERNS (point 1 appliqué, points 2 à 4 notés sous « Priority Tiers »)

> **Note** : la re-review complète de `design/gdd/game-concept.md` (`/design-review`, après
> la révision de ses 7 points bloquants) n'a pas encore eu lieu. Cet index peut devoir
> suivre ses conclusions.

---

## Overview

*La Meute Orpheline* est un 4X léger au tour par tour sur mobile, aux règles proches de
Polytopia : carte en tuiles sous brouillard, nœuds qui produisent de l'énergie, drones
qui attaquent et ripostent, protocoles à rechercher, et une IA qui annonce ses attaques
un tour à l'avance. Deux couches le distinguent : un monde gris qui se recolore sous les
pas de la meute (pilier 1, « La meute se voit grandir ») et des ruines qui livrent, dans
un ordre fixe, les fragments d'une chronique conservée d'une partie à l'autre (pilier 2,
« Chaque faction a une mémoire » ; pilier 5, « Le brouillard cache une question »). Le jeu
compte 23 systèmes. La boucle de 30 secondes (déplacer, révéler, attaquer ou capturer)
repose sur la carte, les unités, le combat, le brouillard et la recoloration ; la boucle
de 5 à 15 minutes (réveiller, rechercher, faire monter un nœud) sur l'énergie, les nœuds,
le réveil et les protocoles ; la boucle de la partie sur les tours, l'IA et les ruines ;
la progression longue sur la chronique et le profil.

### Rôle de chaque système

**Fondations.** Le **modèle d'état de partie (1)** contient toute la partie sous forme
de données pures : tuiles, unités, nœuds, tour en cours, intentions annoncées. C'est un
conteneur sans règles ; chaque système possède sa tranche de données et les règles qui
s'y appliquent. Le **profil et données méta (22)** est son équivalent hors partie :
chronique, position dans le pool de fragments, réglages. Il est séparé pour que la
progression survive à une défaite et pour qu'aucun système de partie ne dépende d'un
système méta.

**Socle.** La **carte en tuiles (2)** définit la grille, le terrain, les coûts de
déplacement et la carte fixe du MVP. Les **tours et conditions de victoire (3)** fixent
la suite des phases d'un tour (joueur, exécution ennemie, publication des intentions),
la limite de 30 tours, la domination et le score ; le score lit ses comptes dans l'état
de partie. Les **commandes et événements (23)** sont la couche d'actions validées
partagée par le joueur et l'IA (déplacer, attaquer, capturer, réveiller, rechercher) et
le bus d'événements qu'écoutent le HUD et l'audio. Les **contrôles tactiles (4)**
traduisent les appuis en commandes et gèrent la caméra (zoom sans pincement). La
**sauvegarde automatique (16)** enregistre la partie et le profil de façon cohérente.
Les **réglages et accessibilité (19)** stockent les choix du joueur dans le profil.

**Fonctionnalités.** Les **unités (6)** portent les types, les stats et la phrase qui
explique chaque unité (pilier 3). Le **combat (8)** calcule attaque, riposte et l'aperçu
déterministe. L'**énergie (10)** et les **nœuds (11)** forment l'économie ; les nœuds sont
le seul système qui écrit le territoire. Le **brouillard (5)** calcule la vision des
unités et des nœuds. Le **réveil des drones (7)** est le geste qui fait grandir la meute à
l'écran. Les **protocoles (12)** débloquent unités et capacités. La **recoloration (15)**
traduit la possession en couleur, tuile par tuile, sans rien stocker. Les **ruines et
fragments (13)** copient la chronique du profil à la création de la partie, en tirent le
fragment suivant, recolorent une zone et nourrissent le score ; dès le MVP,
elles portent aussi une **vue minimale de la chronique**, en lecture seule (la liste des
fragments déjà trouvés), pour que les tests mesurent l'envie de rejouer pour la
chronique (CD-SYSTEMS, point 1). L'**IA à
intentions (9)** joue en deux temps : elle annonce, puis exécute ou annule. La
**chronique (14)** assemble les fragments trouvés et débloque les factions. La
**génération procédurale (21)** produira des cartes équitables après validation de la
boucle sur cartes fixes.

**Présentation.** Le **HUD (17)** est déjà spécifié (`design/ux/hud.md`). Les **menus et
écrans hors partie (18)** couvrent l'accueil, la pause, l'aide, le score de fin et la
chronique. L'**audio (20)** double chaque événement de jeu d'un son, jamais seul porteur
d'une information.

### Relations critiques

- **Tout passe par l'état de partie (1).** Les 22 autres systèmes en dépendent. Il doit
  rester des données pures, sans Node ni SceneTree, et peu coûteux à cloner, pour que
  l'IA puisse simuler et tenir son budget de 2 s par tour (TD-SYSTEM-BOUNDARY, points 6
  et 7).
- **Une seule voie pour les règles.** Le joueur et l'IA passent par les commandes (23) :
  un seul chemin de validation, des aperçus qui correspondent au résultat, des tests
  possibles sans interface.
- **Territoire : un seul écrivain.** Les nœuds (11) exposent l'écriture du territoire ;
  les ruines (13), le combat et la capture l'appellent. La recoloration (15) se contente
  de lire et d'afficher.
- **Deux sauvegardes, une cohérence.** Le profil (22) est écrit dès qu'une ruine est lue,
  la partie (1) après chaque commande. Aucune règle de partie ne lit le profil : la
  chronique est copiée dans l'état à la création. La sauvegarde (16) doit garantir qu'une reprise après un
  arrêt de l'application ne montre pas une ruine non lue alors que son fragment est déjà
  compté.
- **Les intentions sont dans l'état.** L'IA (9) écrit ses intentions dans l'état de
  partie (1), pour qu'elles soient sauvegardées et que la règle d'annulation (cible morte
  ou déplacée, jamais de redirection) les lise de là.

---

## Systems Enumeration

**Sens de la colonne « Depends On »** (précisé le 2026-10-30) : le système A dépend de B
quand A **lit ou appelle B directement**, par un contrat de données (une tranche de
l'état dont B est propriétaire, une valeur ou une fonction de B) ou de fonction. Cela
veut dire trois choses : le GDD de B est conçu avant celui de A ; un changement du
contrat de B oblige à relire A ; A ne peut pas être testé sans un substitut de B. Cela ne
veut **pas** dire :
- « s'exécute après » (l'ordre des phases est possédé par les tours, 3) ;
- « écrit dans les données de » (qui écrit quoi est dans le modèle d'état, règle 2 du
  GDD 1 : un système peut écrire une tranche sans que son propriétaire dépende de lui) ;
- « reçoit les événements de » (les événements passent par la couche des commandes, 23 :
  le consommateur dépend de 23, jamais du producteur) ;
- « est affiché par » (le HUD, 17, dépend des systèmes qu'il montre, pas l'inverse).
La colonne ne liste que les dépendances **directes** ; la fermeture transitive se lit
dans la carte ci-dessous. Chaque GDD qualifie les siennes de dures (sans elle, rien ne
marche) ou souples (dégradation prévue) dans sa section Dependencies.

| # | System Name | Category | Priority | Status | Design Doc | Depends On |
|---|-------------|----------|----------|--------|------------|------------|
| 1 | Modèle d'état de partie | Core | MVP | Designed | design/gdd/modele-etat-partie.md | — |
| 2 | Carte en tuiles et terrain | Core | MVP | Designed | design/gdd/carte-tuiles-terrain.md | 1 |
| 3 | Tours et conditions de victoire | Core | MVP | Designed | design/gdd/tours-conditions-victoire.md | 1 |
| 4 | Contrôles tactiles et caméra de carte (inferred) | Core | MVP | Designed | design/gdd/controles-tactiles-camera.md | 2, 23 |
| 5 | Brouillard de guerre et vision | Gameplay | MVP | Designed | design/gdd/brouillard-vision.md | 2, 6, 11 |
| 6 | Unités drones | Gameplay | MVP | Designed | design/gdd/unites-drones.md | 1, 2 |
| 7 | Réveil des drones | Gameplay | MVP | Designed | design/gdd/reveil-drones.md | 6, 10 |
| 8 | Combat | Gameplay | MVP | Designed | design/gdd/combat.md | 2, 6 |
| 9 | IA ennemie à intentions | Gameplay | MVP | Designed | design/gdd/ia-ennemie.md | 3, 5, 6, 7, 8, 10, 11, 12, 23 |
| 10 | Énergie | Economy | MVP | Designed | design/gdd/energie.md | 1, 3 |
| 11 | Nœuds | Economy | MVP | Designed | design/gdd/noeuds.md | 2, 10 |
| 12 | Arbre de protocoles | Progression | MVP | Designed | design/gdd/arbre-protocoles.md | 1, 3, 6, 10, 23 |
| 13 | Ruines et fragments | Narrative | MVP | Designed | design/gdd/ruines-fragments.md | 2, 5, 11, 15, 22 |
| 14 | Chronique et progression méta | Narrative | Vertical Slice | Not Started | — | 13, 22 |
| 15 | Recoloration du monde | Gameplay | MVP | Designed | design/gdd/recoloration-monde.md | 2, 11 |
| 16 | Sauvegarde automatique | Persistence | MVP | Designed | design/gdd/sauvegarde-automatique.md | 1, 22 |
| 17 | HUD (inferred) | UI | MVP | Designed | design/gdd/hud-systeme.md ; design/ux/hud.md | 1, 3, 4, 5, 6, 7, 8, 9, 10, 11, 12, 13, 15, 16, 19, 22, 23 |
| 18 | Menus et écrans hors partie (inferred) | UI | Vertical Slice | Not Started | — | 3, 14, 16, 19 |
| 19 | Réglages et accessibilité (inferred) | Meta | Vertical Slice | Not Started | — | 22 |
| 20 | Audio (inferred) | Audio | Vertical Slice | Not Started | — | 19, 23 |
| 21 | Génération procédurale de cartes | Core | Alpha | Not Started | — | 2, 7, 11, 13 |
| 22 | Profil et données méta (inferred) | Persistence | MVP | Designed | design/gdd/profil-donnees-meta.md | — |
| 23 | Commandes et événements (inferred) | Core | MVP | Designed | design/gdd/commandes-evenements.md | 1 |

*Le HUD (17) est spécifié par une UX spec plutôt qu'un GDD ; son statut suit
`/ux-review` (dernier verdict : NOT ASSESSED, 0 point bloquant, en attente de ces GDD).*

---

## Categories

| Category | Description | Systems in this game |
|----------|-------------|-----------------|
| **Core** | Foundation systems everything depends on | 1, 2, 3, 4, 21, 23 |
| **Gameplay** | The systems that make the game fun | 5, 6, 7, 8, 9, 15 |
| **Progression** | How the player grows over time | 12 |
| **Economy** | Resource creation and consumption | 10, 11 |
| **Persistence** | Save state and continuity | 16, 22 |
| **UI** | Player-facing information displays | 17, 18 |
| **Audio** | Sound and music systems | 20 |
| **Narrative** | Story and dialogue delivery | 13, 14 |
| **Meta** | Systems outside the core game loop | 19 |

---

## Priority Tiers

| Tier | Definition | Target Milestone | Design Urgency |
|------|------------|------------------|----------------|
| **MVP** | Required for the core loop to function. Without these, you can't test "is this fun?" | First playable — 14 à 16 semaines (PR-SCOPE) | Design FIRST |
| **Vertical Slice** | Ici, **partie du palier de lancement** (1 faction) : sans menus, réglages, audio ni chronique, aucune version ne peut sortir sur le store. | Palier de lancement — environ 7 mois (PR-SCOPE) | Design SECOND |
| **Alpha** | All features present in rough form. Complete mechanical scope, placeholder content OK. | Alpha, 2 factions — environ 10 mois | Design THIRD |
| **Full Vision** | Polish, edge cases, nice-to-haves, and content-complete features. | 3 factions, iOS — environ 13 à 15 mois | Design as needed |

> **Creative Director Note** (MVP / Vertical Slice — appliqué le 2026-10-29) : l'hypothèse
> du MVP finit par « donne envie de rejouer pour la chronique ». Le MVP inclut donc une
> **vue minimale de la chronique**, en lecture seule (liste des fragments trouvés, sur
> l'écran de lecture ou le score de fin), portée par Ruines et fragments (13). Le système
> complet Chronique (14), avec le déblocage des factions, reste en Vertical Slice.
>
> **Creative Director Note** (Alpha / palier de lancement) : l'hypothèse la plus risquée
> porte sur des fragments « sur une carte générée », alors que le lancement sort avec des
> cartes fixes. Sur une carte fixe, le joueur mémorise les ruines et le pilier 5 s'use.
> Les GDD de la carte (2) et des ruines (13) doivent définir des **emplacements de ruines
> tirés au hasard parmi plusieurs positions candidates** sur chaque carte fixe. La table
> Scope Tiers du concept liste encore le générateur au lancement : à corriger (voir la
> Producer Note).
>
> **Creative Director Note** (MVP) : le pilier 5 (« chaque élément de la carte doit
> éveiller une question ») n'a pas de propriétaire au-delà des ruines. Le GDD de la carte
> (2) possède les **points d'intérêt** (drones endormis, nœuds, ruines visibles sous le
> brouillard) ; le GDD du brouillard (5) porte l'exception « ruine visible dans le
> brouillard » de l'ancrage visuel.
>
> **Creative Director Note** (MVP) : le changement de sens de la recoloration voulu par la
> ligne narrative passe **par le seul contenu des fragments**, jamais par une couche
> mécanique ajoutée (pilier 3). Les GDD des ruines (13) et de la recoloration (15)
> l'écrivent explicitement.
>
> *À relancer si la re-review du concept ou le signal 2 changent les piliers ou la ligne
> narrative.*

**Répartition** : MVP 18 systèmes (9 S, 8 M, 1 L) · Vertical Slice 4 · Alpha 1 · Full
Vision 0 (les factions 2 et 3, les 3 difficultés et iOS sont du contenu ou des réglages de
systèmes existants).

> **Producer Note (PR-SCOPE : OPTIMISTIC, ajustements appliqués le 2026-10-29)** :
> - Le MVP ne tient pas en 10 semaines en solo : 14 à 16 semaines, IA en deux temps
>   comprise (environ +3 semaines, confiance faible).
> - Avant d'engager la date, faire un prototype limité à une semaine du flux annonce,
>   exécution et sauvegarde des intentions (`/prototype`).
> - La génération procédurale (21) reste en Alpha. Le lancement sort avec un pool de **6 à
>   10 cartes faites à la main ou à graine fixe**, pour que chaque point de coupe reste
>   publiable.
> - Le test fermé Google Play démarre dès que le MVP tourne ; l'iOS du premier mois se
>   limite à un export de test.
> - **À reporter dans `design/gdd/game-concept.md` § Scope Tiers** (non modifié par
>   `/map-systems`) : MVP 14 à 16 semaines, lancement environ 7 mois, Alpha environ 10
>   mois, Full Vision 13 à 15 mois, générateur hors palier de lancement.
> - Tous ces chiffres supposent un développeur solo : taille d'équipe à confirmer.

---

## Dependency Map

### Foundation Layer (no dependencies)

1. **Modèle d'état de partie (1)** — toute la partie en données pures ; les 22 autres
   systèmes le lisent ou l'écrivent.
2. **Profil et données méta (22)** — tout ce qui survit à une partie : chronique, position
   dans le pool de fragments, réglages. Ajouté sur TD-SYSTEM-BOUNDARY point 1 pour casser
   le cycle ruines → chronique → ruines.

### Core Layer (depends on foundation)

1. **Commandes et événements (23)** — depends on: 1. Ajouté sur TD-SYSTEM-BOUNDARY points
   5 et 8.
2. **Carte en tuiles et terrain (2)** — depends on: 1
3. **Tours et conditions de victoire (3)** — depends on: 1. Contrat : les tours définissent
   les phases, l'IA s'y branche ; le score lit l'état de partie.
4. **Sauvegarde automatique (16)** — depends on: 1, 22
5. **Réglages et accessibilité (19)** — depends on: 22
6. **Contrôles tactiles et caméra de carte (4)** — depends on: 2, 23

### Feature Layer (depends on core)

1. **Unités drones (6)** — depends on: 1, 2
2. **Énergie (10)** — depends on: 1, 3
3. **Nœuds (11)** — depends on: 2, 10. Seul écrivain du territoire.
4. **Combat (8)** — depends on: 2, 6 (terrain pour les bonus de défense, à confirmer dans
   le GDD)
5. **Brouillard de guerre et vision (5)** — depends on: 2, 6, 11
6. **Réveil des drones (7)** — depends on: 6, 10
7. **Arbre de protocoles (12)** — depends on: 6, 10
8. **Recoloration du monde (15)** — depends on: 2, 11
9. **Ruines et fragments (13)** — depends on: 2, 5, 11, 15, 22
10. **IA ennemie à intentions (9)** — depends on: 3, 5, 6, 7, 8, 10, 11, 12, 23. Dernier
    système de la couche à concevoir.
11. **Chronique et progression méta (14)** — depends on: 13, 22
12. **Génération procédurale de cartes (21)** — depends on: 2, 7, 11, 13

### Presentation Layer (depends on features)

1. **HUD (17)** — depends on: 3, 4, 5, 6, 8, 9, 10, 11, 13, 15, 19, 23
2. **Menus et écrans hors partie (18)** — depends on: 3, 14, 16, 19
3. **Audio (20)** — depends on: 19, 23 (événements de 7, 8, 9 et 13 via le bus)

### Polish Layer (depends on everything)

Aucun système. L'accessibilité est intégrée aux réglages (19) et au HUD (17) dès la
conception, selon `design/accessibility-requirements.md`.

**Goulots d'étranglement** : 1 (tout le monde en dépend), 2, 6, 11.
**Feuilles** (rien n'en dépend, conception tardive possible) : 14, 17, 18, 20, 21.

### Notes TD-SYSTEM-BOUNDARY pour les GDD

| Point | Note | GDD concerné |
|---|---|---|
| 1 | Profil séparé de l'état de partie ; écriture du profil à la lecture d'une ruine, de la partie après chaque commande ; cohérence par le journal de la lecture dans l'état et un instantané de la chronique copié à la création (GDD 1, règle 10) | 22, 16, 13, 14 |
| 2 | Les intentions annoncées vivent dans l'état de partie, pas dans l'IA | 1, 9 |
| 3 | L'IA dépend aussi du réveil, de l'énergie et des protocoles | 9 |
| 4 | API unique d'écriture du territoire dans les nœuds, qui enregistre aussi le dernier changement de propriétaire ; la recoloration déduit la couleur de ces champs et ne garde que le shader de présentation | 11, 15 |
| 5 | Couche de commandes validées commune au joueur et à l'IA | 23, 4, 9 |
| 6 | État en données pures, sans Node ni SceneTree, clonable à faible coût, pour l'IA sur plusieurs images ou dans un thread en moins de 2 s | 1, 9 |
| 7 | L'état de partie reste un conteneur sans règles ; chaque système possède sa tranche et ses règles en fonctions pures | 1 et tous |
| 8 | Le bus d'événements et la liste des événements appartiennent aux commandes et événements | 23, 17, 20 |
| Mineur | Le combat dépend probablement du terrain (bonus de défense) | 8 |

---

## Recommended Design Order

| Order | System | Priority | Layer | Agent(s) | Est. Effort |
|-------|--------|----------|-------|----------|-------------|
| 1 | Modèle d'état de partie (1) | MVP | Foundation | game-designer, lead-programmer | M |
| 2 | Profil et données méta (22) | MVP | Foundation | game-designer, lead-programmer | S |
| 3 | Commandes et événements (23) | MVP | Core | lead-programmer, game-designer | M |
| 4 | Carte en tuiles et terrain (2) | MVP | Core | game-designer, level-designer | S |
| 5 | Tours et conditions de victoire (3) | MVP | Core | game-designer | S |
| 6 | Sauvegarde automatique (16) | MVP | Core | lead-programmer | M |
| 7 | Contrôles tactiles et caméra de carte (4) | MVP | Core | ux-designer, gameplay-programmer | S |
| 8 | Unités drones (6) | MVP | Feature | game-designer, systems-designer | M |
| 9 | Énergie (10) | MVP | Feature | economy-designer | S |
| 10 | Nœuds (11) | MVP | Feature | game-designer, economy-designer | M |
| 11 | Combat (8) | MVP | Feature | systems-designer | M |
| 12 | Brouillard de guerre et vision (5) | MVP | Feature | game-designer | S |
| 13 | Réveil des drones (7) | MVP | Feature | game-designer | S |
| 14 | Arbre de protocoles (12) | MVP | Feature | systems-designer | M |
| 15 | Recoloration du monde (15) | MVP | Feature | game-designer, technical-artist | S |
| 16 | Ruines et fragments (13) | MVP | Feature | game-designer, narrative-director | M |
| 17 | IA ennemie à intentions (9) | MVP | Feature | ai-programmer, game-designer | L |
| 18 | HUD (17) — UX spec existante, à revalider | MVP | Presentation | ux-designer | S |
| 19 | Réglages et accessibilité (19) | Vertical Slice | Core | ux-designer, accessibility-specialist | S |
| 20 | Chronique et progression méta (14) | Vertical Slice | Feature | narrative-director, game-designer | M |
| 21 | Menus et écrans hors partie (18) | Vertical Slice | Presentation | ux-designer | M |
| 22 | Audio (20) | Vertical Slice | Presentation | audio-director, sound-designer | M |
| 23 | Génération procédurale de cartes (21) | Alpha | Feature | level-designer, systems-designer | L |

*Effort : S = 1 session, M = 2 à 3 sessions, L = 4 sessions et plus. Les systèmes
indépendants d'une même couche peuvent être conçus en parallèle.*

---

## Circular Dependencies

- **Aucun cycle**, sous trois conditions :
  - **Ruines ↔ chronique** : cassé par le profil (22), qui porte la chronique. À la
    création de la partie, la chronique est copiée dans l'état (instantané, GDD 1 règle 10) ;
    les ruines (13) n'y lisent que l'instantané et le journal, et la couche des commandes
    (23) applique l'effet « enregistrer un fragment » au profil ; la chronique lit le profil.
  - **Tours ↔ IA** : les tours définissent les phases ; l'IA s'y branche. Les tours ne
    dépendent pas de l'IA.
  - **Score ↔ ruines et nœuds** : le score lit ses comptes dans l'état de partie (1), pas
    directement dans les autres systèmes.

---

## High-Risk Systems

| System | Risk Type | Risk Description | Mitigation |
|--------|-----------|-----------------|------------|
| IA ennemie à intentions (9) | Technical / Scope | IA en deux temps (annonce, exécution, sauvegarde), budget de 2 s par tour sur appareil de référence ; environ +3 semaines, confiance faible ; l'IA dépasse souvent d'un facteur 2 | Prototype d'une semaine du flux d'intentions avant d'engager la date ; IA gloutonne à scores d'abord ; état clonable |
| Ruines et fragments (13) | Design | Hypothèse la plus risquée du concept : des fragments dans un ordre fixe sur une carte générée restent-ils assez forts face à l'expansion ? Au lancement, les cartes sont fixes | Signal 2 à mesurer avec 5 testeurs extérieurs, avec la vue minimale de la chronique ; emplacements de ruines tirés parmi des positions candidates ; seuil d'échec défini dans le concept |
| Sauvegarde automatique (16) | Technical | Deux sauvegardes (partie, profil) à garder cohérentes quand l'OS tue l'application ; versions de sauvegarde quand les règles évoluent | Journal de la lecture de ruine dans l'état de partie ; test de reprise après kill dès le MVP |
| Recoloration du monde (15) | Technical | Shader de saturation par tuile sur les renderers Mobile et Compatibility, 30 fps sur Android d'entrée de gamme | Prototype technique de rendu sur appareil bas de gamme (prévu par le concept) |
| Génération procédurale de cartes (21) | Scope | Souvent sous-estimée d'un facteur 2 ; seule source de rejouabilité si elle glisse | Pool de 6 à 10 cartes fixes au lancement ; générateur en Alpha |
| Modèle d'état de partie (1) | Technical | Goulot de tout le projet ; risque d'objet fourre-tout | Conteneur sans règles, données pures, conçu en premier |

---

## Progress Tracker

| Metric | Count |
|--------|-------|
| Total systems identified | 23 |
| Design docs started | 19 (HUD, UX spec ; GDD 1, 22, 23, 2, 3, 16, 4, 6, 10, 11, 8, 5, 7, 15, 13, 9, 12 et 17) |
| Design docs reviewed | 1 (HUD : `/ux-review` NOT ASSESSED, 0 point bloquant) ; GDD 1, 22, 23, 2, 3, 16, 4, 6, 10, 11, 8, 5, 7, 15, 13, 9, 12 et 17 en attente de `/design-review` |
| Design docs approved | 0 |
| MVP systems designed | 18/18 |
| Vertical Slice systems designed | 0/4 |

---

## Next Steps

- [ ] Re-review du concept : `/design-review design/gdd/game-concept.md`, puis y reporter les dates PR-SCOPE
- [ ] Concevoir les systèmes MVP dans l'ordre ci-dessus (`/design-system [system-name]`, ou `/map-systems next`)
- [ ] Prototype d'une semaine du flux d'intentions de l'IA (`/prototype`)
- [ ] Lancer `/design-review` sur chaque GDD terminé
- [ ] Relancer `/ux-review design/ux/hud.md` quand les GDD MVP existent
- [ ] Lancer `/gate-check technical-setup` quand les systèmes MVP sont conçus
- [ ] Valider les systèmes les plus risqués avec `/vertical-slice` avant la production
