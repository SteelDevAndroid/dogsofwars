# Vision and visibility (GDD 5, ADR-0007): stateless functions, the only code that
# decides who sees what, and the only writer of the Visibility slice and of the
# ViewCache. Sources are walked by ascending id (units, then nodes).
class_name VisionService
extends RefCounted

const UNKNOWN := 0
const EXPLORED := 1
const VISIBLE := 2


## Match setup (GDD 5 rule 22): grids at zero, dormant markers memorized for every
## faction, the territory of each faction at least explored, then the view of
## every faction computed. The cache comes out valid.
static func setup(state: GameState, ctx: VisionContext) -> void:
	var tiles := state.tile_count()
	var nf := state.faction_count()
	state.visibility.setup(tiles, nf)
	var vis := state.visibility
	for row in state.units.row_count():
		if state.units.is_alive(row) and state.units.is_asleep(row):
			for f in nf:
				vis._vis_dormant_memo[f * tiles + state.units.tile_of(row)] = 1
	state.view_cache = ViewCache.new(nf, tiles)
	state.view_cache.valid = true
	recompute(state, ctx.all_factions(nf))


## Rebuilds the cache from the sources without touching the state (after a load,
## ADR-0006 §3 step 5). Eliminated factions see nothing.
static func rebuild(state: GameState, ctx: VisionContext) -> void:
	var cache := ViewCache.new(state.faction_count(), state.tile_count())
	for f in state.faction_count():
		if not state.factions.is_eliminated(f):
			cache.seen[f] = _sources_view(state, ctx, f)
	cache.valid = true
	state.view_cache = cache


## Recomputes the view of every faction of ctx.factions (GDD 5 rule 9), marks the
## new tiles discovered and refreshes the last owner seen (rule 5). The delta
## reports what the player learnt.
static func recompute(state: GameState, ctx: VisionContext) -> VisionDelta:
	var delta := VisionDelta.new()
	for f in ctx.factions:
		if state.factions.is_eliminated(f):
			continue
		var before := state.view_cache.seen[f]
		var seen := _sources_view(state, ctx, f)
		state.view_cache.seen[f] = seen
		_learn(state, f, seen, before, delta, true)
	return delta


## One step of a move (GDD 5 rule 11): the field of the unit at `tile` joins the
## discovered tiles and the current view of its faction. The final recompute of
## the move brings the current view back to the real situation.
static func reveal_step(state: GameState, ctx: VisionContext, unit_id: int, tile: int) -> VisionDelta:
	var delta := VisionDelta.new()
	var row := state.units.find_row(unit_id)
	var f := state.units.faction_of(row)
	if not ctx.factions.has(f):
		return delta
	var before := state.view_cache.seen[f]
	var seen := before.duplicate()
	for t in ctx.fields.field(tile, _unit_radius(state, ctx, row, tile)):
		seen[t] = 1
	state.view_cache.seen[f] = seen
	_learn(state, f, seen, before, delta, false)
	return delta


static func can_see(cache: ViewCache, faction: int, tile: int) -> bool:
	assert(cache.valid, "view cache read before VisionService.rebuild")
	return cache.seen[faction][tile] == 1


## A unit of the faction is always seen; another one if and only if its tile is
## VISIBLE (GDD 5 rule 6). Destroyed or unknown units are never seen.
static func can_see_unit(state: GameState, cache: ViewCache, faction: int, unit_id: int) -> bool:
	var row := state.units.find_row(unit_id)
	if row < 0 or not state.units.is_alive(row):
		return false
	return state.units.faction_of(row) == faction or can_see(cache, faction, state.units.tile_of(row))


## Full information on a node (real owner, level): own node or VISIBLE tile. Out of
## view, a discovered node shows the last owner seen and no level (GDD 5 rule 4).
static func can_see_node(state: GameState, cache: ViewCache, faction: int, node_id: int) -> bool:
	var row := state.nodes.find_row(node_id)
	if row < 0:
		return false
	return state.nodes.owner_of(row) == faction or can_see(cache, faction, state.nodes.tile_of(row))


