# UNITÉ_SOIGNÉE (GDD 6 rule 11): the unit, its HP before and after. It belongs to the
# unit's owner; the other side sees it when the tile was visible.
class_name UnitHealedEvent
extends PresentationEvent

var unit_id: int
var hp_before: int
var hp_after: int
var tile: int


func _init(p_faction: int, p_unit_id: int, p_hp_before: int, p_hp_after: int, p_tile: int) -> void:
	faction = p_faction
	unit_id = p_unit_id
	hp_before = p_hp_before
	hp_after = p_hp_after
	tile = p_tile


func tiles() -> PackedInt32Array:
	return PackedInt32Array([tile])
