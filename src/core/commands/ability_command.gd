# CAPACITÉ (GDD 6 rule 12, GDD 23): a unit uses the active ability of its type. No target: the
# effect is on the unit and its neighbours. Valid for the player; the Guardians have none.
class_name AbilityCommand
extends Command

var unit_id: int


func _init(p_faction: int, p_emitter: int, p_unit_id: int) -> void:
	faction = p_faction
	emitter = p_emitter
	unit_id = p_unit_id


func type() -> int:
	return CommandType.ABILITY


func params() -> PackedInt64Array:
	return PackedInt64Array([unit_id])


static func from_params(p_faction: int, p_emitter: int, values: PackedInt64Array) -> AbilityCommand:
	return AbilityCommand.new(p_faction, p_emitter, values[0]) if values.size() == 1 else null