## Terrain as the faction knows it: real once discovered, a plain otherwise (ADR-0007 §5).
static func known_terrain(state: GameState, faction: int, tile: int) -> int:
	return state.terrain.at(tile) if _discovered(state, faction, tile) else TerrainGrid.PLAIN


## Real owner on a VISIBLE tile, last owner seen elsewhere (GDD 5 rule 4).
static func known_tile_owner(state: GameState, faction: int, tile: int) -> int:
	if can_see(state.view_cache, faction, tile):
		return state.map.owner_at(tile)
	return state.visibility._vis_last_owner_seen[faction * state.tile_count() + tile]


## Why a tile is owned, as the faction sees it: real on a VISIBLE tile, unknown
## (NONE) elsewhere, like the history of the owner changes.
static func known_anchor(state: GameState, faction: int, tile: int) -> int:
	return state.map.anchor_at(tile) if can_see(state.view_cache, faction, tile) else MapSlice.ANCHOR_NONE


## A node is known when it is the faction's own or its tile is discovered.
static func knows_node(state: GameState, faction: int, node_id: int) -> bool:
	var row := state.nodes.find_row(node_id)
	if row < 0:
		return false
	return state.nodes.owner_of(row) == faction or _discovered(state, faction, state.nodes.tile_of(row))


## Owner of a known node: real in view, last owner seen of its tile out of view.
static func known_node_owner(state: GameState, faction: int, node_id: int) -> int:
	if not knows_node(state, faction, node_id):
		return Faction.NONE
	var row := state.nodes.find_row(node_id)
	if can_see_node(state, state.view_cache, faction, node_id):
		return state.nodes.owner_of(row)
	return state.visibility._vis_last_owner_seen[faction * state.tile_count() + state.nodes.tile_of(row)]


## Level of a known node: real in view, 0 (not remembered) out of view; -1 when unknown.
static func known_node_level(state: GameState, faction: int, node_id: int) -> int:
	if not knows_node(state, faction, node_id):
		return -1
	if can_see_node(state, state.view_cache, faction, node_id):
		return state.nodes.level_of(state.nodes.find_row(node_id))
	return 0


## Turn the owner acquired a node: real when the node is fully seen (own or in view),
## -1 otherwise, like the level.
static func known_node_since_turn(state: GameState, faction: int, node_id: int) -> int:
	if not can_see_node(state, state.view_cache, faction, node_id):
		return -1
	return state.nodes.since_turn_of(state.nodes.find_row(node_id))


## Turn of a node's last upgrade, same visibility as the level; -1 when never or unseen.
static func known_node_upgraded_turn(state: GameState, faction: int, node_id: int) -> int:
	if not can_see_node(state, state.view_cache, faction, node_id):
		return -1
	return state.nodes.upgraded_turn_of(state.nodes.find_row(node_id))


## Drawn ruins are marked for the player from turn 1 (GDD 5 rule 15); the AI does
## not know them (ADR-0005 §6).
static func knows_ruins(faction: int) -> bool:
	return faction == Faction.PLAYER


## GDD 5 rule 3: the only states a faction's view exposes.
static func tile_state(state: GameState, faction: int, tile: int) -> int:
	if can_see(state.view_cache, faction, tile):
		return VISIBLE
	if _discovered(state, faction, tile):
		return EXPLORED
	return UNKNOWN


## What a faction knows of a tile (GDD 5): never seen, seen before, seeing it now.
const FOG_UNDISCOVERED := 0
const FOG_EXPLORED := 1
const FOG_VISIBLE := 2


static func fog_level(state: GameState, faction: int, tile: int) -> int:
	if can_see(state.view_cache, faction, tile):
		return FOG_VISIBLE
	return FOG_EXPLORED if _discovered(state, faction, tile) else FOG_UNDISCOVERED


## One byte per tile, 1 where `faction` has discovered the tile (what tile_state reads, in bulk).
static func discovered_row(state: GameState, faction: int) -> PackedByteArray:
	var tiles := state.tile_count()
	return state.visibility._vis_discovered.slice(faction * tiles, (faction + 1) * tiles)


static func _discovered(state: GameState, faction: int, tile: int) -> bool:
	return state.visibility._vis_discovered[faction * state.tile_count() + tile] == 1


