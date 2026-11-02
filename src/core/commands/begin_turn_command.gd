# COMMENCER_LE_TOUR (GDD 3 rule 2, GDD 23 rule 13): internal command of the turn system.
class_name BeginTurnCommand
extends Command


func _init(p_faction: int, p_emitter: int = EMITTER_SYS) -> void:
	faction = p_faction
	emitter = p_emitter


func type() -> int:
	return CommandType.BEGIN_TURN


static func from_params(p_faction: int, p_emitter: int, values: PackedInt64Array) -> BeginTurnCommand:
	return BeginTurnCommand.new(p_faction, p_emitter) if values.is_empty() else null
