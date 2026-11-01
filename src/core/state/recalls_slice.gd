# owner: src/core/state/ src/core/units/ src/core/nodes/
# Presentation recalls of the last enemy phase (GDD 1, HUD rule 22): no game
# effect. Lost units (tile, side) are written by system 6, lost tiles by system 11.
class_name RecallsSlice
extends SliceBase

const COLUMNS := [
	[&"_recall_unit_tile", TYPE_PACKED_INT32_ARRAY],
	[&"_recall_unit_side", TYPE_PACKED_BYTE_ARRAY],
	[&"_recall_lost_tile", TYPE_PACKED_INT32_ARRAY],
]

var _recall_unit_tile := PackedInt32Array()
var _recall_unit_side := PackedByteArray()
var _recall_lost_tile := PackedInt32Array()


func columns() -> Array:
	return COLUMNS


## Recalls of what the player lost, for the HUD only: not the AI's knowledge.
func private_to() -> int:
	return Faction.PLAYER


func length_error(_tiles: int, _factions: int) -> String:
	var n := _recall_unit_tile.size()
	return "" if _recall_unit_side.size() == n else "_recall_unit_side: %d rows, expected %d" % [_recall_unit_side.size(), n]
