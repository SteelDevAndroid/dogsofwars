# ADR-0010: Entrées tactiles et caméra de carte — interpréteur de gestes pur, caméra mathématique sans Camera2D, échelle en dp par le facteur de contenu

## Status
Accepted

## Date
2026-10-31

## Last Verified
2026-10-31 — conception sur le GDD 4 et les ADR-0002, 0004, 0007, 0008 ; **vérifié en headless** Godot 4.7.2 Windows : existence de `Input.set_use_accumulated_input`, `DisplayServer.get_display_safe_area`, du réglage `input_devices/pointing/emulate_touch_from_mouse`, des réglages `display/window/stretch/*`, de la propriété `Window.content_scale_mode` et de `InputEventScreenTouch.canceled`. **Non vérifié** : tout le comportement tactile réel (annulation de contact, accumulation, densité d'écran) : Android seulement.

## Decision Makers
Utilisateur (direction de projet, choix « recommandé » délégué), Claude (rédaction), godot-specialist et technical-director (validation, TD-ADR : CONCERNS traités le 2026-10-31). **L'acceptation (`Accepted`) exige une confirmation explicite de l'utilisateur, ADR par ADR : le choix « recommandé » délégué ne vaut pas acceptation.**

## Summary
Le GDD 4 renvoie à un ADR les événements tactiles de Godot, la caméra, la projection et la conversion du point en pixels. Décision : un `GestureInterpreter` pur (suite d'événements de pointeur → gestes), une `MapCamera` pure (centre, zoom, projection) qui pilote le transform d'un `Node2D` sans `Camera2D`, un `TapResolver` pur qui applique le tableau d'effets du GDD 4 pour produire des commandes soumises au pipeline, l'échelle en dp obtenue par `content_scale_factor`, et une requête de portée issue du même code que la validation de DÉPLACER.

## Engine Compatibility

| Field | Value |
|-------|-------|
| **Engine** | Godot 4.7.2 |
| **Domain** | Input |
| **Layer** | Presentation |
| **Knowledge Risk** | HIGH (entrées tactiles, densité d'écran et zones sûres ne sont pas couvertes par la référence du moteur ; comportement Android non vérifié) |
| **References Consulted** | `docs/engine-reference/godot/VERSION.md`, `docs/engine-reference/godot/current-best-practices.md`, `design/gdd/controles-tactiles-camera.md`, `design/ux/hud.md` (section 3), `design/accessibility-requirements.md`, ADR-0002, ADR-0004, ADR-0007, ADR-0008 |
| **Post-Cutoff APIs Used** | Aucune connue ; `DisplayServer.get_display_safe_area()` et `Window.content_scale_factor` sont à confirmer sur Android |
| **Verification Required** | (1) **Android** : `InputEventScreenTouch` (pose, relevé, `canceled`), `InputEventScreenDrag`, effet de l'accumulation (`use_accumulated_input`) sur le seuil d'appui ; (2) `DisplayServer.screen_get_dpi()` donne la densité et `content_scale_factor = dpi / 160` rend une tuile minimale de 31 dp ; (3) zone sûre et découpes ; (4) pause et perte de focus abandonnent le contact ; (5) coût de la requête de portée (≤ 2 ms sur l'appareil) ; (6) un second doigt `InputEventScreenTouch` atteint-il bien `_gui_input` du `Control` ; (7) sur PC, `content_scale_factor = 2` divise le rectangle visible par deux |

## ADR Dependencies

| Field | Value |
|-------|-------|
| **Depends On** | ADR-0004 (`check`, `submit`, `RuleTable`), ADR-0002 (événements, `CommandGate`, idle du séquenceur), ADR-0007 (`FactionView`), ADR-0008 (`InputSurface` construite par `MatchScreen`), ADR-0009 (réglages de contrôles) — Accepted avant celui-ci |
| **Enables** | Stories de contrôles tactiles, caméra, recentrage, plage de déplacement, ciblage |
| **Blocks** | Stories : sélection, déplacement, attaque, zoom, défilement, annulation du déplacement |
| **Ordering Note** | Après ADR-0008 ; le prototype sur appareil du GDD 4 (seuils, accumulation) peut précéder l'acceptation sans la bloquer |

## Context

### Problem Statement
Le système 4 transforme des doigts en ordres et en mouvements de caméra sans jamais écrire dans la partie. Il doit tenir au pouce sur des tuiles de 31 pt, ne jamais lire un glissement comme un ordre, et afficher une portée qui **est** la validation. Les GDD laissent à un ADR le choix des événements d'entrée, de la caméra, de la projection et du mode d'étirement.

### Constraints
- GDScript, Godot 4.7.2, Android d'abord ; aucun geste à deux doigts n'est obligatoire.
- Un contact est jugé **au relâchement** ; un défilement est irréversible dans un contact (GDD 4, règles 1 et 2).
- Le « point » du GDD est le dp (Android) / pt (iOS), indépendant de la densité.
- La caméra n'est pas sauvegardée (présentation) ; le Core ne référence pas la Presentation.
- Budget de validation : 0,3 ms par commande (provisoire, ADR-0004).

### Requirements
- Interpréteur de gestes testable sans moteur ni appareil.
- Un seul chemin d'une commande : `check` puis `submit`, sur l'état de la partie ; aucun calcul de portée propre.
- Caméra bornée (marge de 2 tuiles), zoom ancré, recentrage animé ou instantané.

## Decision

**1. Entrée normalisée.** `InputSurface` (`Control`, ADR-0008) couvre le rectangle de carte, `mouse_filter = STOP`, et traduit les `InputEventScreenTouch` (pose, relevé, `canceled`) et `InputEventScreenDrag` en `PointerEvent` (valeur : `index`, `phase` DOWN/MOVE/UP/CANCEL, position en unités de viewport). **Source unique** : `InputSurface._gui_input` **ignore tout `InputEventMouse*`** (vérifié : avec `emulate_mouse_from_touch = true`, valeur par défaut, chaque `InputEventScreenTouch` arrive doublé d'un `InputEventMouseButton`, y compris sur un contact `canceled`, d'où double appui ou faux relevé) ; le réglage `input_devices/pointing/emulate_mouse_from_touch` est mis à `false`. Sur ordinateur, `input_devices/pointing/emulate_touch_from_mouse` fournit un doigt (un clic livre alors un `ScreenTouch` **et** le `MouseButton` d'origine, ignoré par la règle précédente) ; le pincement est testé par injection de `PointerEvent`, pas par la souris. Les notifications `NOTIFICATION_APPLICATION_FOCUS_OUT` et `NOTIFICATION_APPLICATION_PAUSED`, la pause de l'arbre et un événement `canceled` produisent un `CANCEL` (règle 7 du GDD 4). `Input.set_use_accumulated_input(false)` : chaque déplacement est livré tel quel, car l'accumulation (valeur par défaut) pourrait fusionner un aller-retour au-delà de la demi-tuile et faire manquer le franchissement du seuil (risque noté par le GDD 4, section « Bloqués ») ; le critère de validation « dépasse la demi-tuile puis revient ne donne jamais un appui » tient alors aussi sur appareil ; en cas de fusion malgré tout, `GestureInterpreter` somme les `relative` des `ScreenDrag`, pas leurs positions ; le seuil d'appui est mesuré sur appareil (vérification 1). Les racines du `HudLayer` (`CanvasLayer` au-dessus) ont `mouse_filter = IGNORE` sur leurs zones transparentes, sans quoi elles consomment les contacts avant `InputSurface`.

**2. `GestureInterpreter`, pur.** `RefCounted` sans nœud, sans horloge, sans moteur : automate par contact (LIBRE → APPUI_POSSIBLE → APPUI ou DÉFILEMENT ; seconde pose → PINCEMENT ; tout état → LIBRE par CANCEL). Il consomme des `PointerEvent` et rend des `Gesture` : `Tap(position)`, `Scroll(delta)`, `PinchUpdate(centre, facteur)`, `PinchEnd`, `Cancel`. Seuil : `TAP_SLOP_MILLI` × taille de tuile / 1000 (0,5 tuile par défaut) **en unités de viewport** (donc proportionnel au zoom) ; une distance **égale** au seuil est un appui. Un `DOWN` sur un index déjà actif vaut `CANCEL` puis `DOWN` (AC-C7). Après un pincement, le doigt restant n'est pas repris en défilement avant d'avoir été relevé (état `ORPHELIN`, règle 4). Aucun double appui, appui long ni glisser-déposer (règle 6).

**3. `MapCamera`, pure, sans `Camera2D`.** `MapCamera` (`RefCounted`) tient le centre (en tuiles), le zoom (taille de tuile en dp) et le rectangle de carte ; elle fournit `tile_to_screen`, `screen_to_tile` (formule 3), les bornes de défilement (marge `EDGE_MARGIN_TILES`), l'ancrage du zoom et le décalage minimal de focus (formules 5 à 7). Le nœud `World` (`Node2D`) reçoit `position` et `scale` calculés par la caméra à chaque image où elle change. **Pas de `Camera2D`** : ses limites et son lissage dupliqueraient les règles du GDD, et la projection reste testable en pur. Le recentrage animé est un interpolateur de la caméra, appelé par le `CameraHandler` d'ADR-0002 (qui rend le `PresentationHold` de `RECENTER_MS`), instantané avec « Réduction des animations ». La caméra mémorise son état à FINIR_LE_TOUR et le restitue au début du tour du joueur ; elle ne suit pas les actions ennemies (règle 20d : les `UNITÉ_DÉPLACÉE` de l'autre faction sont ignorées). Le HUD demande un recentrage (puces d'alerte, règle 20a) par `camera.request_recenter(tile)`.

**4. Échelle en dp.** Le mode d'étirement du projet est `disabled` ; au démarrage et à chaque `size_changed` (changement de taille ou d'orientation) de la fenêtre racine (`get_tree().root`, qui est la `Window`), `UiScale` règle `Window.content_scale_factor = clamp(DisplayServer.screen_get_dpi() / 160.0, 1.0, 4.0)` (modulé par le réglage d'échelle du texte). Une unité de viewport vaut alors un dp. La zone sûre vient de `DisplayServer.get_display_safe_area()` (en pixels écran : soustraire la position de la fenêtre, puis diviser par `content_scale_factor`) et alimente le rectangle de carte (règle 14 du GDD 4) ; **un rectangle vide ou de taille nulle** (valeur rendue en headless, vérifiée) signifie « écran entier ». Elle est relue à chaque `size_changed`. L'affichage bord à bord d'Android (4.5+) peut faire passer les barres système sur la carte si la zone sûre n'est pas appliquée : à tester sur appareil. Ce choix remplace un étirement `canvas_items` dont l'unité dépendrait de la taille d'écran en paysage.

**5. `InteractionModel` et `TapResolver`, purs.** Le **mode** d'interaction (REPOS, SÉLECTION, CIBLAGE, RÉSOLUTION, LECTURE, TOUR_ENNEMI, SUSPENDU) est une **dérivation** de l'état de partie (par `StateView`) et du HUD, jamais stockée dans l'état. `TapResolver.resolve(mode, selection, target, checks) -> TapAction` implémente le tableau B du GDD 4 (l'aperçu recalculé du ciblage passe par `pipeline.preview`, ADR-0004 §6) ; l'action est `Select`, `Deselect`, `Command(cmd)`, `Refusal(code)` ou `Ignore`. En RÉSOLUTION, LECTURE et TOUR_ENNEMI les appuis sont ignorés sans commande, le défilement et le zoom restent actifs ; en SUSPENDU tout est ignoré.

**6. Commande : `check` puis `submit`.** `InteractionController` (Presentation) reçoit un `Tap`, convertit la position en tuile par `MapCamera`, interroge `InteractionModel` et `TapResolver`, puis appelle `pipeline.check(cmd)` et, si permis, `pipeline.submit(cmd)`. Le refus affiché est le code du pipeline, inchangé. Une tuile sous brouillard est validée sur la vue du joueur (ADR-0007) et n'affiche aucune information cachée ; le seul refus possible sur une tuile jamais vue est `HORS_DE_PORTÉE`.

**7. Plage de déplacement = validation.** La portée affichée n'est pas calculée par le système 4 : `RuleTable.check_move_range(view: StateView, unit_id: int) -> PackedInt32Array` (**ajout à ADR-0004**) rend les tuiles où DÉPLACER est permis, par un parcours qui appelle **le même code d'étape** que `validate` de DÉPLACER ; un test de parité vérifie, pour chaque tuile, `RuleTable.validate(view, Move)` permis ⇔ tuile ∈ plage (c'est `validate` qui est comparé, **pas** `pipeline.check`, dont le préfixe de refus — PAS_VOTRE_TOUR, verrous — ferait échouer la parité en tour ennemi). La plage est calculée à la sélection et mémorisée par (révision, unité) ; elle est recalculée quand la révision change. Si le coût dépasse 2 ms sur l'appareil, le calcul (fonction pure sur une copie) passe sur `WorkerThreadPool` comme la planification de l'IA (ADR-0005 §7) et la plage apparaît **entière** à la fin, jamais partielle.

**8. Caméra et événements.** `MapCamera` n'est pas dans l'état ni la sauvegarde : au chargement, zoom par défaut et centre sur l'unité du joueur d'identifiant le plus bas. Elle écoute DÉPLACEMENT_ANNULÉ, ÉTAT_CHARGÉ, UNITÉ_DÉPLACÉE, RUINE_LUE et TOUR_COMMENCÉ par le gestionnaire de présentation (ADR-0002) et n'émet aucune commande de caméra : « la caméra n'est pas une commande ».

**9. Hors périmètre.** Lecteur d'écran (TalkBack, VoiceOver) : une `InputSurface` personnalisée est invisible pour AccessKit ; renvoyé à l'ADR d'accessibilité. iOS : `dpi / 160` est faux sur iOS (référence 163, échelle entière) ; le MVP vise Android, iOS reprendra `DisplayServer.screen_get_scale()`.

**10. Bouton retour Android.** `Node.NOTIFICATION_WM_GO_BACK_REQUEST` ouvre le menu pause (SUSPENDU) ; il n'est jamais un ordre de jeu. Le réglage `application/config/quit_on_go_back` vaut `true` par défaut (vérifié) : il **doit** être mis à `false`, sans quoi le retour quitte l'application avant le menu. La livraison de cette notification aux nœuds sur appareil est non vérifiée.

### Architecture Diagram

```
 InputEventScreenTouch / ScreenDrag / focus-out ──► InputSurface (Control) ──► PointerEvent(index, phase, pos dp)
                                                           │
                                          GestureInterpreter (pur) ──► Tap | Scroll | PinchUpdate | PinchEnd | Cancel
                                   Scroll / Pinch ──► MapCamera (pur) ──► World.position / scale
                                   Tap ──► MapCamera.screen_to_tile ──► InteractionModel (mode dérivé de StateView + HUD)
                                                                             │
                                                              TapResolver (pur, tableau B) ──► Select | Deselect | Refusal | Command
                                                                             │ Command
                                                       pipeline.check(cmd) ──► pipeline.submit(cmd) ──► (ADR-0004)
 Sélection ──► RuleTable.check_move_range(view, unit) ──► PackedInt32Array ──► surcouche de portée (mémorisée par révision)
 UiScale : Window.content_scale_factor = dpi / 160 (unité de viewport = 1 dp) ; zone sûre ──► rectangle de carte
```

### Key Interfaces

```gdscript
class_name PointerEvent extends RefCounted      # valeur : index, phase (DOWN/MOVE/UP/CANCEL), position (unités de viewport = dp)

class_name GestureInterpreter extends RefCounted
func feed(event: PointerEvent, tile_size_dp: float) -> Array[Gesture]    # pur, déterministe

class_name MapCamera extends RefCounted
func tile_to_screen(tile: Vector2) -> Vector2
func screen_to_tile(pos: Vector2) -> Vector2i
func scroll(delta: Vector2) -> void             # borné par EDGE_MARGIN_TILES
func zoom_at(anchor: Vector2, factor: float) -> void
func recenter_to(tile: Vector2i, animated: bool) -> void

class_name TapResolver extends RefCounted
static func resolve(mode: int, selection: int, target: TapTarget, checks: CheckPort) -> TapAction

# ajout à ADR-0004 (RuleTable)
static func check_move_range(view: StateView, unit_id: int) -> PackedInt32Array
```

### Implementation Guidelines
- `GestureInterpreter`, `MapCamera` et `TapResolver` **doivent** rester purs (aucun nœud, aucune horloge, aucun appel moteur) et testés sans scène.
- Aucune commande **ne doit** naître d'un défilement, d'un pincement ni d'un contact interrompu.
- Le système 4 **ne doit jamais** calculer une portée ni écrire dans l'état ; il lit la plage du pipeline et soumet des commandes.
- Le mode d'interaction **ne doit jamais** être stocké dans l'état de partie.
- Les tailles tactiles **doivent** être exprimées en dp (unité de viewport) ; aucun pixel en dur.
- Un `CANCEL` **doit** abandonner le contact en cours sans appui ni défilement.
- Toute valeur de réglage (seuil, `ZOOM_STEP_MILLI`, `EDGE_MARGIN_TILES`, `RECENTER_MS`) **doit** venir du catalogue (ADR-0009).

## Alternatives Considered

### Alternative 1: `Camera2D` pour défilement et zoom
- **Description**: nœud caméra avec limites et lissage de Godot.
- **Pros**: moins de code ; limites intégrées.
- **Cons**: lissage et limites dupliquent les règles du GDD ; ancrage du zoom et décalage minimal à recoder de toute façon ; projection moins testable.
- **Estimated Effort**: moindre.
- **Rejection Reason**: règles déterministes du GDD plus simples en pur.

### Alternative 2: Étirement `canvas_items` avec taille de base 360 × 640
- **Description**: mise à l'échelle automatique du viewport.
- **Pros**: aucune logique d'échelle ; courant.
- **Cons**: l'unité dépend du rapport d'aspect ; en paysage une tuile de 31 dp tombe à environ 20 dp ; zone sûre à convertir quand même.
- **Estimated Effort**: moindre.
- **Rejection Reason**: la règle 17 du GDD exige un point indépendant de la densité.

### Alternative 3: Gestes dans les nœuds de l'interface (`_gui_input` partout)
- **Description**: chaque élément interprète ses propres contacts.
- **Pros**: pas d'automate central.
- **Cons**: état de contact dispersé ; double lecture possible d'un même geste ; tests impossibles hors scène.
- **Estimated Effort**: moindre.
- **Rejection Reason**: contredit « un contact est jugé au relâchement, une seule fois ».

## Consequences

### Positive
- Les gestes, la caméra et la décision d'un appui sont testables en headless, sans appareil.
- Une seule source de vérité pour la portée (la validation) ; pilier 4 préservé.
- Le point reste un dp sur tous les écrans, portrait comme paysage.

### Negative
- Une caméra et un interpréteur à écrire et tester plutôt que d'utiliser `Camera2D`.
- `check_move_range` ajoute une fonction à la table de règles et un test de parité.

### Neutral
- Le pincement n'est testé que par injection d'événements (la souris n'émule qu'un doigt).

## Risks
- **Comportement tactile Android différent** (accumulation, annulation, seuils) : *Atténuation* : vérifications 1 et 4 sur appareil, interpréteur pur donc ajustable sans changer le reste.
- **Densité d'écran mal rapportée** : *Atténuation* : borne `clamp(1, 4)`, réglage utilisateur d'échelle, vérification 2.
- **Plage de déplacement trop chère** : *Atténuation* : mémoïsation par (révision, unité), répartition sur plusieurs images sans affichage partiel.

## GDD Requirements Addressed

| GDD System | Requirement | How This ADR Addresses It |
|------------|-------------|--------------------------|
| controles-tactiles-camera.md (4) | Règles 1 à 7 : appui, défilement, pincement, contact interrompu | `GestureInterpreter` pur |
| controles-tactiles-camera.md (4) | Règle 8 : la portée affichée est la validation | `check_move_range` et test de parité sur `validate` (le GDD dit « valider DÉPLACER pour chaque tuile » : l'ADR l'interprète par une requête groupée de la même validation, **à signaler dans le GDD 4**) |
| controles-tactiles-camera.md (4) | Tableau B et règles 9 à 12 : effet d'un appui, ciblage, annulation | `InteractionModel`, `TapResolver` |
| controles-tactiles-camera.md (4) | Règles 13 à 20 : repère, rectangle de carte, zoom, bornes, recentrage (dont 20a demandes du HUD, 20d caméra à FINIR_LE_TOUR) | `MapCamera`, `UiScale`, `CameraHandler`, `request_recenter` |
| controles-tactiles-camera.md (4) | Règle 17 : point indépendant de la densité (renvoyé à un ADR) | Section 4 |
| commandes-evenements.md (23) | Règle 7 : l'aperçu et la portée sont des validations | Sections 6 et 7 |
| brouillard-vision.md (5) | Règle 11 : un appui sur le brouillard n'affiche rien de caché | `FactionView` (ADR-0007) |
| accessibility-requirements.md | Zoom sans pincement ; réduction des animations | Boutons de zoom ; recentrage instantané |

## Performance Implications
- **CPU**: automate de gestes et projection négligeables ; la plage de déplacement (jusqu'à environ 120 tuiles) est mémorisée par révision, à mesurer (≤ 2 ms).
- **Memory**: quelques objets par contact ; plage mémorisée (un `PackedInt32Array`).
- **Load Time**: sans objet.
- **Network**: sans objet.

## Migration Plan
Aucun code existant. À créer : `InputSurface`, `GestureInterpreter`, `MapCamera`, `InteractionModel`, `TapResolver`, `UiScale`, `InteractionController` ; amendement d'ADR-0004 (`check_move_range`) ; réglages `input_devices/pointing/emulate_touch_from_mouse` (développement), `input_devices/pointing/emulate_mouse_from_touch = false`, `application/config/quit_on_go_back = false` et `display/window/stretch/mode = disabled`.

**Rollback plan**: repasser à l'étirement `canvas_items` avec base 360 × 640 et accepter l'écart en paysage si `content_scale_factor` pose problème sur Android.

## Validation Criteria
- Suite de tests purs : une séquence qui dépasse la demi-tuile puis revient ne donne jamais un appui ; pose, seconde pose, relevé ne produit aucune commande.
- Parité `check(Move)` / `check_move_range` sur 1 000 états aléatoires.
- Sur appareil : tuile minimale de 31 dp, zone sûre respectée, perte de focus sans commande.

## Related
- ADR-0002, ADR-0004 (amendé), ADR-0007, ADR-0008, ADR-0009.
- `design/gdd/controles-tactiles-camera.md`, `design/ux/hud.md`, `design/accessibility-requirements.md`.
