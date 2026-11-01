# Revue d'architecture — 2026-10-30

**Périmètre** : ADR-0001 à ADR-0006 (tous Proposed), `docs/registry/architecture.yaml`, contrôle CI `tools/ci/check-slice-writes.sh`, rapports de prototypes ; recoupement ciblé avec les GDD 1, 9, 16, 17, 23.

**Verdict : CONCERNS.** L'architecture est cohérente dans ses grands choix (état en colonnes, commandes en données pures, séquenceur en machine à états, enveloppe de sauvegarde). Cinq points bloquent l'acceptation : deux sont des défauts de conception (budget d'image de l'IA, déterminisme de la reprise), trois sont des contrats contradictoires entre ADR.

Ordre d'acceptation inchangé : ADR-0003 → ADR-0002 → ADR-0001 ; ADR-0004 → ADR-0005 et ADR-0006.

---

## 1. Bloquants

### B1. Budget d'image de l'IA impossible à tenir (ADR-0005, registre `ai-runner-frame`)
- Le registre fixe la pire image du runner à 2 ms, avec « une unité par image » (GDD 9, règle 19).
- Formule 3 du GDD 23 : `T_ai` = 2 000 ms pour C = 2 000 candidates, soit environ 1 000 ms d'aperçus par tour. Réparti sur une dizaine d'unités, cela fait de l'ordre de **100 à 200 ms dans une seule image**, au lieu de 2 ms.
- `plan_next` est synchrone dans `_process` : rien ne découpe la planification d'une unité.

**Correction recommandée** : exécuter `AiPlanner.plan_next` sur `WorkerThreadPool`. Le runner poste la tâche puis interroge son achèvement dans `_process`. Le planificateur est déjà pur (copie figée possédée, `RefCounted`, sans moteur), et le budget est compté, pas mesuré : le déterminisme est conservé. Deux conditions :
- le planificateur appelle une table de règles sans état (handlers et `validate`/`apply`), **pas** l'instance de `CommandPipeline`, qui détient `CommandGate` et `UndoSlot` ;
- le registre `ai-runner-frame` devient le coût du runner sur le fil principal (perception et soumission), pas celui de la planification.

### B2. La reprise en cours de phase ennemie n'est pas déterministe (ADR-0005 §1, §4, §5 ; AC-IA33)
Trois causes indépendantes :
1. **Perception par unité** : sans arrêt, les coups 2 et suivants d'une unité sont planifiés sur la copie figée *avant* son premier coup. Après une reprise, la copie est refaite sur l'état d'*après* ce coup, qui contient la vision gagnée. Les deux runs divergent.
2. **`curseur_ia`** = id de la dernière unité qui a *émis* une commande. Quand une unité finit, `plan_next` rend `null` et rien n'est écrit. Après une reprise, cette unité est donc replanifiée sur un état changé.
3. **`AiBudget` transitoire et par tour** : après une reprise, les compteurs repartent de zéro. Un tour qui avait atteint le plafond sans arrêt ne l'atteint plus après une reprise.

**Correction recommandée** : une perception, c'est-à-dire un `filtered_copy(IA)` de l'état réel, **avant chaque appel à `plan_next`**, et un budget **par appel à `plan_next`** au lieu d'un budget par tour (plafond = budget du tour ÷ nombre d'unités, en données). Avec ces deux règles, le run sans arrêt et le run repris font exactement les mêmes appels sur les mêmes entrées, et les causes 1 et 3 disparaissent par construction. La cause 2 aussi : sans arrêt, après le dernier coup de l'unité u, le runner appelle déjà `plan_next(perception(état))` pour u et reçoit `null`. La reprise fait le même appel avec le même résultat. Le surcoût est de quelques dizaines de `filtered_copy` par tour, à compter dans le budget.

### B3. Deux sources pour le numéro de schéma (ADR-0003 contre ADR-0006)
- ADR-0003, section Sérialisation : « Le numéro de schéma est dans l'en-tête », et l'en-tête de `GameState` porte la « version du schéma ».
- La même section ajoute plus loin : « porté par l'enveloppe (source unique) ». ADR-0006 §2 le confirme : « la charge utile ne le porte plus ».

**Correction** : retirer la version de schéma de l'en-tête de `GameState` (ADR-0003, Decision et en-tête ; GDD 1, tableau des tranches). `from_bytes(bytes, content_schema)` la reçoit de l'enveloppe.

### B4. Enum `CommandType` et signature `apply_on` (ADR-0004, registre)
- §2 annonce 13 types (VALIDER_LA_LECTURE comprise). La section Context et les Consequences en comptent 12, et l'enum de Key Interfaces en liste 12, **sans `VALIDATE_RUIN_READ`**.
- Le registre `command_submission` déclare `apply_on(copy, command, collector)`, alors qu'ADR-0004 déclare `apply_on(copy, command)`.

