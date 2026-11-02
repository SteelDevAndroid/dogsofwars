# FINIR_LE_TOUR (GDD 23): the player ends their phase.
class_name EndTurnCommand
extends Command


func _init(p_faction: int = Faction.PLAYER, p_emitter: int = EMITTER_PLAYER) -> void:
	faction = p_faction
	emitter = p_emitter


func type() -> int:
	return CommandType.END_TURN


static func from_params(p_faction: int, p_emitter: int, values: PackedInt64Array) -> EndTurnCommand:
	return EndTurnCommand.new(p_faction, p_emitter) if values.is_empty() else null
