# Brouillard de guerre et vision

> **Status**: Designed (pending /design-review)
> **Author**: user + Claude (game-designer, systems-designer, art-director)
> **Last Updated**: 2026-10-30
> **Last Verified**: 2026-10-30
> **Implements Pillar**: Pilier 5 « Le brouillard cache une question » ; pilier 4 « La puissance se mérite » (les menaces sont annoncées et visibles) ; pilier 3 « Lisible comme Polytopia »
> **Creative Director Review (CD-GDD-ALIGN)**: REVISED 2026-10-30 — CONCERNS (le bord de son propre territoire de niveau 3 s'affichait atténué ; « l'IA ne triche pas » dépendait d'une question ouverte ; le brouillard comme taxe de mouvement non garanti ; PM d'une unité arrêtée non fixés) corrigées : la vue d'un nœud vaut au moins le rayon de son territoire, contrainte dure pour 9 (l'IA planifie sur un état filtré à sa vue), critère de playtest de densité des révélations, marqueur de dormant périmé dessiné comme un souvenir, déplacement consommé par une embuscade

## Summary

Le brouillard décide ce que chaque faction sait de la carte : chaque tuile est inconnue, explorée
(son terrain et son dernier propriétaire connu sont gardés, jamais les unités) ou visible. La vue vient
des unités éveillées (rayon de leur type, jusqu'à 4 pour l'Éclaireur) et des nœuds possédés (rayon 2, et 3 au niveau 3),
arrêtée par les montagnes ; chaque faction, l'IA comprise, ne lit que sa propre vue, et un refus de
commande ne révèle rien de caché. Les trois ruines tirées sont visibles sous le brouillard dès le
tour 1. Ce système existe pour que la carte pose des questions (pilier 5) sans jamais piéger le joueur
(pilier 4).

> **Quick reference** — Layer: `Feature` · Priority: `MVP` · Key deps: `Carte en tuiles et terrain, Unités drones, Nœuds`

## Overview

Le brouillard décide ce que chaque faction sait de la carte. Pour chaque faction, il tient dans la
tranche « Visibilité » de l'état (`design/gdd/modele-etat-partie.md`) deux informations par tuile :
a-t-elle **déjà été découverte**, et quel était son **dernier propriétaire vu**. La tuile est-elle **vue
maintenant** n'est pas stockée : 5 la recalcule à partir des unités et des nœuds, dans un cache hors de
l'état (décision du 2026-10-30, PR #3). Il en tire trois états —
*inconnue*, *explorée*, *visible* — que chaque faction, l'IA comprise, est seule à lire : aucun
système ne lit l'état brut en dehors de la vue de sa faction. Il possède la **portée de vue** de
chaque source (unités, nœuds possédés), la règle de **révélation** (à chaque pas d'un
déplacement, à la capture, à la destruction d'une unité qui voyait), l'**exception des ruines**
(visibles sous le brouillard) et la **mémoire** d'une tuile explorée : son terrain et le dernier
propriétaire connu, jamais les unités. La géométrie de la vue (ligne de vue arrêtée par les
montagnes) appartient à la carte (`design/gdd/carte-tuiles-terrain.md`, règle 8 et formule 3).

Il existe pour que la carte pose des questions (pilier 5) sans jamais tricher avec le joueur
(pilier 4) : tout ce qui menace une unité du joueur est **annoncé** (une unité cachée peut frapper
de plus loin que sa vue, mais seulement au titre d'une intention annoncée), et un refus de commande
ne révèle rien de caché.

*Cadrage : à la fois la couche de données (tranche Visibilité, vue filtrée) et son effet pour le
joueur (le brouillard qui recule). Aucun ADR n'existe encore sur la vue.*

## Player Fantasy

*Cadrage : à la fois direct (le brouillard qui recule) et en dessous (la vue que lisent l'IA et les
commandes). Retenu (`creative-director`, 2026-10-30) : « La lueur qui appelle » comme fantasme,
« La carte ne ment pas » comme garantie. *Le brouillard pose des questions, jamais des pièges.**

**La lueur qui appelle.** L'éclaireur avance de quatre tuiles : l'aplat sombre recule par sa lisière
d'une demi-tuile, et la lueur ocre aperçue depuis trois tours devient une ruine que l'on peut
atteindre. Un marqueur de dormant reste muet : on ne connaît pas son type. Chaque pas lève une
question, et c'est la meute elle-même qui repousse le noir (piliers 5 et 1).

**La carte ne ment pas.** Un drone entre dans une forêt et s'arrête net : un losange ennemi caché
s'y trouvait. L'arrêt est annoncé, l'ennemi apparaît, et rien ne meurt sans signal préalable. L'IA ne
sait que ce que ses propres unités voient (pilier 4).

**Règle de lecture : le gris du souvenir.** Une tuile quittée garde son terrain et son dernier
propriétaire connu, mais se vide de ses unités : on sait ce qu'on a su, pas ce qui est. Cela informe sans
faire désirer, c'est donc une règle (voir Core Rules) plutôt qu'une fantaisie.

**Ton.** Calme, attentif, silencieux, à la deuxième personne comme le Core Fantasy. Verbes concrets :
*reculer, lisière, lueur, dernier connu*. Jamais « brume », « danger » ni « mystère » plaqué : le brouillard
est un aplat, non une ambiance animée.

**Trois échecs à éviter.**
1. *Le brouillard comme taxe* : explorer coûte des tours sans rien rendre ; chaque recul doit révéler
   une ruine, un marqueur, une lisière ennemie ou un relief qui interroge (pilier 5).
2. *Le soupçon de triche* : l'IA semble savoir des choses ; elle ne lit que sa propre vue, et un refus de
   commande ne révèle rien de caché.
3. *La perte sans signal* : une unité cachée tue sans avoir été annoncée, contre le critère du pilier 4 ;
   l'embuscade arrête l'unité, elle ne la punit jamais dans le même temps.

## Detailed Design

*Décisions du 2026-10-30 : trois états par tuile (inconnue, explorée, visible) ; une tuile explorée garde
son terrain et le dernier propriétaire connu, jamais les unités ; un nœud possédé voit à rayon 2 (3 au niveau 3, jamais moins
que son territoire) et le territoire seul ne donne aucune vue ; **les trois ruines tirées sont visibles sous le brouillard dès le
tour 1**. Les valeurs chiffrées sont des valeurs de départ [PROP].*

### Core Rules

**A. Données**

1. **Tranche Visibilité, 2 octets par tuile et par faction** (budget compté dans la formule 5 du
   GDD 1). Octet 0, drapeaux : bit 1 `découverte`, bit 2 `dormant_mémorisé` (le bit 0 est toujours 0 dans l'état :
   `vue_maintenant` vit dans le **cache de vue**, hors de l'état, même disposition de bits, reconstruit
   depuis les sources au chargement et après `restore_from`)
   (règle 17). Octet 1 : `dernier_propriétaire_vu` (0 = aucun ou neutre, 1..F = faction). Indice de
   tuile = `tile_index`. 16 × 16 à deux factions : 256 × 2 × 2 = **1 024 octets** (576 en 12 × 12).
2. **Invariants** : le bit 0 stocké vaut 0 ; l'octet 1 vaut 0 tant que la tuile n'est pas découverte ;
   après recalcul, toute tuile du cache `vue_maintenant` est `découverte` (validation de l'état, règle 14 du
   GDD 1, à chaque chargement et dans les tests).
3. **Trois états dérivés** (jamais stockés) : VISIBLE si `vue_maintenant` ; EXPLORÉE si `découverte` et
   non `vue_maintenant` ; INCONNUE sinon. Ce sont les seuls que la vue d'une faction expose.
4. **Mémoire du propriétaire.** Une couche stockée par faction (octet 1), non un instantané du
   propriétaire réel : celui-ci (tranche Carte, écrite par 11) est la vérité partagée et ne peut pas
   servir de mémoire sans fuite. La mémoire d'un **nœud** est l'octet 1 de sa tuile ; son **niveau**
   hors de vue n'est pas mémorisé (aucune fuite : un nœud adverse hors de vue s'affiche sans niveau).
5. **Rafraîchissement.** Après chaque commande appliquée, une fois les écritures de territoire faites et
   la vue recalculée (règle 9), l'octet 1 de chaque tuile VISIBLE est recopié depuis le propriétaire
   réel. **Exception** : quand une tuile **perd** ou **gagne** la faction qui regarde comme propriétaire (une zone de
   ruine plus grande que le champ de vue, par exemple), cette faction l'apprend aussitôt (octet 1 mis à jour même
   hors de vue), car le pilier 4 et la puce « Nœud perdu » du
   HUD l'exigent.
6. **Les unités ne sont jamais mémorisées.** Une unité est visible si et seulement si sa tuile est
   VISIBLE pour la faction. Aucune table « unités vues » dans l'état ; une mémoire d'unités de l'IA, si
   9 en veut une, vit dans la tranche de 9.