**Correction** : ajouter `VALIDATE_RUIN_READ` à l'enum, aligner « 13 » partout et aligner le registre sur ADR-0004.

### B5. Le verrou du joueur bloque des commandes internes (ADR-0002 §8, ADR-0004 §4–5)
`CommandGate.is_locked(faction)` ne connaît que la faction. VALIDER_LA_LECTURE est émise par SYS pour la faction du joueur. Quand l'écriture du profil est retentée plus tard (changement suivant, arrière-plan, chargement : ADR-0006 §8), cette commande peut arriver pendant `FRAGMENT_PANEL` ou `ATTACK_RESOLUTION`. Elle est alors refusée, ce qui viole la règle 12 du GDD 23 (« ni l'IA ni les commandes internes »).

**Correction** : `is_locked(faction: int, emitter: int)`, vrai pour un verrou du joueur seulement si `emitter == JOUEUR`.

---

## 2. Incohérences à corriger avant acceptation

| # | Où | Constat | Correction |
|---|---|---|---|
| M1 | ADR-0004 §4 contre ADR-0006 §7–8 | ADR-0004 s'appuie sur « l'écriture coalescée d'ADR-0006 », mais ADR-0006 dit qu'en synchrone il n'y a pas de coalescence : chaque commande écrit | Retirer la phrase d'ADR-0004. Le coût réel est N écritures d'environ 20 ms par phase ennemie, au-dessus du budget de 8 ms : décider le fil d'écriture dès maintenant si AC-F1 le confirme |
| M2 | ADR-0005, Implementation Guidelines | « La reprise doit rejouer le tour entier à partir de l'état d'après FINIR_LE_TOUR » contredit §5 (reprise à la commande suivante) | Remplacer par la règle de §5 |
| M3 | ADR-0005, diagramme | `plan_next` → `Array[Command]` (l'interface rend une seule `Command`) ; cadence par `PresentationSequencer.is_idle()` (§3 passe par `PacingGate`) ; pistes, siège et IA passive placés dans la tranche des agents (§2 les met dans Intentions et dans l'en-tête) | Redessiner le diagramme d'après §1 à §3 |
| M4 | ADR-0005, Validation et GDD Requirements | AC-IA32 exige « paliers à 70 % et 100 % », alors que §4 fait du MVP un plafond dur et renvoie les paliers au palier Lancement | Restreindre l'AC au plafond dur au MVP |
| M5 | Registre, `forbidden_patterns` | `runner_saves_or_references_presentation.why` dit « aucune sauvegarde pendant la phase ennemie » et `ai_state_outside_state.why` dit « rejoué depuis le début de la phase » : les deux sont périmés depuis la sauvegarde après chaque commande. `ai_decision_outside_state.adr` pointe ADR-0006 au lieu d'ADR-0005 | Mettre à jour `why` et `adr` (`revised: 2026-10-30`) |
| M6 | Registre, `performance_budgets` | Aucune entrée `target_fps` / `total_frame_budget_ms`, donc la somme n'est pas vérifiable. `game-state-copy` (0,2 ms) est un coût par copie, pas un budget d'image | Ajouter la cible (60 i/s, 16,6 ms, Mobile). Sortir `game-state-copy` des budgets d'image, ou le noter comme coût unitaire. Pire image d'un commit du joueur : 1 + 0,3 + 0,3 + 8 = 9,6 ms, ce qui tient ; avec les 20 ms d'écriture du GDD 16, la cible est dépassée |
| M7 | ADR-0003 | Le diagramme donne « en-tête (PackedInt32Array) » alors que la Decision et le registre donnent `PackedInt64Array`. La consigne « graine stockée dans un PackedInt32Array devient négative » est périmée. « Une entité détruite doit être marquée et non retirée » et « les entités détruites restent dans les colonnes » contredisent le compactage de fin de tour | Aligner le diagramme et les consignes sur la Decision |
| M8 | ADR-0002 | La liste des `process_priority` (−20, −10, 0, 10) ignore `AiRunner` (20, ADR-0005). L'Ordering Note (« attendent aussi l'ADR du modèle d'état ») et la section Related (« ADR-0001 à amender ») sont périmées | ADR-0002 possède la liste : y ajouter 20 et rafraîchir les notes |
| M9 | ADR-0006 §6 | « Supprimer le courant s'il existe encore » quand sa validité est inconnue contredit la contrainte « un fichier abîmé n'est jamais supprimé, il est renommé » | Renommer le courant de validité inconnue en fichier mis de côté (`BAD_FILE_CAP`) au lieu de le supprimer |
| M10 | ADR-0001 | 48 octets par instance : faux avec deux vec4. `TRANSFORM_2D` (8 floats), custom (4) et color (4) font 16 floats, soit **64 octets**, environ 16 Ko pour 256 tuiles (le prototype mesurait 12 floats avec un seul vec4). La phrase « Contrat de données… » est dupliquée (Key Interfaces). Related : « ADR à écrire : ADR-0002 » est périmé | Corriger les chiffres et supprimer le doublon |
| M11 | ADR-0004 et ADR-0006, Related | ADR-0004 garde « GDD SYNC : GDD 1 règle 3, exception validée », alors que §5 supprime l'exception. ADR-0006 garde « ADR-0004 §4 (déclencheurs : chaque commande du joueur) » au lieu de « chaque commande » | Rafraîchir |

