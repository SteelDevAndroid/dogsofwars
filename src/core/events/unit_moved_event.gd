# UNITÉ_DÉPLACÉE (GDD 23): unit, start, arrival, requested destination (distinct
# from the arrival after an ambush or an undiscovered obstacle).
class_name UnitMovedEvent
extends PresentationEvent

var unit_id: int
var from_tile: int
var to_tile: int
var requested_tile: int


func _init(p_faction: int, p_unit_id: int, p_from: int, p_to: int, p_requested: int) -> void:
	faction = p_faction
	unit_id = p_unit_id
	from_tile = p_from
	to_tile = p_to
	requested_tile = p_requested


func tiles() -> PackedInt32Array:
	return PackedInt32Array([from_tile, to_tile])
