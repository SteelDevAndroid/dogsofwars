# owner: src/core/state/ src/core/protocols/
# Acquired protocols (GDD 1, system 12): sorted set of (faction, protocol id),
# including the AI protocols granted by the fixed calendar.
class_name ProtocolsSlice
extends SliceBase

const COLUMNS := [
	[&"_proto_faction", TYPE_PACKED_BYTE_ARRAY],
	[&"_proto_id", TYPE_PACKED_INT32_ARRAY],
]

var _proto_faction := PackedByteArray()
var _proto_id := PackedInt32Array()


func columns() -> Array:
	return COLUMNS


func length_error(_tiles: int, _factions: int) -> String:
	return _parallel_error()


func faction_of(row: int) -> int:
	return _proto_faction[row]


func protocol_of(row: int) -> int:
	return _proto_id[row]


func has(faction: int, protocol: int) -> bool:
	for row in _proto_id.size():
		if _proto_faction[row] == faction and _proto_id[row] == protocol:
			return true
	return false
