# Arbre de protocoles

> **Status**: Designed (pending /design-review)
> **Author**: user + Claude (game-designer)
> **Last Updated**: 2026-10-30
> **Last Verified**: 2026-10-30
> **Implements Pillar**: Pilier 4 « La puissance se mérite » ; pilier 1 « La meute se voit grandir » (effets lisibles sur la carte) ; pilier 3 (une phrase par protocole)
> **Creative Director Review (CD-GDD-ALIGN)**: REVISED 2026-10-30 — CONCERNS (le contrepoids de l'IA n'existait pas au MVP ; trois effets sans signal sur la carte ; noms de protocoles sans mémoire ; plage de DÉF trop large ; déblocages du palier de lancement non tranchés) corrigées ; déblocages laissés en question ouverte (aucune préférence de l'utilisateur)
> **System**: 12 — Progression, MVP. Dépend de 1, 3, 6, 10, 23 ; lu par 5, 6, 7, 8.

## Summary

Deux branches linéaires de trois protocoles que la meute recherche avec de l'énergie : Réseau (vision, prix de réveil, mouvement) et Meute (soin, défense, attaque du Rempart). Chaque protocole est un modificateur additif sur une statistique existante ; l'état ne stocke que les identifiants acquis. Seul le joueur recherche au MVP.

## Overview

RECHERCHER dépense de l'énergie (15 à 35) et lance une recherche de 2 à 3 tours, une à la fois par faction. Quand elle se termine, le protocole s'applique à tous les drones de la meute, par un accesseur pur `stat_effective` lu par les systèmes d'unités, de combat, de réveil et de brouillard. Aucun protocole ne touche au revenu, au territoire ni à la vue des nœuds. Les protocoles n'existent que dans la partie : rien ne persiste dans le profil.

## Player Fantasy

**La meute apprend.** Le joueur choisit une direction (voir plus loin, ou tenir mieux), attend quelques tours, et voit la différence sur la carte : des drones qui éclairent plus loin, des lourds qui avancent plus vite, des coups qui font moins mal. La puissance coûte du temps et de l'énergie qu'on aurait pu mettre dans un réveil ou une montée de nœud.

Trois échecs à éviter : le protocole abstrait qu'on ne voit jamais agir ; l'arbre qui rend le joueur trop fort face à une IA qui ne peut pas répondre ; la personnalisation par unité (anti-pilier).

## Detailed Design

*Décisions du 2026-10-30 : 2 branches de 3 ; protocoles sans poids dans le score (`w_p` = 0 au MVP) ; stats de combat touchées, modestement. Tous les chiffres sont [PROP].*

### Core Rules

**A. L'arbre**

1. **Forme.** 2 branches linéaires de 3 niveaux, 6 nœuds. Un protocole n'a qu'un prérequis : le niveau précédent de sa branche, terminé.
2. **Effets.** Chaque effet est un modificateur additif sur une statistique existante, pour tous les drones de la meute. Aucune personnalisation par unité.

| Branche | Niv. | Protocole | Source (≤ 24 car.) | Phrase joueur | Prix | Durée | Effet |
|---|---|---|---|---|---|---|---|
| Réseau | 1 | Veille élargie | Consigne de poste | Vos drones voient plus loin. | 15 | 2 tours | Vision +1 aux types à vision 2 (Assaut, Rempart, Ouvrier) : 2 → 3 |
| Réseau | 2 | Réveil sobre | Fiche de démarrage | Réveiller coûte moins cher. | 20 | 2 tours | `prix_réveil` −1, plancher 1 |
| Réseau | 3 | Cadence de marche | Fiche de marche | Vos lourds avancent plus vite. | 30 | 3 tours | MVT +1 à Assaut, Rempart, Ouvrier |
| Meute | 1 | Repos réglementaire | Fiche de relève | Le repos soigne davantage. | 15 | 2 tours | `REST_HEAL` +1 (2 → 3) |
| Meute | 2 | Blindage d'appoint | Note de maintenance | Vos drones encaissent mieux. | 25 | 2 tours | DÉF +1 à tous les types de la meute |
| Meute | 3 | Rempart armé | Fiche d'ouvrage | Le Rempart frappe plus fort. | 35 | 3 tours | ATQ +1 au Rempart seulement (1 → 2) |

2bis. **Règle de nommage** (décision du 2026-10-30). Le nom est un groupe nominal de 1 à 3 mots, ≤ 20 caractères (limite dure 24), sans verbe ni impératif ni « vos / nous / on », qui évoque un document ou une procédure humaine retrouvée (veille, réveil, cadence, repos, blindage, ouvrage) sans dire qui l'a écrit, qui doit l'appliquer ni pour qui. Il est vrai à la lettre (un effet ≤ +1 reçoit un qualificatif de modestie : élargie, sobre, d'appoint), ne cite une unité que si l'effet lui est limité, reprend le vocabulaire des règles (« réveil », « repos », « Rempart »), n'emploie jamais « allumer » (réservé aux fragments et à la recoloration) et tient pour une meute sans maître comme pour une meute fidèle. La ligne « source » est un type de document, jamais un auteur, une date ni un destinataire ; pour un nœud verrouillé elle s'affiche telle quelle. Branches conservées : **Réseau** et **Meute** ; titre de l'écran : « Protocoles ».
3. **Choix volontaires.** L'Éclaireur garde l'exclusivité de la vue 4, l'Assaut celle de l'ATQ 3. Aucun protocole ne touche aux revenus (`REVENU_NIVEAU`) ni à `PRIX_MONTÉE` (boucle qui s'auto-alimente), ni au territoire (11 seul écrivain), ni à la vue des nœuds (règle 23 du brouillard), et aucun ne révèle de tuile directement.
4. **Pas de déblocage de type au MVP.** Le concept prévoit des protocoles qui débloquent unités et capacités ; au MVP, l'arbre ne donne que des modificateurs (`unites-drones.md`, ligne 225).

**B. RECHERCHER**

5. **Coût.** Payé en énergie à l'application par `dépenser(raison RECHERCHE)`, sans remboursement (`energie.md`, règle 8). `tours_restants = durée` au démarrage.
6. **Une recherche à la fois** par faction. Elle avance au début du tour de la faction, après le revenu. À `tours_restants` = 0 : RECHERCHE_TERMINÉE, le protocole est utilisable aussitôt. Recherche lancée au tour n avec durée 2 : terminée au début du tour n+2.
7. **Survie.** Une recherche en cours survit à la perte d'un nœud ; une faction éliminée est gelée.
8. **Ordre de validation** (première cause en échec rendue) : PARTIE_TERMINÉE / PAS_VOTRE_TOUR ; PROTOCOLE_INCONNU (à ajouter à 23) ; PROTOCOLE_ACQUIS ; RECHERCHE_EN_COURS ; PRÉREQUIS_MANQUANT (un prérequis seulement en cours ne compte pas) ; ÉNERGIE_INSUFFISANTE (besoin, disponible), toujours en dernier (`energie.md`, règle 7).
9. **Qui.** Seul le joueur appelle RECHERCHER au MVP ; la validation est neutre vis-à-vis de la faction. L'IA ne recherche pas : elle reçoit ses protocoles par un **calendrier fixe en données** (règle 15).

**C. Effets**

10. **État.** Seuls l'ensemble trié des ids acquis et la recherche en cours (id, tours restants) sont stockés. Les effets sont calculés, jamais stockés.
11. **Accesseur.** `stat_effective(état, faction, type, stat)` = base + somme des modificateurs des protocoles acquis, par id croissant, puis borne. 6 (vision, MVT, `REST_HEAL`), 8 (ATQ, DÉF), 7 (`prix_réveil`) et 5 (rayon de vue des unités) le lisent. Entiers, additif, sans hasard ; une stat à 0 reste à 0 (la Sentinelle ne bouge ni n'attaque).
12. **Bénéficiaires.** Les modificateurs suivent le propriétaire de l'unité : un drone réveillé après coup en profite ; un dormant neutre n'a rien.
13. **Dépendance.** 12 expose `modificateurs()` en lecture seule ; 6, 7, 8 et 5 le consomment (dépendance souple, pas de cycle).
14. **Vue.** À la fin des Veille élargie, la vue est recalculée une fois (TUILES_RÉVÉLÉES) : amende la règle 9 de `brouillard-vision.md`.

**D. Équilibre**

15. **Contrepoids de l'IA : calendrier fixe en données** (décision du 2026-10-30). Le renfort de Gardiens de `ia-ennemie.md` (règle 17bis) est vide au MVP : sans contrepoids, un joueur devenu plus résistant (Blindage d'appoint réduit d'un tiers les dégâts d'un Chasseur) face à une IA qui ne répond jamais ferait s'effondrer le pilier 4. L'IA reçoit donc des protocoles à des tours fixes, `CALENDRIER_PROTOCOLES_IA` dans `assets/data/ai.*` (départ : Blindage d'appoint au tour 12, Rempart armé au tour 18), sans logique de choix, sans énergie, sans commande RECHERCHER : au début de son tour du tour indiqué, l'identifiant est ajouté à ses protocoles acquis. `stat_effective` prend déjà la faction en paramètre. Le crochet `choisir_recherche` de 9 se contente de lire cette liste. Autres garde-fous : gain total modeste (+1 de vue, −1 de prix, +1 de MVT sur 3 types, +1 de soin, +1 de DÉF, +1 d'ATQ sur un seul type) ; coût d'opportunité réel (140 énergie sur un revenu cumulé d'environ 380, premier protocole vers le tour 6, dernier vers le tour 20). Une IA qui recherche réellement (liste de choix, difficulté) est reportée à l'Alpha.
16. **Score.** `w_p` = 0 au MVP : le protocole est récompensé par sa puissance, pas par le score (à porter dans 3).

**E. Persistance**

17. Les protocoles vivent dans la partie seulement (tranche Factions de 1, sauvegarde de 16). Aucune tranche du profil (22). Un registre cosmétique « protocoles découverts » est possible au Vertical Slice (avec 14), sans effet de jeu.

**F. Interface**

18. Un écran dédié, ouvert depuis un bouton du HUD (à spécifier dans `design/ux/protocoles.md`) : deux colonnes de trois nœuds reliés ; par nœud : icône, nom, phrase, prix, durée ; états acquis, en cours (tours restants), disponible, verrouillé, « manque n » ; jamais la couleur seule ; un appui ouvre « Rechercher (15) ». Au HUD : puce « Recherche : Veille élargie, 2 t » et notification à RECHERCHE_TERMINÉE. Le panneau d'unité affiche la stat effective avec « +1 ».

### States and Transitions

| État du protocole | Événement | État suivant |
|---|---|---|
| Verrouillé | Prérequis terminé | Disponible |
| Disponible | RECHERCHER validé | En cours (tours_restants = durée) |
| En cours | Début de tour, tours_restants −1 | En cours |
| En cours | tours_restants = 0 | Acquis (RECHERCHE_TERMINÉE) |
| Acquis | — | Acquis (jusqu'à la fin de la partie) |

### Interactions with Other Systems

| # | Système | Sens | Contrat |
|---|---|---|---|
| 1 État | écrit | Tranche Factions : ids acquis, recherche en cours |
| 3 Tours | lu par | Avance la recherche au début du tour ; `w_p` = 0 |
| 5 Brouillard | lit | Vision effective ; recalcul à la fin des Veille élargie |
| 6 Unités | lit | MVT, vision, `REST_HEAL` effectifs |
| 7 Réveil | lit | `prix_réveil` effectif |
| 8 Combat | lit | ATQ, DÉF effectifs |
| 9 IA | lit | Calendrier fixe de protocoles de l'IA (règle 15) ; aucun RECHERCHER |
| 10 Énergie | appelle | `dépenser(RECHERCHE)` |
| 17 HUD | écoute | RECHERCHE_TERMINÉE, puce, écran |
| 23 Commandes | appelé par | RECHERCHER, codes de refus, `PROTOCOLE_INCONNU` |

## Formulas

*Entiers uniquement.*

### F1. Statistique effective

`stat_effective = clamp(base + Σ mod_p, min, max)`, somme sur les protocoles acquis p applicables au type, par id croissant.

| Symbole | Description |
|---|---|
| base | Valeur des données d'unités (6) |
| mod_p | Modificateur du protocole p (tableau, règle 2) |
| min, max | Bornes des données (prix de réveil [1, 99] ; stats dans leurs plages) |

**Exemples** : Rempart ATQ 1, Rempart armé acquis → 2 ; Assaut vision 2, Veille élargie → 3 ; Éclaireur vision 4 → 4 (non concerné) ; Sentinelle MVT 0, Cadence de marche → 0 ; `prix_réveil` Éclaireur 4, Réveil sobre → 3, Éclaireur ne descend jamais sous 1.

### F2. Calendrier d'une recherche

`fin = tour_départ + durée` (la recherche est terminée au début du tour `fin`). **Exemple** : Veille élargie lancées au tour 6, durée 2 → terminées au début du tour 8. Les trois protocoles de la branche Réseau coûtent 65 énergie et prennent 7 tours minimum ; l'arbre complet coûte 140 et 14 tours minimum.

### F3. Effet sur les duels (plaine, PV pleins)

Blindage d'appoint : un Chasseur frappe un Éclaireur pour 4 au lieu de 6, un Rempart pour 3 au lieu de 4. Rempart armé : le Rempart fait 4 au lieu de 2 contre un Chasseur, 2 au lieu de 1 contre un Bastion. Vérifié avec la formule du combat (`8 × ATQ × PV // (PV_max × (4 + DÉF))`, PV pleins) : Chasseur ATQ 3 contre Éclaireur DÉF 0 : 24 // 4 = 6, puis 24 // 5 = 4 ; contre Rempart DÉF 2 : 24 // 6 = 4, puis 24 // 7 = 3 ; Rempart ATQ 1 contre Chasseur DÉF 0 : 8 // 4 = 2, puis ATQ 2 : 16 // 4 = 4 ; contre Bastion DÉF 2 : 8 // 6 = 1, puis 16 // 6 = 2. Les 11 vecteurs de duel de `combat.md` sont à recalculer avec DÉF +1 et ATQ Rempart 2, et la borne de F1 du combat passe de 0..4 à 0..5.

## Edge Cases

- **Recherche déjà en cours** : RECHERCHE_EN_COURS, sans consommer d'énergie.
- **Protocole acquis relancé** : PROTOCOLE_ACQUIS.
- **Prérequis seulement en cours** : PRÉREQUIS_MANQUANT.
- **Énergie insuffisante** : ÉNERGIE_INSUFFISANTE (besoin, disponible), vérifiée en dernier ; rien n'est dépensé.
- **Perte de nœuds pendant la recherche** : elle continue ; **dernier nœud perdu** : élimination, recherche gelée.
- **Drone réveillé après l'acquisition** : il bénéficie des modificateurs. **Dormant** : aucun.
- **Fin des Veille élargie** : tombe toujours au début du tour du joueur (seul le joueur recherche) ; la vue est recalculée alors, jamais pendant le tour de l'IA. Un protocole du calendrier de l'IA s'applique au début de son tour sans recherche ni événement de vue pour le joueur.
- **Prix de réveil à 1** : plancher ; un second modificateur ne descend pas plus bas.
- **Stat à 0** : reste à 0.
- **Rechargement d'une sauvegarde** : ids acquis et recherche en cours restaurés ; aucune recherche relancée ni payée deux fois.
- **Tour 30** : une recherche non terminée n'a aucun effet.
- **Chargement d'un profil sans protocole** : aucun effet (rien ne persiste).

## Dependencies

| Système | Direction | Nature |
|---|---|---|
| 1 État, 10 Énergie, 23 Commandes, 3 Tours | dépend de | dur |
| 6 Unités | dépend de | dur (stats de base) |
| 5 Brouillard, 6 Unités, 7 Réveil, 8 Combat | est utilisé par | dur (lecture de `stat_effective`) |
| 17 HUD | est utilisé par | dur |
| 9 IA | est utilisé par | souple (calendrier fixe en données) |
| 22 Profil | aucune | rien ne persiste |

## Tuning Knobs

| Réglage | Départ | Plage sûre | Effet si trop haut | Effet si trop bas |
|---|---|---|---|---|
| Prix des protocoles | 15, 15, 20, 25, 30, 35 | grille de 10 | Arbre jamais fini | Puissance trop tôt |
| Durées | 2, 2, 3 tours | 1 à 4 | Attente | Choix sans tension |
| Modificateurs (±1) | 1 | 1 ; la DÉF reste à 1 tant que la punition de l'IA n'est pas mesurée (AC-PR30) | Joueur trop fort | Effet invisible |
| `CALENDRIER_PROTOCOLES_IA` | Blindage d'appoint tour 12, Rempart armé tour 18 | tours 8 à 25 | IA trop dure | Joueur sans contrepoids |
| Plancher du prix de réveil | 1 | 1 à 2 | — | Réveil gratuit |
| `w_p` | 0 | 0 à 10 | Achat pour les points | — |

## Visual/Audio Requirements

- Icône par protocole (silhouette, jamais la couleur seule) ; marqueur visuel sur la carte pour les six protocoles (art-director), sans personnalisation par unité. Chaque effet se lit sur la carte au moment où il agit : l'aperçu de combat (`combat.md`, règle 12) et les intentions annoncées de l'IA affichent les dégâts modifiés avec une marque discrète de l'icône du protocole (Blindage d'appoint, Rempart armé) ; le prix de réveil réduit s'affiche sur le dormant lui-même, avec l'icône (Réveil sobre) ; un chiffre de soin flottant « +3 » avec l'icône apparaît sur l'unité au repos (Repos réglementaire). Audio facultatif (20) : un cue de fin de recherche, sans cadence de victoire.

## Game Feel

La fin d'une recherche est une confirmation calme (puce et notification), pas une récompense. L'effet doit se lire dans la première action qui suit (critère testable protocole par protocole : AC-PR29).

## UI Requirements

- Écran de l'arbre (voir règle 18), puce « Recherche : nom, n t », notification de fin, stat effective avec « +1 » dans le panneau d'unité, phrases pour l'écran d'aide d'accessibilité. L'écran se spécifie dans `design/ux/protocoles.md` (à créer).

## Cross-References

- `design/gdd/commandes-evenements.md` : `PROTOCOLE_INCONNU`, ordre des refus de RECHERCHER, RECHERCHE_TERMINÉE.
- `design/gdd/brouillard-vision.md` : règle 9 (recalcul à la fin des Veille élargie).
- `design/gdd/unites-drones.md` : règle 1 (stats effectives par accesseur).
- `design/gdd/combat.md` : bornes de F1, 11 vecteurs de duel.
- `design/gdd/reveil-drones.md` : ligne 329 (l'IA ne dépense pas en protocoles).
- `design/gdd/tours-conditions-victoire.md` : `w_p` = 0.
- `design/gdd/energie.md` : recherche qui survit à la perte d'un nœud (ouverte fermée).
- `design/gdd/systems-index.md` : dépendances de 12 (1, 3, 23, 6, 10) et lecteurs (5, 6, 7, 8).
- `design/gdd/game-concept.md` : mécanique 4 (10 à 12 protocoles, déblocages) à réconcilier avec le MVP.

## Acceptance Criteria

*Étiquettes : **Logic** = `tests/unit/protocoles/`, état par fabrique, horloge injectée ; **Intégration** = `tests/integration/protocoles/` ; **UI** = capture retenue dans `production/qa/evidence/arbre-protocoles/` (nom `ACPR<n>-<scène>-<ms>.png`), sur l'appareil cible ; **Playtest** = rapport de séance au même endroit. [BLOQUÉ n] = attend le système n. Valeurs de départ [PROP] : prix 15, 15, 20, 25, 30, 35 (arbre 140, branche Réseau 65), durées 2, 2, 3 tours (arbre complet 14 tours minimum), plancher du prix de réveil 1, `w_p` 0, `REST_HEAL` 2. Entiers uniquement ; aucune graine ni horodatage dans la logique de 12.*

### A. Forme de l'arbre et effets (règles 1 à 4, F1)

- **AC-PR1** (Logic, règles 1 et 4) **THEN** l'arbre compte exactement 6 nœuds dans 2 branches de 3 niveaux ; chaque protocole a au plus 1 prérequis, le niveau précédent de sa branche ; aucun prérequis entre branches, aucun cycle, aucun effet de type « débloquer une unité » ; le test de données refuse un 7e nœud, un nœud à 2 prérequis et un cycle.
- **AC-PR2** (Logic, règle 2, F1) **GIVEN** une meute avec Éclaireur, Assaut, Rempart, Ouvrier, Sentinelle, **THEN** chaque protocole acquis seul donne : Veille élargie, vision 2 → 3 (Assaut, Rempart, Ouvrier) ; Réveil sobre, `prix_réveil` −1 (plancher 1) ; Cadence de marche, MVT +1 (Assaut, Rempart, Ouvrier) ; Repos réglementaire, `REST_HEAL` 2 → 3 ; Blindage d'appoint, DÉF +1 à tous les types ; Rempart armé, ATQ du Rempart 1 → 2 ; toute autre statistique reste à sa base.
- **AC-PR3** (Logic, règle 3) **THEN** avec les 6 protocoles : vision de l'Éclaireur 4 ; ATQ de tout type autre que le Rempart inchangée ; Sentinelle MVT 0 et ATQ 0 ; `REVENU_NIVEAU`, `PRIX_MONTÉE`, territoire et vue des nœuds identiques octet pour octet avec 0 ou 6 protocoles.

### B. RECHERCHER (règles 5 et 6, F2)

- **AC-PR4** (Logic, règle 5) **GIVEN** 40 d'énergie, **WHEN** RECHERCHER Veille élargie est validé, **THEN** l'énergie passe à 25 par un seul `dépenser(RECHERCHE)` à l'application, `tours_restants` = 2, aucun remboursement dans aucun cas (terminée, nœud perdu, partie perdue, rechargement) ; prix testés : 15, 15, 20, 25, 30, 35.
- **AC-PR5** (Logic, règle 6, F2) **THEN** durées 2 (Veille élargie, Réveil sobre, Repos réglementaire, Blindage d'appoint) et 3 (Cadence de marche, Rempart armé) ; lancée au tour n avec la durée d, terminée au début du tour n+d (Veille élargie au tour 6 → tour 8 ; Cadence de marche au tour 10 → tour 13).
- **AC-PR6** (Logic, règle 6) **THEN** l'ordre au début du tour est revenu, avance, RECHERCHE_TERMINÉE ; le protocole est utilisable aussitôt (le niveau suivant est acceptable le même tour).
- **AC-PR7** (Logic, règle 6) **THEN** une seconde recherche pendant une recherche en cours est refusée (RECHERCHE_EN_COURS), état identique ; acceptée au tour de fin ; sur 1 000 séquences de graine fixe, jamais deux recherches simultanées.
- **AC-PR8** (Logic, F2) **THEN** Réseau complet (65) en 7 tours minimum, arbre complet (140) en 14 tours minimum ; aucune séquence valide plus rapide.

### C. Refus (règles 8 et 9)

- **AC-PR9** (Logic, règle 8) **THEN** chaque code est rendu par un cas minimal, énergie et état identiques avant et après : PARTIE_TERMINÉE, PAS_VOTRE_TOUR, PROTOCOLE_INCONNU (ids −1, 0, 7), PROTOCOLE_ACQUIS, RECHERCHE_EN_COURS, PRÉREQUIS_MANQUANT, ÉNERGIE_INSUFFISANTE (besoin, disponible).
- **AC-PR10** (Logic, règle 8) **THEN** à causes multiples, le premier code de l'ordre est rendu ; tests par paires adjacentes (id inconnu sans énergie → PROTOCOLE_INCONNU ; acquis avec recherche en cours → PROTOCOLE_ACQUIS ; prérequis manquant avec 0 énergie → PRÉREQUIS_MANQUANT) ; un prérequis seulement en cours donne PRÉREQUIS_MANQUANT. [BLOQUÉ 23]
- **AC-PR11** (Logic, règle 8) **GIVEN** 14 d'énergie et Veille élargie (15), **THEN** ÉNERGIE_INSUFFISANTE (besoin 15, disponible 14) ; avec 15 la commande réussit, énergie 0 ; jamais de dépense partielle. [BLOQUÉ 10]

### D. Survie et état stocké (règles 7, 10, 17)

- **AC-PR12** (Logic, règle 7) **THEN** la perte d'un nœud (il en reste un) laisse id et `tours_restants` inchangés ; la perte du dernier nœud fige `tours_restants` (aucune avance ni RECHERCHE_TERMINÉE). [BLOQUÉ 11]
- **AC-PR13** (Logic, règles 10 et 11) **THEN** l'état stocké se limite à l'ensemble trié des ids acquis et à la recherche en cours ; aucun champ d'effet ni cache ; deux ordres d'acquisition de même ensemble → état sérialisé identique octet pour octet.

### E. stat_effective (règles 11 et 12)

- **AC-PR14** (Logic, F1) **THEN** Rempart ATQ 1 + Rempart armé → 2 ; Assaut vision 2 + Veille élargie → 3 ; Éclaireur vision 4 → 4 ; Sentinelle MVT 0 + Cadence de marche → 0 ; `prix_réveil` Éclaireur 4 + Réveil sobre → 3 ; toujours dans [min, max].
- **AC-PR15** (Logic, règle 11) **THEN** un `prix_réveil` à 1 reste 1 sous un second modificateur de −1 simulé.
- **AC-PR16** (Logic, règle 12) **GIVEN** Blindage d'appoint acquis, **THEN** un dormant réveillé après a DÉF = base + 1 dès son réveil ; un dormant non réveillé a la base ; une unité adverse n'a jamais le modificateur du joueur. [BLOQUÉ 6, 7]
- **AC-PR17** (Logic, règle 11) **THEN** `stat_effective` est pur (100 appels, même résultat, aucune écriture) ; les lecteurs 5, 6, 7 et 8 passent par lui (une lecture directe de la base échoue au test).

### F. Vue, IA, score, persistance (règles 9, 14 à 17)

- **AC-PR18** (Intégration, règle 14) **THEN** la fin d'Veille élargie recalcule la vue une seule fois (un TUILES_RÉVÉLÉES), les types concernés passent à vision 3, l'Éclaireur garde 4 ; aucun autre protocole ne déclenche de recalcul. [BLOQUÉ 5]
- **AC-PR19** (Intégration, règle 14) **THEN** la fin d'Veille élargie tombe au début du tour du joueur ; aucun TUILES_RÉVÉLÉES pour le joueur ne naît d'un protocole de l'IA. [BLOQUÉ 3, 5]
- **AC-PR20** (Intégration, règles 9 et 15) **GIVEN** 30 tours d'IA de graine fixe, **THEN** aucun RECHERCHER émis par l'IA, aucune dépense `RECHERCHE`, aucune recherche en cours côté IA ; ses protocoles acquis sont exactement ceux du calendrier, Blindage d'appoint au début de son tour 12 et Rempart armé au début de son tour 18, et `stat_effective` de ses drones en tient compte dès ce tour. [BLOQUÉ 9]
- **AC-PR21** (Logic, règle 16) **GIVEN** deux états identiques avec 0 et 6 protocoles, **THEN** le score de victoire est identique à `w_p` = 0 ; avec `w_p` de test 10, il diffère de 10 × le nombre de protocoles, sans changer le code. [BLOQUÉ 3]
- **AC-PR22** (Logic + Intégration, règle 17) **THEN** le profil est identique octet pour octet avant et après une partie à 6 protocoles ; la partie suivante commence sans protocole ni recherche ; aucune tranche du profil ne contient d'id de protocole. [BLOQUÉ 22]
- **AC-PR23** (Intégration, Edge Cases) **GIVEN** une sauvegarde juste après RECHERCHER Blindage d'appoint (25 dépensés, `tours_restants` 2), **THEN** le chargement restaure l'id et les tours, l'énergie est identique (aucune double dépense, aucune relance), terminée au tour prévu ; les ids {Veille élargie, Blindage d'appoint} sont restaurés exactement. [BLOQUÉ 1, 16]

### G. Combat, tour 30, déterminisme

- **AC-PR24** (Logic, F3) **THEN** en plaine, PV pleins : Blindage d'appoint, Chasseur → Éclaireur 4 (au lieu de 6), Chasseur → Rempart 3 (au lieu de 4) ; Rempart armé, Rempart → Chasseur 4 (au lieu de 2), Rempart → Bastion 2 (au lieu de 1) ; la borne de F1 du combat passe à 0..5. [BLOQUÉ 8]
- **AC-PR25** (Logic) **GIVEN** une recherche de 3 tours lancée au tour 29, **THEN** à la fin de la partie elle n'a produit aucun effet, aucun RECHERCHE_TERMINÉE, aucun point ; l'énergie n'est pas remboursée. [BLOQUÉ 3]
- **AC-PR26** (Logic) **THEN** sur 100 exécutions de même graine, ids acquis, tours restants, énergie, événements et `stat_effective` de toutes les paires sont identiques octet pour octet ; aucun générateur aléatoire ni horloge système.

### H. Équilibre (règle 15)

- **AC-PR30** (Intégration + Playtest, règle 15) **GIVEN** 10 graines fixes, **WHEN** on compare 0 protocole et les 6 protocoles côté joueur (calendrier de l'IA actif), **THEN** les attaques annoncées puis exécutées par l'IA et les pertes du joueur restent dans le budget de pertes de `ia-ennemie.md` (AC-IA37 et AC-IA38) ; hors du budget, on ajuste le calendrier ou la valeur des modificateurs. [BLOQUÉ 9]

- **AC-PR27** (Intégration + Playtest) **GIVEN** un joueur scripté (il recherche dès que possible, dans l'ordre Veille élargie, Repos réglementaire, Réveil sobre, Blindage d'appoint, Cadence de marche, Rempart armé ; réveils et montées de nœud selon un script de référence figé), **THEN** sur 10 graines : Veille élargie acquis au plus tard au tour 6 ± 1, le dernier protocole au tour 20 ± 2, l'arbre complet jamais avant le tour 14 ni après le tour 30 [PROP, à confirmer avec le producer] ; hors plages, ajuster prix et durées par la grille de 10. [BLOQUÉ 3, 10]

### I. Interface (règle 18)

- **AC-PR31** (UI, Visual/Audio) **THEN** capture retenue pour chacun des six protocoles de l'effet qui se lit sur la carte au moment où il agit : dégâts modifiés dans l'aperçu de combat et dans une intention annoncée avec icône (Blindage d'appoint, Rempart armé) ; prix réduit sur le dormant avec icône (Réveil sobre) ; « +3 » flottant sur l'unité au repos (Repos réglementaire) ; vision élargie visible (Veille élargie) ; déplacement possible plus loin (Cadence de marche). [BLOQUÉ 17]

- **AC-PR28** (UI) **THEN** l'écran montre deux colonnes de trois nœuds reliés avec icône, nom, ligne « source » (≤ 24 caractères, non requise pour l'état du nœud), phrase, prix, durée ; cinq états reconnaissables sans la couleur : acquis, en cours (« 2 t »), disponible, verrouillé, « manque n » (n = prix − énergie, par exemple « manque 5 » à 10 d'énergie pour Veille élargie) ; captures dont une en niveaux de gris. [BLOQUÉ 17]
- **AC-PR29** (UI) **THEN** un appui sur un nœud disponible ouvre « Rechercher (n) » au bon prix ; aucun bouton actif sur un nœud verrouillé, acquis ou en cours ; la puce « Recherche : Veille élargie, 2 t » décrémente à chaque début de tour et disparaît à la fin avec une notification ; le panneau d'unité affiche « 3 (+1) » pour un Assaut après Veille élargie et aucun « +1 » pour un Éclaireur. [BLOQUÉ 17]

### Captures retenues exigées (toutes [BLOQUÉ 17])

AC-PR31 (six effets lisibles sur la carte), AC-PR28 (cinq états et version en niveaux de gris), AC-PR29 (fenêtre « Rechercher (15) », puce, notification, panneau d'unité avec et sans « +1 »), rapport de séance d'AC-PR27.

## Open Questions

| Question | Propriétaire | Échéance | Statut |
|---|---|---|---|
| Recalcul des 11 vecteurs de duel avec DÉF +1 et ATQ Rempart 2 | systems-designer | `/balance-check` | Ouverte |
| Marqueur visuel des six protocoles sur la carte (pilier 1) | art-director | Art bible §5 | Ouverte |
| Passe de nommage | narrative-director | — | **Faite le 2026-10-30** : noms adoptés par l'utilisateur (voir règle 2bis) ; à relire par le CD au CD-PLAYTEST (la ligne narrative n'est pas verrouillée) |
| Palier de lancement : nombre de protocoles (concept : 10 à 12) et déblocages (par exemple une capacité en fin de branche) ; aucune décision de l'utilisateur à ce jour | game-designer, producer | Révision du concept | Ouverte |
| IA qui recherche réellement (liste de choix, difficulté) à la place du calendrier fixe | game-designer, ai-programmer | Alpha | Reporté |
| Registre cosmétique « protocoles découverts » (pilier 2) ; il ne doit pas devenir un écran de texte à côté du jeu | narrative-director | Palier de lancement | Reporté |
