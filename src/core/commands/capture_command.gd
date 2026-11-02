# CAPTURER (GDD 11 rules 4 and 5, GDD 23): the unit captures the node it stands on.
class_name CaptureCommand
extends Command

var unit_id: int


func _init(p_faction: int, p_emitter: int, p_unit_id: int) -> void:
	faction = p_faction
	emitter = p_emitter
	unit_id = p_unit_id


func type() -> int:
	return CommandType.CAPTURE


func params() -> PackedInt64Array:
	return PackedInt64Array([unit_id])


static func from_params(p_faction: int, p_emitter: int, values: PackedInt64Array) -> CaptureCommand:
	return CaptureCommand.new(p_faction, p_emitter, values[0]) if values.size() == 1 else null
