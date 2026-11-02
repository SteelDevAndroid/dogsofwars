# VALIDER_LA_LECTURE (GDD 13 rule 14, GDD 23, ADR-0006 §8): internal command applied by the
# command layer only, after a successful profile write; it turns the journal entry of
# the ruin from pending to validated. It may be retried during the enemy phase.
class_name ValidateRuinReadCommand
extends Command

var ruin_id: int


func _init(p_faction: int = Faction.PLAYER, p_ruin_id: int = 0) -> void:
	faction = p_faction
	emitter = EMITTER_SYS
	ruin_id = p_ruin_id


func type() -> int:
	return CommandType.VALIDATE_RUIN_READ


func params() -> PackedInt64Array:
	return PackedInt64Array([ruin_id])


static func from_params(p_faction: int, p_emitter: int, values: PackedInt64Array) -> ValidateRuinReadCommand:
	if values.size() != 1:
		return null
	var command := ValidateRuinReadCommand.new(p_faction, values[0])
	command.emitter = p_emitter
	return command
