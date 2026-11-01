# TUILES_RÉVÉLÉES (GDD 5 rule 14): tiles of the player gone from unknown to
# discovered by one command, ascending, never empty; never for the AI.
class_name TilesRevealedEvent
extends PresentationEvent

var revealed_tiles: PackedInt32Array


func _init(p_tiles: PackedInt32Array) -> void:
	faction = Faction.PLAYER
	revealed_tiles = p_tiles


func tiles() -> PackedInt32Array:
	return revealed_tiles
