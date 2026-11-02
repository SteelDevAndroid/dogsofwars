# ATTAQUE_RÉSOLUE (GDD 8 rule 7): attacker and target. It belongs to the attacker's
# faction; the other side sees it when either tile was visible.
class_name AttackResolvedEvent
extends PresentationEvent

var attacker_id: int
var target_id: int
var attacker_tile: int
var target_tile: int


func _init(p_faction: int, p_attacker_id: int, p_target_id: int, p_attacker_tile: int, p_target_tile: int) -> void:
	faction = p_faction
	attacker_id = p_attacker_id
	target_id = p_target_id
	attacker_tile = p_attacker_tile
	target_tile = p_target_tile


func tiles() -> PackedInt32Array:
	return PackedInt32Array([attacker_tile, target_tile])
