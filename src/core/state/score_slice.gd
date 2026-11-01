# owner: src/core/state/ src/core/nodes/ src/core/combat/
# Raw score counters per faction (GDD 1): nodes held (system 11), units destroyed
# (system 8). Fragments read are counted from the ruin journal.
class_name ScoreSlice
extends SliceBase

const COLUMNS := [
	[&"_score_nodes_held", TYPE_PACKED_INT32_ARRAY],
	[&"_score_units_destroyed", TYPE_PACKED_INT32_ARRAY],
]

var _score_nodes_held := PackedInt32Array()
var _score_units_destroyed := PackedInt32Array()


func columns() -> Array:
	return COLUMNS


func length_error(_tiles: int, factions: int) -> String:
	var error := _sized_error(&"_score_nodes_held", factions)
	return error if not error.is_empty() else _sized_error(&"_score_units_destroyed", factions)


func units_destroyed_of(faction: int) -> int:
	return _score_units_destroyed[faction]


func setup(factions: int) -> void:
	_score_nodes_held.resize(factions)
	_score_units_destroyed.resize(factions)
