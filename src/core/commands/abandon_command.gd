# ABANDONNER (GDD 3 rule 9, GDD 23): the player gives up, after confirming in the
# pause menu (18).
class_name AbandonCommand
extends Command


func _init(p_faction: int = Faction.PLAYER, p_emitter: int = EMITTER_PLAYER) -> void:
	faction = p_faction
	emitter = p_emitter


func type() -> int:
	return CommandType.ABANDON


static func from_params(p_faction: int, p_emitter: int, values: PackedInt64Array) -> AbandonCommand:
	return AbandonCommand.new(p_faction, p_emitter) if values.is_empty() else null
