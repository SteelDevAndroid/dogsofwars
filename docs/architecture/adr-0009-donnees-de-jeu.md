# ADR-0009: Données de jeu — fichiers JSON validés, entiers seulement, chargés une fois au démarrage dans un catalogue immuable

## Status
Accepted

## Date
2026-10-31

## Last Verified
2026-10-31 — conception sur les Tuning Knobs de tous les GDD MVP et les renvois des ADR-0001 à 0008 ; **tests headless** Godot 4.7.2 Windows : `JSON.parse_string` rend **tous les nombres en `float`** (`typeof` = `TYPE_FLOAT`, un entier au-delà de 2⁵³ perd sa précision : 9007199254740993 devient …992.0), **une clé dupliquée est silencieusement écrasée** (`{"a":1,"a":2}` donne `a = 2`), une erreur de syntaxe est rapportée par `JSON.new().parse` avec code et message. Inclusion des `.json` dans l'export Android : **non vérifiée**.

## Decision Makers
Utilisateur (direction de projet, choix « recommandé » délégué), Claude (rédaction), godot-specialist et technical-director (validation, TD-ADR : CONCERNS traités le 2026-10-31). **L'acceptation (`Accepted`) exige une confirmation explicite de l'utilisateur, ADR par ADR : le choix « recommandé » délégué ne vaut pas acceptation.**

## Summary
Tous les ADR renvoient à `assets/data/…` (durées, poids de l'IA, tables de teintes, `Q_max`, rayons de vue, pools de fragments) sans dire dans quel format, avec quelle validation ni à quel moment on les lit. Décision : un fichier JSON par domaine, des **entiers seulement**, un schéma déclaré en code, un `DataCatalog` chargé **une fois au démarrage** qui rend des objets typés immuables, et un échec franc (jamais de valeur par défaut silencieuse).

## Engine Compatibility

| Field | Value |
|-------|-------|
| **Engine** | Godot 4.7.2 |
| **Domain** | Core |
| **Layer** | Foundation |
| **Knowledge Risk** | MEDIUM (`JSON`, `FileAccess`, `HashingContext` existent depuis 4.0 ; comportement vérifié en headless sur Windows) |
| **References Consulted** | `docs/engine-reference/godot/VERSION.md`, `docs/engine-reference/godot/current-best-practices.md`, Tuning Knobs des GDD 1 à 23, ADR-0002 à 0006 |
| **Post-Cutoff APIs Used** | Aucune |
| **Verification Required** | (1) **Android** : les `*.json` de `assets/data/` sont dans l'export (filtre d'inclusion des fichiers non ressources) et lisibles par `FileAccess` sur `res://` ; (2) durée du chargement de tous les fichiers au démarrage sur l'appareil de référence ; (3) test CI de clés dupliquées (le moteur ne les détecte pas) |

## ADR Dependencies

| Field | Value |
|-------|-------|
| **Depends On** | None |
| **Enables** | ADR-0008 (le catalogue est construit à la racine de composition), ADR-0005 (`AiParams`), ADR-0002 (durées, `Q_max`), ADR-0001 (`TABLE_TEINTES`), ADR-0007 (rayons de vue), ADR-0011 (fixtures) |
| **Blocks** | Toutes les stories qui lisent une valeur de réglage |
| **Ordering Note** | Foundation : à accepter tôt, avec ADR-0003 ; aucune dépendance entrante |

## Context

### Problem Statement
Les standards du projet exigent des valeurs de jeu pilotées par les données (« jamais codées en dur »). Les GDD listent des centaines de valeurs de réglage, plusieurs ADR citent `assets/data/ai.*`, `assets/data/units.*`, `assets/data/brouillard.*`. Aucun ADR ne fixe le format, la validation ni le moment du chargement. Les règles de jeu sont en **entiers seulement** (GDD 1, règle 6) pour que deux appareils calculent la même chose.

### Constraints
- GDScript, Godot 4.7.2, Android d'abord ; déterminisme exigé (rejeu, reprise de la phase ennemie).
- JSON.parse rend des `float` : un champ entier doit être vérifié, pas supposé.
- Les valeurs de réglage changent entre deux versions (équilibrage) sans changer le schéma de sauvegarde (GDD 16, règle 17bis) : une partie reprend avec les nouvelles valeurs.
- Pas de singleton (ADR-0002) : le catalogue est injecté.

### Requirements
- Format lisible et diffable en revue, éditable sans l'éditeur Godot, extensible à un tableur d'équilibrage plus tard.
- Validation complète au chargement : type, bornes, clés inconnues ou manquantes, références croisées.
- Rien ne se relit en cours de partie ; un échec de chargement est une erreur de démarrage, pas un défaut silencieux.

## Decision