## GDD 5 rule 20: an event of another faction reaches `faction` only if one of its
## tiles was VISIBLE before or after the command.
static func event_visible(before: ViewCache, after: ViewCache, faction: int, event: PresentationEvent) -> bool:
	if event.faction == faction or event.faction == Faction.NONE:
		return true
	for tile in event.tiles():
		if can_see(before, faction, tile) or can_see(after, faction, tile):
			return true
	return false


## Invariants of GDD 5 rule 2, checked at load (ADR-0006 §3 step 5): every visible
## tile is discovered; no last owner is remembered on an undiscovered tile.
static func consistency_errors(state: GameState) -> PackedStringArray:
	var errors := PackedStringArray()
	var tiles := state.tile_count()
	var vis := state.visibility
	for f in state.faction_count():
		for t in tiles:
			var discovered := vis._vis_discovered[f * tiles + t] == 1
			if state.view_cache.seen[f][t] == 1 and not discovered:
				errors.append("faction %d sees undiscovered tile %d" % [f, t])
			if vis._vis_last_owner_seen[f * tiles + t] != Faction.NONE and not discovered:
				errors.append("faction %d remembers an owner on undiscovered tile %d" % [f, t])
	return errors


static func _sources_view(state: GameState, ctx: VisionContext, f: int) -> PackedByteArray:
	var seen := PackedByteArray()
	seen.resize(state.tile_count())
	var units := state.units
	for row in units.row_count():
		if units.is_alive(row) and not units.is_asleep(row) and units.faction_of(row) == f:
			for t in ctx.fields.field(units.tile_of(row), _unit_radius(state, ctx, row, units.tile_of(row))):
				seen[t] = 1
	var nodes := state.nodes
	for row in nodes.row_count():
		if nodes.owner_of(row) == f:
			var tile := nodes.tile_of(row)
			var radius := ctx.node_radius[nodes.level_of(row)] + (ctx.mountain_bonus if state.terrain.is_mountain(tile) else 0)
			for t in ctx.fields.field(tile, radius):
				seen[t] = 1
	return seen


## Effective vision of the unit's type for its owner (GDD 12 rule 11), +1 on a mountain.
static func _unit_radius(state: GameState, ctx: VisionContext, row: int, tile: int) -> int:
	var vision := ProtocolEffects.unit_stat(state.view(), state.units.faction_of(row), state.units.type_of(row),
			ProtocolEffects.VISION, ctx.catalog)
	return vision + (ctx.mountain_bonus if state.terrain.is_mountain(tile) else 0)


## Writes what faction f learns from its new view `seen` (previous view `before`):
## discovered tiles, last owner seen (rule 5, with its gain-or-loss exception when
## `refresh_all`), dormant markers (rule 17). Fills `delta` for the player only.
static func _learn(state: GameState, f: int, seen: PackedByteArray, before: PackedByteArray,
		delta: VisionDelta, refresh_all: bool) -> void:
	var tiles := state.tile_count()
	var vis := state.visibility
	var base := f * tiles
	var player := f == Faction.PLAYER
	var dormant_tiles := {}
	for row in state.units.row_count():
		if state.units.is_alive(row) and state.units.is_asleep(row):
			dormant_tiles[state.units.tile_of(row)] = true
	for t in tiles:
		var owner := state.map.owner_at(t)
		var memo := vis._vis_last_owner_seen[base + t]
		var gained_or_lost := refresh_all and ((owner == f) != (memo == f))
		if seen[t] == 0 and not gained_or_lost:
			continue
		if vis._vis_discovered[base + t] == 0:
			vis._vis_discovered[base + t] = 1
			if player:
				delta.discovered_tiles.append(t)
				delta.revealed = true
		if owner != memo:
			vis._vis_last_owner_seen[base + t] = owner
			if player and seen[t] == 1:
				delta.revealed = true
		if seen[t] == 1 and not dormant_tiles.has(t):
			vis._vis_dormant_memo[base + t] = 0
	if not player:
		return
	for row in state.units.row_count():
		var tile := state.units.tile_of(row)
		if state.units.is_alive(row) and state.units.faction_of(row) != f and seen[tile] == 1 and before[tile] == 0:
			delta.newly_seen_units.append(state.units.id_of(row))
			delta.revealed = true
