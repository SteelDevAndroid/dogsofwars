# UNITÉ_DÉTRUITE (GDD 23): unit, tile, destroyed by (-1 for an elimination).
class_name UnitDestroyedEvent
extends PresentationEvent

var unit_id: int
var tile: int
var by: int


func _init(p_faction: int, p_unit_id: int, p_tile: int, p_by: int) -> void:
	faction = p_faction
	unit_id = p_unit_id
	tile = p_tile
	by = p_by


func tiles() -> PackedInt32Array:
	return PackedInt32Array([tile])