---

## 3. GDD SYNC encore ouverts

- **Verrou d'attaque** : 1,5 s dans le GDD 8 (l. 462, 502) et le GDD 17 (l. 99, 114, AC-HU23) ; 1,6 s dans le GDD 23 (l. 159), le GDD 4 (l. 210) et `hud.md` (l. 371). ADR-0002 impose une valeur unique `ATTACK_LOCK_MS` sans la trancher. La décision revient au game-designer, puis il faut aligner les cinq documents.
- **GDD 16, règle 10** (l. 137–138) : la note GDD SYNC a été insérée, mais l'ancienne phrase « l'écriture est masquée par le délai de 400 ms » est toujours là, juste après. Le texte se contredit.
- **GDD 16, Limites connues** (l. 589) : « stabilité d'un CRC32 natif » est toujours présent ; ADR-0006 demande de le retirer.

---

## 4. Contrôle CI `check-slice-writes.sh`

Le self-test passe (5/5). Trois limites :
- **Faux positifs entre tranches** : le contrôle cherche `.<champ>` dans tout `src`, sans savoir à quelle tranche appartient l'objet. Si `UnitsSlice` et `NodesSlice` déclarent toutes deux `_alive`, le propriétaire des nœuds est signalé comme violant `UnitsSlice`. Il faut soit imposer des noms de champs uniques entre tranches (règle à écrire dans ADR-0003 et à vérifier par le script), soit préfixer les champs par la tranche.
- **Les tests ne sont jamais analysés** : `grep -r "$ROOT"` ne parcourt que `src`, donc l'argument `tests` n'a aucun effet. Le cas « tests may read private fields » réussit à vide, sans rien vérifier.
- **Contournement dynamique** : `get("_hp")`, `set("_hp", …)` et `s["_hp"]` échappent au motif. Ajouter un motif sur `get|set\("_` ou l'interdire par convention.

---

## 5. Couverture : ADR manquants

Classés par impact sur les ADR existants :
1. **Vision et prédicat de visibilité (GDD 5)** : ADR-0004 (parité `FactionView` / `filtered_copy`) et ADR-0005 (perception) reposent sur un « prédicat unique » et sur un cache de vision hors de l'état qu'aucun ADR ne définit. C'est la frontière anti-fuite du jeu.
2. **Racine de composition** : tout est injecté et aucun singleton n'est permis (ADR-0002), mais aucun ADR ne dit qui construit le pipeline, la file, le séquenceur, les ports et le runner, ni dans quelle scène, ni comment ces objets sont reconstruits au chargement.
3. **Format et chargement des fichiers de données** (`assets/data/…`) : tous les ADR y renvoient (durées, poids de l'IA, `TABLE_TEINTES`, `Q_max`) sans format, sans validation et sans moment de chargement.
4. **Entrées tactiles vers commandes (GDD 4)**, **composition des couches de présentation** (annoncé par ADR-0001) et **cadre de tests** (le fixture CI suppose GUT, ce qu'aucun ADR ne décide).

---

## 6. Références introuvables dans le dépôt

`docs/engine-reference/godot/*` (cité par les six ADR comme référence consultée), `.claude/docs/coding-standards.md`, `.claude/rules/prototype-code.md`, `.claude/scripts/registry.sh` (format du registre), `prototypes/meute-orpheline-concept/REPORT.md` (cité dans `prototypes/index.md`). À l'inverse, le prototype `etat-copie/` n'apparaît pas dans `prototypes/index.md`. Soit ces fichiers sont versionnés, soit les citations indiquent qu'ils sont externes au dépôt.

---

## 7. Ce qui est solide

- Séparation Core et Presentation tenue par construction : `EventSink`, `PacingGate`, ports nuls pour le rejeu.
- « Une copie ne publie jamais » garanti structurellement (effets rendus puis jetés), pas par un drapeau.
- Choix de représentation de l'état étayé par des mesures, avec un classement qui ne dépend pas de la plateforme.
- Chaque point NOT SOURCEABLE de la sauvegarde a un repli écrit (renommage, cycle de vie, exclusion Android).
- Registre YAML valide, propriétaires d'état sans doublon.
