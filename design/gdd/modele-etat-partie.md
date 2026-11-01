# Modèle d'état de partie

> **Status**: In Design
> **Author**: user + Claude (game-designer, systems-designer, lead-programmer)
> **Last Updated**: 2026-10-30
> **Last Verified**: 2026-10-30
> **Implements Pillar**: Pilier 4 « La puissance se mérite » (directement) ; socle de tous les piliers
> **Creative Director Review (CD-GDD-ALIGN)**: REVISED 2026-10-29 — CONCERNS (garantie « aucune attaque sans intention annoncée » non écrite ; promesse « l'aperçu est le résultat » dépendante d'un combat déterministe) corrigées : invariant ajouté, combat déterministe décidé

## Summary

Le modèle d'état de partie contient toute la partie en cours sous forme de données
pures (carte, unités, nœuds, ruines, énergie, protocoles, tour, intentions de l'IA,
graine de hasard), sans aucune règle : chaque autre système en possède une tranche et
l'écrit par ses propres fonctions. Pour le joueur, il garantit que « le monde tient
parole » : la partie reprend à l'identique après une fermeture forcée, une attaque
annoncée est toujours là au tour suivant et s'annule si sa cible a bougé, et un aperçu
de combat est son résultat. C'est la fondation des 22 autres systèmes et la seule
chose que la sauvegarde enregistre pour la partie.

> **Quick reference** — Layer: `Foundation` · Priority: `MVP` · Key deps: `None`

## Overview

