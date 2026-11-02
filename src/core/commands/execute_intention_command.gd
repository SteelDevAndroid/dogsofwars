# EXÉCUTER_UNE_INTENTION (GDD 9 rule 4, GDD 23, ADR-0004 §9): internal command of the AI
# system, emitted by SYS at the start of the enemy phase, once per stored intention.
class_name ExecuteIntentionCommand
extends Command

var intention_id: int


func _init(p_intention_id: int = 0) -> void:
	faction = Faction.AI
	emitter = EMITTER_SYS
	intention_id = p_intention_id


func type() -> int:
	return CommandType.EXECUTE_INTENTION


func params() -> PackedInt64Array:
	return PackedInt64Array([intention_id])


static func from_params(p_faction: int, p_emitter: int, values: PackedInt64Array) -> ExecuteIntentionCommand:
	if values.size() != 1:
		return null
	var command := ExecuteIntentionCommand.new(values[0])
	command.faction = p_faction
	command.emitter = p_emitter
	return command
