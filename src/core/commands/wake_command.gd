# RÉVEILLER (GDD 7, GDD 23): a unit of the pack wakes the dormant it names.
class_name WakeCommand
extends Command

var waker_id: int
var target_id: int


func _init(p_faction: int, p_emitter: int, p_waker_id: int, p_target_id: int) -> void:
	faction = p_faction
	emitter = p_emitter
	waker_id = p_waker_id
	target_id = p_target_id


func type() -> int:
	return CommandType.WAKE


func params() -> PackedInt64Array:
	return PackedInt64Array([waker_id, target_id])


static func from_params(p_faction: int, p_emitter: int, values: PackedInt64Array) -> WakeCommand:
	return WakeCommand.new(p_faction, p_emitter, values[0], values[1]) if values.size() == 2 else null
