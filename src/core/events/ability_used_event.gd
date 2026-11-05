# CAPACITÉ_UTILISÉE (GDD 6 rule 12): the unit, the ability (UnitTypes.ABILITY_*) and its tile.
# It belongs to the unit's owner; the other side sees it when the tile was visible.
class_name AbilityUsedEvent
extends PresentationEvent

var unit_id: int
var ability: int
var tile: int


func _init(p_faction: int, p_unit_id: int, p_ability: int, p_tile: int) -> void:
	faction = p_faction
	unit_id = p_unit_id
	ability = p_ability
	tile = p_tile


func tiles() -> PackedInt32Array:
	return PackedInt32Array([tile])