**B. Sources et portées**

7. **Sources de la faction F** : chaque unité éveillée de F, au rayon de son type (Éclaireur 4, Sentinelle
   3, Chasseur 3, Assaut 2, Rempart 2, Ouvrier 2, Bastion 2) ; chaque nœud possédé par F, de rayon `max(2, RAYON_NIVEAU[niveau])`, soit 2 aux niveaux 1 et 2 et 3 au
   niveau 3, de sorte que la vue d'un nœud couvre toujours son propre territoire. Le
   territoire seul ne donne aucune vue. Un **dormant ne voit pas**. Chaque faction, IA comprise, a sa
   propre vue ; une faction éliminée n'est plus recalculée. Une unité voit toujours sa propre tuile.
8. **Champ de vue d'une source.** La tuile T est visible depuis V si la distance de Chebyshev est au plus
   le rayon effectif et si `bloquée(V, T)` est faux (`design/gdd/carte-tuiles-terrain.md`, formule 3).
   Rayon effectif = rayon + 1 si V est une montagne. La montagne qui bloque est elle-même visible ; une
   tuile voisine n'est jamais cachée ; le champ est borné par les bords de la carte.
9. **Recalcul.** `recalculer_vue(état, faction)` remet à zéro `vue_maintenant`, parcourt les sources par
   identifiant croissant (unités, puis nœuds), met `vue_maintenant` et `découverte` aux tuiles de leurs
   champs, puis rafraîchit l'octet 1. Il est appelé pour **les deux factions** après toute commande
   appliquée de type DÉPLACER, ATTAQUER, CAPTURER, RÉVEILLER, MONTER_NŒUD ou EXÉCUTER_UNE_INTENTION
   (déplacement, destruction d'une unité qui voyait, capture ou perte de nœud, réveil, **montée d'un nœud** dont la vue
   passe de 2 à 3 au niveau 3). Aucun recalcul pour RECHERCHER, FINIR_LE_TOUR, COMMENCER_LE_TOUR (aucune source ne
   change).
10. **Champs de vue précalculés.** Le terrain étant fixe, `champ(V, r_eff)` est une fonction pure : une
    liste ordonnée d'indices de tuiles par couple (V, r_eff), construite à la mise en place (ou
    paresseusement), conservée **hors de l'état**, partagée en lecture seule par les copies, jamais
    sérialisée ni comparée par l'égalité profonde. Le recalcul n'est alors qu'une union de listes (voir
    « Coût de calcul »).

**C. Révéler le long d'un chemin**

11. **Pas à pas.** L'application de DÉPLACER avance l'unité tuile par tuile. À chaque pas, le champ de vue
    de l'unité à sa nouvelle tuile s'ajoute à `découverte` et à `vue_maintenant` de sa faction (union avec
    les pas précédents) ; à la fin, `recalculer_vue` remet `vue_maintenant` à la situation réelle (les
    tuiles vues seulement en route deviennent EXPLORÉES).
12. **Embuscade** (cohérent avec `design/gdd/commandes-evenements.md`, règle 6) : si la tuile suivante est
    occupée par une unité (ennemie cachée ou non), le déplacement s'arrête sur la dernière tuile libre et
    l'unité rencontrée est révélée. Il n'y a **aucun arrêt automatique** pour un ennemi simplement aperçu
    à distance (sinon l'annulation d'un déplacement serait presque impossible). Un obstacle de terrain non
    découvert (eau) arrête aussi l'unité, **sans la punir** : le déplacement est consommé (« a bougé » vrai,
    points de mouvement restants perdus, `unites-drones.md`, règle 5) mais l'unité peut encore agir ; une tuile INCONNUE est supposée de coût 1 à la validation, le
    coût réel étant lu à l'application.
13. **« A révélé »** (annulation, 23 règle 15). Un déplacement a révélé si, à un moment quelconque de ses
    pas, pour la faction du joueur : (a) une tuile INCONNUE est devenue découverte ; (b) une unité
    (ennemie ou dormant) qui n'était pas visible au début l'est devenue, même si elle ne l'est plus à
    l'arrivée ; (c) l'octet 1 d'une tuile VISIBLE a changé ; (d) une embuscade a eu lieu ; (e) une ruine a
    été lue. Passer d'EXPLORÉE à VISIBLE sans rien de nouveau ne compte pas. L'instantané d'annulation
    est pris avant, donc l'annulation restaure aussi la tranche Visibilité.
