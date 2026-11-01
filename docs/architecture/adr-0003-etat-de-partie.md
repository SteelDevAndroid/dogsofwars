# ADR-0003: État de partie — colonnes de tableaux typés, copie par duplicate(), sérialisation binaire versionnée

## Status
Accepted

## Date
2026-10-30

## Last Verified
2026-10-30 — banc `prototypes/etat-copie/` exécuté par l'agent prototyper (Godot 4.7.2-stable official, Windows, headless). **Android non mesuré.** Tests headless de godot-specialist le même jour : indépendance après `duplicate()`, partage par affectation, corruption de `var_to_bytes`, masque 32 bits.

## Decision Makers
Utilisateur (direction de projet), Claude (rédaction), godot-specialist et technical-director (validation avant écriture).

## Summary
Le GDD 1 impose un état en données pures, copiable sans partage à très bas coût (budget de plusieurs milliers de copies par tour d'IA), à identifiants stables et parcouru par id croissant, sérialisable sans perte avec une version de schéma. On représente l'état par des **colonnes de tableaux typés** (`PackedInt32Array`, `PackedByteArray`) regroupées en tranches, copiées par `duplicate()` de chaque colonne et sérialisées par `var_to_bytes` : sur ce PC, 15 µs la copie contre 284 µs (`Dictionary` imbriqués) et 711 µs (objets `RefCounted`).

## Engine Compatibility

| Field | Value |
|-------|-------|
| **Engine** | Godot 4.7.2 |
| **Domain** | Core |
| **Layer** | Foundation |
| **Knowledge Risk** | HIGH |
| **References Consulted** | `docs/engine-reference/godot/VERSION.md`, `docs/engine-reference/godot/breaking-changes.md` (`duplicate_deep`, `FileAccess.store_*` qui renvoie `bool`), `design/gdd/modele-etat-partie.md`, `prototypes/etat-copie/REPORT.md` |
| **Post-Cutoff APIs Used** | Aucune dans la solution retenue (`Packed*Array.duplicate()` existe depuis 4.0). `Dictionary.duplicate_deep()` (4.5+) n'est utilisé que par l'alternative C, mesurée, non retenue |
| **Verification Required** | (1) **Android** : `t_clone` sur l'appareil de référence (non nommé) ; les rapports entre représentations ne sont pas démontrés sur mobile ; (2) comportement de copie sur écriture des tableaux typés après `duplicate()` (copie partielle) : le banc chronomètre `duplicate()` sans écrire derrière ; (3) mémoire résidente par représentation ; (4) stabilité de `var_to_bytes` entre versions du moteur (la sauvegarde porte son propre numéro de schéma) ; (5) débordement d'entier sur ARM ; (6) coût du ramasse-miettes sur longue durée ; (7) l'ordre d'itération d'un `Dictionary` est **observé** comme celui d'insertion, **non garanti** : la décision ne s'y fie pas ; (8) **sémantique par référence des tableaux typés** (un getter ou une affectation partage-t-il le tampon ? Dans Godot 4 les tableaux typés sont documentés comme passés par référence, ce que les références du dépôt ne couvrent pas : NOT SOURCEABLE) : test headless avant de figer ce que rend `StateView` ; (9) coût mesuré de **copie + une écriture par colonne** et de **copie + un coup simulé typique**, qui entre dans la formule 5 ; (10) coût de `filtered_copy` |

## ADR Dependencies

| Field | Value |
|-------|-------|
| **Depends On** | None (couche Foundation : rien en amont) |
| **Enables** | ADR-0002 (`StateView` est déclarée ici ; ADR-0002 en dépend) ; ADR du pipeline de commandes (validation, application, instantané et restauration) ; ADR du système de sauvegarde (16) ; budget de l'IA (copies par tour) |
| **Blocks** | Stories Core : modèle d'état, pipeline de commandes, clonage et IA à intentions |
| **Ordering Note** | À accepter **avant** ADR-0002 puis ADR-0001. Le passage à Accepted n'attend pas Android : le choix de représentation tient sur le nombre d'allocations ; Android reste un critère du **budget** de l'IA. Le format de sauvegarde sur disque (fichiers, atomicité, moments) reste au GDD 16 ; cet ADR fixe le contenu, le numéro de schéma et un `to_bytes` déterministe |

## Context

### Problem Statement
Le GDD 1 fixe le contenu de l'état (règles 1 à 14) et renvoie à un ADR la représentation, le mécanisme de copie, le format de sérialisation et la migration. Les contraintes pèsent lourd : 2 500 copies par tour d'IA, l'état sans `Node`, `Object` ni `Callable`, une copie sans donnée partagée modifiable, un parcours par id croissant et une égalité profonde. Aucune représentation n'est imposée par le moteur et les références ne couvrent pas le coût réel des conteneurs.

### Constraints
- GDScript, Godot 4.7.2 ; Android d'abord ; cartes jusqu'à 16×16 (256 tuiles), 60 unités, 10 nœuds, 3 ruines tirées sur 9 candidates, 120 intentions.
- Données pures (règle 4), identifiants jamais réutilisés (règle 5), entiers seulement (règle 6), itération par id croissant (règle 8), copie sans partage (règle 9), taille bornée (règle 12), sérialisation sans perte avec version de schéma (règle 13).
- Une simulation applique les fonctions de règle sans passer par la couche des commandes et jette leurs effets : elle ne publie aucun événement et n'écrit aucun profil (règles 3 et 9 du GDD 1, mis à jour par la PR #3 ; règles 8 et 9 du GDD 23).

### Requirements
- Copie complète en quelques dizaines de microsecondes sur mobile.
- Égalité profonde testable octet pour octet.
- Un écrivain par champ : l'accès par colonne ne doit pas contourner les fonctions d'écriture des systèmes propriétaires.

## Decision

**Représentation.** `GameState` (`RefCounted`) porte des **tranches** ; chaque tranche est un ensemble de **colonnes** `PackedInt32Array` ou `PackedByteArray` :
- **En-tête** : un **`PackedInt64Array`** à indices nommés par constantes (identifiants de partie, compteurs d'identifiants, graine, compteur de tirages, tour, phase…). Une graine de 0 à 2³²−1 ne tient pas dans un `PackedInt32Array` signé (4294967295 y devient −1) ; les compteurs `counter` et `next_id` sont bornés à 2³¹−1 et tiennent.
- **Carte, visibilité** : une grille indexée par `tile_index` (propriétaire, dernier changement de propriétaire : tour, propriétaire précédent et cause, ancrage, point d'intérêt ; deux octets de visibilité par faction : découverte et dernier propriétaire vu). **Ni la couleur affichée ni la vision actuelle ne sont stockées** (PR #3) : la couleur est déduite par le GDD 15 et la vision recalculée par le GDD 5, toutes deux dans des caches hors de l'état, reconstruits au chargement et après `restore_from`. Le **terrain** est une colonne fixe pour toute la partie, partagée en lecture seule entre copies **réelles** ; `filtered_copy` en construit une **copie propre** (256 octets) où toute tuile non découverte vaut « plaine de coût 1, non occultante » (ADR-0007 §5).
- **Unités, nœuds, ruines, intentions (avec type et tuiles de la cible), agents et pistes de l'IA, rappels de présentation, instantané de la chronique, journal des lectures de ruine** : des colonnes parallèles, une ligne par entité. Les **ids sont triés par ordre croissant** et jamais réutilisés (ils restent consommés) ; une entité détruite est marquée (`alive = 0`) pendant le tour, puis **toutes les collections sont compactées en fin de tour par un tri stable**, id croissant préservé : la taille reste bornée (règle 12 du GDD 1). Les unités, dormants compris, sont toutes créées à la mise en place (un réveil change un drapeau, pas une ligne). La recherche par id se fait par **dichotomie** (pas d'index direct).
- **Contrôle d'accès (par convention vérifiée, pas par le langage)** : GDScript n'a pas de contrôle d'accès. Les colonnes sont regroupées **par tranche dans une classe** (`UnitsSlice`, `NodesSlice`, …) dont les champs sont préfixés `_` ; seules les fonctions d'écriture du système propriétaire y écrivent (règle 2 du GDD 1). Un contrôle en CI (`tools/ci/check-slice-writes.sh`, auto-test `tests/unit/ci/test_check_slice_writes.sh`, workflow `.github/workflows/slice-writes.yml`) interdit tout accès (lecture ou écriture, y compris dynamique par `get`, `set` ou `["_x"]`) à un champ `_` hors des chemins listés par la ligne `# owner:` du fichier de sa tranche ; les tests peuvent lire un champ privé, jamais l'écrire ; **les noms de champs `_` sont uniques entre tranches** (le script refuse un doublon, car il ne sait pas à quel objet appartient `.nom`) ; le motif interdit `direct_cross_system_state_write` est enregistré.
- **`StateView`** (déclarée ici) est une façade en lecture seule qui rend des **scalaires ou des copies**, jamais une colonne brute (les tableaux typés sont passés par référence : un lecteur pourrait écrire dans l'état). Le **terrain** vit dans un objet statique sans setter, partagé en lecture seule entre copies.
- **Table déclarative des colonnes** : une table unique (nom, type, tranche propriétaire, **attribut « privé à la faction »** : une tranche privée n'est gardée que par `filtered_copy` de sa faction ; la tranche « agents de l'IA » en est une, ADR-0005) dont dérivent les indices, la copie, l'égalité, la sérialisation et la validation ; c'est la parade à l'erreur d'indexation.

**Copie.** `GameState.duplicate_state()` appelle `duplicate()` sur chaque colonne (42 colonnes dans le banc) ; le terrain est partagé par référence. Une copie **ne porte aucun drapeau** (PR #3) : une simulation n'écrit pas le profil ni ne publie parce qu'elle n'appelle que les fonctions de règle, pures, et jette les effets qu'elles rendent ; seule la couche des commandes les applique (ADR-0004). L'état ne connaît ni le puits d'événements ni les gestionnaires (ADR-0002). Le **`ViewCache`** d'ADR-0007 (vision actuelle, 256 octets par faction) est un compagnon transitoire de l'état : `duplicate_state()` le **copie**, `to_bytes` et `equals` l'ignorent, et `from_bytes` comme `restore_from` appellent `VisionService.rebuild(state)`. `restore_from(snapshot)` remet l'état à un instantané (annulation du déplacement, règle 15 du GDD 23) **en conservant la tranche « journal des commandes »** : la révision n'est jamais reculée (règle 14) et avance de 1 après l'annulation.

**Copie filtrée.** `filtered_copy(faction) -> GameState` retire aussi les **tranches privées d'une autre faction** (par exemple `filtered_copy(JOUEUR)` ne contient aucune ligne d'agent de l'IA) et construit, par le **même code** que l'aperçu, l'état **reconstruit à partir de la vue** d'une faction (règle 11 du GDD 1, base de toute simulation de l'IA) : lignes cachées (unités hors de vue, ruines non repérées, dormants jamais vus) absentes ou masquées, octets de visibilité des autres factions neutralisés. Son coût se paie une fois par perception, pas par copie ; il est à mesurer (Verification 10) ; AC-IA14 : aucune unité cachée ni ruine dans la copie filtrée.

**Parcours et égalité.** Toute règle parcourt les lignes dans l'ordre des colonnes, qui est l'ordre croissant des ids : aucun `Dictionary` n'est parcouru pour une règle de jeu. **L'égalité profonde** compare les lignes **vivantes** par identifiant, sans tenir compte des lignes mortes ni de la disposition interne, comme la règle 13 du GDD 1 (hors drapeau de copie).

**Sérialisation.** Une **liste ordonnée** (schéma, puis les colonnes dans l'ordre de la table déclarative) sérialisée par `var_to_bytes` **sans objets** (sauvegarde, rejeu, tests) ; `to_bytes` est **déterministe** pour deux états égaux (ordre fixe, pas de clés de `Dictionary`), ce qui permet l'empreinte d'intégrité du GDD 16. **Intégrité** : `to_bytes` rend la **charge utile seule** (déterministe) ; l'**enveloppe** (préfixe figé, longueur, empreinte SHA-256) et le **contrôle d'intégrité avant tout décodage** relèvent d'**ADR-0006** (mesuré ici : `var_to_bytes` seul accepte 23 % des octets altérés et la perte du dernier octet, d'où ce contrôle externe). `from_bytes` utilise `bytes_to_var` sans objets (**jamais** `bytes_to_var_with_objects`, qui instancie des nœuds) puis **valide** la structure : type de retour attendu, clés et types, **longueur de chaque colonne** par rapport à l'en-tête (règle 14 du GDD 1), bornes des ids ; il rend une valeur de retour claire (`null` ou `Error`). Le numéro de schéma de contenu est porté **par l'enveloppe seule** (source unique, ADR-0006) : l'en-tête de `GameState` ne le contient pas, et `from_bytes(bytes, content_schema)` le reçoit de l'enveloppe. Le JSON est réservé au débogage. **Jusqu'au premier build du test fermé** on incrémente le schéma et on refuse l'ancien état ; **ensuite** une migration est obligatoire ; un état plus récent est toujours refusé. Le fichier, l'écriture atomique et le moment des sauvegardes appartiennent à 16.

**Hasard (décidé ici).** Une seule fonction de tirage, SplitMix32, masque `& 0xFFFFFFFF` avant chaque décalage (le débordement 64 bits de GDScript est un complément à deux, mesuré). Le banc a trouvé que `hash32(0, 0) = 0` est un **point fixe** parce qu'il n'ajoutait pas l'incrément à c = 0. **Forme canonique retenue** : `z = (seed + (counter + 1) × 0x9E3779B9) & 0xFFFFFFFF`, qui supprime le point fixe et garde la graine 0 légale. Les vecteurs de référence des cinq graines (0, 1, 1234, 987654321, 4294967295) sont à **recalculer** avec cette forme et figés dans un test ; la formule 2 du GDD 1 est à amender (**GDD SYNC**, voir ci-dessous).

### Architecture Diagram

```
 GameState (RefCounted)
   ├─ en-tête (PackedInt64Array, indices nommés)
   ├─ carte / visibilité  (colonnes par tile_index ; terrain partagé en lecture seule ; ni couleur ni vision actuelle)
   ├─ unités, nœuds, ruines, intentions, agents, pistes, rappels, instantané de la chronique, journal  (colonnes triées par id croissant)
   ├─ duplicate_state() ── duplicate() de chaque colonne ──► copie (sans drapeau)
   ├─ to_bytes() / from_bytes()  ── var_to_bytes, schéma versionné, migration
   └─ StateView (lecture seule, ADR-0002) ◄── HUD, rendu, audio
 Écriture : fonctions des systèmes propriétaires uniquement (règle 2 du GDD 1)
```

### Key Interfaces

```gdscript
class_name GameState extends RefCounted
func duplicate_state() -> GameState
func equals(other: GameState) -> bool                      # égalité profonde, hors disposition interne
func to_bytes() -> PackedByteArray                         # var_to_bytes sans objets
static func from_bytes(bytes: PackedByteArray, content_schema: int) -> GameState  # schéma lu dans l'enveloppe (ADR-0006) ; migre ou refuse
func filtered_copy(faction: int) -> GameState               # état vu par une faction (lignes cachées absentes ou masquées)
func restore_from(snapshot: GameState) -> void              # garde le journal des commandes ; la révision n'est jamais reculée
func view() -> StateView                                    # lecture seule, scalaires ou copies, jamais une colonne brute

class_name StateView extends RefCounted                     # interface de lecture seule (déclarée ici, utilisée par ADR-0001 et ADR-0002)
```
Les colonnes et leurs indices sont définis dans un fichier de constantes unique ; toute modification d'une colonne incrémente la version du schéma.

### Implementation Guidelines
- L'état **ne doit jamais** contenir un `Node`, un `Object`, un `Callable`, un `RID`, un `Dictionary` ni un `Array` non typé dans une règle de jeu.
- Une règle **doit** parcourir par id croissant ; elle **ne doit jamais** s'appuyer sur l'ordre d'un `Dictionary`.
- Un système **ne doit jamais** écrire la colonne d'un autre système ; il appelle la fonction d'écriture du propriétaire.
- Une entité détruite **doit** être marquée (`alive = 0`) pendant le tour, puis retirée par le compactage de fin de tour ; un id **ne doit jamais** être réutilisé.
- Toute valeur stockée **doit** être un entier ; un changement de colonne **doit** incrémenter le schéma et fournir une migration.
- Le JSON **ne doit pas** servir à la sauvegarde de production.
- **Toute affectation de colonne partage le tampon** (les tableaux typés sont passés par référence, mesuré : affectation, argument, champ) ; une copie qui oublie un `duplicate()` partage silencieusement. Seule la table déclarative écrit la copie, et le test d'indépendance porte sur **chaque colonne**.
- Les valeurs 32 bits non signées (graine, hachage) vivent dans l'en-tête `PackedInt64Array` ; dans une colonne `PackedInt32Array` elles deviendraient négatives et celles hors plage seraient tronquées sans erreur : les y éviter, sinon masquer à la lecture (`& 0xFFFFFFFF`) et valider les bornes dans les fonctions d'écriture ; un accès hors bornes arrête la fonction en debug : les accesseurs par id vérifient leurs bornes.
- Le terrain partagé **ne doit jamais** être modifié après la mise en place ; il est servi par un objet statique sans setter ; un test compare une empreinte du terrain avant et après une partie simulée.
- `StateView` **ne doit jamais** rendre une colonne brute ; une colonne ne sort d'une tranche que par une copie.
- `to_bytes` **doit** être déterministe ; `from_bytes` **doit** refuser tout octet tronqué, corrompu ou toute colonne de longueur incohérente.

## Alternatives Considered

### Alternative 1: Objets `RefCounted` typés (une classe par entité)
- **Description**: `UnitState`, `NodeState`… dans des `Array` typés, copie profonde manuelle.
- **Pros**: modèle « propre », accès par attribut typé.
- **Cons**: mesuré : 711 µs la copie (médiane), 920 µs avec libération, 3 443 µs l'aller-retour `var` ; 389 petites allocations par copie ; `var_to_bytes` perd les objets.
- **Rejection Reason**: 47 fois plus lent que les colonnes à copier ; incompatible avec le budget de copies.

### Alternative 2: `Dictionary` et `Array` imbriqués avec `duplicate(true)` ou `duplicate_deep()`
- **Description**: l'état en dictionnaires de tableaux.
- **Pros**: simple, lisible, sérialisable directement.
- **Cons**: mesuré : 283 µs la copie, 1 204 µs l'aller-retour `var`, 58 Ko sérialisés ; ordre d'itération observé mais non garanti ; `duplicate()` non profond partage les imbriqués.
- **Rejection Reason**: 19 fois plus lent que les colonnes ; reste un repli si l'IA exige moins de 500 copies par tour.

### Alternative 3: `Resource` avec `duplicate_deep()`
- **Description**: l'état en ressources personnalisées, copie profonde du moteur, `.res` / `.tres` pour la sauvegarde.
- **Pros**: outillage de l'éditeur et du chargeur.
- **Cons**: **non mesuré** ; une ressource est un `Object` (contredit la règle 4 : pas de ressource créée à l'exécution) ; format de sauvegarde lié au moteur.
- **Rejection Reason**: contraire à la règle 4 du GDD 1 ; coût non démontré.

## Consequences

### Positive
- Copie d'environ 15 µs sur ce PC, sans écriture derrière : de l'ordre de 29 000 copies par tour d'IA au budget du GDD contre 1 362 (C) et 543 (B), à reconfirmer avec la première écriture.
- 7,5 Ko sérialisés, aller-retour en 59 µs ; égalité profonde exacte.
- L'ordre de parcours par id est structurel, pas contractuel.
- Aucune dépendance à des API postérieures à la connaissance du modèle.

### Negative
- Écriture moins ergonomique : accès par index et par colonne, derrière des accesseurs.
- Un changement de colonne exige schéma et migration.
- Les chiffres sont d'un PC : le classement est solide, les valeurs absolues (29 000 copies par tour) ne le sont pas ; le banc chronomètre `duplicate()` sans écriture derrière (à compléter par « copie + écriture »).
- Les entités détruites restent dans les colonnes jusqu'au compactage de fin de tour (60 unités au plus : négligeable).

## Risks
- **Budget de l'IA non tenu sur Android** : le classement des représentations vient du nombre d'allocations (42 `duplicate()` contre 389 petites allocations) et ne dépend pas de la plateforme ; ce qui reste à prouver, c'est le **budget** de la formule 5. *Atténuation* : critère de validation sur appareil ; si le seuil est dépassé, on revoit le budget de l'IA (`f_clone`, nombre de copies), pas la représentation. Un repli vers C ne se justifierait que par l'ergonomie, jamais par la performance.
- **Erreur d'indexation de colonnes** : bogues silencieux. *Atténuation* : constantes d'indices uniques, accesseurs par système, validation des invariants (règle 14 du GDD 1), tests de parité.
- **`var_to_bytes` instable entre versions du moteur**. *Atténuation* : schéma propre au jeu, test de relecture d'un fichier témoin à chaque montée de version du moteur.
- **Point fixe du hachage (graine 0)**. *Atténuation* : décalage de graine, test des cinq graines mesurées.

## GDD Requirements Addressed

| GDD System | Requirement | How This ADR Addresses It |
|------------|-------------|--------------------------|
| modele-etat-partie.md (1) | Règles 4 à 6 : données pures, ids, entiers | Colonnes d'entiers, ids croissants jamais réutilisés |
| modele-etat-partie.md (1) | Règles 8 et 9 : parcours par id croissant, copie sans partage, terrain partagé | Ordre structurel ; `duplicate()` par colonne ; terrain en lecture seule |
| modele-etat-partie.md (1) | Règle 13 : sérialisation sans perte, schéma, migration, égalité profonde | `var_to_bytes` versionné, `equals` par colonne |
| modele-etat-partie.md (1) | Formule 5 : 2 500 copies par tour d'IA | 15 µs par copie mesurée ; budget à confirmer sur Android |
| modele-etat-partie.md (1) | Formule 2 : tirage borné par hachage | Débordement mesuré, point fixe de la graine 0 signalé |
| commandes-evenements.md (23) | Règle 15 : instantané d'annulation hors de l'état | `duplicate_state()` peu coûteuse |
| ia-ennemie.md (9) | Règle 19 : budget de 2 500 copies par tour | Copie à 15 µs |
| hud-systeme.md (17) | `StateView` en lecture seule | Façade sur les colonnes |

## Performance Implications
- **CPU**: copie ≈ 15 µs (médiane), 21 µs (p95) sur le PC de test ; aller-retour `var` 59 µs.
- **Memory**: 4 264 octets bruts pour T = 256, F = 2, U = 60, N = 10, R = 3, I = 60 ; non mesuré en mémoire résidente.
- **Load Time**: désérialisation 49 µs sur le PC de test.
- **Network**: sans objet.

## Migration Plan
Sans objet : aucun code de production n'existe. Le banc `prototypes/etat-copie/` n'est pas migré.

## Validation Criteria
- Sur l'appareil Android de référence : **copie + première écriture ≤ 200 µs** (500 ms ÷ 2 500 copies, formule 5), soit une marge de 2 si la copie seule vaut ≤ 100 µs ; sinon revoir le budget de l'IA.
- Égalité profonde après aller-retour `to_bytes` / `from_bytes` sur un état complet (AC du GDD 1).
- Copie sans partage : modifier la copie laisse l'original intact.
- Test de hachage : cinq graines (0, 1, 1234, 987654321, 4294967295) reproductibles avec la forme canonique, graine 0 sans point fixe ; **la graine 4294967295 fait l'aller-retour en-tête → `to_bytes` → `from_bytes`** et `draw` donne le même résultat avant et après.
- `to_bytes` déterministe pour deux états égaux ; `from_bytes` refuse une structure ou une colonne de longueur incohérente (le critère « octet tronqué, altéré ou ajouté refusé avant décodage » est porté par ADR-0006).
- Test d'indépendance copie ↔ original sur **chacune** des colonnes (pas seulement les PV).
- Écrire dans une copie, ou dans le terrain d'une copie, laisse l'original intact (ou l'écriture dans le terrain est impossible).
- `restore_from` : après annulation, révision = instantané + 2 (GDD 23, règles 14 et 15) et le journal des commandes n'a pas reculé.
- `filtered_copy` : aucune unité cachée ni ruine non repérée (AC-IA14) ; coût mesuré.
- État au maximum de la formule 5 (I = 120, le banc a mesuré I = 60) et couverture des tranches absentes du banc : Factions (énergie, ensemble trié des protocoles, recherche en cours, éliminée), compteurs de score, journal des commandes, dimensions W et H.
- L'égalité profonde ignore les lignes mortes et la disposition interne.
- Tests de migration de schéma (ancien état migré, nouveau refusé).

## Related
- GDD : `design/gdd/modele-etat-partie.md` (1), `commandes-evenements.md` (23), `ia-ennemie.md` (9), `sauvegarde-automatique.md` (16). **GDD SYNC** : formule 2 du GDD 1 (forme canonique du hachage, graine 0 légale) ; règle 12 (compactage de fin de tour) ; règle 13 (égalité par lignes vivantes, `to_bytes` déterministe).
- ADR-0002 (dépend de celui-ci pour `StateView`), ADR-0001.
- Banc : `prototypes/etat-copie/REPORT.md`.
