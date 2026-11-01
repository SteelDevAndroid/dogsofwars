# owner: src/core/state/ src/core/units/
# Units by id (GDD 1, system 6 is the sole writer: wake-up and combat call its
# functions). All units, dormant ones included, are created at setup.
class_name UnitsSlice
extends SliceBase

const COLUMNS := [
	[&"_unit_id", TYPE_PACKED_INT32_ARRAY],
	[&"_unit_type", TYPE_PACKED_INT32_ARRAY],
	[&"_unit_faction", TYPE_PACKED_BYTE_ARRAY],
	[&"_unit_tile", TYPE_PACKED_INT32_ARRAY],
	[&"_unit_hp", TYPE_PACKED_INT32_ARRAY],
	[&"_unit_moved", TYPE_PACKED_BYTE_ARRAY],
	[&"_unit_acted", TYPE_PACKED_BYTE_ARRAY],
	[&"_unit_asleep", TYPE_PACKED_BYTE_ARRAY],
	[&"_unit_alive", TYPE_PACKED_BYTE_ARRAY],
]

var _unit_id := PackedInt32Array()
var _unit_type := PackedInt32Array()
var _unit_faction := PackedByteArray()
var _unit_tile := PackedInt32Array()
var _unit_hp := PackedInt32Array()
var _unit_moved := PackedByteArray()
var _unit_acted := PackedByteArray()
var _unit_asleep := PackedByteArray()
var _unit_alive := PackedByteArray()


func columns() -> Array:
	return COLUMNS


func id_column() -> StringName:
	return &"_unit_id"


func alive_column() -> StringName:
	return &"_unit_alive"


func length_error(_tiles: int, _factions: int) -> String:
	return _parallel_error()


## Setup only (GameStateSetup): appends a live unit; `id` is above every existing id.
func append(id: int, type: int, faction: int, tile: int, hp: int, asleep: bool) -> void:
	_unit_id.append(id)
	_unit_type.append(type)
	_unit_faction.append(faction)
	_unit_tile.append(tile)
	_unit_hp.append(hp)
	_unit_moved.append(0)
	_unit_acted.append(0)
	_unit_asleep.append(1 if asleep else 0)
	_unit_alive.append(1)


func is_alive(row: int) -> bool:
	return _unit_alive[row] == 1


func tile_of(row: int) -> int:
	return _unit_tile[row]


func faction_of(row: int) -> int:
	return _unit_faction[row]


func hp_of(row: int) -> int:
	return _unit_hp[row]


func id_of(row: int) -> int:
	return _unit_id[row]


func type_of(row: int) -> int:
	return _unit_type[row]


func is_asleep(row: int) -> bool:
	return _unit_asleep[row] == 1
