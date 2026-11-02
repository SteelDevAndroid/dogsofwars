# Terrain of every tile, fixed for the whole match (GDD 1, ADR-0003): set once at
# construction, no setter, shared by reference between real copies.
class_name TerrainGrid
extends RefCounted

## Terrain codes, in the order of the GDD 2 table. PLAIN (cost 1, not occluding)
## is what a filtered copy shows on undiscovered tiles (ADR-0007 §5).
const PLAIN := 0
const FOREST := 1
const MOUNTAIN := 2
const WATER := 3

var _cells: PackedByteArray


func _init(cells: PackedByteArray) -> void:
	_cells = cells.duplicate()


func at(tile: int) -> int:
	return _cells[tile]


func is_mountain(tile: int) -> bool:
	return _cells[tile] == MOUNTAIN


func size() -> int:
	return _cells.size()


func to_bytes() -> PackedByteArray:
	return _cells.duplicate()


func equals(other: TerrainGrid) -> bool:
	return _cells == other._cells
