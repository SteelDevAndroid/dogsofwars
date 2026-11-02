# NŒUD_MONTÉ (GDD 11 rule 12): node, owning faction, new level. It belongs to the
# owner; the other side sees it when the node's tile was visible.
class_name NodeUpgradedEvent
extends PresentationEvent

var node_id: int
var level: int
var tile: int


func _init(p_faction: int, p_node_id: int, p_level: int, p_tile: int) -> void:
	faction = p_faction
	node_id = p_node_id
	level = p_level
	tile = p_tile


func tiles() -> PackedInt32Array:
	return PackedInt32Array([tile])
