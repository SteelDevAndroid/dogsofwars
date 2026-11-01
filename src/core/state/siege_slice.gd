# owner: src/core/state/ src/core/ai/
# Siege count of the last node (GDD 1, Intentions, system 9): two scalars.
class_name SiegeSlice
extends SliceBase

const NODE := 0
const COUNT := 1
const SIZE := 2

const COLUMNS := [[&"_siege", TYPE_PACKED_INT32_ARRAY]]

## [node id under siege (-1 when none), count].
var _siege := PackedInt32Array([-1, 0])


func columns() -> Array:
	return COLUMNS


func length_error(_tiles: int, _factions: int) -> String:
	return _sized_error(&"_siege", SIZE)
