# Revue d'architecture — 2026-11-02

**Périmètre** : ADR-0001 à ADR-0011 (tous Accepted), `docs/registry/architecture.yaml`, et pour la première fois la **conformité du code** (`src/`, 211 fichiers, environ 12 000 lignes ; 89 suites de tests) aux décisions et aux motifs interdits du registre. Base : `main` (`a15ec68`) plus la PR #17, qui solde la revue du 2026-11-01 (CI verte, `gdunit4` compris).

**Verdict : CONCERNS.** Les contrats Core sont tenus dans le code : pipeline, état, vision, sauvegarde, injection sans autoload, séquenceur sans `await` ni minuteur. Trois écarts majeurs séparent le code des décisions acceptées. Le plus gros : ADR-0001 décrit un rendu qui n'existe pas.

---

## 1. Majeurs

### A1. ADR-0001 est Accepted, mais le rendu décrit n'a pas été construit
- **Le code** : `TileRenderer` (`src/presentation/tiles/tile_renderer.gd`) dessine en mode immédiat dans `_draw()`, avec `draw_rect` et `draw_polyline` pour chaque tuile, nœud, ruine, unité et effet, à partir d'un `TileSnapshot` pris sur `FactionView(JOUEUR)`. Les animations sont des `TileEffect` minutés sur l'horloge de présentation.
- **Ce qui n'existe pas** : `MultiMeshInstance2D`, le contrat à huit canaux, `WaveScheduler`, le shader, `g_time`, `TileTimeSource`, l'événement `ColorTilesChanged`. Aucun `.gdshader` hors de `prototypes/`.
- **Le registre décrit le système absent** : `tile_render_data` (état), `tile_wave_animation` (API), `shader_reads_game_state` et `global_shader_parameter_get_in_game` (motifs interdits), budget `tile-rendering` (« 1 appel de dessin »).
- **Où l'écart est noté** : seulement dans ADR-0002 (Écarts, point 1). ADR-0001 n'a aucune note d'implémentation.
- **Risque de performance** : chaque `queue_redraw()` redessine toute la carte, soit 256 tuiles avec bords de brouillard, motifs et unités. Cela arrive à chaque image pendant un effet, et à chaque image tant que la flèche d'aide des premiers tours oscille. Le coût n'est mesuré nulle part, alors que le budget est de 1 ms.

**Correction recommandée** : un **ADR-0012 « Rendu immédiat par instantané »** qui remplace ADR-0001 (`superseded_by`). Il décrirait `TileSnapshot` (la frontière anti-fuite est meilleure qu'avec ADR-0001 : le rendu ne lit jamais l'état réel), les `TileEffect`, le redessin à la fin d'un lot et un budget mesuré sur appareil. Le MultiMesh d'ADR-0001 deviendrait le repli si la mesure dépasse 1 ms. Les entrées du registre seraient marquées `superseded_by: ADR-0012`. Garder ADR-0001 Accepted laisse les futures stories construire sur un contrat absent.

### A2. Animations réduites : la limite de 3 flashs par seconde (WCAG 2.3.1) n'est pas garantie
- ADR-0002 §6 confie la fusion en créneaux de `T_CRENEAU_RÉDUIT` (334 ms) au séquenceur. `PresentationSequencer` n'appelle jamais `handle_merged` (Écarts d'ADR-0002, point 2).
- En animations réduites, les ondes passent à 0 ms : chaque lot change les couleurs d'un coup. À la vitesse Instantanée du tour ennemi (horloge × 1 000), plusieurs lots de `TileOwnersChanged` / `TilesRevealed` peuvent se suivre dans la même seconde. C'est justement ce que la fusion devait empêcher, et le réglage « Réduire les animations » existe maintenant pour le joueur (`settings_screen.gd`).

**Correction** : dans `PresentationSequencer.advance`, en `reduced_motion`, regrouper les événements fusionnables de lots consécutifs dans un créneau de `reduced_slot_ms` et appeler `handle_merged`. Les étapes d'attaque, `RuinRead` et `MatchEnded` ne sont jamais fusionnés. Ajouter le test AC-HU38 sur horloge factice (au plus 3 changements de luminance par seconde, quelle que soit la vitesse).

