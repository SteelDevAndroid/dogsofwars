# owner: src/core/state/ src/core/map/ src/core/nodes/
# Per-tile map data indexed by tile_index (GDD 1, formula 1). The terrain is not
# here: it is the shared, read-only TerrainGrid. Points of interest belong to
# system 2; owner and last owner change belong to system 11 (sole territory writer).
class_name MapSlice
extends SliceBase

## Why a tile is owned (GDD 11 rules 13 and 15): through a node's territory, or
## recoloured by a ruin (survives the loss of the faction's nodes); NONE when neutral.
const ANCHOR_NONE := 0
const ANCHOR_NODE := 1
const ANCHOR_RUIN := 2

const CAUSE_NONE := 0
const CAUSE_CAPTURE := 1
const CAUSE_COMBAT := 2
const CAUSE_RUIN := 3
## A node upgrade widened the territory. GDD 15 lists MONTÉE as a cause of recolouring
## while GDD 1 names only capture, combat and ruin: GDD SYNC.
const CAUSE_UPGRADE := 4

const COLUMNS := [
	[&"_tile_owner", TYPE_PACKED_BYTE_ARRAY],
	[&"_tile_anchor", TYPE_PACKED_BYTE_ARRAY],
	[&"_tile_change_turn", TYPE_PACKED_INT32_ARRAY],
	[&"_tile_prev_owner", TYPE_PACKED_BYTE_ARRAY],
	[&"_tile_change_cause", TYPE_PACKED_BYTE_ARRAY],
	[&"_tile_poi", TYPE_PACKED_BYTE_ARRAY],
]

var _tile_owner := PackedByteArray()
var _tile_anchor := PackedByteArray()
## Turn of the last owner change, -1 when it never changed.
var _tile_change_turn := PackedInt32Array()
var _tile_prev_owner := PackedByteArray()
var _tile_change_cause := PackedByteArray()
var _tile_poi := PackedByteArray()


func columns() -> Array:
	return COLUMNS


func length_error(tiles: int, _factions: int) -> String:
	for spec: Array in COLUMNS:
		var error := _sized_error(spec[0], tiles)
		if not error.is_empty():
			return error
	return ""


func setup(tiles: int) -> void:
	_tile_owner.resize(tiles)
	_tile_owner.fill(Faction.NONE)
	_tile_anchor.resize(tiles)
	_tile_change_turn.resize(tiles)
	_tile_change_turn.fill(-1)
	_tile_prev_owner.resize(tiles)
	_tile_prev_owner.fill(Faction.NONE)
	_tile_change_cause.resize(tiles)
	_tile_poi.resize(tiles)


func owner_at(tile: int) -> int:
	return _tile_owner[tile]


func anchor_at(tile: int) -> int:
	return _tile_anchor[tile]
