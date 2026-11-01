# ADR-0006: Sauvegarde — enveloppe binaire à préfixe figé, écriture synchrone en série, port d'écriture injecté

## Status
Accepted

## Date
2026-10-30

## Last Verified
2026-10-30 — conception sur les GDD 16 et 22 et les ADR-0003 et 0004 ; tests headless de godot-specialist sur Godot 4.7.2-stable official, **Windows seulement**. Le comportement d'Android (remplacement par renommage, cycle de vie, exclusion de sauvegarde automatique, `fsync`) est NOT SOURCEABLE.

## Decision Makers
Utilisateur (direction de projet), Claude (rédaction), godot-specialist et technical-director (validation avant écriture).

## Summary
Un unique écrivain en série (`SaveStore`) écrit quatre fichiers sous `user://` (partie, copie de secours, profil, copie de secours), chacun dans une **enveloppe binaire à préfixe figé** (marque, version d'enveloppe, longueur, schéma de contenu, révision) autour d'une charge utile, terminée par une **empreinte SHA-256**. L'écriture est **synchrone sur le fil principal** dans le `PostCommitPort` d'ADR-0004, derrière un port `FileStore` injecté (réel, ou en mémoire avec injection de pannes). L'ordre des contrôles au chargement est normatif ; un fichier `.tmp` n'est jamais promu.

## Engine Compatibility

| Field | Value |
|-------|-------|
| **Engine** | Godot 4.7.2 |
| **Domain** | Core (persistance) |
| **Layer** | Core |
| **Knowledge Risk** | HIGH |
| **References Consulted** | `docs/engine-reference/godot/VERSION.md`, `docs/engine-reference/godot/breaking-changes.md` (ligne 91 : `FileAccess.store_*` renvoie `bool`), `docs/engine-reference/godot/current-best-practices.md`, `design/gdd/sauvegarde-automatique.md`, `design/gdd/profil-donnees-meta.md`, ADR-0003, ADR-0004 |
| **Post-Cutoff APIs Used** | `FileAccess.store_*` qui renvoie `bool` (4.4) ; `HashingContext`, `DirAccess.rename_absolute`, `DirAccess.copy`, `DirAccess.remove_absolute` existent depuis 4.0 et ne sont pas couverts par les références : NOT SOURCEABLE ; **vérifiés par test headless sur Windows, 4.7.2** ; Android non vérifié |
| **Verification Required** | (1) **Android** : résolution de `user://`, comportement de `rename` (sur Windows, mesuré : `rename` **supprime la cible avant de déplacer**, et la cible est perdue si le déplacement échoue ; ce n'est donc pas un remplacement atomique) ; (2) cycle de vie : les noms de notification existent en 4.7.2 (`NOTIFICATION_APPLICATION_PAUSED` 2015, `NOTIFICATION_APPLICATION_RESUMED` 2014, `NOTIFICATION_APPLICATION_FOCUS_OUT` 2017, `NOTIFICATION_WM_GO_BACK_REQUEST` 1007) ; leur déclenchement sur Android est NOT SOURCEABLE ; (3) exclusion de la partie de la sauvegarde automatique d'Android et équivalent iOS : NOT SOURCEABLE ; (4) vidage sur disque : `flush()` et `close()` ne renvoient rien et `FileAccess` n'offre pas de `fsync` connu ; la relecture vérifie le cache du système, pas le disque (Open Question du GDD 16) ; (5) coût de SHA-256 sur appareil (mesuré sur PC : 46 µs pour 8 Ko, 120 µs pour 26 Ko) ; (6) stockage plein (non testé) ; (7) mesure de `t_write` sur appareil (AC-F1) |

## ADR Dependencies

| Field | Value |
|-------|-------|
| **Depends On** | ADR-0003 (`to_bytes`, `from_bytes`, schéma de contenu, `restore_from`) ; ADR-0004 (`PostCommitPort`, ordre sauvegarde avant `EventSink.push`, `ProfilePort`, commande interne VALIDER_LA_LECTURE) — Accepted avant celui-ci ; l'amendement d'ADR-0003 (enveloppe) est fait |
| **Enables** | Stories de persistance (partie, profil, migration, réconciliation) ; menus (18) ; chronique (14) |
| **Blocks** | Stories Core : sauvegarde, chargement, réconciliation du journal de ruines, migration |
| **Ordering Note** | Après ADR-0003 et ADR-0004. La mesure Android est un critère de validation, pas une condition d'acceptation, **parce que** chaque point NOT SOURCEABLE a un repli écrit dans la Décision (renommage, cycle de vie, exclusion, fil d'écriture) |

## Context

### Problem Statement
Le GDD 16 fixe quatre fichiers, des déclencheurs (après **chaque commande appliquée, celles de l'IA comprises**, et en fin de partie ; décision du 2026-10-30, reprise de la PR #3 : un arrêt en phase ennemie reprend à la commande suivante), une lecture de ruine avec la partie sauvegardée avant l'apparition du panneau et le profil écrit après, un chargement avec repli sur la copie de secours, la migration et le refus d'une version plus récente. Il renvoie à un ADR le format, l'empreinte, le remplacement, le cycle de vie, le fil d'écriture et l'exclusion de la sauvegarde automatique d'Android. Le GDD 22 y ajoute des écritures du profil hors commandes (réglages, score, réinitialisation).

### Constraints
- Jamais de fichier à moitié écrit ; un fichier abîmé n'écrase jamais une bonne copie ; un fichier abîmé n'est jamais supprimé, il est renommé.
- Un échec d'écriture ne bloque jamais le jeu.
- Budget sur le fil principal : `SAVE_MAIN_THREAD_BUDGET` (provisoire 8 ms, **en pic sur l'image du commit**, distinct des budgets par image) ; chargement ≤ 150 ms au pire (provisoire).
- `var_to_bytes` seul accepte 23 % des octets altérés (ADR-0003) : le contrôle d'intégrité précède tout décodage.
- Écritures du profil hors commandes : réglages modifiés, score soumis, réinitialisation, passage en arrière-plan, nouvel essai après échec.

### Requirements
- Chaque étape de fichier testable avec injection de pannes ; un seul écrivain en série pour la partie et le profil, suppressions comprises.
- L'ordre « partie d'abord, profil ensuite » (GDD 16, règles 10 et 13) garanti par construction.

## Decision

**1. Quatre fichiers, pas d'index.** `user://match.sav`, `match.bak`, `profile.sav`, `profile.bak`, plus un `*.tmp` par écriture. Aucun fichier d'index.

**2. Enveloppe à préfixe figé.** Chaque fichier = **préfixe définitif** (marque de 4 octets, version d'enveloppe, **longueur** de la charge utile, schéma de contenu, révision) puis la **charge utile**, puis l'**empreinte SHA-256** (`HashingContext`, 32 octets) de tout ce qui précède. Le **préfixe ne change jamais** (marque, version d'enveloppe, longueur, position de l'empreinte) : l'empreinte reste toujours vérifiable ; seul le schéma de contenu évolue. SHA-256 est un algorithme normalisé : sa sortie ne dépend pas de la version du moteur (contrainte de la formule 4 du GDD 16). La charge utile est `GameState.to_bytes()` (partie, déterministe, **sans enveloppe**, ADR-0003 amendé) ou le contenu du GDD 22 (profil). **Source unique du schéma de contenu** : l'enveloppe fait foi ; la charge utile ne le porte plus.

**3. Ordre normatif des contrôles au chargement.** (1) marque ; (2) longueur ; (3) empreinte ; (4) schéma de contenu (**plus récent** : refus sans repli, fichier non modifié, copie non essayée, profil en lecture seule ; **plus ancien** : migration selon la règle 17bis du GDD 16 — avant le test fermé, mise de côté sans migration ; ensuite, chaîne de migrations N → N + 1 testées sur fixtures) ; (5) `from_bytes` et validation des invariants (GDD 1, règle 14). Un fichier plus récent n'est donc jamais lu comme « abîmé », et un octet de version altéré est attrapé par l'empreinte avant d'être interprété.

**4. Port `FileStore` injecté.** Toute opération de fichier passe par `FileStore` : `write(path, bytes) -> Error` (échec = premier `store_*` en échec), `read(path) -> PackedByteArray`, `rename(from, to) -> Error`, `delete(path) -> Error`, `exists(path) -> bool`. Les opérations rendent un **`Error`** (`DirAccess.rename_absolute`, `copy` et `remove_absolute` n'ont pas d'« erreur courante » à relire ; `FileAccess.get_open_error()` n'existe qu'après un échec d'ouverture). Deux implémentations : réelle (`FileAccess`, `DirAccess`, chemins complets `user://`) et **en mémoire avec injection de pannes** (échec à l'étape n, stockage plein, arrêt simulé entre deux étapes). Aucun appel de `FileAccess` ou `DirAccess` hors de l'implémentation réelle.

**5. `SaveStore` : un seul écrivain en série.** Partie et profil passent par le même écrivain, suppressions comprises ; le coordinateur et le profil (`ProfileStore.request_write()` pour les écritures hors commit : réglages, score, réinitialisation, arrière-plan, nouvel essai) ne l'appellent que de façon synchrone. Une seule écriture est donc en cours à tout instant, par construction.

**6. Séquence d'écriture, sûre à chaque étape.** Entre deux commandes, sur le fil principal : sérialiser, construire l'enveloppe (`PackedByteArray`, immuable ensuite) ; écrire `*.tmp` (fermé avant tout renommage, mesuré) ; **relire et vérifier** son empreinte ; si le courant est valide (drapeau « courant valide », positionné par le dernier chargement ou la dernière écriture vérifiée, remis à « inconnu » après tout échec de renommage) : supprimer l'ancien `*.bak`, renommer le courant en `*.bak` ; si un courant de validité inconnue existe encore, le **mettre de côté** (renommé, `BAD_FILE_CAP` respecté, jamais supprimé) au lieu de le supprimer, puis renommer `*.tmp` en courant. Comme `rename` supprime la cible avant de déplacer sur Windows, la suppression explicite de la cible précède **toujours** le renommage, de sorte que le comportement ne dépende pas de la plateforme. Arrêt à chaque étape : pendant `*.tmp` → courant et `.bak` intacts ; après vérification avant rotation → courant intact, `.tmp` jeté ; entre rotation et renommage → pas de courant, `.bak` = sauvegarde précédente valide (une sauvegarde perdue, acceptée par le GDD) ; après renommage → nouvel état. Face à une **coupure d'alimentation**, la relecture vérifie le cache du système, pas le disque : le repli sur `.bak` est la seule défense (Verification 4).

**7. Écriture synchrone, fil d'écriture en déclencheur de révision.** L'écriture se fait **dans `on_commit`, sur le fil principal**, avant `EventSink.push` (ADR-0004 §4) : « une écriture à la fois » et l'ordre partie puis profil sont ainsi garantis, sans amender ADR-0004. La mesure de `t_write` (AC-F1) tranche. Si elle dépasse le budget, **passer à un fil d'écriture est un amendement de cet ADR et d'ADR-0004 §4**, qui impose : (a) les octets capturés au commit dans un emplacement unique écrasé, jamais un drapeau resérialisé plus tard (sinon la capture suivante pourrait tomber pendant la phase ennemie) ; (b) un panneau de fragment qui attend une « révision durable ≥ R » au lieu de retarder le push. **Conséquence de la sauvegarde après chaque commande (2026-10-30)** : une phase ennemie de N commandes fait N écritures synchrones (jusqu'à plusieurs dizaines par tour) ; chaque commande de l'IA est déjà cadencée par le `PacingGate`, donc deux écritures ne se chevauchent pas, mais **chacune retarde son image** : le fil d'écriture devient probable, pas seulement possible, si `t_write` dépasse le budget sur l'appareil de référence. **GDD SYNC** : la règle 10 du GDD 16 dit que l'écriture d'environ 20 ms est « masquée par le délai de 400 ms », ce qui n'est vrai qu'en asynchrone ; en synchrone, ces 20 ms retardent le début de l'onde et dépassent le budget de 8 ms (règle 7).

**8. `SaveCoordinator` = `PostCommitPort` réel (ADR-0004).** **Prédicat : toute commande appliquée par le pipeline réel, quel que soit l'émetteur (JOUEUR, IA, SYS), plus la fin de partie.** Il n'y a plus de drapeau « simulation » ni de condition de phase : les simulations n'appellent pas le pipeline, et le rejeu injecte le port nul. Les écritures sont coalescées par « une écriture à la fois » (règle 5 du GDD 16) quand un fil d'écriture existera ; en synchrone chaque commande écrit. **Lecture d'une ruine** (ADR-0004 §5) : sauvegarde de la partie **avant** `EventSink.push` (le panneau ne s'ouvre qu'après l'écriture), puis le `ProfilePort` applique l'effet « enregistrer un fragment » (idempotent) et écrit le profil via `ProfileStore` ; la commande interne **VALIDER_LA_LECTURE** (commande de suite, ordinaire, avec révision et sauvegarde) ne passe l'entrée du journal à « validée » **que si l'écriture du profil a réussi et que le profil n'est pas en lecture seule** ; sinon l'entrée reste « en attente », et l'écriture du profil est retentée au changement suivant, au passage en arrière-plan et au chargement. Le port nul (post-commit et profil) est utilisé pour le rejeu ; l'aperçu et les simulations n'y passent pas. Le coordinateur n'écoute jamais la file d'événements.

**9. Chargement.** Ordre au lancement : supprimer les `*.tmp` restants ; profil ; partie ; réconciliation du journal des lectures de ruine avec le profil (validées comprises) ; remplissage d'un profil neuf depuis le journal d'une partie valide ; jeu prêt ; `on_state_loaded()` du pipeline. **Chaîne de chargement : courant, puis `.bak`, rien d'autre** : un `.tmp` n'est **jamais promu** (même valide), pour qu'une partie abandonnée ne ressuscite pas après un arrêt pendant les règles 12 et 13. Un fichier abîmé (marque, longueur, empreinte, lecture) bascule **automatiquement** sur sa copie de secours avec un avertissement ; le courant abîmé est **mis de côté** (renommé, jamais supprimé ; au plus `BAD_FILE_CAP` = 2 par type, le plus ancien supprimé) dès le chargement ; si les deux sont abîmés, le jeu démarre sans partie ou avec un profil neuf. Un profil dépassant `PROFILE_SIZE_CAP` est refusé à l'écriture (GDD 22, formule 6). **Garde-fou d'époque inconditionnel** : une partie dont l'époque de réinitialisation est inférieure à celle du profil est écartée avec un avertissement, que l'exclusion d'Android fonctionne ou non. Si la phase stockée est EXÉCUTION_ENNEMIE, le système 3 fait **reprendre** la phase à la commande suivante après `on_state_loaded()` (GDD 3, règle 3 ; ADR-0005 §5, `AiRunner.resume`).

**10. Fin de partie, nouvelle partie, réinitialisation.** Fin de partie : la partie terminée est sauvegardée, le score est soumis au profil (idempotence par identifiant de partie, portée par le GDD 22), le fichier est supprimé à la sortie de l'écran de fin ; un arrêt entre les deux rouvre l'écran de fin. Nouvelle partie alors qu'une partie existe : supprimer les `*.tmp`, puis la copie de secours, puis le fichier courant, puis écrire la nouvelle (sauf une partie d'une version plus récente, mise de côté). Réinitialisation de la progression : supprimer les `*.tmp`, la partie d'abord, puis réinitialiser le profil.

**11. Cycle de vie et Android.** `on_app_paused()` ne fait que **retenter les écritures en échec** (partie, profil) : chaque commande du joueur sauvegarde déjà de façon synchrone, donc la borne de perte (formule 2 du GDD 16) ne dépend d'aucune notification NOT SOURCEABLE. L'**exclusion** de la partie de la sauvegarde automatique d'Android demande probablement des règles de sauvegarde dans le manifeste, donc sans doute un build Gradle personnalisé : **impact possible sur la chaîne d'export**, non vérifié ; le **garde-fou d'époque est le mécanisme principal**, l'exclusion une amélioration. Équivalent iOS : NOT SOURCEABLE.

### Architecture Diagram

```
 CommandPipeline ── commit ──► PostCommitPort = SaveCoordinator
        (prédicat : toute commande appliquée du pipeline réel ∨ fin de partie)      ProfileStore.request_write()
                                   └──────────────► SaveStore (écrivain unique, synchrone, en série) ◄───────────┘
                          sérialiser (to_bytes) + enveloppe (préfixe figé + SHA-256) → *.tmp → relire/vérifier
                          → supprimer .bak → courant→.bak (si valide) → courant inconnu : mis de côté → *.tmp→courant      [via FileStore]
        user://match.sav  match.bak  profile.sav  profile.bak
 Lancement : supprimer *.tmp → profil → partie (courant, puis .bak) → réconciliation du journal → on_state_loaded() → reprise éventuelle de la phase ennemie à la commande suivante
```

### Key Interfaces

```gdscript
class_name FileStore extends RefCounted            # port ; réel et factice (injection de pannes)
func write(path: String, bytes: PackedByteArray) -> Error
func read(path: String) -> PackedByteArray
func rename(from: String, to: String) -> Error
func delete(path: String) -> Error
func exists(path: String) -> bool

class_name SaveEnvelope extends RefCounted         # préfixe figé + empreinte SHA-256
static func wrap(payload: PackedByteArray, content_schema: int, revision: int) -> PackedByteArray
static func unwrap(bytes: PackedByteArray) -> SaveEnvelopeResult   # ordre : marque, longueur, empreinte, schéma ; refuse tronqué, altéré, ajouté

class_name SaveStore extends RefCounted            # écrivain unique, synchrone
func save_match(state: GameState) -> Error
func save_profile(profile: ProfileData) -> Error
func delete_match() -> Error
func load_match() -> LoadResult                    # courant, puis .bak

class_name SaveCoordinator extends PostCommitPort
func on_commit(state: GameState, command: Command, result: ApplyResult) -> void
func on_app_paused() -> void                       # retente seulement
func load_all() -> LoadResult
```

### Implementation Guidelines
- Les opérations de fichier **ne doivent jamais** appeler `FileAccess` ou `DirAccess` hors de l'implémentation réelle de `FileStore`.
- Le contrôle de l'enveloppe **doit** suivre l'ordre marque → longueur → empreinte → schéma → `from_bytes` ; `bytes_to_var_with_objects` **ne doit jamais** être utilisé.
- Un `.tmp` **ne doit jamais** être promu ; les `.tmp` restants **doivent** être supprimés au chargement et au début des règles de nouvelle partie et de réinitialisation.
- La suppression de la cible **doit** précéder tout renommage ; le `.tmp` **doit** être fermé avant le renommage.
- Un fichier abîmé **ne doit jamais** écraser une copie valide ni être supprimé.
- La sauvegarde de la partie **ne doit jamais** être déclenchée pendant `apply` ni depuis un gestionnaire de présentation ; elle l'est après chaque commande appliquée par le pipeline réel, phase ennemie comprise.
- Chaque `store_*` **doit** voir sa valeur de retour vérifiée ; `flush()` et `close()` ne renvoient rien : la relecture avec empreinte est la seule détection d'une erreur différée.
- Toute modification du format **doit** incrémenter le schéma de contenu et, après le premier build du test fermé, fournir une migration (règle 17bis du GDD 16 : une migration en échec met la partie de côté, jamais d'écrasement) ; la CI échoue sur un incrément sans migration à partir de ce build.

## Alternatives Considered

### Alternative 1: Texte JSON ou `ConfigFile`
- **Description**: état et profil en texte.
- **Pros**: lisible, débogable.
- **Cons**: 2,8 ms l'aller-retour contre 59 µs pour `var` (ADR-0003), 2,5 fois plus gros, pas d'intégrité native.
- **Rejection Reason**: coût, taille et intégrité ; le JSON reste un format de débogage.

### Alternative 2: `ResourceSaver` (`.tres` / `.res`)
- **Description**: l'état en ressources.
- **Pros**: outillage du moteur.
- **Cons**: contraire au GDD 1 (pas de ressource créée à l'exécution) ; format lié au moteur ; pas d'enveloppe versionnée propre.
- **Rejection Reason**: contraire au GDD 1 et à la maîtrise de la migration.

### Alternative 3: SQLite ou plugin natif (GDExtension)
- **Description**: base de données locale.
- **Pros**: transactions atomiques.
- **Cons**: dépendance externe, export plus lourd ; disproportionné pour 8 Ko.
- **Rejection Reason**: sur-ingénierie pour 5 mois.

### Alternative 4: Deux emplacements A/B sans renommage
- **Description**: écrire alternativement dans deux fichiers, charger celui de plus haute révision valide.
- **Pros**: aucun renommage, donc aucun comportement de `rename` à vérifier (important sur Android, non sourcé) ; la copie de secours est naturelle.
- **Cons**: s'écarte du GDD 16 (courant/copie de secours) ; la règle 12 (supprimer d'abord la copie, puis le courant) se réécrit.
- **Rejection Reason**: **repli documenté** si le renommage s'avère non fiable sur Android ; non retenu d'emblée pour rester aligné sur le GDD 16.

### Alternative 5: CRC32 en GDScript
- **Description**: empreinte maison de 32 bits.
- **Pros**: conforme à la lettre de la formule 4 du GDD 16, petit.
- **Cons**: code à maintenir ; détection plus faible ; `HashingContext` n'offre pas de CRC32 natif.
- **Rejection Reason**: SHA-256 normalisé, 46 µs pour 8 Ko mesurés.

### Alternative 6: Écriture sur un autre fil (`WorkerThreadPool`)
- **Description**: l'E/S hors du fil principal.
- **Pros**: libère le fil principal ; l'API fonctionne (écriture et renommage depuis un fil, mesurés).
- **Cons**: classe de bogues (capture d'état, ordre partie puis profil, annulation des écritures en attente) ; impose un amendement d'ADR-0004 ; sûreté sur Android NOT SOURCEABLE.
- **Rejection Reason**: non retenue en première intention ; déclencheur de révision de la section 7.

### Alternative 7: Sauvegarde dans le nuage
- **Description**: synchronisation de compte.
- **Pros**: multi-appareil.
- **Cons**: hors périmètre MVP (une partie par installation), comptes.
- **Rejection Reason**: hors périmètre.

## Consequences

### Positive
- Intégrité garantie avant décodage ; replis testables par injection de pannes à chaque étape.
- Algorithme d'empreinte normalisé et préfixe d'enveloppe figé : une version future ne peut pas être prise pour un fichier abîmé.
- L'ordre partie puis profil et le panneau après l'écriture sont garantis par la sérialisation synchrone.
- Aucune dépendance externe ; un seul écrivain.

### Negative
- Une enveloppe maison à maintenir ; SHA-256 plus coûteux que CRC32 (négligeable sur PC, à mesurer sur appareil).
- Une écriture synchrone d'environ 20 ms retarde le début de l'onde de recoloration d'une ruine (à mesurer ; GDD SYNC).
- Le repli sur `.bak` est la seule défense contre une coupure d'alimentation ; l'atomicité du renommage et le cycle de vie d'Android restent à vérifier sur appareil.
- Impact possible sur la chaîne d'export (exclusion de la sauvegarde automatique, build Gradle personnalisé).

## Risks
- **Renommage non atomique** (mesuré sur Windows : la cible est supprimée avant le déplacement) : *Atténuation* : suppression explicite de la cible, `.bak` valide, chargement courant puis `.bak`, tests d'injection de pannes à chaque étape ; repli A/B.
- **Budget de 8 ms dépassé** : *Atténuation* : mesure sur appareil ; fil d'écriture par amendement (section 7).
- **Notification d'arrière-plan non fiable** : *Atténuation* : écriture après chaque commande ; la pause ne fait que retenter.
- **Sauvegarde automatique d'Android qui restaure une ancienne partie** : *Atténuation* : garde-fou d'époque inconditionnel.
- **Stockage plein ou erreur différée** : *Atténuation* : relecture avec empreinte ; échec non bloquant, retentative.
- **`.tmp` orphelin** : *Atténuation* : jamais promu, supprimé au chargement.

## GDD Requirements Addressed

| GDD System | Requirement | How This ADR Addresses It |
|------------|-------------|--------------------------|
| sauvegarde-automatique.md (16) | Règles 1 à 3 : quatre fichiers, contenu, une partie | §1, §2 |
| sauvegarde-automatique.md (16) | Règles 4 à 7 : jamais à moitié écrit, une écriture à la fois, échec non bloquant, budget | §5, §6, §7 |
| sauvegarde-automatique.md (16) | Règles 8 à 11 : déclencheurs (chaque commande, IA comprise), lecture d'une ruine, fin de partie | §8, §10 |
| sauvegarde-automatique.md (16) | Règles 12 et 13 : nouvelle partie, réinitialisation | §10 |
| sauvegarde-automatique.md (16) | Règles 14 à 17 : chargement, fichier abîmé, version plus récente ou ancienne | §3, §9 |
| sauvegarde-automatique.md (16) | Règle 18, formule 4 : sauvegarde automatique d'Android, empreinte | §2, §9, §11 |
| profil-donnees-meta.md (22) | Règles 4 à 6 : écriture à chaque changement, jamais à moitié, idempotence et nouvel essai ; règle 15 : l'écriture du profil est un effet appliqué par la couche des commandes seulement | `ProfileStore.request_write()`, port nul |
| profil-donnees-meta.md (22) | Règles 1 à 3, 10 (idempotence par identifiant de partie, portée par 22), 11 : profil et Android, lecture seule, réinitialisation | Même enveloppe et même écrivain |
| modele-etat-partie.md (1) | Règles 10 et 14 : réconciliation du journal, validation à chaque chargement ; règle 13 : schéma | §9, `from_bytes` |
| tours-conditions-victoire.md (3) | Règle 3 : reprise de la phase ennemie à la commande suivante après un arrêt | §9 |
| ruines-fragments.md (13) | Règle 14 : partie d'abord, puis profil | §8 |
| commandes-evenements.md (23) | Règle 15 : l'instantané d'annulation n'est jamais sauvegardé | Seul l'état est sérialisé |

## Performance Implications
- **CPU**: sérialisation 10 µs et aller-retour `var` 59 µs (ADR-0003) ; SHA-256 46 µs pour 8 Ko et 120 µs pour 26 Ko sur PC ; budget principal provisoire 8 ms **en pic sur l'image du commit**.
- **Memory**: un tampon d'enveloppe transitoire (≈ 8 Ko) par écriture.
- **Load Time**: provisoire ≤ 150 ms au pire (formule 5 du GDD 16).
- **Network**: sans objet.

## Migration Plan
Sans objet : aucun code de production n'existe.

## Validation Criteria
- Injection de pannes à chaque étape (`*.tmp`, vérification, suppression, rotation, renommage) : un fichier valide est toujours chargeable ; aucun `.tmp` n'est promu ; les `.tmp` restants sont supprimés au chargement et au début des règles 12 et 13.
- Ordre des contrôles marque → longueur → empreinte → schéma ; octet altéré, tronqué ou ajouté refusé avant décodage (critère déplacé d'ADR-0003) ; version plus récente refusée **sans repli** sur `.bak` et sans modification ; vecteur de test SHA-256 connu.
- Lecture d'une ruine : partie sauvegardée avant le panneau, profil ensuite ; VALIDER_LA_LECTURE seulement après une écriture réussie du profil, « en attente » si échec ou lecture seule (AC-16) ; arrêt entre chaque étape : réconciliation idempotente.
- Une sauvegarde après chaque commande de l'IA ; un arrêt après la commande k reprend à k + 1 au même état final qu'une phase sans arrêt, pour tout k (AC-09, AC-IA33).
- Garde-fou d'époque inconditionnel (AC-18) ; `BAD_FILE_CAP` (AC-X3) ; refus au-delà de `PROFILE_SIZE_CAP` ; profil neuf rempli depuis le journal.
- Test d'intégration du `FileStore` réel sur disque dans `tests/integration/save/` ; les tests unitaires n'ont aucun accès fichier.
- Mesure sur l'appareil Android de référence : `t_write` (AC-F1), chargement (AC-F5), comportement du renommage et de l'exclusion (AC-18) ; critères de validation, pas conditions d'acceptation.

## Related
- GDD : `design/gdd/sauvegarde-automatique.md` (16), `profil-donnees-meta.md` (22), `modele-etat-partie.md` (1), `tours-conditions-victoire.md` (3), `ruines-fragments.md` (13), `commandes-evenements.md` (23). **GDD SYNC** : GDD 16 (formule 4 : `SHA-256(préfixe ‖ charge utile)`, 32 octets, empreinte en fin d'enveloppe et non dans l'en-tête ; règle 10 : l'écriture de 20 ms n'est masquée que si asynchrone ; Limites connues : retirer « stabilité d'un CRC32 natif ») ; GDD 13 règle 14 (écrire « la partie est écrite, puis le profil »).
- ADR-0003 (à amender : `to_bytes` rend la charge utile seule, l'intégrité est contrôlée par cet ADR), ADR-0004 §4 (déclencheurs : chaque commande appliquée, IA comprise), ADR-0005 §5.
