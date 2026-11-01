# DÉPLACER (GDD 23): a unit of the faction to a destination tile.
class_name MoveCommand
extends Command

var unit_id: int
var tile: int


func _init(p_faction: int, p_emitter: int, p_unit_id: int, p_tile: int) -> void:
	faction = p_faction
	emitter = p_emitter
	unit_id = p_unit_id
	tile = p_tile


func type() -> int:
	return CommandType.MOVE


func params() -> PackedInt64Array:
	return PackedInt64Array([unit_id, tile])


static func from_params(p_faction: int, p_emitter: int, values: PackedInt64Array) -> MoveCommand:
	return MoveCommand.new(p_faction, p_emitter, values[0], values[1]) if values.size() == 2 else null
