# owner: src/core/state/ src/core/ai/
# AI agents (ADR-0005 §2), private to the AI faction: role state, turns without a
# target, post, current motive, by unit id. The scalar curseur_ia is AiCursorSlice.
class_name AiAgentsSlice
extends SliceBase

const COLUMNS := [
	[&"_agent_unit", TYPE_PACKED_INT32_ARRAY],
	[&"_agent_role_state", TYPE_PACKED_BYTE_ARRAY],
	[&"_agent_idle_turns", TYPE_PACKED_INT32_ARRAY],
	[&"_agent_post_tile", TYPE_PACKED_INT32_ARRAY],
	[&"_agent_motive", TYPE_PACKED_BYTE_ARRAY],
]

var _agent_unit := PackedInt32Array()
var _agent_role_state := PackedByteArray()
var _agent_idle_turns := PackedInt32Array()
var _agent_post_tile := PackedInt32Array()
var _agent_motive := PackedByteArray()


func columns() -> Array:
	return COLUMNS


func id_column() -> StringName:
	return &"_agent_unit"


func private_to() -> int:
	return Faction.AI


func length_error(_tiles: int, _factions: int) -> String:
	return _parallel_error()
