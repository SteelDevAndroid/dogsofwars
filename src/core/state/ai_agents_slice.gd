# owner: src/core/state/ src/core/ai/
# AI agents (ADR-0005 §2), private to the AI faction: role state, turns without a
# target, post, current motive, by unit id. The scalar curseur_ia is AiCursorSlice.
class_name AiAgentsSlice
extends SliceBase

## Role states (GDD 9 rule 10 and ADR-0005 §2): Chasseur POSTE, TRAQUE, RETOUR; Bastion
## CAPTURE, TIENT, RIPOSTE, SIÈGE; Sentinelle IMMOBILE.
const ROLE_POST := 0
const ROLE_HUNT := 1
const ROLE_RETURN := 2
const ROLE_CAPTURE := 3
const ROLE_HOLD := 4
const ROLE_RIPOSTE := 5
const ROLE_SIEGE := 6
const ROLE_IMMOBILE := 7
const ROLE_COUNT := 8
## "No post" (an int32 column) and "no current motive" (a byte column) in the columns.
const NO_POST := -1
const NO_MOTIVE := 255

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


func unit_of(row: int) -> int:
	return _agent_unit[row]


func role_of(row: int) -> int:
	return _agent_role_state[row]


func idle_turns_of(row: int) -> int:
	return _agent_idle_turns[row]


func post_tile_of(row: int) -> int:
	return _agent_post_tile[row]


func motive_of(row: int) -> int:
	return _agent_motive[row]


func private_to() -> int:
	return Faction.AI


func length_error(_tiles: int, _factions: int) -> String:
	return _parallel_error()
