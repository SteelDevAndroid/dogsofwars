# ANNULER_LE_DÉPLACEMENT (GDD 23 rule 15): the player's last move, if allowed.
class_name UndoMoveCommand
extends Command


func _init(p_faction: int = Faction.PLAYER, p_emitter: int = EMITTER_PLAYER) -> void:
	faction = p_faction
	emitter = p_emitter


func type() -> int:
	return CommandType.UNDO_MOVE


static func from_params(p_faction: int, p_emitter: int, values: PackedInt64Array) -> UndoMoveCommand:
	return UndoMoveCommand.new(p_faction, p_emitter) if values.is_empty() else null