Le modèle d'état de partie est la représentation complète d'une partie en cours, sous
forme de données pures : la carte et le propriétaire de chaque tuile, les unités, les nœuds,
les ruines, l'énergie, les protocoles, le tour en cours, les intentions annoncées par
l'IA et la graine de hasard. Ce n'est pas un système de règles : c'est un conteneur que
les 22 autres systèmes lisent, et dont chacun ne modifie que la tranche qui lui
appartient, par des règles écrites en fonctions pures (TD-SYSTEM-BOUNDARY, point 7). Le
joueur ne le voit jamais ; il le ressent à travers trois garanties. Une partie reprend
exactement où elle s'était arrêtée, même quand le téléphone a tué l'application (la
sauvegarde automatique n'enregistre que ce modèle). Une attaque annoncée au tour
précédent est toujours là au tour suivant, et une attaque dont la cible a bougé
s'annule au lieu de changer de cible (pilier 4, « La puissance se mérite »). Ce que
montre un aperçu de combat est ce qui se produit, parce que les règles s'appliquent à
des données identiques et que le hasard passe par une graine stockée ici. Sans ce
modèle, la sauvegarde, l'IA en deux temps et les aperçus fiables ne seraient pas
possibles ; c'est aussi lui que l'IA copie pour simuler ses coups dans son budget de
2 secondes par tour (TD-SYSTEM-BOUNDARY, point 6).

*Le choix technique (Resources, Dictionaries ou classes RefCounted, format de
sérialisation) relève d'un ADR (`/architecture-decision`), pas de ce document.*

## Player Fantasy

*Système indirect : le joueur ne le voit jamais, il ressent ce qu'il garantit.*

**Le monde tient parole.** Ce que le jeu annonce arrive, et seulement cela. Une attaque
signalée sera là au tour suivant, et elle tombe dans le vide si sa cible a bougé.
L'aperçu d'un combat est son résultat. Quand on perd un drone, on sait pourquoi, et on
sait qu'on aurait pu l'éviter. On peut poser le téléphone en plein tour : en revenant,
tout est à sa place.

**L'émotion visée est la confiance.** Le pilier 4 (« La puissance se mérite ») veut une
IA « juste mais dure » ; une défaite n'est acceptable que si le joueur est certain que
les règles ont tenu. Ce système est ce qui rend cette certitude vraie.

**Moment d'ancrage.** Fin du tour : un marqueur d'attaque est posé sur un drone. Le
joueur le déplace. Au tour suivant, l'attaque s'annule, et le joueur pense « j'avais vu
juste ». Moment plus discret : il rouvre l'application après que le téléphone l'a
fermée, et retrouve le même tour, le même marqueur, le même aperçu.

**Test de conception.** Un testeur ne dit jamais « le jeu a triché », et rien n'a
changé après une fermeture forcée puis une réouverture.

*Cadrage choisi avec le creative-director. Écarté : un cadrage dans la fiction (« les
machines n'oublient rien »), qui ferait porter du récit à un système d'infrastructure
alors que le pilier 2 réserve le récit au contenu. Le mot « mémoire » est aussi évité :
le pilier 2 l'emploie déjà pour les factions.*

## Detailed Design

### Core Rules

*Conçu avec systems-designer (principal), gameplay-programmer et engine-programmer
(faisabilité). Les points marqués NOT SOURCEABLE ne sont pas couverts par
`docs/engine-reference/godot/` et doivent être vérifiés dans un prototype ou un ADR.*

#### Tranches de données

L'état est découpé en tranches. Chaque tranche a **un seul système propriétaire**, qui
définit le sens de ses champs et les seules fonctions qui l'écrivent.

| Tranche | Contenu | Propriétaire |
|---|---|---|
| En-tête de partie | Identifiant de partie, époque de réinitialisation du profil à la création, graine, compteur de tirages, compteurs d'identifiants (prochain id d'unité, de nœud, de ruine, d'intention), numéro de tour, T_MAX, drapeau « IA passive », phase en cours, faction active, statut de fin | 1 (identifiant, époque, graine, compteurs d'id) ; 3 (tour, T_MAX, IA passive, phase, faction active, statut de fin) |
| Carte | Dimensions, terrain de chaque tuile (fixe pendant la partie), propriétaire de chaque tuile, couche d'ancrage de chaque tuile (NŒUD, RUINE ou aucun), dernier changement de propriétaire de chaque tuile (tour, propriétaire précédent, cause : capture, combat ou ruine), point d'intérêt de chaque tuile | 2 (dimensions, terrain, points d'intérêt) ; 11 (propriétaire et dernier changement) |
| Visibilité | Pour chaque faction : tuiles déjà découvertes et **dernier propriétaire vu** de chaque tuile (mémoire du territoire hors de vue, 1 octet par tuile et par faction ; décision du 2026-10-30) ; la vision actuelle n'est pas stockée | 5 |
| Unités | Par id : type, faction, position, PV, a bougé, a agi, endormie | 6 (le réveil de 7 et les PV du combat 8 passent par les fonctions de 6) |
| Nœuds | Par id : position, propriétaire, niveau | 11 |
| Ruines | Par id : position (tirée parmi 9 candidats, 3 zones de 3), zone, faction de mémoire (donnée du fichier de carte), lue ou non, tour de lecture (−1 si non lue), faction lectrice ; R figé à 3 ruines tirées | 13 (21 n'écrit que la mise en place initiale) |
| Instantané de la chronique | Par faction en jeu : identifiants stables des fragments déjà trouvés à la création de la partie, copiés du profil (22) | 13 (écrit une seule fois, à la création ; jamais modifié ensuite) |
| Factions | Par faction : stock d'énergie, ensemble trié des ids de protocoles acquis, recherche en cours (id, tours restants), éliminée ou non ; pour l'IA, protocoles reçus par le calendrier fixe (`arbre-protocoles.md`, règle 15) | 10 (stock) ; 12 (protocoles) ; 3 (éliminée) |
| Intentions | Par id : unité auteur, tuile de l'auteur à l'annonce, type de cible (unité ou nœud), cible (id dans ce type), tuile de la cible à l'annonce, type d'action (attaque ou capture), motif (TRAQUE, REPRÉSAILLE, CAPTURE, DÉFENSE), tour d'annonce, tour d'exécution, statut (annoncée, exécutée, annulée), raison d'annulation (AUTEUR_DÉTRUIT, CIBLE_DÉTRUITE, CIBLE_DÉPLACÉE, HORS_DE_PORTÉE, UNITÉ_ABSENTE, UNITÉ_DÉTRUITE, NŒUD_DÉJÀ_À_L'IA) ; une intention par unité (`INTENT_CAP`, `ia-ennemie.md`, règle 15) ; compte de siège du dernier nœud | 9 |
| Agents de l'IA | **Tranche privée à la faction de l'IA** (ADR-0005) : par Gardien, état de rôle (POSTE, TRAQUE, RETOUR ; CAPTURE, TIENT, RIPOSTE, SIÈGE), compteur « tours sans cible », poste, motif courant ; une valeur scalaire `curseur_ia` (id de la dernière unité de l'IA qui a émis une commande ce tour, 0 au début de la phase ennemie : point de reprise des coups ordinaires) ; `filtered_copy(IA)` la garde, `filtered_copy(JOUEUR)` la retire ; écrite par l'application d'ANNONCER_LES_INTENTIONS | 9 |
| Pistes de l'IA | Au plus 16 entrées (id de l'unité du joueur, tuile, tour de vue, type), durée de vie 4 tours (`ia-ennemie.md`, règle 9) | 9 |
| Rappels de présentation | Pour la dernière phase ennemie seulement : unités perdues (tuile, camp), tuiles perdues ; vidée à la fin du tour suivant du joueur ; **aucun effet de jeu** (ni le score, ni l'IA, ni la vue ne la lisent ; `hud-systeme.md`, règle 22) | 17 lit ; 6 et 11 écrivent |
| Compteurs de score | Comptes bruts : nœuds tenus, unités détruites (les fragments lus se comptent dans le journal des lectures de ruine) | Chaque compte a le système qui le fait avancer (11, 8) ; 3 possède la formule du score |
| Journal des lectures de ruine | Par lecture : id de ruine, faction, **identifiant stable du fragment**, statut (en attente, validée) | 13 (voir règle 10) |
| Journal des commandes | Révision de l'état (= numéro de la dernière commande appliquée, un seul numéro) ; propriété du pipeline de commandes, incrémentée par lui à chaque commande appliquée ; conservée par `restore_from` | 23 |

Ne sont **pas** dans l'état : le revenu d'énergie et le score (calculés par 10 et 3 à
partir de l'état), la couleur des tuiles (déduite par 15 du propriétaire et du dernier
changement), les tuiles vues actuellement (recalculées par 5 à partir des unités et des
nœuds), les données du profil (chronique, position dans le pool de fragments, réglages :
système 22 ; seul un instantané de la chronique est copié à la création, voir règle 10),
l'animation, la sélection et tout ce qui est purement visuel. Une valeur qui se recalcule
à partir de l'état n'y est jamais stockée.

#### Règles

1. **Conteneur sans règles.** L'état ne contient que des données : aucune règle de jeu,
   aucune validation de coup. Les règles vivent dans les systèmes propriétaires, sous
   forme de fonctions pures qui prennent l'état (ou une tranche) en argument
   (TD-SYSTEM-BOUNDARY, point 7).
2. **Un écrivain par champ.** Un système n'écrit jamais la tranche d'un autre. Quand
   deux systèmes doivent modifier la même donnée, le propriétaire expose la seule
   fonction d'écriture et l'autre l'appelle (le combat appelle « modifier les PV » des
   unités ; le réveil appelle « réveiller » des unités ; la capture, le combat et les
   ruines appellent l'écriture du territoire des nœuds ; tout coût d'énergie passe par
   « dépenser » de l'énergie).
3. **Chemin d'écriture unique.** En partie, l'état n'est modifié que par une commande
   validée (système 23), qu'elle vienne du joueur ou de l'IA. Les fonctions de règle
   sont pures : elles rendent leurs écritures et la liste de leurs **effets** (événements
   à émettre, écritures du profil) sous forme de valeurs ; seule la couche des commandes
   (23) applique ces effets. L'interface, l'audio et les menus ne font que lire.
4. **Données pures.** L'état ne contient que des valeurs simples : entiers, booléens,
   chaînes, listes et tables de ces valeurs. Jamais de référence à un Node, un Object,
   un Callable, un signal, un RID ou une ressource créée à l'exécution. Il ne dépend pas
   de la SceneTree.
5. **Références par identifiant.** Les unités, nœuds, ruines et intentions ont un
   identifiant entier, croissant par type, tiré d'un compteur de l'en-tête. **Un
   identifiant n'est jamais réutilisé** dans une partie, même après la destruction de
   l'unité ou l'annulation de l'intention. Les tuiles sont désignées par leurs
   coordonnées. Une tranche ne référence une autre que par identifiant ou coordonnées,
   jamais par partage de données.
6. **Entiers seulement.** Toute valeur de règle stockée (PV, énergie, position, niveau,
   coût) est un entier. Les valeurs de réglage restent dans des fichiers de
   configuration, mais leurs résultats dans l'état sont entiers, pour que deux appareils
   calculent la même chose.
7. **Hasard par la graine.** Tout tirage passe par une seule fonction de l'état, qui
   utilise la graine et fait avancer le compteur de tirages. Aucun système n'utilise le
   hasard du moteur. L'aperçu de combat ne fait aucun tirage. **Le combat (8) est
   déterministe** (décision du 2026-10-29) : il ne fait aucun tirage non plus, ce qui
   rend vraie la promesse « l'aperçu d'un combat est son résultat ». Une copie emporte le
   compteur : les tirages faits dans une simulation de l'IA ne modifient jamais l'état
   réel.
8. **Ordre d'itération défini.** Toute règle qui parcourt des unités, nœuds, ruines ou
   intentions le fait **par identifiant croissant**, jamais dans l'ordre interne d'une
   table (l'ordre d'itération des Dictionary n'est pas garanti par la référence du
   moteur : NOT SOURCEABLE).
9. **Copie sans partage.** L'état peut être copié entièrement. Une copie ne partage
   aucune donnée modifiable avec l'original ; seules les données fixes pour toute la
   partie (le terrain) peuvent être partagées, en lecture seule. Une copie ne porte
   aucun drapeau : une simulation applique les fonctions de règle sans passer par la
   couche des commandes et jette leurs effets (règle 3) ; elle ne peut donc ni écrire
   le profil ni émettre d'événement. Les données par tuile et par unité sont plates et
   homogènes (une grille
   indexée par tuile, des unités indexées par id), pour que la copie reste peu coûteuse.
10. **Instantané de la chronique et journal des lectures de ruine** (TD-SYSTEM-BOUNDARY,
    point 1). À la création de la partie, la chronique du profil (22) est copiée dans
    l'instantané, pour chaque faction en jeu. Pendant la partie, le prochain fragment
    d'une faction se calcule **sur l'état seul** : formule 1 de
    `design/gdd/profil-donnees-meta.md`, appliquée à l'instantané plus les fragments du
    journal. Aucune règle de partie ne lit le profil : une partie se rejoue à
    l'identique sans lui, et les simulations de l'IA n'y touchent pas. Quand une ruine
    est lue, la même commande marque la ruine lue, ajoute au journal une entrée « en
    attente » (ruine, faction, identifiant stable du fragment — jamais une position dans
    le pool, qu'une mise à jour du contenu pourrait décaler) et rend l'effet
    « enregistrer un fragment ». La couche des commandes (23) applique cet effet au
    profil ; si l'écriture du fichier réussit, elle applique la commande interne
    « valider la lecture », qui passe l'entrée à « validée ». Au chargement, **chaque entrée
    du journal, en attente ou validée**, est réconciliée : si le fragment est déjà dans
    le profil, l'entrée est (ou reste) validée ; sinon, l'écriture du profil est rejouée
    (elle est idempotente par identifiant de fragment). Les entrées validées sont aussi
    vérifiées parce qu'un profil restauré par la sauvegarde automatique d'Android peut
    être plus ancien que la partie (`design/gdd/profil-donnees-meta.md`, règle 1). Une
    ruine n'apparaît jamais non lue alors que son fragment est compté, et un fragment
    lu n'est jamais perdu.
11. **Vue par faction.** Chaque faction, IA comprise, ne lit l'état qu'à travers sa vue
    filtrée par le brouillard (tuiles visibles et découvertes, tranche Visibilité de 5).
    L'IA ne voit pas ce que le joueur ne lui montre pas (décision du 2026-10-29 :
    pilier 4 « juste mais dure », pilier 5 « Le brouillard cache une question »).
    Une simulation de l'IA part d'un état **reconstruit à partir de sa vue** (hors vue :
    terrain découvert seulement, sans unité, nœud ni propriétaire), jamais d'une copie
    de l'état complet : une simulation bloquée par une unité cachée la révélerait. Ce
    qui arrive quand un coup, validé sur l'état réel, rencontre une unité cachée
    appartient aux commandes (23), avec la même règle pour le joueur et pour l'IA.
    Seuls la sauvegarde (16), la couche des commandes (23) et les tests lisent l'état
    complet.
12. **Taille bornée.** Les collections sont **compactées en fin de tour** par un tri stable (id croissant préservé, ids consommés jamais réutilisés ; ADR-0003). L'état ne grandit pas sans limite : pas d'historique, pas de
    journal d'événements. Les bornes sont des constantes de ce document (voir Tuning
    Knobs) : 16 × 16 tuiles, 60 unités, 10 nœuds, et un plafond d'intentions par tour.
    L'instantané qui permet d'annuler le dernier déplacement est une copie gardée
    **hors de l'état** par les commandes (23), jamais sauvegardée.
13. **Sérialisable sans perte.** L'état se sérialise et se recharge en un état égal
    (égalité profonde définie par ce système). Le numéro de version du schéma est porté
    par l'enveloppe du fichier (ADR-0006), pas par l'état ; un état d'une version plus ancienne est migré au chargement, un état d'une
    version plus récente est refusé. Ce système possède le schéma et le contrat
    « vers données / depuis données » ; la sauvegarde (16) possède les fichiers, l'écriture
    atomique et le moment des sauvegardes. **Égalité profonde** (ADR-0003 : elle ignore les lignes mortes et la disposition interne ; `to_bytes` est déterministe et rend la charge utile seule ; l'enveloppe, la taille et l'empreinte d'intégrité relèvent de la sauvegarde, ADR-0006) : deux états sont égaux
    quand toutes leurs tranches ont les mêmes champs avec les mêmes valeurs, les
    collections indexées par identifiant étant comparées par identifiant (sans tenir
    compte de l'ordre interne) et les grilles case par case.
14. **Validable.** Une fonction de validation vérifie les invariants (voir Edge Cases)
    dans les tests et à chaque chargement.

### States and Transitions

L'état **stocke** la phase et le statut de fin ; c'est le système de tours (3) qui
possède leur enchaînement et décide ce qui est légal. Une pause ou un arrêt de
l'application n'est pas un état : c'est un point de sauvegarde, et la reprise retombe
sur la dernière phase sauvegardée.

| Valeur stockée | Atteinte depuis | Déclencheur (propriétaire) | Ce qui doit être vrai |
|---|---|---|---|
| CRÉÉE | — | Nouvelle partie (3, avec la carte 2 ou le générateur 21) | Graine fixée, compteurs d'id à zéro, tour 0, instantané de la chronique copié du profil (13) |
| PHASE_JOUEUR (tour n) | CRÉÉE, FIN_DE_TOUR | Début du tour (3), par la commande interne COMMENCER_LE_TOUR (`design/gdd/commandes-evenements.md`) | Revenu appliqué (10) |
| EXÉCUTION_ENNEMIE | PHASE_JOUEUR | Commande « fin du tour » (3) | Les intentions du tour précédent sont exécutées ou annulées (cible détruite ou déplacée, jamais redirigée) ; puis l'IA joue ; puis elle **annonce** ses intentions du tour suivant (9), sauf au tour 30 |
| FIN_DE_TOUR | EXÉCUTION_ENNEMIE | 3 | État complet et cohérent |
| TERMINÉE (domination, défaite, 30e tour, abandon) | toute phase | Contrôle de fin de partie (3) | Statut de fin posé ; l'état ne change plus |

*Décidé dans `design/gdd/tours-conditions-victoire.md` : la publication des intentions
est une étape de la fin de la phase ennemie, pas une phase stockée. Une sauvegarde au
milieu de la résolution d'une commande est interdite : la sauvegarde sur pause
enregistre le dernier état cohérent.*

*Sauvegarde après chaque commande (décision du 2026-10-30) : la partie est enregistrée
de façon atomique après chaque commande appliquée, du joueur ou de l'IA (environ 32 Ko,
formule 5). Une fermeture forcée en plein tour ne perd au plus que la commande en cours,
ce qui tient la promesse « poser le téléphone en plein tour ». Une reprise au milieu de
l'exécution ennemie repart de la commande suivante : l'IA décide donc à partir de l'état
seul (propriétaire : 9). Une sauvegarde au milieu de la résolution d'une commande est
interdite ; la sauvegarde sur pause n'est qu'un filet.*

### Interactions with Other Systems

Aucun des 22 systèmes dépendants n'a encore de GDD : chaque ligne est un **contrat
provisoire**, à confirmer dans le GDD du système concerné.

| # | Système | Lit | Écrit (seulement par ses fonctions) |
|---|---|---|---|
| 2 | Carte en tuiles et terrain | Carte | Dimensions, terrain, points d'intérêt (à la création) |
| 3 | Tours et conditions de victoire | En-tête, compteurs de score, Factions | Tour, phase, faction active, statut de fin, faction éliminée |
| 4 | Contrôles tactiles et caméra | Vue de la faction du joueur | — (passe par les commandes) |
| 5 | Brouillard et vision | Carte, Unités, Nœuds | Visibilité (tuiles découvertes ; la vision actuelle est recalculée) |
| 6 | Unités drones | Carte, Unités | Unités (seul écrivain : PV, réveil, position, drapeaux) |
| 7 | Réveil des drones | Unités, Factions | — (appelle « réveiller » de 6 et « dépenser » de 10) |
| 8 | Combat | Unités, Carte | — (appelle « modifier les PV » de 6 ; compteur d'unités détruites) |
| 9 | IA à intentions | Vue de sa faction (ses simulations partent d'un état reconstruit à partir de cette vue) | Intentions ; ses coups passent par les commandes |
| 10 | Énergie | Nœuds, Factions | Stock d'énergie |
| 11 | Nœuds | Carte, Factions | Nœuds ; propriétaire et dernier changement de propriétaire des tuiles (seul écrivain du territoire ; l'appelant donne la cause) ; compteur de nœuds tenus |
| 12 | Arbre de protocoles | Factions | Protocoles recherchés, recherche en cours |
| 13 | Ruines et fragments | Carte, Visibilité, Ruines, instantané de la chronique, journal | Ruines, instantané (à la création seulement), journal des lectures ; rend l'effet « enregistrer un fragment » |
| 14 | Chronique | — (lit le profil) | — |
| 15 | Recoloration du monde | Propriétaire et dernier changement des tuiles | — (la couleur se déduit de ces champs ; rien dans l'état) |
| 16 | Sauvegarde automatique | Tout l'état | — (fichiers, écrits après chaque commande ; version du schéma lue) |
| 17 | HUD | Vue de la faction du joueur, Intentions la visant | — |
| 18 | Menus et écrans | Statut de fin, compteurs de score | — |
| 19 | Réglages | — (profil) | — |
| 20 | Audio | — (événements du bus de 23) | — |
| 21 | Génération procédurale | — | Carte, Nœuds, Ruines, Unités initiales (mise en place seulement) |
| 22 | Profil et données méta | — (stockage séparé ; sa chronique est copiée dans l'instantané à la création, par 13) | — |
| 23 | Commandes et événements | Tout l'état (validation) | Journal des commandes, révision ; applique les fonctions des propriétaires et leurs effets (événements, écritures du profil) |

## Formulas

*Proposées par systems-designer. Ce système ne possède aucune valeur d'équilibrage
(dégâts, énergie, coûts : systèmes 8, 10, 12). Ses formules sont structurelles.*

### 1. Index de tuile

The tile_index formula is defined as:

`tile_index = y * W + x`

**Variables:**
| Variable | Type | Range | Source | Description |
|----------|------|-------|--------|-------------|
| x, y | int | 0..W−1, 0..H−1 | calculated | Coordonnées de la tuile |
| W, H | int | 1..16 | data file (carte, système 2) | Dimensions de la carte |
| tile_index | int | 0..W×H−1 | calculated | Position dans les grilles plates de tuiles |

**Output Range:** 0 à 255 sur une carte de 16 × 16. Des coordonnées hors de la carte
sont refusées, jamais ramenées dans les bornes.
**Example:** W = 12, tuile (5, 3) → 3 × 12 + 5 = 41.

### 2. Tirage borné

The draw formula is defined as:

`draw(n) = hash32(seed, counter) mod n`, puis `counter = counter + 1`, avec `hash32(seed, counter)` = SplitMix32 appliqué à `z = (seed + (counter + 1) × 0x9E3779B9) & 0xFFFFFFFF` (forme canonique, ADR-0003 : le point fixe `hash32(0, 0) = 0` d'une forme sans incrément n'existe plus et la graine 0 reste légale)

**Variables:**
| Variable | Type | Range | Source | Description |
|----------|------|-------|--------|-------------|
| seed | int | 0..2³²−1 | calculated (en-tête, fixé à la création) | Graine de la partie |
| counter | int | 0..2³¹−1 | calculated (en-tête) | Compteur de tirages |
| n | int | 1..65 536 | calculated (appelant) | Nombre de résultats possibles |
| hash32 | fonction | 0..2³²−1 | constant (algorithme figé par ADR) | Hachage entier fixe (type finaliseur SplitMix ou PCG), masqué sur 32 bits |

**Output Range:** 0 à n − 1. n = 0 est une erreur de l'appelant et est refusé. Le biais
du modulo vaut au plus n / 2³², soit 1,5 × 10⁻⁵ pour n = 65 536 : il est accepté, parce
que le rejet d'échantillons rendrait variable le nombre de tirages par appel et
casserait la reproductibilité. n est plafonné à 65 536. Le comportement des entiers
GDScript en cas de dépassement n'est pas couvert par la référence du moteur (NOT
SOURCEABLE) : chaque étape du hachage est masquée, et le hachage est figé par des tests
à valeurs de référence.
**Example:** hash32(1234, 7) = 2 913 004 551 (*valeur fictive, à recalculer avec la forme canonique et figer dans un test ; les graines de référence sont 0, 1, 1234, 987654321 et 4294967295*) ; n = 6 → 2 913 004 551 mod 6 = 3 ; le compteur passe
à 8.

### 3. Attribution d'identifiant

The id formula is defined as:

`id = next_id[type]`, puis `next_id[type] = next_id[type] + 1`

**Variables:**
| Variable | Type | Range | Source | Description |
|----------|------|-------|--------|-------------|
| type | enum | unité, nœud, ruine, intention | constant | Famille d'identifiants |
| next_id[type] | int | 0..2³¹−1 | calculated (en-tête) | Prochain identifiant libre de la famille |

**Output Range:** 0 à 2³¹ − 1, strictement croissant, jamais réutilisé.
**Example:** next_id[unité] = 17 → le drone réveillé reçoit l'id 17, le compteur passe à
18.

### 4. Borne des intentions stockées

The stored_intentions_max formula is defined as:

`stored_intentions_max = INTENT_CAP × INTENT_RETENTION_TURNS`

**Variables:**
| Variable | Type | Range | Source | Description |
|----------|------|-------|--------|-------------|
| INTENT_CAP | int | 1..60 | constant | Intentions annoncées au plus par tour (provisoire : 60, le plafond d'unités ; la règle « une par unité » relève de l'IA, 9) |
| INTENT_RETENTION_TURNS | int | 2 | constant | Tour en cours et tour précédent |

**Output Range:** 0 à 120. Les intentions plus anciennes sont retirées de l'état ; leurs
identifiants restent consommés. La borne est une constante, pas une fonction du nombre
d'unités ennemies : l'état a besoin d'un maximum fixe, et le nombre réel par tour est une
décision de l'IA (9).
**Example:** 60 × 2 = 120 intentions au plus dans l'état.

### 5. Taille brute et coût de copie (estimations à mesurer)

The state_size formula is defined as:

`S_raw = 64 + T×6 + T×F×2 + U×16 + N×8 + R×8 + I×24 + F×64 + F×P×2` (octets)

`N_clones_max = floor(T_ai × f_clone / t_clone)`

**Variables:**
| Variable | Type | Range | Source | Description |
|----------|------|-------|--------|-------------|
| T | int | 1..256 | calculated | Nombre de tuiles (W × H) |
| U | int | 0..60 | calculated | Unités |
| N | int | 0..10 | calculated | Nœuds |
| R | int | à fixer | data file (carte, 2 ou 21) | Ruines |
| F | int | à fixer | data file (partie, 3) | Factions |
| I | int | 0..120 | calculated | Intentions stockées |
| P | int | ~12 | data file (pools de fragments, contenu) | Fragments par pool, borne de l'instantané par faction |
| T_ai | int (ms) | 2000 | constant | Budget d'un tour d'IA (concept, TD-FEASIBILITY) |
| f_clone | int (%) | 10..30 | constant | Part du budget de l'IA consacrée aux copies |
| t_clone | int (µs) | à mesurer | calculated | Durée d'une copie complète sur l'appareil de référence |

Estimations par entité : tuile 6 octets (propriétaire, dernier changement : tour,
propriétaire précédent et cause, point d'intérêt ; le terrain est partagé, la couleur
est déduite), visibilité 2 octets par tuile et par faction (découverte, dernier propriétaire vu), unité 16, nœud 8,
ruine 8, intention 24, fragment de l'instantané 2.

**Output Range:** environ 8 Ko de données brutes au maximum ; environ 32 Ko sur disque
avec un format texte (facteur 4). Le surcoût réel des Dictionary et Object de Godot 4.7
n'est pas couvert par la référence (NOT SOURCEABLE ; il peut multiplier ces chiffres par
10 à 50) : ces valeurs servent de budget à vérifier, pas de garantie.
**Example:** T = 256, F = 4, U = 60, N = 10, R = 20, I = 120, P = 12 → 8 080 octets,
environ 8 Ko. Avec
t_clone = 200 µs et f_clone = 25 % : floor(2000 ms × 25 % / 0,2 ms) = 2 500 copies par
tour d'IA.

## Edge Cases

*Proposés par systems-designer. « Propriétaire » indique le GDD qui doit reprendre le
cas ; ce document en fixe seulement le contrat côté état.*

### Cas propres à l'état

- **Si un compteur d'identifiants atteint 2³¹ − 1** : l'attribution échoue et la commande
  est refusée. Hors d'atteinte dans les bornes du jeu ; sert de garde-fou.
- **Si un tirage est demandé avec n = 0 ou n > 65 536** : le tirage est refusé et le
  compteur ne bouge pas.
- **Si l'aperçu de combat demande un tirage** : le tirage est refusé et le compteur ne
  bouge pas. L'aperçu doit rester déterministe.
- **Si une simulation de l'IA produit des effets** (événement, écriture du profil) : ils
  sont jetés avec la simulation. Seule la couche des commandes (23) applique des effets,
  et une simulation ne passe pas par elle.
- **Si la carte est plus petite que 16 × 16** : les grilles ont W × H cases ; des
  coordonnées hors de W ou H sont invalides, même si elles restent sous 16.
- **Si l'IA demande une tuile hors de sa vue** : la vue répond « inconnue » (seul le
  terrain déjà découvert est rendu), jamais l'état réel.
- **Si la version du schéma d'un état chargé est plus récente que celle du jeu** : le
  chargement est refusé et le fichier n'est pas modifié.
- **Si la version du schéma est plus ancienne** : les migrations s'appliquent dans
  l'ordre, puis l'état est validé.
- **Si la validation échoue au chargement** (un invariant ci-dessous est violé) : le
  chargement est refusé, la sauvegarde n'est pas écrasée, et la copie de secours est
  utilisée automatiquement, avec un avertissement (`design/gdd/sauvegarde-automatique.md`,
  règle 15). Propriétaire de l'écran d'avertissement : 18.
- **Si une entrée du journal des lectures de ruine est « en attente » au chargement et
  que le fragment est déjà dans le profil** : l'entrée passe à « validée » et la ruine
  reste lue.
- **Si l'entrée est « en attente » et que le fragment est absent du profil** : l'écriture
  du profil est rejouée (idempotente par identifiant de fragment), puis l'entrée passe à
  « validée ».
- **Si l'entrée est « validée » mais que le fragment est absent du profil** (profil
  restauré plus ancien que la partie) : l'écriture du profil est rejouée de la même
  façon ; l'entrée reste « validée ».
- **Si l'application est tuée pendant l'écriture d'une sauvegarde** : la sauvegarde
  précédente reste la référence ; l'état n'expose jamais une commande à moitié
  appliquée. Propriétaire de l'écriture atomique : 16.
- **Si l'application est tuée en plein tour, sans passage en arrière-plan** : la reprise
  repart de la dernière commande appliquée (sauvegarde après chaque commande). Au milieu
  de l'exécution ennemie, l'IA reprend à la commande suivante en décidant à partir de
  l'état seul. Propriétaires : 16 et 9.

### Invariants vérifiés par la validation

- Chaque unité est sur une tuile de la carte ; deux unités ne partagent jamais une tuile.
- Tout identifiant référencé existe, ou désigne une entité détruite (l'intention qui la
  vise est alors annulée).
- Tout identifiant est inférieur au compteur de sa famille.
- Le propriétaire de chaque tuile et de chaque nœud est une faction valide ou personne.
- Une intention annoncée a un auteur vivant ; sinon elle est annulée.
- Une intention désigne sa cible par un couple (type, identifiant) ; ses tuiles d'auteur
  et de cible à l'annonce sont des tuiles de la carte.
- L'instantané de la chronique ne change pas après la création de la partie.
- **Aucune attaque sans annonce** (pilier 4) : une attaque ennemie ne s'exécute que
  contre une intention stockée dont le tour d'annonce est antérieur au tour
  d'exécution. Il n'existe aucun autre chemin d'attaque ennemie dans l'état.
- Le tour est compris entre 0 et 30 ; la faction active n'est pas éliminée, sauf si la
  partie est terminée.
- Le nombre d'unités, de nœuds et d'intentions respecte les bornes de Tuning Knobs.

### Cas à reprendre dans un autre GDD

- **Si la cible d'une intention est détruite** : l'intention est annulée, avec la raison
  « cible détruite », jamais redirigée. Propriétaire : 9.
- **Si la cible d'une intention n'est plus sur la tuile enregistrée à l'annonce** :
  l'intention est annulée avec la raison « cible déplacée ». Propriétaire : 9.
- **Si un coup validé sur l'état réel rencontre une unité cachée** (déplacement vers une
  tuile hors vue) : comportement identique pour le joueur et l'IA. Propriétaire : 23.
- **Si deux intentions visent la même cible** : elles restent valides toutes les deux et
  se résolvent par identifiant d'intention croissant. Propriétaire : 9 et 8.
- **Si la meute compte déjà 60 unités et qu'un réveil ou une production est demandé** :
  refusé, sans identifiant attribué ni énergie dépensée. Propriétaire : 6 et 7 (l'état
  fournit seulement la borne).
- **Si l'IA atteint INTENT_CAP au moment d'annoncer** : les attaques au-delà du plafond
  ne sont pas annoncées, donc pas exécutées au tour suivant. Atteindre le plafond
  signifie « l'IA n'attaque pas », jamais « une attaque non annoncée ». Propriétaire : 9.
- **Si le 30e tour est atteint pendant l'exécution ennemie** : l'exécution se termine,
  puis le statut de fin est posé. Propriétaire : 3.
- **Si la faction active est éliminée** : son tour se termine et ses intentions sont
  annulées. Propriétaire : 3 et 9.

## Dependencies

### En amont (ce système dépend de)

**Aucun.** C'est la couche Foundation de `design/gdd/systems-index.md`. Il ne dépend que
du moteur, et seulement pour les types de données de base (pas de SceneTree, pas de
Node).

### En aval (systèmes qui dépendent de lui)

Tous les autres systèmes en dépendent. Toutes ces dépendances sont **dures** : aucun ne
fonctionne sans l'état. La nature de chaque lien est détaillée dans « Interactions with
Other Systems ».

| Nature | Systèmes |
|---|---|
| **Lecture et écriture de sa tranche** | 2 Carte, 3 Tours, 5 Brouillard, 6 Unités, 9 IA, 10 Énergie, 11 Nœuds, 12 Protocoles, 13 Ruines, 15 Recoloration, 23 Commandes |
| **Écriture indirecte** (par les fonctions d'un autre propriétaire) | 7 Réveil, 8 Combat |
| **Lecture seule** | 4 Contrôles, 16 Sauvegarde, 17 HUD, 18 Menus |
| **Mise en place initiale** | 21 Génération procédurale |
| **Aucun lien direct** (passent par le profil 22 ou le bus de 23) | 14 Chronique, 19 Réglages, 20 Audio |
| **Stockage séparé, cohérence obligatoire** | 22 Profil (instantané à la création, journal des lectures de ruine, règle 10) |

### Bidirectionnalité

Aucun des systèmes en aval n'a encore de GDD. **Chaque futur GDD doit citer
`design/gdd/modele-etat-partie.md` dans sa section Dependencies** et confirmer la tranche
qu'il possède. Un écart entre le contrat d'ici et le GDD d'un système se règle en
modifiant les deux documents, jamais un seul.

### Décisions techniques renvoyées à un ADR

- Représentation (Resources, Dictionary, tableaux typés ou classes RefCounted).
- Mécanisme de copie et son coût réel sur Android (NOT SOURCEABLE).
- Format de sérialisation et migration de schéma.
- Générateur de hasard à compteur (choix de la fonction de hachage).

## Tuning Knobs

*Dérivés des variables de Formulas. Ce sont des bornes structurelles, pas des valeurs
d'équilibrage ; elles vivent dans un fichier de configuration, pas dans le code.*

| Paramètre | Valeur | Plage sûre | Trop haut | Trop bas | Interagit avec |
|---|---|---|---|---|---|
| MAX_MAP_SIZE (W et H) | 16 | 8..16 | Copie plus chère, tour d'IA hors budget de 2 s | Pas de place pour 2 tailles de carte (concept) | Formule 5 ; IA (9) ; générateur (21) |
| MAX_UNITS | 60 | 20..60 | Copie et sauvegarde plus lourdes ; IA plus lente | Le réveil (7) et la production se bloquent trop tôt ; la meute ne « grandit » plus (pilier 1) | INTENT_CAP ; unités (6), réveil (7) |
| MAX_NODES | 10 | 4..16 | Économie (10, 11) plus longue à évaluer pour l'IA | Pas assez de nœuds à capturer sur une grande carte | Carte (2), nœuds (11) |
| INTENT_CAP | 60 | 1..MAX_UNITS | Aucun effet au-delà de MAX_UNITS | L'IA ne peut plus annoncer toutes ses attaques : elle attaque moins (jamais sans annonce, voir l'invariant « Aucune attaque sans annonce ») | IA (9) ; doit rester ≤ MAX_UNITS |
| INTENT_RETENTION_TURNS | 2 | 2 | Intentions périmées gardées sans usage | En dessous de 2, une intention annoncée disparaît avant son exécution | Tours (3) |
| MAX_DRAW_N | 65 536 | 256..65 536 | Biais du modulo plus grand (négligeable jusqu'à 2¹⁶) | Certains tirages (placement parmi les tuiles) deviennent impossibles | Ruines (13), générateur (21) |
| f_clone | 25 % | 10..30 % | Moins de temps pour l'évaluation des coups de l'IA | Moins de copies, IA plus faible | Formule 5 ; IA (9) |

*systems-designer consulté pour les formules dont ces paramètres sont tirés ; pas de
consultation séparée, les paramètres ne s'influencent pas entre eux au-delà des liens
listés.*

## Visual/Audio Requirements

Aucune. Ce système n'a ni rendu ni son : il stocke le propriétaire et le dernier
changement de chaque tuile, dont la recoloration (15) déduit la couleur. Les exigences visuelles et sonores appartiennent à la
recoloration (15), au HUD (17) et à l'audio (20).

## Game Feel

Sans objet : le joueur n'agit jamais directement sur ce système. Sa seule contribution
au ressenti est indirecte et mesurable : ne jamais retarder une action (copie et
validation dans les budgets de Formulas) et reprendre la partie à l'identique (voir
Player Fantasy).

## UI Requirements

Aucune interface propre. Deux exigences pour les interfaces qui le lisent :
- le HUD (17) et les contrôles (4) ne lisent que la **vue de la faction du joueur**
  (règle 11) ;
- l'écran de reprise après une sauvegarde invalide (Edge Cases) appartient à la
  sauvegarde (16) et aux menus (18).

## Cross-References

| Document | Ce qui en est repris ou ce qui y est imposé |
|---|---|
| `design/gdd/game-concept.md` | Pilier 4 (« La puissance se mérite », IA en deux temps, intentions sauvegardées) ; Technical Considerations (état en données pures, reprise après kill, tour d'IA < 2 s, 30 fps) ; MVP Definition (point 8) |
| `design/gdd/systems-index.md` | Place du système (1, Foundation, MVP) ; notes TD-SYSTEM-BOUNDARY points 1, 2, 6 et 7 ; contrats « le score lit l'état » et « territoire écrit par 11 seulement » |
| `design/ux/hud.md` | Le HUD lit les intentions, la visibilité, les compteurs de score, le journal des lectures (fragments lus) et le dernier changement de propriétaire des tuiles (marqueurs « recolorée par une ruine » et « tuile perdue » de sa section 8, qui survivent ainsi à une reprise) ; état « Reprise après un kill » de sa section 5 |
| `design/accessibility-requirements.md` | Aucune exigence directe ; la pause partout et la sauvegarde automatique (Cognitive Accessibility) reposent sur la règle 13 |
| `docs/engine-reference/godot/breaking-changes.md` | `duplicate_deep()` (4.5+) et `FileAccess.store_*` qui renvoie `bool` : à prendre en compte dans l'ADR de représentation et dans le GDD de la sauvegarde (16) |
| GDD 2 à 23 (à écrire) | Chaque GDD confirme la tranche qu'il possède (Interactions with Other Systems) et cite ce document dans ses Dependencies |

## Acceptance Criteria

*Rédigés avec qa-lead. Étiquettes : **[U]** test unitaire dans `tests/unit/game_state/`,
**[I]** test d'intégration dans `tests/integration/game_state/`, **[P]** mesure sur
l'appareil de référence (Google Pixel, modèle à préciser). Les états de test sont
construits par des fonctions de fabrique ; le profil et l'horloge sont des doublures
injectées ; aucun accès fichier dans les tests unitaires.*

### Règles

- **AC-01 (règle 1)** [U] — **GIVEN** un état construit par la fabrique, **WHEN** on liste
  ses fonctions publiques, **THEN** on ne trouve que des accès aux données, le tirage
  borné, l'attribution d'identifiant, la copie, la conversion vers et depuis des
  données, et la validation ; aucune fonction de règle de jeu.
- **AC-02 (règle 2)** [U] — **GIVEN** un coup porté en combat, **WHEN** les PV baissent,
  **THEN** la modification passe par la fonction « modifier les PV » des unités
  (exactement un appel enregistré) et aucune autre tranche ne change.
- **AC-03 (règle 3)** [I] — **GIVEN** une partie en cours, **WHEN** l'interface, l'audio et
  les menus tournent pendant 10 images sans commande, **THEN** la révision de l'état ne
  change pas ; **WHEN** une commande valide est appliquée, **THEN** la révision augmente
  d'exactement 1.
- **AC-04 (règle 4)** [U] — **GIVEN** un état quelconque, **WHEN** un parcours récursif
  inspecte chaque valeur, **THEN** chacune est un entier, un booléen, une chaîne, ou une
  liste ou table de ces types ; aucune n'est un Node, Object, Callable, signal ou RID.
- **AC-05 (règle 5)** [U] — **GIVEN** l'unité d'identifiant k détruite, **WHEN** une unité
  est créée, **THEN** elle reçoit le prochain identifiant du compteur, jamais k.
- **AC-06 (règle 6)** [U] — **GIVEN** un état après une séquence scriptée qui utilise une
  valeur de configuration en pourcentage, **WHEN** on contrôle chaque champ de règle,
  **THEN** tous sont des entiers.
- **AC-07 (règle 7)** [U] — **GIVEN** une copie, **WHEN** on y fait 5 tirages, **THEN** le
  compteur de tirages de l'original ne change pas ; **GIVEN** un aperçu de combat,
  **WHEN** il demande un tirage, **THEN** le tirage est refusé et le compteur ne change
  pas.
- **AC-08 (règle 8)** [U] — **GIVEN** des unités insérées avec les identifiants 5, 1, 3,
  **WHEN** l'itérateur de règles les parcourt, **THEN** l'ordre est 1, 3, 5.
- **AC-09 (règles 3 et 9)** [U] — **GIVEN** une simulation de l'IA qui lit une ruine et
  porte une attaque, **WHEN** elle se termine, **THEN** la doublure du profil et le bus
  d'événements enregistrent 0 appel et l'état réel est inchangé ; **GIVEN** les mêmes
  coups passés par la couche des commandes, **THEN** les mêmes effets sont appliqués
  exactement une fois.
- **AC-10 (règle 10)** [U] — **GIVEN** la lecture d'une ruine, **WHEN** la commande est
  appliquée, **THEN** dans la même révision la ruine est lue, le journal contient une
  entrée « en attente » et la commande rend l'effet « enregistrer un fragment » ;
  **WHEN** l'écriture du profil réussit, **THEN** l'entrée passe à « validée » par la
  commande interne « valider la lecture ».
- **AC-11 (règle 11)** [U] — **GIVEN** une tuile jamais vue par la faction B et occupée
  par une unité, **WHEN** on interroge la vue de B, **THEN** la tuile est « inconnue » ;
  **GIVEN** une simulation de l'IA de B, **THEN** l'état qu'elle reçoit ne contient ni
  unité, ni nœud, ni propriétaire sur les tuiles hors de sa vue.
- **AC-12 (règle 12, test de borne)** [U] — **GIVEN** 60 unités, **WHEN** une 61e est
  demandée, **THEN** elle est refusée, aucun identifiant n'est consommé et l'énergie ne
  change pas ; de même pour un 11e nœud et une 121e intention stockée.
- **AC-13 (règle 13)** [U] — **GIVEN** un état d'une version de schéma plus récente,
  **WHEN** on le charge, **THEN** le chargement est refusé et les données d'entrée sont
  inchangées ; **GIVEN** une version plus ancienne, **THEN** les migrations s'appliquent
  dans l'ordre et la validation réussit.
- **AC-14 (règle 14)** [U] — **GIVEN** un état par invariant, chacun violant seulement
  cet invariant, **WHEN** la validation s'exécute, **THEN** elle échoue et nomme
  l'invariant violé.
- **AC-15 (règle 10, instantané)** [U] — **GIVEN** un profil doublé dont la chronique de
  la faction f vaut {1, 2}, **WHEN** une partie est créée puis la doublure est remplacée
  par un profil vide, **THEN** deux ruines de f lues ensuite donnent les fragments 3 puis
  4 : le calcul ne dépend que de l'état.
- **AC-16 (intentions)** [U] — **GIVEN** une unité et un nœud qui portent tous deux
  l'identifiant 5, et une intention visant le nœud 5, **WHEN** on résout sa cible,
  **THEN** c'est le nœud ; **GIVEN** une intention dont la cible n'est plus sur sa tuile
  d'annonce, **THEN** la tuile d'annonce stockée permet de le constater sans autre
  donnée.

### Formules

- **AC-F1 (formule 1)** [U] — **GIVEN** W = 12, **WHEN** on indexe la tuile (5, 3),
  **THEN** l'index vaut 41 ; **GIVEN** W = 12 et H = 10, **THEN** (12, 0) et (0, 10)
  sont refusées, pas ramenées dans les bornes.
- **AC-F2 (formule 2)** [U] — **GIVEN** les valeurs de référence du hachage fixées par
  l'ADR, **WHEN** draw(n) s'exécute, **THEN** les sorties correspondent exactement et le
  compteur augmente de 1 par appel ; bornes : n = 1 rend 0, n = 65 536 est accepté,
  n = 0 et n = 65 537 sont refusés sans changer le compteur. *Bloqué jusqu'à l'ADR du
  générateur de hasard.*
- **AC-F3 (formule 3)** [U] — **GIVEN** next_id[unité] = 17, **WHEN** une unité est
  créée, **THEN** elle reçoit 17 et le compteur passe à 18 ; **GIVEN** un compteur à
  2³¹ − 1, **THEN** l'attribution et sa commande sont refusées.
- **AC-F4 (formule 4)** [U] — **GIVEN** des intentions des tours n − 2, n − 1 et n,
  **WHEN** le tour n commence, **THEN** seules celles de n − 1 et n restent, et les
  nouveaux identifiants restent supérieurs aux identifiants retirés.
- **AC-F5 (formule 5)** [P] — **GIVEN** un état maximal (256 tuiles, 60 unités, 10 nœuds,
  120 intentions), **WHEN** on chronomètre 1 000 copies, **THEN** la durée médiane d'une
  copie est ≤ 200 µs (*seuil provisoire, issu de la formule 5, à confirmer par le
  prototype de l'IA*) ; **GIVEN** un tour d'IA scripté, **THEN** le 95e centile de sa
  durée est ≤ 2 000 ms.

### Entre systèmes

- **AC-X1** [I] — **GIVEN** une entrée du journal restée « en attente » et un profil
  doublé qui contient le fragment, **WHEN** la sauvegarde est rechargée, **THEN**
  l'entrée passe à « validée » et la ruine reste lue ; **GIVEN** le fragment absent,
  **THEN** l'écriture du profil est rejouée une fois ; deux rechargements successifs
  donnent toujours exactement un fragment ; **GIVEN** une entrée « validée » et un
  profil doublé plus ancien qui ne contient pas le fragment, **WHEN** la sauvegarde est
  rechargée, **THEN** le fragment est ajouté au profil.
- **AC-X2** [I] — **GIVEN** la faction de l'IA, **WHEN** son module de décision
  s'exécute, **THEN** il ne reçoit que la vue filtrée par le brouillard ; une unité
  témoin cachée dans le brouillard ne change pas les commandes choisies.
- **AC-X3** [U] — **GIVEN** un état quelconque, **WHEN** on le sérialise puis on le
  recharge, **THEN** le résultat est égal à l'original (égalité profonde, règle 13).
- **AC-X4** [U] — **GIVEN** une copie, **WHEN** on modifie chacun de ses champs
  modifiables, **THEN** l'original reste égal à un instantané pris avant.
- **AC-X5** [I] — **GIVEN** la même graine, le même instantané de la chronique et la même
  liste de commandes jouées deux fois, sans profil injecté, **WHEN** les deux parties se
  terminent, **THEN** les états finaux sont égaux et les révisions par tour concordent.
- **AC-X6 (Player Fantasy)** [I, test de jeu] — **GIVEN** une partie en cours avec une
  intention annoncée, **WHEN** l'application est fermée de force puis rouverte, **THEN**
  le même tour, la même intention et le même aperçu de combat sont affichés.
- **AC-X7** [I] — **GIVEN** un joueur qui a appliqué 3 commandes au tour n, **WHEN**
  l'application est fermée de force sans passage en arrière-plan, puis rouverte,
  **THEN** les 3 commandes sont appliquées, et le tour et la révision sont ceux d'avant
  la fermeture.

### Limites connues

- Les règles 2 et 3 (« un système n'écrit jamais la tranche d'un autre ») ne se
  prouvent pas entièrement à l'exécution : AC-02 et AC-03 les échantillonnent, une
  vérification en revue de code ou par analyse statique les complète.
- Les critères de transition entre phases sont dans `design/gdd/tours-conditions-victoire.md`.

## Open Questions

| Question | Owner | Deadline | Resolution |
|---|---|---|---|
| Représentation : Resources, Dictionary, tableaux typés ou RefCounted ? Coût de copie réel sur l'appareil de référence ? (NOT SOURCEABLE) | lead-programmer, technical-director | ADR avant le premier sprint | |
| Peut-on simuler l'IA hors du fil principal sur Android ? (NOT SOURCEABLE) ; repli prévu : travail réparti sur plusieurs images | engine-programmer | Prototype des intentions de l'IA (1 semaine, PR-SCOPE) | |
| Ordre d'itération des Dictionary dans la version installée de Godot (NOT SOURCEABLE) ; la règle 8 l'évite, mais l'ADR doit le confirmer | gameplay-programmer | ADR de représentation | |
| Comportement des entiers GDScript en cas de dépassement, pour le hachage du tirage (NOT SOURCEABLE) | gameplay-programmer | ADR du générateur de hasard | |
| INTENTIONS_PUBLIÉES : phase stockée ou étape interne de la fin de tour ? | game-designer | GDD des tours (3) | **Résolu le 2026-10-29** : étape de la fin de la phase ennemie, pas une phase stockée |
| INTENT_CAP : une intention au plus par unité ennemie ? | game-designer, ai-programmer | GDD de l'IA (9) | |
| Une ruine lue par l'IA fait-elle avancer la chronique du joueur ? (le concept fait avancer un pool quand on joue la faction ou qu'on l'affronte) | game-designer | GDD des ruines (13) | |
| Que se passe-t-il quand un coup rencontre une unité cachée (arrêt du déplacement, coup refusé) ? | game-designer, lead-programmer | GDD des commandes (23) | |
| Nombre de factions par partie (F) et de ruines par carte (R), qui fixent la taille maximale de l'état | game-designer | GDD des tours (3) et de la carte (2) | |
| Comment l'IA se souvient-elle des unités vues puis perdues de vue, si elle ne voit que sa vue filtrée ? (mémoire propre à l'IA, hors de l'état ou dans sa tranche). Contrainte : cette mémoire ne contient que ce que la faction de l'IA a réellement vu, pour que la règle 11 tienne. La réponse décide si l'IA paraît « dure » ou distraite (CD-GDD-ALIGN) | ai-programmer | GDD de l'IA (9) | |
| Modèle exact du Pixel de référence, et seuil définitif de copie (AC-F5, provisoirement 200 µs) | user, performance-analyst | Prototype des intentions de l'IA | |
| La version installée de Godot n'est pas déterminée (`VERSION.md`) : les API 4.5+ ne sont pas vérifiées localement | user | `/setup-engine` | |