**1. Un fichier JSON par domaine, UTF-8.** `assets/data/<domaine>.json` : `units`, `ai`, `brouillard`, `energie`, `noeuds`, `combat`, `protocoles`, `fragments`, `recoloration`, `presentation` (durées, `Q_max`, `ATTACK_LOCK_MS`), `teintes`, `hud`, `controles`, `sauvegarde`, plus `cartes/<nom>.json` pour les fichiers de carte (GDD 2). Chaque fichier commence par `"schema_version": <entier>`. Les textes affichés (fragments, libellés) sont adressés par **identifiant stable** et relèvent de la localisation, hors de ce périmètre.

**2. Entiers seulement.** Toute valeur est un entier ou une chaîne ; **aucun nombre fractionnaire** dans les données, y compris les réglages de contrôles et de caméra. Les rapports sont exprimés en centièmes, millièmes ou millionièmes avec un suffixe de nom (`_pct`, `_milli`, `_micro`) : le GDD 4 passe à `TAP_SLOP_MILLI` = 500, `ZOOM_STEP_MILLI` = 1260 (2^(1/3)), `ZOOM_MAX_MILLI`, `FOCUS_CLEARANCE_MILLI` = 500, `ZOOM_EPS_MICRO` = 1000 (**GDD SYNC** : renommer ces réglages dans le GDD 4) ; les durées en millisecondes (`_ms`), les couleurs en chaînes `"#RRGGBB"` converties en entier au chargement. Le validateur lit le `float` rendu par le moteur et exige `value == floor(value)` et `|value| ≤ 2³¹ − 1` ; sinon erreur (« 2,5 » refusé, jamais arrondi). Cas vérifiés : `2.0` est accepté comme l'entier 2 ; `-0` donne 0 ; `1e999` donne `inf` avec un avertissement du moteur, attrapé par la borne. Les règles de jeu n'effectuent donc aucun calcul flottant sur une donnée.

