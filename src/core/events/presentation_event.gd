# Base of the presentation events published after a command (ADR-0002).
class_name PresentationEvent
extends RefCounted

## (revision, index in the batch).
var event_id: Vector2i
## Faction the event belongs to; Faction.NONE for an event of nobody (turn, load).
var faction: int = Faction.NONE


## Tiles where the event happens, for the fog filter (GDD 5 rule 20); overridden
## by events that have a place.
func tiles() -> PackedInt32Array:
	return PackedInt32Array()
