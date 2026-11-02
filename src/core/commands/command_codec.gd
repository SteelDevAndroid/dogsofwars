# Lossless command serialization (ADR-0004 §1): [type id, faction, emitter, params...].
class_name CommandCodec
extends RefCounted


static func encode(command: Command) -> PackedInt64Array:
	var values := PackedInt64Array([command.type(), command.faction, command.emitter])
	values.append_array(command.params())
	return values


## null for an unknown type or a wrong parameter count.
static func decode(values: PackedInt64Array) -> Command:
	if values.size() < 3:
		return null
	var rest := values.slice(3)
	match values[0]:
		CommandType.MOVE:
			return MoveCommand.from_params(values[1], values[2], rest)
		CommandType.UNDO_MOVE:
			return UndoMoveCommand.from_params(values[1], values[2], rest)
		CommandType.BEGIN_TURN:
			return BeginTurnCommand.from_params(values[1], values[2], rest)
		CommandType.END_TURN:
			return EndTurnCommand.from_params(values[1], values[2], rest)
		CommandType.UPGRADE_NODE:
			return UpgradeNodeCommand.from_params(values[1], values[2], rest)
		CommandType.WAKE:
			return WakeCommand.from_params(values[1], values[2], rest)
		CommandType.ATTACK:
			return AttackCommand.from_params(values[1], values[2], rest)
		CommandType.CAPTURE:
			return CaptureCommand.from_params(values[1], values[2], rest)
		CommandType.ABANDON:
			return AbandonCommand.from_params(values[1], values[2], rest)
		CommandType.RESEARCH:
			return ResearchCommand.from_params(values[1], values[2], rest)
	return null
