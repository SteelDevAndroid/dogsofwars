# DRONE_RÉVEILLÉ (GDD 7 rule 3): the unit woken and the unit that woke it. It belongs
# to the waker's faction; the other side sees it when the dormant's tile was visible.
class_name DroneWokenEvent
extends PresentationEvent

var unit_id: int
var by: int
var tile: int


func _init(p_faction: int, p_unit_id: int, p_by: int, p_tile: int) -> void:
	faction = p_faction
	unit_id = p_unit_id
	by = p_by
	tile = p_tile


func tiles() -> PackedInt32Array:
	return PackedInt32Array([tile])
