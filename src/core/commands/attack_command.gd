# ATTAQUER (GDD 8, GDD 23): an attacker strikes a target unit.
class_name AttackCommand
extends Command

var attacker_id: int
var target_id: int


func _init(p_faction: int, p_emitter: int, p_attacker_id: int, p_target_id: int) -> void:
	faction = p_faction
	emitter = p_emitter
	attacker_id = p_attacker_id
	target_id = p_target_id


func type() -> int:
	return CommandType.ATTACK


func params() -> PackedInt64Array:
	return PackedInt64Array([attacker_id, target_id])


static func from_params(p_faction: int, p_emitter: int, values: PackedInt64Array) -> AttackCommand:
	return AttackCommand.new(p_faction, p_emitter, values[0], values[1]) if values.size() == 2 else null
