# RUINE_LUE (GDD 13 rule 14 g): the ruin, the reading faction, the fragment id (0 when
# the pool is exhausted) and the tile. It belongs to the reader; the fog filters it for
# the other side.
class_name RuinReadEvent
extends PresentationEvent

var ruin_id: int
var fragment_id: int
var tile: int


func _init(p_faction: int, p_ruin_id: int, p_fragment_id: int, p_tile: int) -> void:
	faction = p_faction
	ruin_id = p_ruin_id
	fragment_id = p_fragment_id
	tile = p_tile


func tiles() -> PackedInt32Array:
	return PackedInt32Array([tile])
