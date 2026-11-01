# ADR-0005: IA ennemie — planificateur pur sur copie filtrée figée, exécuteur cadencé par la présentation

## Status
Accepted

## Date
2026-10-30

## Last Verified
2026-10-30 — conception sur le GDD 9 et les ADR-0002 à 0004 ; **aucun prototype** ; aucune API de moteur postérieure à la connaissance du modèle n'est utilisée.

## Decision Makers
Utilisateur (direction de projet), Claude (rédaction), technical-director (validation avant écriture).

## Summary
Le tour de l'IA est une fonction déterministe de l'état au début de la phase ennemie : un **planificateur pur** (`AiPlanner`, `RefCounted`) évalue ses candidates sur une **copie filtrée figée** de l'état vu par l'IA et rend des commandes ; un **`AiRunner`** (machine à états avancée dans `_process`) les soumet une à une au pipeline de commandes, **cadencé par le séquenceur de présentation** (il n'envoie la commande suivante que lorsque la présentation est inactive). Les états de rôle, les pistes et les compteurs de siège vivent dans une tranche de l'état, jamais dans des nœuds.

## Engine Compatibility

| Field | Value |
|-------|-------|
| **Engine** | Godot 4.7.2 |
| **Domain** | Gameplay (IA) |
| **Layer** | Feature |
| **Knowledge Risk** | HIGH (prudence : aucune API postérieure à la connaissance du modèle n'est utilisée) |
| **References Consulted** | `docs/engine-reference/godot/VERSION.md`, `docs/engine-reference/godot/current-best-practices.md`, `design/gdd/ia-ennemie.md`, `design/gdd/modele-etat-partie.md`, ADR-0002 à 0004 |
| **Post-Cutoff APIs Used** | Aucune |
| **Verification Required** | (0) **`WorkerThreadPool` sur Android** (NOT SOURCEABLE, vérifié seulement sur Windows) : tâche postée, interrogée, jetée sur ÉTAT_CHARGÉ ; (1) coût d'une perception (`filtered_copy`) et d'une copie sur Android ; (2) 20 000 évaluations et 2 500 copies tiennent dans le temps de tour sur l'appareil de référence (non nommé) ; (3) une unité par image : latence perçue du tour ennemi ; (4) test de déterminisme sur 100 exécutions ; (5) reprise après arrêt au milieu de la phase ennemie : rejeu identique |

## ADR Dependencies

| Field | Value |
|-------|-------|
| **Depends On** | ADR-0003 (état, tranches, `filtered_copy`, `duplicate_state`) ; ADR-0004 (`submit`, `check`, `preview`, `apply_on`) ; ADR-0002 (état inactif du séquenceur, file bornée) ; ADR-0007 (prédicat de visibilité de la perception) — Accepted avant celui-ci |
| **Enables** | ADR du système de sauvegarde (reprise de tour) ; stories d'IA ; équilibrage des poids en données |
| **Blocks** | Stories Feature : IA ennemie (planificateur, rôles, runner, intentions, siège) |
| **Ordering Note** | Après ADR-0003, ADR-0002, ADR-0004 |

## Context

### Problem Statement
Le GDD 9 fixe le flux d'un tour (début de tour, perception, exécution des intentions, coups ordinaires, annonce, sauvegarde), un score glouton déterministe à poids en données, des rôles (Sentinelle, Chasseur, Bastion) à états, des pistes de dernières positions, un budget de 2 500 copies et 20 000 évaluations, une dégradation à deux paliers, un tour 1 et un tour 30 particuliers et un tour rejouable à l'identique. Il ne dit pas où vit le code, où sont les états, ni comment cadencer l'IA avec la présentation : un tour d'IA entier publierait plus d'événements que la file bornée (256) d'ADR-0002 ne peut en tenir, et provoquerait une RESYNCHRONISATION qui perdrait les animations du tour ennemi.

### Constraints
- L'IA ne triche pas : elle ne lit que sa vue (`filtered_copy`), y compris les pistes (règle 3 et 9 du GDD 9).
- Aucun hasard du moteur ni du compteur de tirages ; ordre total des égalités (règle 14).
- Budget en **comptage**, jamais en millisecondes, pour rester rejouable (règle 19).
- ATTAQUER et CAPTURER seulement par une intention stockée (`AUCUNE_INTENTION`, ADR-0004).
- Une intention par unité ; annonce en fin de phase ennemie, exécution au début de la suivante.
- Sauvegardes (GDD 16, règles 8 et 9, décision du 2026-10-30 reprise de la PR #3) : **après chaque commande appliquée, celles de l'IA comprises**, et en fin de partie. Un arrêt en cours de phase ennemie recharge l'état d'après la dernière commande : le système des tours (3) fait **reprendre** la phase, et l'IA décide **à partir de l'état seul**.

### Requirements
- Tour d'IA = fonction pure de l'état de début de phase (même état, mêmes commandes).
- Pas d'état d'IA hors de l'état de jeu (sauvegarde, rejeu, copies).
- Cadence compatible avec « un lot par action ennemie » du HUD (règle 15 de `hud-systeme.md`).

## Decision

**1. Planificateur pur, une commande à la fois.** `AiPlanner` (`RefCounted`, sans nœud, sans accès au moteur) reçoit une copie **filtrée** de l'état vu par l'IA (`filtered_copy(IA)`, bâtie sur le prédicat `VisionService.can_see` d'ADR-0007), les paramètres en données (`assets/data/ai.*` : poids de F1, `K_DEST`, `LEASH`, `PISTES_TTL`, `RAID_RADIUS`, `EVALS_MAX`…) et un `AiBudget`. `plan_next(frozen, params, budget) -> Command` rend **la prochaine commande** (ou `null` quand l'unité a fini) pour **l'unité courante**, après avoir évalué ses candidates avec `check` et `apply_on` de la `RuleTable` (ADR-0004 §2, table de règles sans état, **pas** l'instance du pipeline) sur des `duplicate_state()` de la copie ; il n'écrit jamais l'état réel. **Une perception avant chaque appel à `plan_next`** (revue du 2026-10-30, B2) : le runner construit `filtered_copy(IA)` de l'**état réel** avant chaque appel, jamais une copie gardée d'un appel à l'autre. Le moment ne se devine donc pas, il se déduit de l'état : le run sans arrêt et le run repris font exactement les mêmes appels sur les mêmes entrées, et la copie reflète une embuscade subie (zéro refus, AC-IA12). Le surcoût est de quelques dizaines de `filtered_copy` par tour, comptées dans le budget. *Ceci change la règle 3 du GDD 9 (une perception figée) : GDD SYNC, décision du game-designer.* Les égalités se résolvent par l'ordre total du GDD 9 ; **aucun tirage**.

**2. États d'IA dans l'état (propriétaires précisés).** Une nouvelle tranche **« agents de l'IA »** (ADR-0003, colonnes triées par id, propriétaire le système 9) porte seulement les états de rôle (POSTE, TRAQUE, RETOUR ; CAPTURE, TIENT, RIPOSTE, SIÈGE), le compteur « tours sans cible », le poste et le motif courant. Les **pistes** et le **compte de siège** restent dans la tranche Intentions (GDD 1, propriétaire 9), et le drapeau **IA passive** dans l'en-tête (propriétaire 3) ; l'IA le lit. **Chemin d'écriture, un porteur par donnée** : les **pistes** sont mises à jour par la fonction de perception du système 9, appelée par l'application de `COMMENCER_LE_TOUR(IA)` à partir des octets de visibilité de l'IA ; les **rôles, le siège et les compteurs** sont écrits par l'application de `ANNONCER_LES_INTENTIONS`, qui porte leurs nouvelles valeurs en données pures. Au tour 30, en IA passive ou à la coupure `N_REFUS_MAX`, l'annonce est sautée ou réduite : les rôles et le siège **gardent leur valeur précédente**. Ainsi le `CommandLog` seul reconstruit tout (ADR-0004 §10 : le rejeu ne relance pas le planificateur). **Tranche privée à la faction** : un attribut « privé » de la table déclarative des colonnes (ADR-0003) fait que `filtered_copy(IA)` **garde** cette tranche et ses pistes (savoir acquis légitimement ; une piste peut viser un id absent de la copie, le planificateur le tolère) et que `filtered_copy(JOUEUR)` la **retire** (le poste et le rôle d'un Chasseur caché ne doivent pas entrer dans les aperçus du joueur). **GDD SYNC** : GDD 1 (nouvelle tranche, schéma).

**3. Exécuteur cadencé, qui émet quoi.** `AiRunner` (`Node`, `process_priority` 20, valeur 20 inscrite dans la liste d'ADR-0002, source unique : −20, −10, 0, 10, 20) est une machine à états avancée dans `_process` : `IDLE`, `PERCEIVING`, `PLANNING` (tâche de planification en cours, §7), `EXECUTING_INTENTIONS`, `MOVING`, `ANNOUNCING`, `DONE` (**pas d'état `SAVING`** : seul le `PostCommitPort` d'ADR-0004 sauvegarde, après chaque commande ; le runner ne la déclenche pas). Le **système des tours (3)** émet `COMMENCER_LE_TOUR(IA)`, appelle `start_turn`, puis émet `COMMENCER_LE_TOUR(joueur)` quand le runner appelle son rappel `on_turn_finished`. Le **runner** émet les `EXÉCUTER_UNE_INTENTION` par id croissant, les coups ordinaires (DÉPLACER, MONTER_NŒUD) et `ANNONCER_LES_INTENTIONS`. Il avance **d'une commande par image au plus**, et **uniquement quand un `PacingGate`** (port étroit déclaré en Core, implémenté par un adaptateur de présentation ; une version factice toujours prête pour les tests) **dit « prêt »** (séquenceur inactif, file vide) ; il ne référence aucune classe de Presentation. La condition « place dans la file pour le plus gros lot » n'est qu'une **assertion**. Le temps de présentation n'influence **jamais** le choix des commandes : il ne fait que retarder leur envoi. **Refus** : un refus du pipeline réel est journalisé en développement, incrémente le compteur, abandonne les commandes restantes de l'unité, re-perçoit (l'appel suivant repart d'une copie neuve de l'état réel) et passe à l'unité suivante ; à `N_REFUS_MAX` = 32 on passe directement à l'annonce (un refus est lui-même déterministe). **Arrêts** : le runner s'arrête sur `PARTIE_TERMINÉE` (contrôle de fin de partie après chaque commande, ou ABANDONNER entre deux commandes) et revient à `IDLE` sur `ÉTAT_CHARGÉ`. L'annulation d'une intention est décidée par le handler d'`EXÉCUTER_UNE_INTENTION` sur l'état réel (ADR-0004 §9), pas par le planificateur ; `plan_next` ne couvre que les coups ordinaires et l'annonce.

**4. Budget et dégradation en comptage.** Le budget est **par appel à `plan_next`**, non par tour (revue B2, cause 3) : plafond d'un appel = budget du tour ÷ nombre d'unités de l'IA, en données (`EVALS_PAR_APPEL`, `COPIES_PAR_APPEL`) ; l'`AiBudget` est recréé à chaque appel, donc une reprise n'a aucun compteur à retrouver. Le planificateur maintient des compteurs entiers par appel ; le plafond du tour reste copies ≤ 2 500, évaluations ≤ `EVALS_MAX` = 20 000 (données), copies filtrées comprises. Les comptages pilotent la logique ; `T_ai` = 2 000 ms (formule 5 du GDD 1, formule 3 du GDD 23) est une **cible mesurée** sur l'appareil de référence, jamais une coupure : le budget unique du tour est ainsi clos. Un **budget en ms par image sur le fil principal** pour le runner (proposé : 2 ms) est inscrit au registre : il couvre la perception, la soumission et l'interrogation de la tâche, **pas la planification**, qui tourne sur un fil de travail (§7). **Sous-ensemble MVP** : la dégradation est un **plafond dur** (au-delà du budget, les unités restantes rejoignent leur poste ou restent, ANNONCER jamais sauté) ; les deux paliers (70 % puis 100 %), `w_raid` et les pistes sont **[Lancement]** tant qu'un prototype ne montre pas une IA amnésique ; la vitesse Instantanée du HUD l'est aussi.

**5. Reprise à la commande suivante.** Un arrêt en cours de phase ennemie recharge l'état d'après la dernière commande ; le système 3 relance le runner par `resume(state)` et la phase **continue à la commande suivante** (planification déterministe, présentation reconstruite sans onde). Le runner reconstruit sa position **de l'état seul** : étape EXÉCUTION s'il reste des intentions de statut « annoncée » dont le tour d'exécution est le tour courant ; sinon coups ordinaires, puis annonce. Pour que les coups ordinaires reprennent là où ils en étaient, la tranche « agents de l'IA » porte une valeur scalaire **`curseur_ia`** (id de la dernière unité de l'IA qui a émis une commande ce tour ; remise à 0 par COMMENCER_LE_TOUR(IA), écrite par l'application de chaque commande de l'IA) : `plan_next(état)` ne considère que les unités d'id **≥** `curseur_ia` (borne **incluse** : la reprise repart de l'unité qui a émis la dernière commande, exactement comme le run sans arrêt, qui rappelle `plan_next` pour cette unité juste après sa commande et reçoit `null` quand elle a fini ; une unité d'id plus petit n'est pas replanifiée avec un état changé) (**GDD SYNC** : GDD 1, tranche Agents ; GDD 9, règle 3). Le `curseur_ia` fait partie de l'état et de `filtered_copy(IA)`. L'état du runner et `AiBudget` restent **transitoires**, jamais sauvegardés : tout ce qui décide du prochain coup est dans l'état. AC-IA33 : arrêt après la commande k, pour tout k.

**6. Tour 1, tour 30, ruines, difficulté, protocoles.** Tour 1 : rien n'est exécuté ; tour 30 : aucune annonce ; les ruines n'entrent pas dans la copie filtrée ; un seul niveau (« Standard ») plus « IA passive » en première partie (aucune annonce ni mouvement, vue recalculée) ; au MVP l'IA reçoit ses protocoles par le calendrier fixe de `arbre-protocoles.md` (règle 15), sans commande RECHERCHER ; le crochet « renfort » (règle 17bis) est une étape vide.

**7. Planification sur un fil de travail** (revue du 2026-10-30, B1 ; décision de l'utilisateur). Le coût d'une planification (de l'ordre de 100 à 200 ms pour un appel, formule 3 du GDD 23) ne tient pas dans une image. Le runner poste `AiPlanner.plan_next` sur `WorkerThreadPool` et interroge `is_task_completed` dans `_process` (état `PLANNING`), puis soumet la `Command` rendue sur le fil principal. Conditions : (a) la tâche reçoit une copie **qu'elle possède seule** (`filtered_copy` construite avant le poste), des `AiParams` en lecture seule et un `AiBudget` neuf ; elle ne touche ni arbre de scène, ni nœud, ni pipeline, ni état réel ; (b) elle appelle la `RuleTable` sans état (ADR-0004 §2), jamais l'instance de `CommandPipeline` qui détient `CommandGate` et `UndoSlot` ; (c) le résultat est une fonction de ses entrées seules, donc le fil ne change pas le déterminisme (le temps d'attente n'influence jamais le choix) ; (d) sur `ÉTAT_CHARGÉ`, `PARTIE_TERMINÉE`, ABANDONNER, fin de partie ou libération de la session (ADR-0008 §6), `cancel()` lève un drapeau d'annulation que la tâche teste, attend la fin de la tâche (`wait_for_task_completion`) et **jette** son résultat. Vérifié sur Godot 4.7.2 Windows en headless : `add_task` avec un `Callable`, `is_task_completed`, `wait_for_task_completion` et un résultat identique au calcul sur le fil principal ; **non vérifié sur Android** (`WorkerThreadPool` absent de `docs/engine-reference/godot/` : NOT SOURCEABLE).

### Architecture Diagram

```
 Début de phase ennemie (état sauvegardé après chaque commande ; reprise possible à toute commande)
        │
 AiRunner (Node, _process, machine à états) ── cadencé par ──► PacingGate.is_ready() (adaptateur : séquenceur inactif, file vide)
        │ avant CHAQUE appel : filtered_copy(IA) de l'état réel ──► copie possédée par la tâche
        ▼
 WorkerThreadPool ── tâche : AiPlanner.plan_next(copie, params, AiBudget neuf)  (RefCounted pur, RuleTable sans état, aucun tirage)
        │ is_task_completed() interrogé dans _process ──► une Command (ou null)
        ▼
 CommandPipeline.submit(cmd)  (émetteur IA/SYS ; ADR-0004)  ──► état réel ──► sauvegarde ──► EventBatch ──► EventQueue (ADR-0002)
 État : tranche « agents de l'IA » (rôles, compteur, poste, motif, curseur_ia) ; tranche Intentions (intentions, pistes, siège) ; en-tête (IA passive)
```

### Key Interfaces

```gdscript
class_name AiPlanner extends RefCounted
func plan_next(frozen: GameState, params: AiParams, budget: AiBudget) -> Command   # null quand l'unité courante a fini ; exécutée sur WorkerThreadPool (§7)
func plan_announcement(frozen: GameState, params: AiParams, budget: AiBudget) -> Command   # ANNONCER_LES_INTENTIONS (rôles, siège, compteurs en données)

class_name AiRunner extends Node
var on_turn_finished: Callable                           # rappel injecté par le système des tours (contrat enregistré)
func start_turn(state: GameState, pipeline: CommandPipeline, pacing: PacingGate) -> void
func resume(state: GameState, pipeline: CommandPipeline, pacing: PacingGate) -> void   # reprise à la commande suivante (§5), après on_state_loaded
func cancel() -> void                                    # idempotent : drapeau d'annulation coopératif, wait_for_task_completion, résultat jeté (§7)
func is_running() -> bool

class_name PacingGate extends RefCounted                 # port Core ; adaptateur de présentation ; version factice toujours prête
func is_ready() -> bool

class_name AiParams extends RefCounted                   # données : poids, K_DEST, LEASH, PISTES_TTL, RAID_RADIUS, EVALS_MAX, tir groupé
class_name AiBudget extends RefCounted                   # compteurs de copies et d'évaluations ; plafond dur au MVP, paliers au lancement
```

### Implementation Guidelines
- Le planificateur **doit** être pur : aucune lecture de l'état réel hors de la copie figée, aucune horloge, aucun hasard.
- Le runner **ne doit jamais** choisir une commande : il ne fait que soumettre dans l'ordre rendu par le planificateur.
- Un état d'IA **ne doit jamais** vivre hors des tranches de l'état (agents de l'IA, Intentions, en-tête) ; le runner **ne doit jamais** déclencher de sauvegarde lui-même (c'est le `PostCommitPort`) ni référencer une classe de Presentation.
- L'IA **ne doit jamais** lire une unité cachée, une ruine, un dormant jamais vu ni la tranche des autres factions (AC-IA14).
- Toute pondération **doit** venir des données ; aucune statistique en dur.
- La reprise **doit** continuer à la commande suivante à partir de l'état sauvegardé (§5) ; une perception **doit** précéder chaque appel à `plan_next` et le budget **doit** être par appel.
- La tâche de planification **ne doit jamais** toucher l'arbre de scène, un nœud, l'état réel ni le pipeline.
- `filtered_copy(JOUEUR)` **ne doit jamais** contenir une ligne de la tranche « agents de l'IA ».

## Alternatives Considered

### Alternative 1: Arbres de comportement en nœuds Godot
- **Description**: un arbre de nœuds par Gardien, état dans les nœuds.
- **Pros**: outillage visuel, familier.
- **Cons**: état hors de l'état de jeu (sauvegarde, rejeu, copie impossibles) ; difficile à rendre déterministe ; non copiable pour les 2 500 aperçus.
- **Rejection Reason**: contredit « données pures » et le rejeu.

### Alternative 2: Recherche globale (minimax, MCTS)
- **Description**: exploration de l'arbre des coups sur copies.
- **Pros**: meilleur jeu potentiel.
- **Cons**: budget en comptage difficile à borner, le GDD 9 décide un score glouton lisible (« juste mais dure ») ; un coup imprévisible nuit à la lisibilité du pilier 3.
- **Rejection Reason**: contraire au design (IA lisible et prévisible).

### Alternative 3: États de rôle dans des scripts de nœuds d'unités
- **Description**: chaque unité porte son état de rôle.
- **Pros**: simple à écrire.
- **Cons**: les nœuds d'unité n'existent pas dans l'état ; copie et rejeu perdent l'état.
- **Rejection Reason**: contredit ADR-0003.

### Alternative 4: IA exécutée d'un trait, sans cadencer la présentation
- **Description**: tout le tour d'IA calculé et appliqué en une image.
- **Pros**: simple.
- **Cons**: déborde la file d'événements bornée (RESYNCHRONISER) et perd les animations du tour ennemi ; pas de « un lot par action ennemie ».
- **Rejection Reason**: incompatible avec ADR-0002 et le HUD (règle 15).

## Consequences

### Positive
- Le tour d'IA est une fonction pure de l'état de début de phase : reproductible, testable, rejouable après arrêt.
- Aucun état caché : copie, sauvegarde et rejeu emportent tout.
- La présentation n'influence pas le jeu (seul le rythme).
- Planificateur testable sans moteur de rendu.

### Negative
- Un tour d'IA dure aussi longtemps que sa présentation (une commande à la fois) ; l'IA « passive » et la vitesse Instantanée l'atténuent.
- Un second objet (runner) à tester ; la perception se refige après chaque révélation.
- Les poids et la dégradation sont à équilibrer en données ; la qualité de jeu n'est pas prouvée.

## Risks
- **Budget non tenu sur Android** : *Atténuation* : mesure sur appareil ; réduire `K_DEST`, candidates et poids avant de changer d'architecture.
- **Latence perçue d'un tour ennemi long** (une commande par action visible) : *Atténuation* : vitesses Rapide et Instantanée (HUD) ; la planification n'est pas retardée.
- **Rejeu non identique** (un état caché dans une variable) : *Atténuation* : état d'IA uniquement dans la tranche, test de rejeu sur 100 exécutions.
- **Re-perception avant chaque unité** : une dizaine de `filtered_copy` par tour. *Atténuation* : comptées dans `AiBudget` ; coût mesuré ; si trop cher, re-perception seulement après une commande dont le résultat montre une révélation (lue sur `ApplyResult`, pas sur la file).
- **Fuite par la tranche privée** : *Atténuation* : attribut « privé » de la table de colonnes, test de parité `FactionView` / `filtered_copy`.

## GDD Requirements Addressed

| GDD System | Requirement | How This ADR Addresses It |
|------------|-------------|--------------------------|
| ia-ennemie.md (9) | Règles 1 à 8 : flux d'un tour, annonce en fin de phase, invariant d'intention | `AiRunner` (états), pipeline (ADR-0004) |
| ia-ennemie.md (9) | Règle 3 et 9 : état filtré, pistes | `filtered_copy` figée, tranche « agents de l'IA » |
| ia-ennemie.md (9) | Règles 10 à 13 : rôles, couverture, raid, siège | États de rôle en tranche, évalués par le planificateur |
| ia-ennemie.md (9) | Règles 14 à 17 : score glouton déterministe, poids en données | `AiPlanner` pur, `AiParams`, égalités ordonnées |
| ia-ennemie.md (9) | Règles 19 et 20 : budget en comptage, dégradation | `AiBudget`, paliers à 70 % et 100 % |
| ia-ennemie.md (9) | Règles 21 à 25 : tour 1, 30, ruines, passif | §6 |
| hud-systeme.md (17) | Règle 15 : un lot par action ennemie | Cadence par `sequencer.is_idle()` |
| commandes-evenements.md (23) | Formule 3 : budget par commande ; formule 4 : file bornée | Budgets, place dans la file avant chaque soumission |
| modele-etat-partie.md (1) | Formule 5 : 2 500 copies par tour | `AiBudget` |

## Performance Implications
- **CPU**: ≤ 2 500 copies et ≤ 20 000 évaluations par tour (comptage) ; copie mesurée 15 µs sur PC (ADR-0003) ; une commande par image au plus.
- **Memory**: copie filtrée figée plus des `duplicate_state()` transitoires (≈ 8 Ko chacune).
- **Load Time**: négligeable.
- **Network**: sans objet.

## Migration Plan
Sans objet : aucun code de production n'existe.

## Validation Criteria
- AC-IA31 : même état et même graine, 100 exécutions, intentions identiques octet pour octet ; compteur de tirages inchangé.
- AC-IA32 : copies ≤ 2 500 et évaluations ≤ 20 000 ; paliers à 70 % et 100 % ; ANNONCER jamais sauté.
- AC-IA33 (reformulé : « arrêt en cours de tour ») : reprise rejouée à l'identique sans exécution doublée.
- AC-IA14 : la copie figée ne contient ni unité cachée, ni ruine, ni dormant non vu.
- AC-IA6 : ATTAQUER/CAPTURER émis par l'IA via `submit` hors exécution d'intention refusé `AUCUNE_INTENTION`.
- Le runner n'envoie une commande que si le séquenceur est inactif et la file peut tenir un lot ; un tour d'IA entier ne provoque jamais de RESYNCHRONISER.
- **Déterminisme sous perturbation de la présentation** : le même tour, avec et sans RESYNCHRONISER forcé et à des vitesses différentes, produit les mêmes commandes octet pour octet.
- Une embuscade pendant un coup de l'IA : zéro refus et une re-perception.
- Rejeu par `CommandLog` seul : rôles, pistes et siège identiques sans relancer le planificateur.
- Coupure à `N_REFUS_MAX`, puis annonce ; arrêt du runner sur PARTIE_TERMINÉE et retour à IDLE sur ÉTAT_CHARGÉ ; le runner n'émet aucune sauvegarde (le port post-commit écrit après chaque commande) ; reprise après un arrêt à la commande k, pour tout k, au même tour qu'un tour sans arrêt.
- Test de couche : le runner ne référence aucune classe de Presentation ; `filtered_copy(JOUEUR)` ne contient aucune ligne d'agent de l'IA.
- Pire image du runner ≤ 2 ms (proposé) ; mesure du budget sur Android de référence.

## Related
- GDD : `design/gdd/ia-ennemie.md` (9), `commandes-evenements.md` (23), `modele-etat-partie.md` (1), `hud-systeme.md` (17), `arbre-protocoles.md` (12), `sauvegarde-automatique.md` (16).
- ADR-0002, ADR-0003, ADR-0004.
