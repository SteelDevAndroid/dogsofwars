# RECHERCHER (GDD 12 rule 5, GDD 23): start researching a protocol.
class_name ResearchCommand
extends Command

var protocol: int


func _init(p_faction: int, p_emitter: int, p_protocol: int) -> void:
	faction = p_faction
	emitter = p_emitter
	protocol = p_protocol


func type() -> int:
	return CommandType.RESEARCH


func params() -> PackedInt64Array:
	return PackedInt64Array([protocol])


static func from_params(p_faction: int, p_emitter: int, values: PackedInt64Array) -> ResearchCommand:
	return ResearchCommand.new(p_faction, p_emitter, values[0]) if values.size() == 1 else null