### A3. La phase ennemie tourne entièrement sur le fil principal, et le registre dit le contraire
- `AiRunner.advance` appelle `plan_next` sur le fil appelant : c'est l'écart noté dans ADR-0005 (Implémentation, Écarts). Chaque commande de l'IA enchaîne, dans la même image : une `filtered_copy`, jusqu'à 1 000 évaluations, `apply` avec le recalcul de vue des deux factions, puis la **sauvegarde synchrone** (écriture, relecture, SHA-256).
- Le registre `ai-runner-frame` affirme que « la planification tourne sur WorkerThreadPool et n'y compte pas ». C'est faux pour le code actuel.
- `t_write` n'est toujours pas mesuré sur appareil (point ouvert de la revue du 01/11). Avec les 20 ms du GDD 16, chaque commande de l'IA dépasse à elle seule la cible de 16,6 ms.

**Correction** : écrire l'état réel dans la note du registre (« planification sur le fil principal au MVP, écart d'ADR-0005 §7 »). Mesurer sur appareil, dans une seule story « spike », la pire image d'une commande de l'IA (planification, application et sauvegarde) et `t_write`. Le résultat décide des deux reports à la fois : le fil de travail du planificateur (ADR-0005 §7) et le fil d'écriture (ADR-0006 §7).

---

## 2. Mineurs

| # | Où | Constat | Correction |
|---|---|---|---|
| m1 | ADR-0002, Écarts | Point 2 : « pas encore de réglage d'utilisateur » ; point 3 : « pas de `CameraHandler` ». Les deux sont périmés : `GameSettings.REDUCED_MOTION` est dans l'écran des réglages et `camera_handler.gd` existe | Rafraîchir les écarts 2 et 3 |
| m2 | ADR-0001, Related | « ADR-0002 : écrit (Proposed) », alors qu'il est Accepted | Inclus dans A1 |
| m3 | `src/app/real_file_store.gd` | `write` ignore le `bool` rendu par `store_buffer` et se fie à `get_error()`. La consigne d'ADR-0006 dit « chaque `store_*` doit voir sa valeur de retour vérifiée » | `if not file.store_buffer(bytes): …` avant `get_error()` |
| m4 | `perception_rules.gd` (`keys()`, `values()`), `territory_rules.gd` (`keys()`) | Parcours de `Dictionary` dans des règles de jeu. Le résultat ne dépend pas de l'ordre (lignes triées par id, clés triées), mais le motif interdit `dictionary_iteration_in_game_rule` est absolu et aucun contrôle de CI ne le vérifie | Préciser le motif : « jamais d'itération **dont le résultat dépend de l'ordre** ; un parcours de clés est trié avant usage ». Ou réécrire sur des tableaux triés |
| m5 | `AiRunner` (`_skipped`, `refusals`) | État transitoire remis à zéro par `resume`. `_skipped` est sans effet après une reprise, car une sauvegarde suit toujours une commande appliquée et le `curseur_ia` dépasse alors l'unité refusée. En revanche, la coupure `refusals_max` peut tomber à un autre moment qu'en un run sans arrêt | Écrire cet invariant dans ADR-0005 §5, ou compter les refus dans l'état ; un refus reste un bogue (« jamais attendu ») |

---

## 3. Conformité vérifiée dans le code

