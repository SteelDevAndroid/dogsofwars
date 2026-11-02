# owner: src/core/state/ src/core/ruins/
# Ruins by id (GDD 1, system 13; system 21 writes the initial setup only).
class_name RuinsSlice
extends SliceBase

const COLUMNS := [
	[&"_ruin_id", TYPE_PACKED_INT32_ARRAY],
	[&"_ruin_tile", TYPE_PACKED_INT32_ARRAY],
	[&"_ruin_zone", TYPE_PACKED_BYTE_ARRAY],
	[&"_ruin_memory_faction", TYPE_PACKED_BYTE_ARRAY],
	[&"_ruin_read", TYPE_PACKED_BYTE_ARRAY],
	[&"_ruin_read_turn", TYPE_PACKED_INT32_ARRAY],
	[&"_ruin_reader", TYPE_PACKED_BYTE_ARRAY],
]

var _ruin_id := PackedInt32Array()
var _ruin_tile := PackedInt32Array()
var _ruin_zone := PackedByteArray()
var _ruin_memory_faction := PackedByteArray()
var _ruin_read := PackedByteArray()
## Turn of the reading, -1 while unread.
var _ruin_read_turn := PackedInt32Array()
var _ruin_reader := PackedByteArray()


func columns() -> Array:
	return COLUMNS


func id_column() -> StringName:
	return &"_ruin_id"


func length_error(_tiles: int, _factions: int) -> String:
	return _parallel_error()


## Setup only (GameStateSetup).
func append(id: int, tile: int, zone: int, memory_faction: int) -> void:
	_ruin_id.append(id)
	_ruin_tile.append(tile)
	_ruin_zone.append(zone)
	_ruin_memory_faction.append(memory_faction)
	_ruin_read.append(0)
	_ruin_read_turn.append(-1)
	_ruin_reader.append(Faction.NONE)


func zone_of(row: int) -> int:
	return _ruin_zone[row]


func memory_faction_of(row: int) -> int:
	return _ruin_memory_faction[row]


func is_read(row: int) -> bool:
	return _ruin_read[row] == 1


func read_turn_of(row: int) -> int:
	return _ruin_read_turn[row]


func reader_of(row: int) -> int:
	return _ruin_reader[row]


## Row of the ruin standing on `tile`, -1 when none.
func row_at_tile(tile: int) -> int:
	return _ruin_tile.find(tile)


func tile_of(row: int) -> int:
	return _ruin_tile[row]


func id_of(row: int) -> int:
	return _ruin_id[row]
