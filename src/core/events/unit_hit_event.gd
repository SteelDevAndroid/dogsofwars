# UNITÉ_TOUCHÉE (GDD 8 rule 7): the unit, the HP really lost (before - after, not the
# raw value) and the HP left. It belongs to the owner of the unit hit.
class_name UnitHitEvent
extends PresentationEvent

var unit_id: int
var damage: int
var hp_left: int
var tile: int


func _init(p_faction: int, p_unit_id: int, p_damage: int, p_hp_left: int, p_tile: int) -> void:
	faction = p_faction
	unit_id = p_unit_id
	damage = p_damage
	hp_left = p_hp_left
	tile = p_tile


func tiles() -> PackedInt32Array:
	return PackedInt32Array([tile])