| Décision ou motif interdit | Vérification | Résultat |
|---|---|---|
| Pas d'`await` ni de `create_timer` (ADR-0002) | grep sur `src/` | Aucun |
| Distribution des événements sans signal (ADR-0002) | grep `emit` / `signal` | Signaux du HUD seulement (boutons de l'interface), aucun dans le séquenceur |
| Pas d'autoload ni de recherche dans l'arbre depuis le Core (ADR-0008) | `project.godot`, `check-layer-deps` | Aucun autoload ; `get_tree()` seulement dans `Bootstrap` (application) |
| `FileAccess` / `DirAccess` derrière un port (ADR-0006, 0009) | grep | `RealFileStore` et `ResDataSource` seulement |
| Aucun hasard du moteur dans les règles (ADR-0003) | grep `randi`, `RandomNumberGenerator` | `randi()` seulement pour la graine d'une nouvelle partie (`Bootstrap`), hors des règles |
| Jamais `JSON.parse_string` (ADR-0009) | grep | Aucun |
| Entiers seulement dans le Core (ADR-0003, 0009) | grep des flottants | Seulement le `delta` de `_process` et le contrôle de schéma |
| `process_priority` (ADR-0002) | grep | −20 / 0 / 10 / 20, conformes ; −10 absent faute de `TileTimeSource` (A1) |
| Séquence d'écriture de la sauvegarde (ADR-0006 §6) | `save_store.gd` | `.tmp`, relecture vérifiée, rotation, mise de côté si le courant est douteux, suppression de la cible avant renommage ; `.tmp` supprimé au chargement |
| Rendu sans fuite (ADR-0007) | `tile_snapshot.gd`, `match_screen.refresh` | Instantané pris sur `FactionView(JOUEUR)` et `fog_level`, redessiné seulement à l'état inactif ou à la fin d'un lot |
| Outillage promis | dépôt | `check-layer-deps`, `check-json-duplicate-keys`, `.gitattributes`, `export_presets.cfg`, gdUnit4 6.2.2, workflow `tests` : présents |

---

## 4. Suivi des revues précédentes

- **2026-10-30** : soldée.
- **2026-11-01** : soldée par la PR #17 (tableau de suivi en section 6). Reste ouverte la mesure de `t_write`, reprise ici dans A3.

---

## 5. Ce qui est solide

- La frontière anti-fuite tient de bout en bout : validation sur `FactionView`, copies filtrées, événements filtrés par la vue du joueur, rendu sur un instantané de la vue. Aucun chemin du rendu ne lit l'état réel.
- Les ADR 0003 à 0011 sont implémentés avec des notes d'écarts datées. Seul ADR-0001 n'en a pas.
- Les tests de propriété (états aléatoires, rejeu, reprise après chaque commande) couvrent les invariants les plus coûteux à perdre.
- Le CI garde les règles de structure : écrivain unique par tranche, sens des dépendances, clés JSON dupliquées.

---

## 6. Suivi (2026-11-02)

| Point | État |
|---|---|
| A1 | **Ouvert, décision attendue** : remplacer ADR-0001 par un ADR-0012 (rendu immédiat) ou construire le MultiMesh |
| A2 | Fait : le séquenceur espace de `reduced_slot_ms` de temps réel les lots qui changent les couleurs (`SequenceOrder.is_mergeable`, `ClockSource.scale()`) ; 4 tests sur horloge factice (créneau, vitesse Instantanée, mode normal inchangé, attaque jamais retardée). Au lieu de `handle_merged`, qui n'a rien à fusionner : l'état final d'un lot est déjà la dernière valeur par tuile (ADR-0002, Écarts) |
| A3 | Partiel : la note du registre dit la vérité (planification sur le fil principal au MVP) ; les compteurs `AiRunner.worst_advance_usec` et `SaveCoordinator.worst_write_usec` et la procédure du spike sont en place (ADR-0005). **Ouvert** : la mesure elle-même, sur un appareil Android de référence |
| m1 | Fait : écarts 2 et 3 d'ADR-0002 mis à jour |
| m2 | Fait : ADR-0001, Related (le reste relève d'A1) |
| m3 | Fait : `RealFileStore.write` vérifie le `bool` de `store_buffer` |
| m4 | Fait : le motif `dictionary_iteration_in_game_rule` vise l'ordre qui décide du résultat ; les deux parcours triés sont cités comme permis |
| m5 | Fait : ADR-0005 §3, un refus de l'IA est un bogue, et ce qu'une reprise change à la coupure `N_REFUS_MAX` |
