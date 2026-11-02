# Territory (GDD 11 rules 13 to 15), owned by the nodes system, sole writer of the
# tile owners: a full recompute after every node write. A node's tile takes its
# owner; another tile goes to the closest owned node within R(level) (Chebyshev,
# terrain ignored), keeping its owner on a tie, else the lowest node id; out of
# every territory it is neutral, unless a ruin recoloured it (anchor RUIN), which
# only a node of another faction takes back.
class_name TerritoryRules
extends RefCounted


## Recomputes every tile; returns the changes as [tiles, old owner, new owner]
## groups, sorted by old owner then new owner, neutral first (GDD 11 rule 7).
static func recompute(state: GameState, nodes: NodeParams, cause: int) -> Array:
	var changed := {}
	for tile in state.tile_count():
		var result := _owner_of(state, nodes, tile)
		var owner: int = result[0]
		var old := state.map.owner_at(tile)
		state.map._tile_anchor[tile] = MapSlice.ANCHOR_NONE if owner == Faction.NONE else result[1]
		if owner == old:
			continue
		state.map._tile_owner[tile] = owner
		state.map._tile_prev_owner[tile] = old
		state.map._tile_change_turn[tile] = state.turn()
		state.map._tile_change_cause[tile] = cause
		if old == Faction.PLAYER:
			RecallWrites.tile_lost(state, tile)
		var key := Vector2i(_sort_key(old), _sort_key(owner))
		if not changed.has(key):
			changed[key] = PackedInt32Array()
		changed[key].append(tile)
	var keys := changed.keys()
	keys.sort()
	var groups := []
	for key: Vector2i in keys:
		groups.append([changed[key], _faction_of_key(key.x), _faction_of_key(key.y)])
	return groups


## [owner, anchor] of a tile after the recompute.
static func _owner_of(state: GameState, nodes: NodeParams, tile: int) -> Array:
	var current := state.map.owner_at(tile)
	var w := state.width()
	var best := -1
	var claimants := PackedInt32Array()
	for row in state.nodes.row_count():
		var node_tile := state.nodes.tile_of(row)
		if node_tile == tile:
			return [state.nodes.owner_of(row), MapSlice.ANCHOR_NODE]
		var owner := state.nodes.owner_of(row)
		if owner == Faction.NONE:
			continue
		var d := maxi(absi(node_tile % w - tile % w), absi(node_tile / w - tile / w))
		if d > nodes.territory_radius(state.nodes.level_of(row)):
			continue
		if best < 0 or d < best:
			best = d
			claimants = PackedInt32Array([owner])
		elif d == best:
			claimants.append(owner)
	var ruin := state.map.anchor_at(tile) == MapSlice.ANCHOR_RUIN and current != Faction.NONE
	if claimants.is_empty():
		return [current, MapSlice.ANCHOR_RUIN] if ruin else [Faction.NONE, MapSlice.ANCHOR_NONE]
	if ruin and _only(claimants, current):
		return [current, MapSlice.ANCHOR_RUIN]
	if claimants.has(current):
		return [current, MapSlice.ANCHOR_NODE]
	return [claimants[0], MapSlice.ANCHOR_NODE]


## True when every claimant is `faction` (a ruin tile is only taken by another faction).
static func _only(claimants: PackedInt32Array, faction: int) -> bool:
	for owner in claimants:
		if owner != faction:
			return false
	return true


## recolorer_zone (GDD 11 rule 15), the interface of the ruins (13): only neutral
## tiles that hold no node are written, with the RUIN anchor; an enemy tile is never
## taken. Returns the tiles really changed, ascending.
static func recolor_zone(state: GameState, faction: int, tiles: PackedInt32Array, cause: int) -> PackedInt32Array:
	var changed := PackedInt32Array()
	var sorted := tiles.duplicate()
	sorted.sort()
	for tile in sorted:
		if state.map.owner_at(tile) != Faction.NONE or state.view().node_at(tile) >= 0:
			continue
		state.map._tile_owner[tile] = faction
		state.map._tile_anchor[tile] = MapSlice.ANCHOR_RUIN
		state.map._tile_prev_owner[tile] = Faction.NONE
		state.map._tile_change_turn[tile] = state.turn()
		state.map._tile_change_cause[tile] = cause
		changed.append(tile)
	return changed


## Ruin tiles of an eliminated faction become neutral (GDD 11 rule 15).
static func release_ruin_tiles(state: GameState, faction: int) -> void:
	for tile in state.tile_count():
		if state.map.owner_at(tile) == faction and state.map.anchor_at(tile) == MapSlice.ANCHOR_RUIN:
			state.map._tile_anchor[tile] = MapSlice.ANCHOR_NONE


static func _sort_key(owner: int) -> int:
	return -1 if owner == Faction.NONE else owner


static func _faction_of_key(key: int) -> int:
	return Faction.NONE if key == -1 else key
