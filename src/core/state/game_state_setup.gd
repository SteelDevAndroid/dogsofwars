# Match setup (GDD 1 state CRÉÉE): the only writes outside a command, used by the
# new-game factory (ADR-0008) and the procedural generation (system 21).
class_name GameStateSetup
extends RefCounted


## Empty match at turn 0: seed fixed, id counters at zero, view cache invalid
## until VisionService.rebuild (ADR-0007 §2).
static func create(map_width: int, map_height: int, faction_count: int, seed_value: int,
		terrain_cells: PackedByteArray, match_id: int = 0, profile_epoch: int = 0) -> GameState:
	assert(map_width >= 1 and map_width <= GameState.MAX_MAP_SIZE, "map width outside 1..16")
	assert(map_height >= 1 and map_height <= GameState.MAX_MAP_SIZE, "map height outside 1..16")
	assert(terrain_cells.size() == map_width * map_height, "terrain size is not W x H")
	assert(seed_value >= 0 and seed_value <= 0xFFFFFFFF, "seed outside 0..2^32-1")
	var state := GameState.new()
	state.header._header[HeaderSlice.MATCH_ID] = match_id
	state.header._header[HeaderSlice.PROFILE_EPOCH] = profile_epoch
	state.header._header[HeaderSlice.SEED] = seed_value
	state.header._header[HeaderSlice.T_MAX] = GameState.MAX_TURN
	state.header._header[HeaderSlice.PHASE] = HeaderSlice.PHASE_CREATED
	state.header._header[HeaderSlice.ACTIVE_FACTION] = Faction.PLAYER
	state.header._header[HeaderSlice.WIDTH] = map_width
	state.header._header[HeaderSlice.HEIGHT] = map_height
	state.header._header[HeaderSlice.FACTION_COUNT] = faction_count
	var tiles := map_width * map_height
	state.terrain = TerrainGrid.new(terrain_cells)
	state.map.setup(tiles)
	state.visibility.setup(tiles, faction_count)
	state.factions.setup(faction_count)
	state.score.setup(faction_count)
	state.view_cache = ViewCache.new(faction_count, tiles)
	return state


## Adds a live unit (dormant ones included: all units exist from the setup on).
static func add_unit(state: GameState, type: int, faction: int, tile: int, hp: int, asleep: bool = false) -> int:
	var id := state.allocate_id(HeaderSlice.NEXT_UNIT_ID)
	state.units.append(id, type, faction, tile, hp, asleep)
	return id


static func add_node(state: GameState, tile: int, owner: int, level: int) -> int:
	var id := state.allocate_id(HeaderSlice.NEXT_NODE_ID)
	state.nodes.append(id, tile, owner, level)
	state.map._tile_anchor[tile] = MapSlice.ANCHOR_NODE
	return id


static func add_ruin(state: GameState, tile: int, zone: int, memory_faction: int) -> int:
	var id := state.allocate_id(HeaderSlice.NEXT_RUIN_ID)
	state.ruins.append(id, tile, zone, memory_faction)
	state.map._tile_anchor[tile] = MapSlice.ANCHOR_RUIN
	return id


static func set_tile_owner(state: GameState, tile: int, owner: int) -> void:
	state.map._tile_owner[tile] = owner


## Chronicle snapshot copied from the profile; call in (faction, fragment) order.
static func add_chronicle_fragment(state: GameState, faction: int, fragment_id: int) -> void:
	state.chronicle.append(faction, fragment_id)


static func set_turn(state: GameState, turn: int) -> void:
	state.header._header[HeaderSlice.TURN] = turn


## Phase and active faction (tests and setup; in a match, BEGIN_TURN writes them).
static func set_phase(state: GameState, phase: int, active_faction: int) -> void:
	state.header._header[HeaderSlice.PHASE] = phase
	state.header._header[HeaderSlice.ACTIVE_FACTION] = active_faction
