# owner: src/core/state/ src/core/ai/
# AI intentions by id (GDD 1, system 9), at most INTENT_CAP x INTENT_RETENTION_TURNS
# rows. The siege count of the last node is in SiegeSlice.
class_name IntentionsSlice
extends SliceBase

## Kind of the target: a unit or a node (GDD 1: "type de cible").
const TARGET_UNIT := 0
const TARGET_NODE := 1
const ACTION_ATTACK := 0
const ACTION_CAPTURE := 1
## Motives (GDD 9 rule 18): TRAQUE, REPRÉSAILLE, CAPTURE, DÉFENSE.
const MOTIVE_HUNT := 0
const MOTIVE_REPRISAL := 1
const MOTIVE_CAPTURE := 2
const MOTIVE_DEFENSE := 3
const MOTIVE_COUNT := 4
const STATUS_ANNOUNCED := 0
const STATUS_EXECUTED := 1
const STATUS_CANCELLED := 2
## Cancellation reasons (GDD 1), REASON_NONE while the intention is not cancelled.
const REASON_NONE := 0
const REASON_AUTHOR_DESTROYED := 1
const REASON_TARGET_DESTROYED := 2
const REASON_TARGET_MOVED := 3
const REASON_OUT_OF_RANGE := 4
const REASON_UNIT_ABSENT := 5
const REASON_UNIT_DESTROYED := 6
const REASON_NODE_ALREADY_AI := 7

const COLUMNS := [
	[&"_int_id", TYPE_PACKED_INT32_ARRAY],
	[&"_int_author", TYPE_PACKED_INT32_ARRAY],
	[&"_int_author_tile", TYPE_PACKED_INT32_ARRAY],
	[&"_int_target_kind", TYPE_PACKED_BYTE_ARRAY],
	[&"_int_target_id", TYPE_PACKED_INT32_ARRAY],
	[&"_int_target_tile", TYPE_PACKED_INT32_ARRAY],
	[&"_int_action", TYPE_PACKED_BYTE_ARRAY],
	[&"_int_motive", TYPE_PACKED_BYTE_ARRAY],
	[&"_int_announced_turn", TYPE_PACKED_INT32_ARRAY],
	[&"_int_exec_turn", TYPE_PACKED_INT32_ARRAY],
	[&"_int_status", TYPE_PACKED_BYTE_ARRAY],
	[&"_int_cancel_reason", TYPE_PACKED_BYTE_ARRAY],
]

var _int_id := PackedInt32Array()
var _int_author := PackedInt32Array()
var _int_author_tile := PackedInt32Array()
var _int_target_kind := PackedByteArray()
var _int_target_id := PackedInt32Array()
var _int_target_tile := PackedInt32Array()
var _int_action := PackedByteArray()
var _int_motive := PackedByteArray()
var _int_announced_turn := PackedInt32Array()
var _int_exec_turn := PackedInt32Array()
var _int_status := PackedByteArray()
var _int_cancel_reason := PackedByteArray()


func columns() -> Array:
	return COLUMNS


func id_column() -> StringName:
	return &"_int_id"


func length_error(_tiles: int, _factions: int) -> String:
	return _parallel_error()


func author_of(row: int) -> int:
	return _int_author[row]


func target_kind_of(row: int) -> int:
	return _int_target_kind[row]


func target_id_of(row: int) -> int:
	return _int_target_id[row]


func action_of(row: int) -> int:
	return _int_action[row]


func motive_of(row: int) -> int:
	return _int_motive[row]


func announced_turn_of(row: int) -> int:
	return _int_announced_turn[row]


func exec_turn_of(row: int) -> int:
	return _int_exec_turn[row]


func status_of(row: int) -> int:
	return _int_status[row]


func id_of(row: int) -> int:
	return _int_id[row]


func author_tile_of(row: int) -> int:
	return _int_author_tile[row]


func target_tile_of(row: int) -> int:
	return _int_target_tile[row]
