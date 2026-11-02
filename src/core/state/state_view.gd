# Read-only facade on the state (ADR-0003): scalars or copies, never a raw column
# (typed arrays are passed by reference, a reader could write through them).
# FactionView (ADR-0004, ADR-0007) answers the same queries through the fog.
class_name StateView
extends RefCounted

var _state: GameState


func _init(state: GameState) -> void:
	_state = state


func width() -> int:
	return _state.width()


func height() -> int:
	return _state.height()


func tile_count() -> int:
	return _state.tile_count()


func faction_count() -> int:
	return _state.faction_count()


func turn() -> int:
	return _state.turn()


func phase() -> int:
	return _state.header.value(HeaderSlice.PHASE)


func revision() -> int:
	return _state.revision()


## Energy stock of a faction.
func energy(faction: int) -> int:
	return _state.factions.energy_of(faction)


## Protocol under research by a faction, -1 when none.
func research(faction: int) -> int:
	return _state.factions.research_of(faction)


func has_protocol(faction: int, protocol: int) -> bool:
	return _state.protocols.has(faction, protocol)


func max_turn() -> int:
	return _state.header.value(HeaderSlice.T_MAX)


func active_faction() -> int:
	return _state.header.value(HeaderSlice.ACTIVE_FACTION)


func terrain_at(tile: int) -> int:
	return _state.terrain.at(tile)


func tile_owner(tile: int) -> int:
	return _state.map.owner_at(tile)


## Ids of the live units, ascending (a copy).
func unit_ids() -> PackedInt32Array:
	var ids := PackedInt32Array()
	for row in _state.units.live_rows():
		ids.append(_state.units.id_of(row))
	return ids


## Tile of a live unit, -1 when the id is unknown or destroyed.
func unit_tile(unit_id: int) -> int:
	var row := _live_unit_row(unit_id)
	return -1 if row < 0 else _state.units.tile_of(row)


func unit_faction(unit_id: int) -> int:
	var row := _live_unit_row(unit_id)
	return Faction.NONE if row < 0 else _state.units.faction_of(row)


func unit_hp(unit_id: int) -> int:
	var row := _live_unit_row(unit_id)
	return 0 if row < 0 else _state.units.hp_of(row)


## Type of a live unit, -1 when the id is unknown or destroyed.
func unit_type(unit_id: int) -> int:
	var row := _live_unit_row(unit_id)
	return -1 if row < 0 else _state.units.type_of(row)


func unit_moved(unit_id: int) -> bool:
	var row := _live_unit_row(unit_id)
	return row >= 0 and _state.units.has_moved(row)


func unit_acted(unit_id: int) -> bool:
	var row := _live_unit_row(unit_id)
	return row >= 0 and _state.units.has_acted(row)


func unit_asleep(unit_id: int) -> bool:
	var row := _live_unit_row(unit_id)
	return row >= 0 and _state.units.is_asleep(row)


## Id of the live unit on `tile`, or -1.
func unit_at(tile: int) -> int:
	var row := _state.units.live_row_at(tile)
	return -1 if row < 0 else _state.units.id_of(row)


func tile_anchor(tile: int) -> int:
	return _state.map.anchor_at(tile)


func node_ids() -> PackedInt32Array:
	return _state.nodes._node_id.duplicate()


## Id of the node on `tile`, or -1.
func node_at(tile: int) -> int:
	for row in _state.nodes.row_count():
		if _state.nodes.tile_of(row) == tile:
			return _state.nodes.id_of(row)
	return -1


## Turn the current owner acquired the node, -1 when the id is unknown.
func node_since_turn(node_id: int) -> int:
	var row := _state.nodes.find_row(node_id)
	return -1 if row < 0 else _state.nodes.since_turn_of(row)


## Turn of the node's last upgrade, -1 when it never was upgraded or the id is unknown.
func node_upgraded_turn(node_id: int) -> int:
	var row := _state.nodes.find_row(node_id)
	return -1 if row < 0 else _state.nodes.upgraded_turn_of(row)


## Level of a node, -1 when the id is unknown.
func node_level(node_id: int) -> int:
	var row := _state.nodes.find_row(node_id)
	return -1 if row < 0 else _state.nodes.level_of(row)


func ruin_ids() -> PackedInt32Array:
	return _state.ruins._ruin_id.duplicate()


func ruin_tile(ruin_id: int) -> int:
	var row := _state.ruins.find_row(ruin_id)
	return -1 if row < 0 else _state.ruins.tile_of(row)


func node_tile(node_id: int) -> int:
	var row := _state.nodes.find_row(node_id)
	return -1 if row < 0 else _state.nodes.tile_of(row)


func node_owner(node_id: int) -> int:
	var row := _state.nodes.find_row(node_id)
	return Faction.NONE if row < 0 else _state.nodes.owner_of(row)


func _live_unit_row(unit_id: int) -> int:
	var row := _state.units.find_row(unit_id)
	return row if row >= 0 and _state.units.is_alive(row) else -1
