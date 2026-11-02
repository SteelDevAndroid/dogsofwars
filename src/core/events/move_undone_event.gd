# DÉPLACEMENT_ANNULÉ (GDD 23): the unit goes back from its arrival to its start.
class_name MoveUndoneEvent
extends PresentationEvent

var unit_id: int
var from_tile: int
var to_tile: int


func _init(p_unit_id: int, p_from: int, p_to: int) -> void:
	faction = Faction.PLAYER
	unit_id = p_unit_id
	from_tile = p_from
	to_tile = p_to


func tiles() -> PackedInt32Array:
	return PackedInt32Array([from_tile, to_tile])