**3. Schéma déclaré en code, strict.** Chaque domaine a un `DataSchema` (constante GDScript : champ → type, minimum, maximum, énumération de noms, éléments de tableau). Le validateur **refuse** : une clé inconnue, une clé manquante (pas de défaut caché), un type faux, une valeur hors bornes, une référence croisée orpheline (prérequis de protocole inexistant, type d'unité inconnu, identifiant de fragment dupliqué ou non croissant). Il rend **toutes** les erreurs, pas la première, avec le nom du fichier et le chemin du champ.

**4. `DataCatalog`, immuable, typé.** `DataCatalog.load_all(source: DataSource) -> DataCatalogResult` lit tous les fichiers par un port étroit `DataSource` (réel : `FileAccess` sur `res://assets/data/` ; test : dictionnaire en mémoire), valide, puis construit des objets `RefCounted` typés en lecture seule (le chemin de production utilise `JSON.new().parse`, qui rend un code et un message, et **jamais** `JSON.parse_string`, qui imprime une erreur et rend `null` ; la ligne d'erreur peut valoir 0, ne pas l'afficher telle quelle) (`UnitTypes`, `AiParams`, `PresentationParams`, `TeintesTable`, `FragmentPools`…). Aucun `Dictionary` brut ne sort du catalogue : les règles lisent des champs typés. Le catalogue est construit **une fois au démarrage**, avant toute partie, par la racine de composition (ADR-0008), puis **injecté** ; il n'y a ni autoload ni accès statique global.

**5. Échec franc.** Une erreur de chargement en développement affiche toutes les erreurs et arrête le démarrage ; en version distribuée les données sont livrées avec l'application, donc une erreur est un bogue de build : écran d'erreur « données invalides » avec le code, **jamais** de repli sur des valeurs par défaut. La CI valide tous les fichiers (test headless) avant tout merge.

**6. Rechargement à chaud : développement seulement, entre deux parties.** Une commande de débogage reconstruit le catalogue quand aucune partie n'est ouverte ; jamais en cours de partie (déterminisme du rejeu et de la reprise).

**7. Empreinte de contenu.** `catalog.content_hash` = SHA-256 (`HashingContext` : `start`, `update`, `finish().hex_encode()`) de la suite, pour chaque fichier dans l'ordre, de (nom, longueur en octets, **octets** du contenu) (la longueur et le nom lèvent l'ambiguïté d'une concaténation simple ; ce sont les octets `FileAccess.get_file_as_bytes`, jamais du texte : `get_file_as_string` conserve les `\r`, vérifié) dans l'ordre alphabétique **explicite** des noms (`DataSource.list()` trie par `PackedStringArray.sort()` ; `DirAccess` ne garantit aucun ordre, et un PCK Android peut différer). Un `.gitattributes` impose `assets/data/*.json text eol=lf` pour que Windows et Linux calculent la même empreinte. Elle est écrite dans l'en-tête du `CommandLog` (ADR-0004) pour qu'un rejeu avec d'autres données soit signalé, et affichée dans l'écran de débogage. Elle n'est **pas** dans la sauvegarde : une partie reprend avec les valeurs de la version courante (règle 17bis du GDD 16).

**8. Clés dupliquées.** Le moteur n'attend pas de doublon (`{"a":1,"a":2}` donne 2 sans erreur, mesuré) : un contrôle CI `tools/ci/check-json-duplicate-keys` (script Python minimal, `object_pairs_hook`) rejette tout fichier de `assets/data/` qui en contient.

**9. Export.** On suppose que le filtre d'inclusion de l'export Android **doit** contenir `*.json` (hypothèse : un `.json` n'a pas d'importeur, vérifié en éditeur headless, et ne serait donc exporté que par le filtre) ; la vérification (1) la confirme sur l'appareil.

**10. Cohérence entre une partie et les données.** Retirer ou renuméroter un identifiant du catalogue (type d'unité, protocole, fragment) est un **changement de schéma** (GDD 16, règle 17bis). La validation de l'état au chargement contrôle ses références au catalogue (type d'unité connu, PV ≤ maximum courant, identifiants de protocole et de fragment connus) : un identifiant inconnu fait **refuser le fichier** avec repli sur `.bak` (ADR-0006) ; une valeur dépassant le nouveau maximum est ramenée au maximum **par une migration documentée**, jamais en silence.

### Architecture Diagram

```
 assets/data/*.json ──► DataSource (port : FileAccess réel | dictionnaire de test)
        │ parse (JSON.parse_string / JSON.new().parse pour les erreurs)
        ▼
 DataSchema (par domaine) ── valide : types, entiers, bornes, clés, références ──► toutes les erreurs ou ──┐
                                                                                                         ▼
                                       DataCatalog (immuable, typé) : units, ai, presentation, teintes, …  + content_hash
                                             │ construit une fois par Bootstrap (ADR-0008), injecté
                                             ▼
                          règles, pipeline, IA, séquenceur, rendu, HUD (lecture seule)
```

### Key Interfaces

```gdscript
class_name DataSource extends RefCounted
func read_text(path: String) -> String            # "" + erreur si absent ; réel : FileAccess ; test : mémoire
func list(dir: String) -> PackedStringArray

class_name DataCatalog extends RefCounted
static func load_all(source: DataSource) -> DataCatalogResult
var content_hash: String
var units: UnitTypes
var ai: AiParams
var presentation: PresentationParams               # durées, Q_max, ATTACK_LOCK_MS, T_CRENEAU_RÉDUIT
var teintes: TeintesTable
# … un champ typé par domaine

class_name DataCatalogResult extends RefCounted
var ok: bool
var catalog: DataCatalog                           # null si ok == false
var errors: Array[DataError]                       # fichier, chemin du champ, message
```

### Implementation Guidelines
- Une valeur de jeu **ne doit jamais** être codée en dur : elle vient du catalogue.
- Les données **ne doivent contenir** aucun nombre fractionnaire ; un rapport **doit** porter le suffixe `_pct` ou `_milli`.
- Le catalogue **ne doit jamais** être lu par une API statique ni un autoload ; il est injecté.
- Le catalogue **ne doit jamais** être modifié ni rechargé pendant une partie.
- Un champ manquant ou inconnu **doit** être une erreur, jamais un défaut.
- Toute nouvelle valeur de réglage **doit** ajouter sa ligne au `DataSchema` du domaine et son test de bornes.

## Alternatives Considered

### Alternative 1: Ressources `.tres` typées (`Resource` avec `@export`)
- **Description**: un `Resource` par domaine, édité dans l'inspecteur.
- **Pros**: typage et éditeur intégrés ; chargement par `ResourceLoader`.
- **Cons**: diffs bruyants et conflits de fusion ; les nombres peuvent être des flottants ; édition impossible sans l'éditeur ; les erreurs de types sont silencieuses à l'import.
- **Estimated Effort**: similaire.
- **Rejection Reason**: la revue des données d'équilibrage doit passer par un diff lisible, et l'entier doit être imposé.

### Alternative 2: CSV ou `ConfigFile`
- **Description**: tableaux plats ou sections clé = valeur.
- **Pros**: très simple ; adapté aux tableurs.
- **Cons**: pas de structure imbriquée (arbre de protocoles, pools, cartes) ; typage faible ; pas de tableaux.
- **Estimated Effort**: moindre.
- **Rejection Reason**: trop pauvre pour les structures du jeu.

### Alternative 3: Constantes GDScript
- **Description**: valeurs dans des scripts `const`.
- **Pros**: vérifiées par le parseur ; aucun chargement.
- **Cons**: viole « données externes » ; recompile pour tout réglage ; inaccessible à un équilibrage hors code.
- **Estimated Effort**: moindre.
- **Rejection Reason**: contredit la règle « pilotées par les données ».

## Consequences

### Positive
- Une seule porte d'entrée pour les réglages, validée avant la première partie ; une erreur de donnée se trouve en CI, pas en jeu.
- Aucun calcul flottant sur une donnée : même résultat sur tous les appareils.
- Diffs lisibles et reprise possible par un tableur d'équilibrage.

### Negative
- Un schéma à maintenir en code pour chaque fichier ; chaque nouvelle valeur coûte une ligne de schéma et un test.
- Le moteur ne détecte pas les clés dupliquées : un script CI dédié est nécessaire.

### Neutral
- Les rapports s'écrivent en centièmes ou millièmes (`weight_pct = 150`) plutôt qu'en décimales.

## Risks
- **Une mise à jour d'équilibrage rend une sauvegarde invalide** (PV au-dessus du nouveau maximum, type retiré, pool réduit) : *Atténuation* : section 10, contrôle des références au chargement, changement de schéma pour tout retrait d'identifiant.
- **Fichiers absents de l'export Android** : *Atténuation* : filtre `*.json`, vérification sur appareil, erreur de démarrage claire.
- **Schéma et données divergents** : *Atténuation* : validation stricte, test CI de tous les fichiers livrés.
- **Précision JSON au-delà de 2⁵³** : *Atténuation* : borne à 2³¹ − 1 imposée par le validateur.

## GDD Requirements Addressed

| GDD System | Requirement | How This ADR Addresses It |
|------------|-------------|--------------------------|
| modele-etat-partie.md (1) | Règle 6 : entiers seulement ; valeurs de réglage dans des fichiers de configuration | Section 2 |
| ia-ennemie.md (9) | Poids de F1, `K_DEST`, `LEASH`, `EVALS_MAX` en données (`assets/data/ai.*`) | `AiParams` typé |
| unites-drones.md (6), brouillard-vision.md (5) | Rayons de vue et statistiques dans `assets/data/units.*` | `UnitTypes` |
| commandes-evenements.md (23), hud-systeme.md (17) | Durées de séquence, `Q_max`, `ATTACK_LOCK_MS` en données | `PresentationParams` |
| recoloration-monde.md (15) | `TABLE_TEINTES[mode][faction]` en données | `TeintesTable` |
| arbre-protocoles.md (12), ruines-fragments.md (13) | Arbre, calendrier de l'IA, pools de fragments en données | Domaines `protocoles`, `fragments` |
| controles-tactiles-camera.md (4) | Tuning Knobs fractionnaires (anciens `TAP_SLOP_FACTOR`, `ZOOM_STEP_FACTOR`, `ZOOM_EPS`…, renommés `_MILLI` / `_MICRO` dans le GDD 4) | Suffixes `_milli`, `_micro`, domaine `controles` |
| sauvegarde-automatique.md (16) | Règle 17bis : changer une valeur d'équilibrage ne change pas le schéma | Section 7 |

## Performance Implications
- **CPU**: chargement et validation une fois au démarrage (quelques dizaines de fichiers de quelques ko) ; à mesurer sur l'appareil.
- **Memory**: quelques dizaines de ko d'objets typés.
- **Load Time**: ajouté au démarrage ; budget à fixer après mesure (vérification 2).
- **Network**: sans objet.

## Migration Plan
Aucun code existant. À créer (et amender ADR-0004 : `CommandLog.content_hash`, fait ; ADR-0002 : chemin `assets/data/presentation.json`, fait) : `DataCatalog`, `DataSchema` par domaine, `tools/ci/check-json-duplicate-keys`, le test CI qui charge `assets/data/` réel, l'entrée `*.json` du filtre d'export.

Le projet n'a pas encore d'`export_presets.cfg` : le preset Android **doit** porter `include_filter="assets/data/*.json"` (vérifié : aucun importeur pour `.json`, le fichier n'est exporté que par ce filtre). Ajouter `.gitattributes` (`assets/data/*.json text eol=lf`).

**Rollback plan**: repli sur des `.tres` typés par domaine (Alternative 1) si l'export JSON pose problème sur Android.

## Validation Criteria
- Tous les fichiers de `assets/data/` passent le validateur en CI ; un fichier à clé inconnue, manquante, fractionnaire ou dupliquée échoue.
- Deux chargements successifs donnent le même `content_hash`.
- Un build Android charge le catalogue sans erreur (vérification 1).

## Related
- ADR-0008 (racine de composition), ADR-0001, ADR-0002, ADR-0004, ADR-0005, ADR-0007, ADR-0011.
- `design/gdd/modele-etat-partie.md` (règle 6), `design/gdd/sauvegarde-automatique.md` (règle 17bis), Tuning Knobs de chaque GDD.
