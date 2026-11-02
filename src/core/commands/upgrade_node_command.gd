# MONTER_NŒUD (GDD 11 rules 11 and 12, GDD 23): raise one level of an owned node. No
# unit is needed; valid for the player and the AI alike.
class_name UpgradeNodeCommand
extends Command

var node_id: int


func _init(p_faction: int, p_emitter: int, p_node_id: int) -> void:
	faction = p_faction
	emitter = p_emitter
	node_id = p_node_id


func type() -> int:
	return CommandType.UPGRADE_NODE


func params() -> PackedInt64Array:
	return PackedInt64Array([node_id])


static func from_params(p_faction: int, p_emitter: int, values: PackedInt64Array) -> UpgradeNodeCommand:
	return UpgradeNodeCommand.new(p_faction, p_emitter, values[0]) if values.size() == 1 else null
