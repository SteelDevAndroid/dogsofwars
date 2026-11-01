# owner: src/core/state/ src/core/ai/
# AI intentions by id (GDD 1, system 9), at most INTENT_CAP x INTENT_RETENTION_TURNS
# rows. The siege count of the last node is in SiegeSlice.
class_name IntentionsSlice
extends SliceBase

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


func author_tile_of(row: int) -> int:
	return _int_author_tile[row]


func target_tile_of(row: int) -> int:
	return _int_target_tile[row]
