# ADR-0013: Audio — une banque de sons à deux bus, un présentateur du séquenceur, aucun son seul porteur d'information

## Status
Accepted — consigne la décision prise et construite le 2026-11-02 (PR #16), écrite jusque-là dans ADR-0008 (revue d'architecture du 2026-11-03, N1)

## Date
2026-11-03

## Last Verified
2026-11-03 — d'après `src/presentation/audio/sound_bank.gd`, `src/presentation/sequencer/sound_handler.gd`, `src/app/bootstrap.gd`, `src/app/match_screen.gd` et `tests/unit/presentation/sound_bank_test.gd` ; Godot 4.7.2, tests headless. **Rien n'a été écouté sur un appareil.**

## Decision Makers
Utilisateur (direction de projet), Claude (rédaction).

## Summary
Les sons sont des **repères** joués par une `SoundBank` unique (un jeu de huit lecteurs, deux bus **Effects** et **Interface**, un volume en pour cent par bus). Les sons de la carte passent par un **présentateur du séquenceur** (`SoundHandler`, contrat `PresentationHandler` d'ADR-0002) : ils suivent les événements que le joueur peut voir, ne font jamais attendre et se taisent en affichage direct. Aucun son ne porte une information seul.

## Engine Compatibility

| Field | Value |
|-------|-------|
| **Engine** | Godot 4.7.2 |
| **Domain** | Audio |
| **Layer** | Presentation |
| **Knowledge Risk** | MEDIUM |
| **References Consulted** | Aucune référence moteur versionnée (voir `references-externes.md`) ; code et tests cités en Last Verified |
| **Post-Cutoff APIs Used** | Aucune. `AudioStreamPlayer`, `AudioServer.add_bus`, `set_bus_name`, `set_bus_mute`, `set_bus_volume_db`, `linear_to_db` existent depuis 4.0 : NOT SOURCEABLE dans les références |
| **Verification Required** | (1) niveau, durée et agrément des sons sur appareil ; (2) latence de démarrage d'un `AudioStreamPlayer` sur Android ; (3) focus audio d'Android (appel entrant, autre application) ; (4) mode « ne pas déranger » |

## ADR Dependencies

| Field | Value |
|-------|-------|
| **Depends On** | ADR-0002 (séquenceur, `PresentationHandler`, événements filtrés), ADR-0008 (composition : `Bootstrap` construit la banque) |
| **Enables** | GDD 20 (audio), réglages de volume (GDD 19 et 22) |
| **Blocks** | Rien |

## Context
La PR #16 a ajouté quatorze effets synthétiques et leur lecture, mais les décisions (bus, présentateur, règle d'accessibilité) n'étaient écrites que dans une note d'ADR-0008, qui porte sur la racine de composition. Le GDD 20 (audio) n'est pas écrit.

### Constraints
- Le joueur ne doit rien apprendre par un son qu'il ne voit pas (ADR-0007) : un son suit un événement déjà filtré par le brouillard.
- Accessibilité : aucune information n'est portée par le son seul (`design/accessibility-requirements.md`).
- La présentation ne bloque jamais la logique : un son ne retient pas le séquenceur.

## Decision

**1. Les sons.** Quatorze effets WAV mono, 22 050 Hz, 16 bits (`assets/audio/`, 332 Ko), synthétisés par `tools/audio/make_sounds.py` (bibliothèque standard, résultat identique à chaque exécution). Ce sont des **repères** remplaçables à nom égal par un sound designer. Aucune musique au MVP.

**2. La banque.** `SoundBank` (`Node`, `src/presentation/audio/`) charge un flux par repère (`CUES`), tient **huit lecteurs** et crée au besoin deux bus : **Effects** (ce qui se passe sur la carte : déplacement, attaque, destruction, menace, réveil, capture, fragment, tour, victoire, défaite) et **Interface** (tape, retour, sélection, refus). Chaque bus a un volume de 0 à 100 % ; 0 le coupe. Quand tous les lecteurs jouent, le plus ancien est réutilisé. **Un même repère ne démarre qu'une fois par image** : à la vitesse Instantanée du tour ennemi, une phase entière tient en quelques images, et dix déplacements dans la même image donnent un seul son au lieu de couper tous les autres (revue du 2026-11-03). `played` garde les 64 derniers repères demandés, pour les tests et le diagnostic.

**3. Le présentateur.** `SoundHandler` (`PresentationHandler`, ADR-0002 §5) joue le repère de l'événement (`cue_of`), **jamais** en affichage direct (chargement, resynchronisation), et rend toujours une tenue de 0 ms : un son ne fait jamais attendre. Il est le **dernier** gestionnaire de la liste (caméra, tuiles, HUD, son). Les événements qu'il reçoit sont déjà filtrés par la vue du joueur (`CommandPipeline._player_events`) : un son ne révèle rien.

**4. Composition.** `Bootstrap` possède la banque (un enfant, pour toute l'application), lui applique les réglages `volume_effects` et `volume_ui` du profil (défaut 80, pas de 10), fait taper tout bouton de l'application (`node_added`) et passe la banque à `MatchScreen`, qui ajoute le `SoundHandler`. L'écran de fin joue la victoire ou la défaite (rien pour un abandon).

**4 bis. Vibrations (2026-11-03).** `Haptics` (`RefCounted`, `src/presentation/audio/`) double trois repères par une vibration courte d'Android (`Input.vibrate_handheld`) : refus 30 ms, attaque 40 ms, capture 60 ms. `SoundHandler` la déclenche avec le son (jamais en affichage direct), `MatchScreen` avec la bannière de refus. Au plus une vibration par image. Réglage `vibration` du profil (défaut 1), appliqué par `Bootstrap` ; permission `VIBRATE` dans le préréglage d'export. Une vibration suit la même règle que le son : jamais seule porteuse d'une information.

**5. Accessibilité.** Chaque son a un jumeau visuel : menace (puce et marqueur), réveil (l'unité éveillée), capture (le changement de couleur), fragment (le panneau), refus (la bannière), destruction (le glyphe de débris), sélection (l'anneau), fin de tour ennemi (le résumé). Un nouveau repère **doit** nommer le sien.

### Key Interfaces

```gdscript
class_name SoundBank extends Node
const CUES: Array[StringName]                   # un fichier assets/audio/<cue>.wav par repère
func play(cue: StringName) -> void              # une fois par repère et par image ; muet si le bus est à 0
func set_volumes(effects: int, interface: int) -> void   # 0..100, 0 coupe le bus
func bus_of(cue: StringName) -> StringName

class_name SoundHandler extends PresentationHandler
static func cue_of(event: PresentationEvent) -> StringName   # "" pour un événement muet
```

### Implementation Guidelines
- Un son **ne doit jamais** porter une information seul ; un nouveau repère **doit** avoir un signal visuel.
- `SoundHandler` **ne doit** lire que l'événement, jamais l'état, et **doit** rendre une tenue de 0 ms.
- Aucun son en affichage direct.

## Alternatives Considered

### Alternative 1: Un `AudioStreamPlayer` par événement, créé à la volée
- **Pros**: simple.
- **Cons**: allocations à chaque son, aucun plafond de voix.
- **Rejection Reason**: le jeu de huit lecteurs borne le coût et le nombre de voix.

### Alternative 2: Des signaux des systèmes vers l'audio
- **Cons**: contredit ADR-0002 (motif interdit `event_broadcast_by_signal`) ; le son entendrait des événements non filtrés.
- **Rejection Reason**: le présentateur du séquenceur reçoit des événements déjà filtrés, dans l'ordre.

## Consequences

### Positive
- L'audio suit l'ordre et le filtrage des autres présentateurs, et ne peut rien révéler.
- Les repères sont remplaçables sans toucher au code.

### Negative
- Pas de musique, donc pas de réglage « musique » (le GDD 22 en prévoit un).
- Le même son de tape pour tous les boutons.
- Les bus sont créés à l'exécution, pas par un `default_bus_layout`.

## Risks
- **Agrément et niveau inconnus sur appareil**. *Atténuation* : écoute sur l'appareil de référence ; repères remplaçables.
- **Focus audio d'Android** non géré. *Atténuation* : à traiter avec le GDD 20.

## GDD Requirements Addressed

| GDD System | Requirement | How This ADR Addresses It |
|------------|-------------|--------------------------|
| accessibility-requirements.md | Aucune information par le son seul | Jumeau visuel par repère (Decision 5) |
| profil-donnees-meta.md (22) | Volumes dans les réglages | `volume_effects`, `volume_ui` |
| audio (20) | Non écrit | Repères provisoires |

## Performance Implications
- **CPU**: un démarrage de lecteur par repère et par image au plus.
- **Memory**: 332 Ko de flux chargés au démarrage.

## Validation Criteria
- Chaque repère a son fichier et son bus ; un bus à 0 ne joue rien ; un même repère deux fois dans une image ne prend qu'un lecteur (`sound_bank_test.gd`).
- Affichage direct muet ; tenue de 0 ms.
- Écoute sur appareil (niveau, durée, latence).

## Related
- ADR-0002 (séquenceur et contrat des gestionnaires), ADR-0008 (composition), ADR-0007 (filtrage des événements).
- Revue : `docs/architecture/architecture-review-2026-11-03.md`, N1.
