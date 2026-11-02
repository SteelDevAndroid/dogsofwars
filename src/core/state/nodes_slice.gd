# owner: src/core/state/ src/core/nodes/
# Nodes by id (GDD 1, system 11). Nodes are never destroyed.
class_name NodesSlice
extends SliceBase

const COLUMNS := [
	[&"_node_id", TYPE_PACKED_INT32_ARRAY],
	[&"_node_tile", TYPE_PACKED_INT32_ARRAY],
	[&"_node_owner", TYPE_PACKED_BYTE_ARRAY],
	[&"_node_level", TYPE_PACKED_INT32_ARRAY],
	[&"_node_since_turn", TYPE_PACKED_INT32_ARRAY],
	[&"_node_upgraded_turn", TYPE_PACKED_INT32_ARRAY],
]

var _node_id := PackedInt32Array()
var _node_tile := PackedInt32Array()
var _node_owner := PackedByteArray()
var _node_level := PackedInt32Array()
## Turn the current owner acquired the node (GDD 11 rule 1), 0 at the setup.
var _node_since_turn := PackedInt32Array()
## Turn of the last MONTER_NŒUD, -1 when none.
var _node_upgraded_turn := PackedInt32Array()


func columns() -> Array:
	return COLUMNS


func id_column() -> StringName:
	return &"_node_id"


func length_error(_tiles: int, _factions: int) -> String:
	return _parallel_error()


## Setup only (GameStateSetup).
func append(id: int, tile: int, owner: int, level: int) -> void:
	_node_id.append(id)
	_node_tile.append(tile)
	_node_owner.append(owner)
	_node_level.append(level)
	_node_since_turn.append(0)
	_node_upgraded_turn.append(-1)


func id_of(row: int) -> int:
	return _node_id[row]


func tile_of(row: int) -> int:
	return _node_tile[row]


func since_turn_of(row: int) -> int:
	return _node_since_turn[row]


func upgraded_turn_of(row: int) -> int:
	return _node_upgraded_turn[row]


func owner_of(row: int) -> int:
	return _node_owner[row]


func level_of(row: int) -> int:
	return _node_level[row]
