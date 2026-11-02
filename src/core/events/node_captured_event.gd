# NŒUD_CAPTURÉ (GDD 11 rule 7): node, capturing faction, previous owner (neutral possible).
class_name NodeCapturedEvent
extends PresentationEvent

var node_id: int
var previous_owner: int
var tile: int


func _init(p_node_id: int, p_faction: int, p_previous: int, p_tile: int) -> void:
	node_id = p_node_id
	faction = p_faction
	previous_owner = p_previous
	tile = p_tile


func tiles() -> PackedInt32Array:
	return PackedInt32Array([tile])