14. **Événement TUILES_RÉVÉLÉES (faction, tuiles)** : un seul par commande et par faction, les tuiles
    passées de INCONNUE à découverte, triées par indice croissant, non vide. Émis **seulement pour la
    faction du joueur** (jamais pour l'IA, sinon fuite). Les passages EXPLORÉE → VISIBLE ne sont pas des
    événements : le HUD relit la vue.

**D. Ce que chaque état montre à la faction**

| Élément | INCONNUE | EXPLORÉE | VISIBLE |
|---|---|---|---|
| Terrain | Non (aplat #1E2329) | Oui, gris-bleu assombri | Oui |
| Propriétaire de tuile | Non | Dernier propriétaire vu | Réel |
| Nœud | Non | Position connue ; propriétaire = octet 1 ; niveau non mémorisé | Réel, niveau visible |
| Unités (toutes factions) | Non | **Non** | Oui, type visible |
| Unités propres | Toujours sur une tuile VISIBLE | — | — |
| Ruine non lue | Marqueur et lueur ocre (règle 15) | idem | idem |
| Dormant | Marqueur gris, type inconnu (règle 17) | Marqueur ; type connu si la tuile a été vue | Type visible |
| Intention annoncée | Marqueur sur la cible si la cible est propre (règle 21) | idem | idem |

15. **Ruines.** Les ruines **tirées** (les trois du MVP, jamais les neuf candidats) et non lues sont
    visibles dès le tour 1 sous le brouillard, pour la faction du joueur : marqueur et lueur ocre, avec la
    puce « Ruine repérée · n tuiles » (distance de Chebyshev à la plus proche non lue). Raison : le test
    de l'identité visuelle (une ruine se repère depuis l'autre bout de l'écran) et le « premier fragment
    avant le tour 5 » ; le tirage par zones (carte, règle 12) rend l'emplacement imprévisible d'une partie
    à l'autre (pilier 5), et la question du brouillard devient « qu'y a-t-il entre moi et elle ? ». Une
    ruine lue passe en glyphe lu, hors puce. Pour l'IA, voir Open Questions.
16. **Pas de ruine ni de nœud entièrement cachés par une montagne** (carte, règle 16) : cette règle porte
    sur le terrain, non sur l'exception des ruines.
17. **Dormants.** Au démarrage, le bit 2 `dormant_mémorisé` est posé, pour chaque faction, sur la tuile de
    chaque dormant : le marqueur est visible partout, même INCONNUE, type inconnu. Il est effacé quand la
    tuile est VISIBLE et ne porte plus de dormant. Hors de vue, un réveil par l'autre faction ne change
    donc rien à l'affichage : aucune fuite. Le type s'affiche dès que la tuile est découverte. Le marqueur
    est un point d'intérêt, non une « unité » au sens de la mémoire. Un marqueur devenu périmé (réveil par
    l'autre faction hors de vue) est de la **mémoire, non un mensonge** : il est dessiné comme un souvenir
    (assombri comme une tuile EXPLORÉE) tant que la tuile n'est pas redevenue VISIBLE.

**E. Information cachée**

18. **ATTAQUER** : la cible est valide si son identifiant désigne une unité dont la tuile est VISIBLE pour
    l'attaquant ; sinon CIBLE_NON_VISIBLE, **même code et mêmes paramètres** pour « cachée »,
    « inexistante », « dormant caché » et « identifiant périmé » (`design/gdd/combat.md`). La règle vaut
    pour l'IA, validée sur sa vue (le refus compte dans `N_REFUS_MAX`).
19. **Aucun refus ne révèle.** Toute validation ne lit que la vue de la faction ; une tuile INCONNUE
    répond « inconnue » ; RÉVEILLER vers un dormant caché donne AUCUN_DRONE_ADJACENT.
20. **Événements de l'autre faction.** Le HUD ne montre un événement de l'autre faction que si ses tuiles
    étaient VISIBLES du joueur avant ou après la commande ; sinon il est omis ou générique. Le filtre est
    une fonction pure de ce système : `événement_visible(vue, événement)`.
21. **Intentions (pilier 4).** Une intention dont la **cible** est une unité ou un nœud du joueur est
    affichée sur la tuile de la cible (hachures, « ! »), que l'auteur soit visible ou non : l'unité du
    joueur voit toujours sa propre tuile, et un nœud possédé aussi. Le contour de l'auteur n'est dessiné
    que si sa tuile est VISIBLE, et le HUD ne reçoit sa position que dans ce cas.

**F. Début et chargement**

22. **Mise en place.** Toutes les grilles à zéro ; bit 2 des dormants posé (règle 17) ; `recalculer_vue`
    pour chaque faction à partir de ses unités de départ et de son nœud de départ ; **le territoire de
    chaque nœud possédé est au moins EXPLORÉ** (la faction connaît sa terre). Le joueur connaît donc sa zone
    de départ, les ruines tirées et les dormants (marqueurs) ; il ne sait rien du camp ennemi, à 8 ou 9 tuiles.
23. **Territoire et vue.** La vue d'un nœud vaut au moins son rayon de territoire (règle 7) : son territoire
    est VISIBLE en entier, jamais atténué à son bord. Une tuile de territoire que plus aucune source ne
    couvre (nœud perdu) est EXPLORÉE, jamais INCONNUE.
24. **Sauvegarde et chargement.** La tranche Visibilité est sérialisée telle quelle (`découverte`, octet 1,
    `dormant_mémorisé`). Au chargement, le cache `vue_maintenant` est **reconstruit** depuis les sources ; si une
    tuile du cache n'est pas `découverte`, l'état est **corrompu et le fichier est refusé** (repli sur la copie de secours, ADR-0006 ; décision de l'ADR-0007, `from_bytes` ne répare jamais l'état) ; le cache de
    champs de vue (règle 10) est reconstruit depuis le terrain. Même sauvegarde, même vue.

24bis. **Exception : le score décisif (17, E07).** Le score exact des deux camps est le seul agrégat public calculé sur des données hors vue : il dit « combien », jamais « où ». Aucune décomposition ni aucun delta n'est affiché, il se met à jour à l'idle de début de tour sans animation de variation (`design/gdd/hud-systeme.md`, règles 4 et 23). La règle 4 du HUD (« vue du joueur seulement ») s'entend sauf cet agrégat.
25. **Contrainte dure pour l'IA (9).** « L'IA ne triche pas » n'est vrai que si elle **planifie sur un état
    filtré à sa vue** : un état complet dont on saute seulement le recalcul de la vue connaîtrait encore la
    position des unités cachées du joueur. Toute simulation de l'IA part d'un état **reconstruit à partir de sa vue**
    (règle 11 du GDD 1 : terrain découvert, unités visibles, propriétaires vus ; hors vue, ni unité, ni nœud, ni
    propriétaire) ; aucune unité cachée du joueur n'y figure.

### Coût de calcul (estimations à mesurer)

*Vitesse de GDScript sur mobile : NOT SOURCEABLE ; hypothèse de 10 à 30 millions d'opérations simples par
seconde.*

- **Recalcul naïf** (sans cache) : 60 unités réparties 30 / 30 plus 5 nœuds par faction, rayon moyen 2,4,
  soit environ 35 tuiles testées par source et environ 1 200 tests par faction ; chaque test (Chebyshev et
  tracé de Bresenham d'au plus 4 cases) coûte 40 à 50 opérations : **2 à 6 ms par faction**, 4 à 12 ms
  pour les deux. Pire cas (60 unités de rayon 4, 81 tuiles) : 4 860 tests, 10 à 25 ms.
- **Avec champs précalculés (règle 10)** : le calcul de chaque couple est fait une fois, 22 320 tests en
  12 × 12 et 39 680 en 16 × 16 (3 couples de rayon effectif distincts par tuile ; quelques ms, une fois,
  paresseux possible), pour **quelques dizaines de ko hors état** ; un recalcul n'est plus
  qu'une union de listes, environ 1 000 écritures d'octet par faction : **0,1 à 0,3 ms** par faction.
- **Seuil** : si la mesure sur l'appareil de référence dépasse **1 ms par commande** (deux factions),
  passer à un compteur par tuile (1 octet par tuile et par faction, hors état, reconstruit au chargement).
- **Copies de l'IA** : le budget de 2 500 copies par tour d'IA ajouterait 750 ms au recalcul seul ; la
  copie de simulation ne recalcule donc pas la vue, ou seulement celle de l'IA, ou l'IA planifie sur sa
  vue figée au début de la planification (contrainte dure de la règle 25, à réaliser par 9).

### States and Transitions

États par tuile et par faction (dérivés des bits) :

| État | Depuis | Déclencheur | Écritures |
|---|---|---|---|
| INCONNUE | — (initial) | Mise en place | Tous les bits à 0 |
| VISIBLE | INCONNUE, EXPLORÉE | Une source de la faction couvre la tuile (règles 9 et 11) | Bits 0 et 1 à 1 ; octet 1 = propriétaire réel |
| EXPLORÉE | VISIBLE | Plus aucune source ne couvre la tuile (unité partie, détruite ou réveillée ailleurs, nœud perdu) | Bit 0 à 0 ; octet 1 conservé |
| (INCONNUE) | — | **Aucun retour** : `découverte` ne repasse jamais à 0 | — |

Transitions interdites : INCONNUE → EXPLORÉE (un pas intermédiaire donne d'abord VISIBLE) ; EXPLORÉE → INCONNUE.
Machine par commande : validation sur la vue, application, recalcul des vues (règle 9), rafraîchissement de
la mémoire, événements (TUILES_RÉVÉLÉES, etc.), booléen `a_révélé` pour 23.

### Interactions with Other Systems

| # | Système | Contrat | Propriétaire de l'interface |
|---|---|---|---|
| 1 | État | Possède le conteneur 2 octets / tuile / faction ; 5 en est le seul écrivain ; la vue est la seule lecture permise aux factions (règle 11 du GDD 1) | 1 pour la forme, 5 pour les écritures |
| 2 | Carte | Fournit terrain, ligne de vue (formule 3), `tile_index`, ruines tirées ; ne fournit pas la portée | 2 pour la géométrie, 5 pour la portée |
| 4 | Contrôles | Lit uniquement la vue du joueur ; l'aperçu de portée ne couvre que des tuiles non INCONNUES | 4 |
| 6 | Unités | Fournit tuile, faction, type, `endormie` ; les valeurs de vision vivent dans `assets/data/units.*`, possédées par 5 ; appelle `recalculer_vue` après une destruction | 5 pour les valeurs |
| 8 | Combat | Valide CIBLE_NON_VISIBLE par `unité_visible(vue, id)` ; recalcul après chaque destruction | 5 |
| 9 | IA | Ne lit que sa vue ; ne reçoit ni unité cachée ni octet 1 de l'adversaire | 9 pour sa mémoire éventuelle |
| 11 | Nœuds | Fournit les nœuds possédés (sources, rayon 2) ; écrit le propriétaire réel, 5 le recopie dans l'octet 1 des tuiles visibles | 11 pour la donnée |
| 13 | Ruines | Fournit ruines tirées et lues ; une lecture compte comme « a révélé » | 13 |
| 15 | Recoloration | Lit le propriétaire réel ; le rendu hors de vue utilise l'octet 1 (présentation de 17) | 15 |
| 17 | HUD | Lit la vue ; puce de ruine ; marqueurs d'intention (règle 21) ; filtre d'événements (règle 20) | 17 |
| 23 | Commandes | Valide sur la vue ; appelle `recalculer_vue` directement ; consomme `a_révélé` pour ANNULER ; DÉPLACEMENT_A_RÉVÉLÉ | 23 |

## Formulas

*Proposées par systems-designer ; les lignes de vue ont été recalculées à la main avec la boucle de
Bresenham de la carte. Les coûts de calcul sont des **estimations à mesurer**.*

### 1. État de visibilité d'une tuile

The visibility_state formula is defined as:

`état(T, F) = VISIBLE si b0 ; EXPLORÉE si b1 ∧ ¬b0 ; INCONNUE sinon`, avec l'invariant `b0 ⇒ b1`

**Variables:**

| Variable | Type | Range | Source | Description |
|---|---|---|---|---|
| b0 | bool | {0, 1} | calculated | Bit 0 du cache de vue (hors de l'état) : `vue_maintenant` |
| b1 | bool | {0, 1} | calculated | Bit 1 : `découverte` |
| état | énumération | {INCONNUE, EXPLORÉE, VISIBLE} | calculated | Jamais stocké (règle 3) |

**Output Range:** 3 valeurs ; le bit 2 (`dormant_mémorisé`) est ignoré ; la combinaison (b0 = 1, b1 = 0) est invalide : état corrompu, signalé par la validation, jamais interprété.
**Example:** octet 0 = `0b011` → VISIBLE ; `0b010` → EXPLORÉE ; `0b110` → EXPLORÉE (dormant mémorisé) ; `0b000` → INCONNUE ; `0b001` → invalide.

### 2. Champ de vue d'une source

The sight_field formula is defined as:

`r_eff = rayon + [terrain(V) = montagne]` ; `in_field(V, T) = cheb(V, T) ≤ r_eff ∧ T ∈ carte ∧ ¬bloquée(V, T)`

`bloquée` est la formule 3 de la carte (Bresenham, départage D = 0 : l'axe mineur n'avance pas), reprise telle quelle.

**Variables:**

| Variable | Type | Range | Source | Description |
|---|---|---|---|---|
| rayon | int | 2..4 | data file (`assets/data/units.*`) | Éclaireur 4 ; Sentinelle, Chasseur 3 ; autres 2 ; nœud : max(2, rayon de territoire) |
| r_eff | int | 2..5 | calculated | Rayon + 1 sur montagne |
| cheb(V, T) | int | 0..15 | calculated | max(\|dx\|, \|dy\|) |
| bloquée(V, T) | bool | {0, 1} | calculated | Carte, formule 3 ; toujours faux depuis une montagne |

**Output Range:** booléen. Maximum (2·r_eff + 1)² tuiles : 81 (rayon 4 en plaine), 121 (Éclaireur sur montagne). Minimum 1 (sa propre tuile). Un voisin n'est jamais caché.
**Example A (montagne entre l'éclaireur et la cible).** Fenêtre 5 × 5 ; Éclaireur (rayon 4, plaine) en V = (0, 2), montagne en (2, 2). T = (3, 0) : intérieur (1, 0), (2, 0), la montagne bloque → **cachée**. T = (4, 1) : D = −2 ; (1, 0) donne D = 0, départage, l'axe mineur n'avance pas ; (2, 0) → **cachée**. T = (3, 1) : intérieur (1, 0), (2, 1) → **visible**. T = (4, 2) : intérieur (1, 0), (2, 1), (3, 1) → **visible**. T = (3, 2) : intérieur (1, 1), (2, 1) → visible. Cachées : (3, 2), (4, 2), (4, 1), (4, 3) selon la symétrie en y, soit 4 tuiles ; la montagne (2, 2) est visible ; 25 − 4 = **21 tuiles visibles** dans la fenêtre.
**Example B (l'éclaireur sur la montagne).** V = (5, 5) sur montagne, 12 × 12 : r_eff = 5, `bloquée` faux pour toute cible ; champ x 0..10, y 0..10 = **121 tuiles**, au lieu de 81. Une montagne en (6, 5) n'empêche pas de voir (8, 5).

### 3. Union des champs

The visible_union formula is defined as:

`visible(F) = ⋃_{s ∈ sources(F)} { T : in_field(pos(s), T) }`

**Variables:**

| Variable | Type | Range | Source | Description |
|---|---|---|---|---|
| sources(F) | ensemble | 0..65 | calculated | Unités éveillées et nœuds possédés (règle 7) |
| pos(s) | tuile | sur la carte | calculated | Tuile de la source |
| visible(F) | ensemble de tuiles | 0..W·H | calculated | Bits 0 posés par `recalculer_vue` |

**Output Range:** 0..W·H ; l'union est idempotente et indépendante de l'ordre.
**Example:** 12 × 12 sans montagne. Éclaireur (rayon 4) en (5, 5) : x 1..9, y 1..9 = 81. Nœud (rayon 2) en (8, 5) : x 6..10, y 3..7 = 25. Intersection : x 6..9 × y 3..7 = 20. Union = 81 + 25 − 20 = **86**.

### 4. Budget d'octets de la tranche Visibilité

The visibility_budget formula is defined as:

`octets = (2 + L) × W × H × F`

**Variables:**

| Variable | Type | Range | Source | Description |
|---|---|---|---|---|
| W, H | int | 12..16 | data file | Taille de la carte |
| F | int | 2 | constant | Factions |
| L | int | {0, 1} | constant [PROP] | Octet de niveau de nœud optionnel (0 retenu) |

**Output Range:** 12 × 12 : 576 (L = 0), 864 (L = 1) ; 16 × 16 : 1 024 (L = 0), 1 536 (L = 1). L = 1 contredit la règle 4 (niveau non mémorisé) : à n'adopter que par décision explicite.
**Example:** 2 × 12 × 12 × 2 = 576 ; 2 × 16 × 16 × 2 = 1 024.

### 5. Coût d'un recalcul complet

The recompute_cost formula is defined as:

`tests = Σ_s (2 × r_eff(s) + 1)²` (écrêté par les bords) ; `temps = tests × ops_par_test / ops_par_seconde`

**Variables:**

| Variable | Type | Range | Source | Description |
|---|---|---|---|---|
| r_eff(s) | int | 2..5 | calculated | Voir formule 2 |
| ops_par_test | int | 40..50 | constant [estimation] | Chebyshev et Bresenham d'au plus 4 cases |
| ops_par_seconde | int | 10 à 30 millions | constant [hypothèse non sourcée] | GDScript mobile |

**Output Range:** toutes les valeurs sont des estimations à mesurer.

| Cas (par faction) | Sources | Tuiles par source | Tests |
|---|---|---|---|
| Unités de rayon 2 | 30 | 25 | 750 |
| Éclaireurs de rayon 4 | 5 | 81 | 405 |
| Nœuds de rayon 2 | 5 | 25 | 125 |
| **Typique** | 40 | — | **1 280** (2 560 pour deux factions) |
| **Pire cas** (60 unités de rayon 4) | 60 | 81 | **4 860** |

- Naïf, typique, deux factions : 2 560 × 40 à 50 = 102 400 à 128 000 opérations, soit **3,4 à 12,8 ms** ; pire cas 6,5 à 24,3 ms.
- Précalcul : 3 couples (V, r_eff) distincts par tuile, soit 25 + 49 + 81 = 155 tests par tuile : **22 320** en 12 × 12 et **39 680** en 16 × 16, amortis après 9 à 16 recalculs naïfs.
- Avec précalcul : environ 2 560 écritures d'octet × 2 à 5 opérations = **0,2 à 1,3 ms** pour les deux factions ; le seuil de 1 ms peut être touché sur le matériel le plus lent, d'où la bascule prévue vers un compteur par tuile.
**Example:** 5 éclaireurs : 5 × 81 = 405 tests ; à 45 opérations et 20 millions par seconde : 0,9 ms.

### 6. Prédicat « a_révélé »

The has_revealed formula is defined as:

`a_révélé = ∃ pas s ∈ 1..n : (a_s ∨ b_s ∨ c_s ∨ d_s ∨ e_s)`

avec a_s : ∃T, état₀(T) = INCONNUE ∧ découverte_s(T) ; b_s : ∃u, ¬vis₀(u) ∧ vis_s(u) ; c_s : ∃T, état_s(T) = VISIBLE ∧ octet1_s(T) ≠ octet1₀(T) ; d_s : embuscade au pas s ; e_s : ruine lue au pas s.

**Variables:**

| Variable | Type | Range | Source | Description |
|---|---|---|---|---|
| état₀, octet1₀ | tranche | — | calculated | Vue du joueur avant la commande (instantané d'annulation) |
| vis₀(u), vis_s(u) | bool | {0, 1} | calculated | Unité (ennemie ou dormant) visible au début, puis au pas s |
| n | int | 1..PM max | calculated | Pas du chemin appliqués |

**Output Range:** booléen, pour la faction du joueur seulement ; vrai interdit ANNULER (23, règle 15) ; EXPLORÉE → VISIBLE sans rien de nouveau donne faux.
**Example:** Ouvrier (rayon 2) en (3, 3), de (3, 3) à (6, 3) ; avant : tout est découvert sauf la colonne x = 8, y 1..5. Pas 1 et 2 : rien d'inconnu ; pas 3 en (6, 3) : champ x 4..8 → 5 tuiles découvertes. `a_révélé` = **vrai** ; TUILES_RÉVÉLÉES = [20, 32, 44, 56, 68] (indice y·12 + x pour (8, 1) à (8, 5)).

### 7. Distance à la ruine non lue la plus proche (puce du HUD)

The ruin_chip_distance formula is defined as:

`d_ruine = min_{r ∈ ruines_tirées_non_lues} min_{p ∈ pièces(joueur)} cheb(p, r)`

**Variables:**

| Variable | Type | Range | Source | Description |
|---|---|---|---|---|
| ruines_tirées_non_lues | ensemble | 0..3 | calculated | Les trois ruines tirées moins les lues |
| pièces(joueur) | ensemble | 1..35 | calculated | Unités éveillées et nœuds du joueur |
| d_ruine | int | 1..15 | calculated | Texte « Ruine repérée · n tuiles » |

**Output Range:** entier ≥ 1 ; **indéfini si l'ensemble est vide : la puce est masquée**. Le point de départ (toutes les pièces) est une hypothèse (voir Open Questions).
**Example:** ruines (9, 2), (2, 10), (10, 10) ; unités (3, 3), (4, 6) ; nœud (2, 2). Depuis (4, 6) vers (2, 10) : 4, le minimum. Puce : « Ruine repérée · 4 tuiles ».

## Edge Cases

*Proposés par systems-designer ; les résolutions du 2026-10-30 sont intégrées.*

- **Si la seule unité d'une faction qui couvrait une tuile T est détruite**: après `recalculer_vue`, T passe VISIBLE → EXPLORÉE ; son terrain et l'octet 1 restent ; les unités ennemies qui s'y trouvent disparaissent de la vue de cette faction ; aucun TUILES_RÉVÉLÉES (pas d'INCONNUE). L'autre faction n'est pas modifiée si ses sources sont intactes.
- **Si un nœud est perdu (capture ennemie)**: sa source de rayon 2 disparaît du recalcul de l'ancien propriétaire ; les tuiles couvertes par aucune autre source passent EXPLORÉES ; l'ancien propriétaire apprend le changement aussitôt (règle 5, exception) ; le capteur gagne la source dans la même commande.
- **Si RÉVEILLER éveille une unité au bord du brouillard**: le recalcul des deux factions l'ajoute comme source à son rayon de type ; les tuiles INCONNUES de son champ deviennent découvertes et un TUILES_RÉVÉLÉES est émis pour le joueur si c'est sa propre unité ; le bit 2 de sa tuile est effacé. Avant le réveil, un dormant ne voyait rien.
- **Si un éclaireur se déplace de 4 tuiles et révèle une crête de montagnes** (de (1, 5) à (5, 5), montagnes en (7, 3)..(7, 7)): la crête est VISIBLE ; derrière elle restent non vues 16 tuiles, (8, 2)..(8, 8) et (9, 1)..(9, 9) ; rien n'est mémorisé de ce qui est derrière ; les ruines tirées qui s'y trouvent restent visibles par l'exception de la règle 15.
- **Si une ligne de vue passe exactement par un coin (D = 0)**: l'axe mineur n'avance pas (formule 3) ; de V (0, 0) vers T (2, 1), seule (1, 0) est testée ; de T vers V, seule (1, 1). La vue est calculée depuis la source : une montagne en (1, 0) cache T à V, pas V à T. Asymétrie acceptée par la carte.
- **Si la ligne de vue traverse de l'eau**: elle n'est pas bloquée, seules les montagnes bloquent.
- **Si une unité sur une montagne regarde d'autres montagnes**: `bloquée` est faux et r_eff = rayon + 1 ; jusqu'à 121 tuiles pour un Éclaireur.
- **Si une tuile passe de VISIBLE à EXPLORÉE**: les unités (toutes factions) disparaissent de la vue ; le terrain et le dernier propriétaire vu restent ; le niveau d'un nœud n'est pas mémorisé.
- **Si une faction perd une tuile qu'elle ne voit pas**: l'octet 1 est mis à jour aussitôt à la valeur réelle (règle 5, exception) ; les autres changements hors de vue restent inconnus.
- **Si une unité ennemie se déplace dans le brouillard**: aucun événement affiché (règle 20) ; aucun TUILES_RÉVÉLÉES (jamais pour l'IA) ; si l'une de ses tuiles est VISIBLE avant ou après, l'événement est montré.
- **Si une cible d'ATTAQUER sort de la vue entre l'aperçu et la confirmation**: la validation à la confirmation lit la vue actuelle et refuse CIBLE_NON_VISIBLE, même code et mêmes paramètres que pour « inexistante » ; aucune écriture.
- **Si une intention annoncée de l'IA vise une unité du joueur et que son auteur est dans le brouillard**: le marqueur (hachures, « ! ») est dessiné sur la tuile cible, toujours VISIBLE ; ni le contour de l'auteur ni sa position n'atteignent le HUD (règle 21).
- **Si un déplacement entre dans le brouillard vers une tuile voisine d'une eau non découverte**: l'unité s'arrête sur la dernière tuile franchissable (règle 12) ; la tuile d'eau devient découverte ; `a_révélé` est vrai par (a) et l'annulation est refusée. Le déplacement est consommé (« a bougé » vrai, PM restants perdus) mais l'unité peut encore agir.
- **Si un déplacement ne révèle rien de neuf** (EXPLORÉE → VISIBLE seulement): `a_révélé` est faux, ANNULER est permis, la tranche Visibilité est restaurée. **Si un pas découvre une tuile INCONNUE autour d'une ruine**: vrai par (a). **Si la ruine est lue**: vrai par (e), annulation refusée.
- **Si l'autre faction réveille un dormant hors de la vue du joueur**: le marqueur (bit 2) reste affiché jusqu'à ce que la tuile soit VISIBLE ; il est alors effacé s'il n'y a plus de dormant. Aucune fuite.
- **Si une ruine est lue**: son marqueur est remplacé par le glyphe « lu » et elle sort de la puce ; la distance est recalculée sur les autres ; s'il n'en reste aucune, la puce est masquée.
- **Si un chargement trouve un bit 0 stocké non nul**: il est ignoré et remis à 0, avec une trace au journal de développement ; le cache `vue_maintenant` est recalculé ; si une tuile recalculée VISIBLE a `découverte` = 0, le fichier est refusé comme corrompu (invariant b0 ⇒ b1, ADR-0007), sans correction silencieuse.
- **Si une sauvegarde est rechargée puis resérialisée sans commande**: la tranche est identique octet pour octet (576 ou 1 024 octets) ; le cache de champs n'est ni écrit ni comparé.
- **Si une faction est éliminée**: à l'élimination, son cache `vue_maintenant` est vidé (tuiles EXPLORÉES) et elle n'est plus recalculée ; `découverte` et l'octet 1 sont conservés. À valider.
- **Si le drapeau d'IA passive est actif**: la vue de l'IA est quand même recalculée à chaque commande listée (règle 9), car la validation et les tests la lisent ; elle ne sert à aucune décision.
- **Si une source se trouve au bord d'une carte 16 × 16** (rayon 4 en (0, 0)): le champ est écrêté à x, y ∈ 0..15 : 25 tuiles au lieu de 81 ; aucun repli de l'autre côté.
- **Si deux sources couvrent la même tuile à la même distance**: la tuile est posée une fois (union idempotente) ; l'octet 1 vient du propriétaire réel, non de la source.
- **Si c'est le premier tour**: seuls les champs de départ, le territoire des nœuds possédés (au moins EXPLORÉ, règle 22), les marqueurs de dormants et les trois ruines tirées sont connus ; le camp ennemi est INCONNU ; toute ATTAQUER vers lui est refusée CIBLE_NON_VISIBLE.

### Cas à traiter dans d'autres GDD

- **23 Commandes**: filtre `événement_visible` (règle 20) ; format de TUILES_RÉVÉLÉES (un par commande, faction du joueur seule, triées) ; événement « unité aperçue » (cas b de `a_révélé`) ; PM restants après un arrêt devant une eau non découverte.
- **1 État**: disposition des bits, invariants (b0 ⇒ b1, octet 1 = 0 si non découverte), validation « stocké = recalculé », octet de niveau optionnel (formule 4).
- **2 Carte**: exception « ruine visible sous le brouillard » contre la règle 16 ; asymétrie de la vue au départage de coin ; formule 3 comme seule source de `bloquée`.
- **6 Unités**: propriété des valeurs de vision ; appel de `recalculer_vue` après destruction.
- **8 Combat**: `unité_visible` à la confirmation, recalcul après chaque destruction.
- **9 IA**: mémoire d'unités éventuelle ; copies de simulation qui ne recalculent pas la vue ou la figent ; ruines pour l'IA.
- **11 Nœuds**: source de rayon 2 au changement de propriétaire ; rayon de territoire 3 contre vue 2.
- **13 Ruines**: règle « ruine visible » ; lecture = « a révélé » ; glyphe « lu ».
- **15 Recoloration**: rendu hors de vue par l'octet 1, jamais par le propriétaire réel.
- **17 HUD**: rendu de l'état EXPLORÉE ; pas de niveau de nœud en mémoire ; puce « Ruine repérée » ; puce « Nœud perdu ».
- **Art bible, section 6**: teinte EXPLORÉE, lisière, marqueur de dormant gris, lueur des ruines.

## Dependencies

### En amont (ce système dépend de)

| Système | Nature | Dure ou souple |
|---|---|---|
| 2 Carte en tuiles et terrain | Terrain, ligne de vue (formule 3), indices de tuile, ruines tirées (`design/gdd/carte-tuiles-terrain.md`) | Dure |
| 6 Unités drones | Position, faction, type, état endormi ; valeurs de vision (`design/gdd/unites-drones.md`) | Dure |
| 11 Nœuds | Nœuds possédés (sources, rayon 2), propriétaire réel (`design/gdd/noeuds.md`) | Dure |

Dépendances de contrat : 1 (conteneur de la tranche), 23 (recalcul après commande, événements).

### En aval (systèmes qui dépendent de lui)

| Système | Ce qu'il utilise | Dure ou souple |
|---|---|---|
| 4 Contrôles tactiles | Vue du joueur, aperçu de portée | Dure |
| 8 Combat | Visibilité de la cible (`unité_visible`) | Dure |
| 9 IA | Sa vue filtrée, rien d'autre | Dure |
| 13 Ruines | Visibilité des ruines, lecture = « a révélé » | Dure |
| 15 Recoloration | Dernier propriétaire vu hors de vue | Dure |
| 17 HUD | Vue, puce de ruine, marqueurs d'intention, filtre d'événements | Dure |
| 23 Commandes | Validation sur la vue ; `a_révélé` pour l'annulation | Dure |

### Bidirectionnalité

- `design/gdd/modele-etat-partie.md`, `design/gdd/carte-tuiles-terrain.md`, `design/gdd/unites-drones.md`, `design/gdd/noeuds.md`, `design/gdd/combat.md` et `design/gdd/controles-tactiles-camera.md` citent déjà ce système.
- `design/ux/hud.md` doit le citer (états du brouillard, puce de ruine, marqueurs d'intention).
- Les GDD 9, 13, 15 et 17 doivent le citer à leur création.

### Décisions techniques renvoyées à un ADR

- Précalcul des champs de vue et son stockage hors de l'état ; compteur par tuile si le recalcul dépasse 1 ms.
- Rendu du brouillard dans le renderer Mobile (fondu transparent ou tuiles opaques).

## Tuning Knobs

*Dans `assets/data/units.*` pour les rayons de vue des types, et `assets/data/brouillard.*` pour le reste.
Valeurs de départ [PROP], à jouer en test.*

| Paramètre | Valeur | Plage sûre | Trop haut | Trop bas | Interagit avec |
|---|---|---|---|---|---|
| Rayon de vue par type | Éclaireur 4 ; Sentinelle et Chasseur 3 ; autres 2 | 1..5 | La carte se révèle trop vite (pilier 5) ; l'Éclaireur écrase les autres | Marche à l'aveugle ; un voisin à 1 reste toujours vu | Types d'unités (6) |
| Rayon de vue d'un nœud | max(2, rayon de territoire) | 2..4 | Surveillance excessive des abords | Le bord de son territoire s'atténue | Rayon de territoire (11) |
| Bonus d'une montagne | +1 | 0..2 | Les sommets dominent la carte | La montagne perd son intérêt de vue | Carte (2) |
| Ruines visibles dès le tour 1 | 3 tirées | tirées / à portée / découvertes | Aucune question sur « où » | La ruine devient une corvée de recherche | Ruines (13), premier fragment avant le tour 5 |
| Seuil de bascule du recalcul | 1 ms par commande | 0,5..2 ms | — (mesure) | — | Compteur par tuile |
| Mélange d'une tuile EXPLORÉE vers le brouillard | à fixer au prototype | — | La mémoire se confond avec l'inconnu | La mémoire se confond avec le visible | Art bible, section 6 |

## Visual/Audio Requirements

*Rédigé d'après la consultation de l'`art-director` du 2026-10-30 et l'art bible (sections 1, 2, 6, 7, 8).*

- **Trois états lisibles en niveaux de gris.** INCONNUE : aplat #1E2329, aucun relief. EXPLORÉE : le même
  terrain gris-bleu, mélangé vers #1E2329 par **un seul facteur** (réglage à fixer au prototype), sous la
  valeur de la tuile VISIBLE la plus sombre (l'eau). Le dernier propriétaire garde sa teinte de faction,
  saturation réduite et valeur baissée par le même mélange, sans le motif de faction (réservé aux nœuds).
  Garde-fou : la teinte résiduelle ne tombe jamais sur #4E5862 (« abandon ») ni ne vire à l'ocre (ruines) ;
  à valider en capture grise et en simulation daltonienne. Aucune donnée nouvelle : c'est le paramètre de
  saturation par tuile déjà prévu.
- **Révélation.** La lisière recule en 200 ms, ralentie en fin de course, sans rebond ; chaque pas d'un
  déplacement révèle ses tuiles au rythme de l'unité, dans l'ordre de la distance à l'unité. Animations
  réduites : apparition directe. VISIBLE → EXPLORÉE : fondu de 150 ms de la tuile, les unités disparaissant
  instantanément (information exacte). Aucune animation pour les révélations de l'IA (fuite).
- **Ruine et dormant.** Ruine : glyphe d'arche brisée et lueur ocre radiale, matériau à part, dessinés
  **après** le brouillard. Dormant : marqueur gris à contour hexagonal pointillé d'environ la moitié de la
  tuile, un point central, sans trait de type ni motif ; il se distingue de l'unité éveillée (pleine, 70 à
  80 % de la tuile, avec trait) et de la ruine (courbe, ocre, haute). Repli si le pointillé ne tient pas à
  31 pt : contour plein gris plus clair. À la découverte de la tuile, le marqueur grandit jusqu'à la
  silhouette endormie du type en 200 ms (apparition directe en mouvement réduit).
- **Nœud adverse mémorisé.** La forme à trois hexagones, la teinte et le motif du dernier propriétaire, tous
  les anneaux **en contour** (aucun plein) : l'état « niveau inconnu » ne ressemble jamais au niveau 1.
- **Intention hors de vue.** Hachures orange-rouge à 135° et « ! » blanc cerné de sombre sur la tuile du
  joueur ; ni contour d'auteur, ni flèche, ni ligne (la direction fuirait la position).
- **Renderer Mobile.** Le fondu transparent d'une demi-tuile n'est qu'une option mesurée ; pas de plan plein
  écran, une seule bande de lisière. Repli : tuiles opaques, la quantité de brouillard étant dans les mêmes
  données par instance que la saturation (aucun appel de dessin en plus), la lisière devenant un palier
  intermédiaire par tuile. Sous le brouillard, une montagne ou une forêt ne doit pas dépasser en silhouette :
  les tuiles INCONNUES sont aplaties ou masquées dans les deux options, les unités hors de vue masquées par
  instance. Le shader interpole depuis un temps de départ (pas de mise à jour CPU à chaque image). À
  confirmer par le technical-artist.
- **Audio.** Rien, ou un souffle très léger par commande (jamais par tuile) avec son équivalent visuel (la
  lisière qui recule) ; la puce « Ruine repérée » est l'équivalent visuel du repérage d'une ruine. Le reste
  revient à l'audio-director.

> 📌 **Asset Spec** — Visual/Audio requirements are defined. After the art bible is approved,
> run `/asset-spec system:brouillard-vision` to produce per-asset visual descriptions, dimensions, and
> generation prompts from this section.

## Game Feel

- **Le brouillard recule avec l'unité.** Chaque pas révèle ses tuiles au rythme du déplacement, sans attente.
- **Une seule chose bouge à la fois** : la lisière, puis le panneau si une ruine est lue.
- **Aucun piège** : l'embuscade arrête l'unité sans la punir ; rien ne meurt sans signal annoncé.
- **Un souvenir est un souvenir** : la tuile quittée s'assombrit sans fanfare ; les unités disparaissent à
  l'instant.
- **Animations réduites** : tout apparaît directement dans son état final.

## UI Requirements

- **États de la carte** : INCONNUE, EXPLORÉE et VISIBLE se lisent aussi en niveaux de gris (valeur, non
  teinte seule).
- **Puce « Ruine repérée · n tuiles »** (règle 15 ; formule 7) : une seule puce, la plus proche ; masquée
  quand il ne reste aucune ruine non lue.
- **Marqueurs d'intention** sur les tuiles du joueur, que l'auteur soit visible ou non.
- **Filtre d'événements** : un événement de l'autre faction hors de la vue du joueur n'est ni montré ni
  annoncé (journal du tour ennemi compris), ou il est générique.
- **Lecteur d'écran** : l'état d'une tuile (inconnue, explorée, visible), « Ruine repérée à n tuiles » et
  l'arrêt d'une embuscade sont annoncés comme du texte.

> 📌 **UX Flag — Brouillard** : ce système a des exigences d'interface (états de la carte, puce de ruine,
> filtre du journal). En phase 4 (pré-production), lancer `/ux-design` pour ces éléments **avant** d'écrire
> les épopées.

## Cross-References

| Ce document cite | Document | Élément précis | Nature |
|---|---|---|---|
| Tranche Visibilité, vue par faction, niveau de validation, budget en octets | `design/gdd/modele-etat-partie.md` | Règles 11 et 14 ; formule 5 | Règle, valeur |
| Ligne de vue (Bresenham), règle 8, ruines tirées, règle 16 | `design/gdd/carte-tuiles-terrain.md` | Règles 8, 12, 16 ; formule 3 | Règle |
| Rayon de vue par type, dormants, ne voit pas | `design/gdd/unites-drones.md` | Règles 2, 3, 8 | Valeur |
| Source de vue d'un nœud, propriétaire réel, rayon de territoire | `design/gdd/noeuds.md` | Règles 13 et 15 | Valeur |
| CIBLE_NON_VISIBLE, refus identique | `design/gdd/combat.md` | Règle 10 | Règle |
| Embuscade, vue par faction, annulation d'un déplacement | `design/gdd/commandes-evenements.md` | Règles 6 et 15 | Règle |
| Aplat #1E2329, lisière d'une demi-tuile, lueur des ruines | `design/art/art-bible.md` | Sections 2, 6, 8 | Style |
| Pilier 4, pilier 5, test de l'identité visuelle | `design/gdd/game-concept.md` | Game Pillars ; Visual Identity Anchor | Intention |

## Acceptance Criteria

*Étiquettes : **Logic** = `tests/unit/brouillard/` sur un état construit par fabrique ; **Intégration** =
`tests/integration/brouillard/` ; **UI** et **Visuel** = capture conservée dans `production/qa/evidence/`,
validée par l'art-director ; **Appareil** = sur l'appareil cible. [BLOQUÉ n] = attend le système n ;
[PROV] = valeur provisoire (Open Questions). AC-BR1 à AC-BR24 suivent la numérotation des règles 1 à 24.*

### Règles

- **AC-BR1** (Logic, règle 1) **GIVEN** une carte 12 × 12 et une 16 × 16, **WHEN** l'état est créé, **THEN** la tranche fait 2 octets par tuile et par faction ; bit 0 stocké = 0 (`vue_maintenant` vit dans le cache hors de l'état), bit 1 = `découverte`, bit 2 = `dormant_mémorisé`, octet 1 = propriétaire (0 = aucun).
- **AC-BR2** (Logic, règle 2) **GIVEN** un état avec bit 0 stocké = 1, ou octet 1 ≠ 0 sur une tuile non découverte, **WHEN** la validation tourne, **THEN** elle signale la corruption ; **GIVEN** un cache dont une tuile VISIBLE n'est pas `découverte` après recalcul, **THEN** elle le signale aussi.
- **AC-BR3** (Logic, règle 3) **GIVEN** les 8 valeurs de l'octet 0, **THEN** l'état dérivé est celui de la formule 1 (voir AC-BR25), et aucune grille d'états n'existe dans la sérialisation (recherche statique).
- **AC-BR4** (Logic, règle 4) **GIVEN** un nœud adverse vu puis perdu de vue, **WHEN** il change de propriétaire hors de vue sans que la faction le perde, **THEN** l'octet 1 garde l'ancien propriétaire ; aucun champ « niveau » n'existe dans la tranche.
- **AC-BR5** (Logic, règle 5) **GIVEN** une tuile VISIBLE, **WHEN** une commande est appliquée, **THEN** son octet 1 vaut le propriétaire réel ; **GIVEN** une tuile non visible dont la faction regardante perd la propriété, **THEN** l'octet 1 est mis à jour aussitôt.
- **AC-BR6** (Logic, règle 6) **GIVEN** une unité sur une tuile EXPLORÉE, **THEN** `unité_visible` est faux ; recherche statique : aucune table « unités vues » dans l'état.
- **AC-BR7** (Logic, règle 7) **GIVEN** un Éclaireur, une Sentinelle, un Chasseur, un Assaut, un Rempart, un Ouvrier, un Bastion et un nœud de niveau 1 ou 2, **THEN** les rayons sont 4, 3, 3, 2, 2, 2, 2 et 2 (un nœud de niveau 3 : 3) ; un dormant ne contribue rien ; un nœud sans unité, avec territoire seul, ne donne aucune vue ; une unité voit sa propre tuile.
- **AC-BR8** (Logic, règle 8) **GIVEN** une source en plaine avec une montagne sur la ligne, **THEN** la montagne est visible et la tuile derrière est cachée ; un voisin n'est jamais caché ; le champ est écrêté aux bords (AC-BR26).
- **AC-BR9** (Logic, règle 9) **GIVEN** DÉPLACER, ATTAQUER, CAPTURER, RÉVEILLER ou EXÉCUTER_UNE_INTENTION appliquée, **THEN** `recalculer_vue` est appelée une fois par faction (doublure comptant les appels = 2) ; **GIVEN** RECHERCHER, MONTER_NŒUD, FINIR_LE_TOUR ou COMMENCER_LE_TOUR, **THEN** 0 appel. [BLOQUÉ 23 : appel direct]
- **AC-BR10** (Logic, règle 10) **GIVEN** un état copié, **THEN** les copies partagent le cache, la sérialisation ne l'inclut pas, l'égalité profonde l'ignore, et chaque `champ(V, r_eff)` est identique au calcul naïf pour toutes les tuiles d'une carte d'essai.
- **AC-BR11** (Logic, règle 11) **GIVEN** un déplacement de 3 pas, **WHEN** appliqué, **THEN** après chaque pas l'union des champs est dans `découverte` et `vue_maintenant` ; à la fin, `vue_maintenant` ne couvre que la situation réelle et les tuiles vues en route sont EXPLORÉES.
- **AC-BR12** (Logic, règle 12) **GIVEN** une unité occupant la tuile suivante, **THEN** l'unité s'arrête sur la dernière tuile libre et l'unité rencontrée est révélée ; **GIVEN** un ennemi aperçu à distance, **THEN** pas d'arrêt ; **GIVEN** une eau non découverte, **THEN** arrêt ; une tuile INCONNUE est supposée de coût 1 à la validation, son coût réel étant lu à l'application. [BLOQUÉ 23 : PM restants, PROV]
- **AC-BR13** (Logic, règle 13) voir AC-BR31 à AC-BR33 (cas a à e). [BLOQUÉ 13 pour (e), 23 pour l'événement de (b)]
- **AC-BR14** (Logic, règle 14) **GIVEN** une commande découvrant 5 tuiles pour le joueur, **THEN** un seul TUILES_RÉVÉLÉES, trié par indice croissant et non vide ; **GIVEN** EXPLORÉE → VISIBLE seul, **THEN** aucun événement. [BLOQUÉ 23 : format]
- **AC-BR15** (Logic, règle 15) **GIVEN** une partie au tour 1, **THEN** les 3 ruines tirées sont visibles pour le joueur sur tuile INCONNUE, et aucune des 9 candidates non tirées ne l'est ; **GIVEN** une ruine lue, **THEN** elle sort de la puce. [BLOQUÉ 13 ; IA : Open Questions]
- **AC-BR16** (Logic, règle 16) Aucun test propre : règle de terrain portée par la carte. Voir AC-BR15 (l'exception des ruines ne contredit pas la règle 16).
- **AC-BR17** (Logic, règle 17) **GIVEN** un dormant au départ, **THEN** le bit 2 est posé pour les deux factions sur sa tuile ; **GIVEN** la tuile VISIBLE sans dormant, **THEN** le bit 2 est effacé. Voir AC-BR37.
- **AC-BR18** (Logic, règle 18) **GIVEN** une cible cachée, inexistante, dormant caché ou identifiant périmé, **THEN** CIBLE_NON_VISIBLE avec réponse identique à l'octet (AC-BR35) ; même règle pour l'IA, refus compté dans `N_REFUS_MAX`. [BLOQUÉ 9]
- **AC-BR19** (Logic, règle 19) **GIVEN** RÉVEILLER vers un dormant caché, **THEN** AUCUN_DRONE_ADJACENT ; **GIVEN** une validation sur une tuile INCONNUE, **THEN** la réponse est « inconnue » ; un refus ne change aucun état.
- **AC-BR20** (Logic, règle 20) **GIVEN** un événement ennemi dont les tuiles sont VISIBLES avant ou après, **THEN** `événement_visible` est vrai, sinon faux, et la fonction est pure. [BLOQUÉ 17 : affichage et version générique]
- **AC-BR21** (Intégration, règle 21) voir AC-BR36. [BLOQUÉ 9, 17]
- **AC-BR22** (Logic, règle 22) **GIVEN** une mise en place, **THEN** toutes les grilles sont à zéro avant calcul, le territoire du nœud de départ est au moins EXPLORÉ, et les tuiles de départ ennemies sont INCONNUES ; ATTAQUER vers le camp ennemi donne CIBLE_NON_VISIBLE.
- **AC-BR23** (Logic, règle 23) **GIVEN** un nœud de niveau 3 (territoire 3, vue 3), **THEN** tout son territoire est VISIBLE ; **GIVEN** le nœud perdu, **THEN** ses tuiles que plus aucune source ne couvre sont EXPLORÉES, jamais INCONNUES.
- **AC-BR24** (Logic, règle 24) voir AC-BR38 et AC-BR39.

### Formules

- **AC-BR25** (Logic, F1) Octet 0 : `0b011` → VISIBLE ; `0b010` → EXPLORÉE ; `0b110` → EXPLORÉE ; `0b000` → INCONNUE ; `0b001` → invalide, signalé par la validation, jamais interprété.
- **AC-BR26** (Logic, F2, exemple A) **GIVEN** un Éclaireur (rayon 4, plaine) en (0, 2) et une montagne en (2, 2), **THEN** les tuiles cachées sont (3, 2), (4, 2), (4, 1), (4, 3) ; la montagne (2, 2) est visible ; 21 tuiles visibles dans la fenêtre 5 × 5 (coordonnées absolues) ; **GIVEN** (4, 1) avec D = 0, **THEN** l'axe mineur n'avance pas, comme à la formule 3 de la carte ; **GIVEN** un rayon 4 en (0, 0) en 16 × 16, **THEN** 25 tuiles au lieu de 81.
- **AC-BR27** (Logic, F2, exemple B) **GIVEN** un Éclaireur sur montagne en (5, 5) en 12 × 12, **THEN** 121 tuiles (x et y de 0 à 10) et une montagne en (6, 5) n'empêche pas de voir (8, 5).
- **AC-BR28** (Logic, F3) **GIVEN** un Éclaireur en (5, 5) et un nœud en (8, 5) en 12 × 12 sans montagne, **THEN** 81 + 25 − 20 = 86 ; l'union est indépendante de l'ordre des sources.
- **AC-BR29** (Logic, F4) **THEN** 576 (12 × 12, L = 0) et 1 024 (16 × 16, L = 0) octets ; 864 et 1 536 avec L = 1 ; L = 1 n'est pas adopté (règle 4).
- **AC-BR30** (Logic, F5) **THEN** le décompte de tests est 1 280 par faction (2 560 pour deux), 4 860 au pire cas, 22 320 en précalcul 12 × 12 et 39 680 en 16 × 16 (155 par tuile).
- **AC-BR31** (Logic, F6) **GIVEN** un Ouvrier (rayon 2) de (3, 3) à (6, 3), tout découvert sauf x = 8, y 1 à 5, **THEN** `a_révélé` est vrai et TUILES_RÉVÉLÉES = [20, 32, 44, 56, 68].
- **AC-BR32** (Logic, F6) **GIVEN** un déplacement EXPLORÉE → VISIBLE sans rien de neuf, **THEN** `a_révélé` est faux, ANNULER est permis et la tranche est restaurée.
- **AC-BR33** (Logic, F6, propriété) **GIVEN** chacun des cas (a) INCONNUE → découverte, (b) unité aperçue même perdue ensuite, (c) octet 1 changé sur tuile VISIBLE, (d) embuscade, (e) ruine lue, **THEN** `a_révélé` est vrai.
- **AC-BR34** (Logic, F7) **GIVEN** ruines (9, 2), (2, 10), (10, 10), unités (3, 3), (4, 6) et nœud (2, 2), **THEN** d = 4 ; **GIVEN** plus aucune ruine non lue, **THEN** la puce est masquée.

### Comportements

- **AC-BR35** (Logic) Refus sur tuile non vue : octets identiques pour une cible cachée et une cible inexistante.
- **AC-BR36** (Intégration) Intention visant une unité du joueur, auteur caché : le marqueur est sur la tuile du joueur et aucune position de l'auteur n'atteint le HUD. [BLOQUÉ 9, 17]
- **AC-BR37** (Logic) **GIVEN** un dormant éveillé par l'autre faction hors de vue, **THEN** le bit 2 reste posé jusqu'à ce que la tuile soit VISIBLE, puis il est effacé.
- **AC-BR38** (Logic) **GIVEN** un chargement avec bit 0 stocké altéré, **THEN** il est remis à 0 et le cache recalculé, une trace est écrite au journal, `découverte` et octet 1 sont conservés ; si b0 est recalculé à 1 avec b1 = 0, le fichier est refusé comme corrompu.
- **AC-BR39** (Logic) Sauvegarde, chargement, resérialisation sans commande : tranche identique à l'octet.
- **AC-BR40** (Logic) Même état et même commande, deux exécutions : octets identiques ; recherche statique : aucun flottant dans le module.
- **AC-BR41** (Logic) Faction éliminée : vue figée en EXPLORÉE, `découverte` et octet 1 conservés ; IA passive : sa vue reste recalculée. [PROV]
- **AC-BR42** (Logic) Aucun TUILES_RÉVÉLÉES pour l'IA ; une unité ennemie qui se déplace dans le brouillard ne produit aucun événement affiché.

### Visuel, UI, Appareil

- **AC-BR43** (Visuel) Captures en couleur et en niveaux de gris des trois états : EXPLORÉE plus sombre que la tuile VISIBLE la plus sombre (l'eau) ; la teinte de faction mémorisée n'est jamais #4E5862 ni ocre (aussi en simulation daltonienne). Le facteur de mélange est à fixer au prototype.
- **AC-BR44** (Visuel) Marqueur de dormant à 31 pt, distinct de l'unité éveillée et de la ruine (repli : contour plein gris plus clair si le pointillé ne tient pas).
- **AC-BR45** (Visuel) Nœud adverse mémorisé : anneaux en contour seul, jamais confondu avec le niveau 1.
- **AC-BR46** (Visuel + Appareil) Révélation en 200 ms ; avec animations réduites, apparition directe ; fondu VISIBLE → EXPLORÉE de 150 ms, unités masquées instantanément.
- **AC-BR47** (Appareil) La mesure d'un recalcul complet, deux factions, est de 1 ms au plus par commande sur l'appareil de référence. Aucun chiffre ne figure dans les documents pour la vitesse de GDScript sur mobile : le seuil n'est qu'une estimation.
- **AC-BR48** (UI) Capture de la puce « Ruine repérée · n tuiles ». [BLOQUÉ 17]
- **AC-BR49** (Appareil, playtest) Sur les dix premiers tours de trois parties, au moins 80 % des déplacements d'un Éclaireur révèlent un élément nouveau (relief, marqueur, lisière ennemie) ; sous ce seuil, la densité de la carte est à revoir (pilier 5).

### Non testable en l'état

- Règle 6 (négation, par recherche statique seulement), règle 16 (règle de terrain portée par la carte) et règle 4 (le niveau « non mémorisé » est une absence).
- Le rendu hors de vue par l'octet 1 (15) : aucun critère avant son GDD ; le marqueur d'une ruine lue : Open Questions.
- Événements manquants en 23 : « unité aperçue », `événement_visible`, DÉPLACEMENT_A_RÉVÉLÉ.

## Open Questions

| Question | Propriétaire | À résoudre avant | Résolution |
|---|---|---|---|
| L'exception « ruines visibles » s'applique-t-elle à la vue de l'IA ? Symétrique par défaut ; l'IA ne lit une ruine que si 13 le prévoit. | game-designer | GDD 9 et 13 | |
| Mémoire d'unités de l'IA : aucune par défaut (symétrique avec le joueur) ; sinon dans la tranche de 9, avec son budget. | game-designer, ai-programmer | GDD 9 | |
| Réaliser la règle 25 : l'IA planifie sur un état filtré à sa vue, dans le budget de 2 500 copies (copie filtrée, vue figée au début de la planification). | ai-programmer | GDD 9 | Contrainte posée |
| Niveau d'un nœud adverse hors de vue : non mémorisé (octet de niveau optionnel, +144 ou +256 octets par faction). À garder ? | game-designer | Playtest | Provisoire : non |
| Point de départ de la distance de la puce « Ruine repérée » : toutes les pièces du joueur (hypothèse), l'unité sélectionnée ou le nœud de départ. | ux-designer | `/ux-design hud` | Provisoire : toutes les pièces |
| Densité de révélations : en moyenne, au moins un élément nouveau (relief, marqueur, lisière ennemie) à chaque déplacement d'éclaireur sur les dix premiers tours, pour que le brouillard ne soit pas une taxe de mouvement (pilier 5) : contrainte de carte et critère de playtest. | level-designer, qa-lead | Fichiers de cartes, playtest | Posé |
| Vue d'une faction éliminée : figée en EXPLORÉE, sans recalcul. | lead-programmer | Revue de 1 | Provisoire : oui |
| Marqueur de dormant en état EXPLORÉE : affiché avec son type connu (point d'intérêt, non une unité). | art-director | Test de silhouette | Provisoire : oui |
| Marqueur d'une ruine lue : glyphe distinct ou disparition ? (`hud.md` ne le précise pas.) | ux-designer | `/ux-design hud` | |
| Vitesse de GDScript sur mobile (NOT SOURCEABLE) : le coût de recalcul (0,2 à 1,3 ms) est une estimation à mesurer. | performance-analyst | Prototype de rendu | |
| Fondu transparent de la lisière ou tuiles opaques : à mesurer (art bible, section 8). | technical-artist | Prototype de rendu | |
| Reporter dans 23 : filtre d'événements, TUILES_RÉVÉLÉES, « unité aperçue » ; dans 1 : disposition des bits, `a_révélé` ; dans `hud.md` : états de la carte, puce de ruine, marqueurs d'intention. | game-designer, ux-designer | Revue de 23, 1 et `/ux-design hud` | |
