# Match state (GDD 1, ADR-0003): pure data in typed-array columns grouped in slices.
# No rule lives here; systems write their slices through their own functions.
# Copy, equality, serialization and validation derive from the slice column tables.
class_name GameState
extends RefCounted

## Content schema of to_bytes; carried by the save envelope only (ADR-0006).
## 2: nodes gain since_turn and upgraded_turn (GDD 11 rule 1), 2026-11-01.
## 3: the AI cursor slice gains the turn of the last announcement, 2026-11-02.
## 4: units gain the ability cooldown, the ability effect flag and the ambush flag, 2026-11-05.
const SCHEMA_VERSION := 4

const MAX_MAP_SIZE := 16
const MAX_UNITS := 60
const MAX_NODES := 10
const MAX_INTENTIONS := 120
## GDD 1 formula 4: the intentions of the current turn and of the previous one are kept.
const INTENT_RETENTION_TURNS := 2
const MAX_TRACKS := 16
const MAX_TURN := 30
const DRAW_MAX := 65536
const ID_MAX := 2147483647

const _MASK32 := 0xFFFFFFFF

var header := HeaderSlice.new()
var map := MapSlice.new()
var visibility := VisibilitySlice.new()
var units := UnitsSlice.new()
var nodes := NodesSlice.new()
var ruins := RuinsSlice.new()
var chronicle := ChronicleSlice.new()
var factions := FactionsSlice.new()
var protocols := ProtocolsSlice.new()
var intentions := IntentionsSlice.new()
var siege := SiegeSlice.new()
var ai_agents := AiAgentsSlice.new()
var ai_cursor := AiCursorSlice.new()
var ai_tracks := AiTracksSlice.new()
var recalls := RecallsSlice.new()
var score := ScoreSlice.new()
var ruin_journal := RuinJournalSlice.new()
var command_log := CommandLogSlice.new()

## Shared, read-only, never copied between real states.
var terrain := TerrainGrid.new(PackedByteArray())
## Transient (ADR-0007): copied with the state, ignored by to_bytes and equals.
var view_cache := ViewCache.new()


## The declarative table: fixed order for copy, equality and serialization.
func slices() -> Array[SliceBase]:
	return [
		header, map, visibility, units, nodes, ruins, chronicle, factions, protocols,
		intentions, siege, ai_agents, ai_cursor, ai_tracks, recalls, score, ruin_journal,
		command_log,
	]


func width() -> int:
	return header.value(HeaderSlice.WIDTH)


func height() -> int:
	return header.value(HeaderSlice.HEIGHT)


func tile_count() -> int:
	return width() * height()


func faction_count() -> int:
	return header.value(HeaderSlice.FACTION_COUNT)


func turn() -> int:
	return header.value(HeaderSlice.TURN)


func revision() -> int:
	return command_log.revision()


## GDD 1 formula 1; -1 outside the map (coordinates are refused, never clamped).
func tile_index(x: int, y: int) -> int:
	if x < 0 or y < 0 or x >= width() or y >= height():
		return -1
	return y * width() + x


## Full copy without shared mutable data; the terrain is shared, read-only.
func duplicate_state() -> GameState:
	var copy := GameState.new()
	var mine := slices()
	var theirs := copy.slices()
	for k in mine.size():
		theirs[k].copy_from(mine[k])
	copy.terrain = terrain
	copy.view_cache = view_cache.duplicate()
	return copy


## Deep equality (GDD 1 rule 13), view cache excluded.
func equals(other: GameState) -> bool:
	if not terrain.equals(other.terrain):
		return false
	var mine := slices()
	var theirs := other.slices()
	for k in mine.size():
		if not mine[k].equals(theirs[k]):
			return false
	return true


## Payload only, deterministic for two equal states with the same layout; the
## envelope and the integrity hash belong to the save (ADR-0006).
func to_bytes() -> PackedByteArray:
	var payload := [terrain.to_bytes()]
	for slice in slices():
		payload.append_array(slice.values())
	return var_to_bytes(payload)


## Decodes a payload whose integrity the envelope already checked. Refuses (null)
## another schema, a wrong structure, a wrong column type or length, unsorted ids.
## The view cache comes back invalid: the load step 5 rebuilds it (ADR-0007 §2).
static func from_bytes(bytes: PackedByteArray, content_schema: int) -> GameState:
	if content_schema != SCHEMA_VERSION:
		return null
	var data: Variant = bytes_to_var(bytes)
	if typeof(data) != TYPE_ARRAY:
		return null
	var state := GameState.new()
	var list := state.slices()
	var expected := 1
	for slice in list:
		expected += slice.columns().size()
	if data.size() != expected or typeof(data[0]) != TYPE_PACKED_BYTE_ARRAY:
		return null
	var offset := 1
	for slice in list:
		if not slice.load_values(data, offset):
			return null
		offset += slice.columns().size()
	state.terrain = TerrainGrid.new(data[0])
	if not state.structure_errors().is_empty():
		return null
	state.view_cache = ViewCache.new(state.faction_count(), state.tile_count())
	return state


## Back to an undo snapshot, keeping the command journal: the revision never goes
## back (GDD 23 rules 14 and 15). The snapshot's view cache comes with it.
func restore_from(snapshot: GameState) -> void:
	var mine := slices()
	var theirs := snapshot.slices()
	for k in mine.size():
		if mine[k] != command_log:
			mine[k].copy_from(theirs[k])
	terrain = snapshot.terrain
	view_cache = snapshot.view_cache.duplicate()


## The state rebuilt from the view of `faction` (GDD 1 rule 11, ADR-0007 §5), base of
## every AI simulation and of the player's previews. Every visibility decision goes
## through VisionService; the view cache must be valid.
## - units: own units and units on VISIBLE tiles only (no hidden unit, AC-IA14);
## - nodes: on discovered tiles only; out of view, last owner seen and no level;
## - ruins: kept for the player (drawn ruins are marked from turn 1, GDD 5 rule 15),
##   absent for the AI (ADR-0005 §6);
## - tiles out of view: last owner seen, no change history; undiscovered tiles:
##   no point of interest, and a terrain of its own where they are plains; the
##   anchor (why a tile is owned) only in view;
## - other factions: their Visibility rows and view-cache rows at zero, their energy
##   and research hidden, their chronicle and journal rows absent;
## - slices private to another faction emptied; authors of intentions out of view
##   lose their tile (GDD 5 rule 21).
func filtered_copy(faction: int) -> GameState:
	assert(view_cache.valid, "filtered_copy needs a rebuilt view cache")
	var copy := duplicate_state()
	var tiles := tile_count()
	var cache := view_cache

	var kept_units := PackedInt32Array()
	for row in units.row_count():
		if VisionService.can_see_unit(self, cache, faction, units.id_of(row)):
			kept_units.append(row)
	copy.units.keep_rows(kept_units)
	for row in copy.units.row_count():
		if copy.units.faction_of(row) != faction:  # another faction's cooldown and ambush stay its own
			copy.units._unit_cooldown[row] = 0
			copy.units._unit_ambush[row] = 0

	var kept_nodes := PackedInt32Array()
	for row in nodes.row_count():
		var node_id := nodes.id_of(row)
		if VisionService.knows_node(self, faction, node_id):
			kept_nodes.append(row)
			copy.nodes._node_owner[row] = VisionService.known_node_owner(self, faction, node_id)
			copy.nodes._node_level[row] = VisionService.known_node_level(self, faction, node_id)
			copy.nodes._node_since_turn[row] = VisionService.known_node_since_turn(self, faction, node_id)
			copy.nodes._node_upgraded_turn[row] = VisionService.known_node_upgraded_turn(self, faction, node_id)
	copy.nodes.keep_rows(kept_nodes)

	if not VisionService.knows_ruins(faction):
		copy.ruins.clear()

	var cells := PackedByteArray()
	for tile in tiles:
		cells.append(VisionService.known_terrain(self, faction, tile))
		copy.map._tile_owner[tile] = VisionService.known_tile_owner(self, faction, tile)
		copy.map._tile_anchor[tile] = VisionService.known_anchor(self, faction, tile)
		if not VisionService.can_see(cache, faction, tile):
			copy.map._tile_change_turn[tile] = -1
			copy.map._tile_prev_owner[tile] = Faction.NONE
			copy.map._tile_change_cause[tile] = MapSlice.CAUSE_NONE
		if VisionService.tile_state(self, faction, tile) == VisionService.UNKNOWN:
			copy.map._tile_poi[tile] = 0
	copy.terrain = TerrainGrid.new(cells)

	for f in faction_count():
		if f == faction:
			continue
		for tile in tiles:
			copy.visibility._vis_discovered[f * tiles + tile] = 0
			copy.visibility._vis_last_owner_seen[f * tiles + tile] = Faction.NONE
			copy.visibility._vis_dormant_memo[f * tiles + tile] = 0
		var unseen := PackedByteArray()
		unseen.resize(tiles)
		copy.view_cache.seen[f] = unseen
		copy.factions._fac_energy[f] = 0
		copy.factions._fac_research_id[f] = -1
		copy.factions._fac_research_turns[f] = 0

	copy.chronicle.keep_rows(_rows_of_faction(chronicle, faction))
	copy.ruin_journal.keep_rows(_rows_of_faction(ruin_journal, faction))
	for slice in copy.slices():
		if slice.private_to() >= 0 and slice.private_to() != faction:
			slice.clear()
	if faction != Faction.AI:
		for row in intentions.row_count():
			if not VisionService.can_see(cache, faction, intentions.author_tile_of(row)):
				copy.intentions._int_author_tile[row] = -1
	return copy


## Rows of a slice with a faction_of(row) reader (chronicle, ruin journal).
static func _rows_of_faction(slice: Variant, faction: int) -> PackedInt32Array:
	var rows := PackedInt32Array()
	for row in slice.row_count():
		if slice.faction_of(row) == faction:
			rows.append(row)
	return rows


## End-of-turn compaction (GDD 1 rule 12): dead rows dropped, id order kept.
func compact() -> void:
	for slice in slices():
		slice.compact()


func view() -> StateView:
	return StateView.new(self)


## The only random source (GDD 1 rule 7): 0..n-1, then the counter moves on.
## -1 and no counter change for n outside 1..DRAW_MAX or an exhausted counter.
func draw(n: int) -> int:
	var counter := header.value(HeaderSlice.DRAW_COUNTER)
	if n < 1 or n > DRAW_MAX or counter >= ID_MAX:
		return -1
	header._header[HeaderSlice.DRAW_COUNTER] = counter + 1
	return hash32(header.value(HeaderSlice.SEED), counter) % n


## GDD 1 formula 3: next id of a family (a HeaderSlice.NEXT_*_ID index), -1 at ID_MAX.
func allocate_id(family: int) -> int:
	var id := header.value(family)
	if id >= ID_MAX:
		return -1
	header._header[family] = id + 1
	return id


## SplitMix32, canonical form of ADR-0003: masked before every shift (GDScript
## integers are 64-bit two's complement), no fixed point at (0, 0).
static func hash32(seed_value: int, counter: int) -> int:
	var z := (seed_value + (counter + 1) * 0x9E3779B9) & _MASK32
	z = ((z ^ (z >> 16)) * 0x85EBCA6B) & _MASK32
	z = ((z ^ (z >> 13)) * 0xC2B2AE35) & _MASK32
	return (z ^ (z >> 16)) & _MASK32


## Shape checks run by from_bytes: sizes, column lengths, sorted ids.
func structure_errors() -> PackedStringArray:
	var errors := PackedStringArray()
	if width() < 1 or width() > MAX_MAP_SIZE or height() < 1 or height() > MAX_MAP_SIZE:
		errors.append("map size %d x %d outside 1..%d" % [width(), height(), MAX_MAP_SIZE])
		return errors
	if faction_count() < 1 or faction_count() >= Faction.NONE:
		errors.append("faction count %d" % faction_count())
		return errors
	if terrain.size() != tile_count():
		errors.append("terrain: size %d, expected %d" % [terrain.size(), tile_count()])
	for slice in slices():
		var error := slice.length_error(tile_count(), faction_count())
		if not error.is_empty():
			errors.append(error)
	if not errors.is_empty():
		return errors
	for pair: Array in [
		[units, HeaderSlice.NEXT_UNIT_ID], [nodes, HeaderSlice.NEXT_NODE_ID],
		[ruins, HeaderSlice.NEXT_RUIN_ID], [intentions, HeaderSlice.NEXT_INTENTION_ID],
		[ai_agents, HeaderSlice.NEXT_UNIT_ID],
	]:
		var error: String = pair[0].id_error(header.value(pair[1]))
		if not error.is_empty():
			errors.append(error)
	return errors


## Invariants of GDD 1 (rule 14), checked in tests and at every load.
func validate() -> PackedStringArray:
	var errors := structure_errors()
	if not errors.is_empty():
		return errors
	var tiles := tile_count()
	var nf := faction_count()
	if turn() < 0 or turn() > header.value(HeaderSlice.T_MAX):
		errors.append("turn %d outside 0..%d" % [turn(), header.value(HeaderSlice.T_MAX)])
	if header.value(HeaderSlice.ACTIVE_FACTION) >= nf:
		errors.append("active faction %d" % header.value(HeaderSlice.ACTIVE_FACTION))
	for tile in tiles:
		if map.owner_at(tile) >= nf and map.owner_at(tile) != Faction.NONE:
			errors.append("tile %d: owner %d" % [tile, map.owner_at(tile)])
	var occupied := {}
	for row in units.row_count():
		if not units.is_alive(row):
			continue
		var tile := units.tile_of(row)
		if tile < 0 or tile >= tiles:
			errors.append("unit %d: tile %d off the map" % [units.id_of(row), tile])
		elif occupied.has(tile):
			errors.append("units %d and %d share tile %d" % [occupied[tile], units.id_of(row), tile])
		else:
			occupied[tile] = units.id_of(row)
		# A dormant is neutral until woken (GDD 6 rule 3).
		var neutral_dormant := units.is_asleep(row) and units.faction_of(row) == Faction.NONE
		if units.faction_of(row) >= nf and not neutral_dormant:
			errors.append("unit %d: faction %d" % [units.id_of(row), units.faction_of(row)])
	for row in nodes.row_count():
		if nodes.tile_of(row) < 0 or nodes.tile_of(row) >= tiles:
			errors.append("node row %d: tile %d off the map" % [row, nodes.tile_of(row)])
		if nodes.owner_of(row) >= nf and nodes.owner_of(row) != Faction.NONE:
			errors.append("node row %d: owner %d" % [row, nodes.owner_of(row)])
		# GDD 11 rule 17: the tile of a node has the node's owner.
		elif nodes.tile_of(row) >= 0 and nodes.tile_of(row) < tiles \
				and map.owner_at(nodes.tile_of(row)) != nodes.owner_of(row):
			errors.append("node row %d: owner %d but its tile belongs to %d" % [row, nodes.owner_of(row), map.owner_at(nodes.tile_of(row))])
	for row in ruins.row_count():
		if ruins.tile_of(row) < 0 or ruins.tile_of(row) >= tiles:
			errors.append("ruin row %d: tile %d off the map" % [row, ruins.tile_of(row)])
	for row in intentions.row_count():
		for tile in [intentions.author_tile_of(row), intentions.target_tile_of(row)]:
			if tile < 0 or tile >= tiles:
				errors.append("intention row %d: tile %d off the map" % [row, tile])
	for bound: Array in [
		[units, MAX_UNITS, "units"], [nodes, MAX_NODES, "nodes"],
		[intentions, MAX_INTENTIONS, "intentions"], [ai_tracks, MAX_TRACKS, "tracks"],
	]:
		if bound[0].row_count() > bound[1]:
			errors.append("%s: %d rows, at most %d" % [bound[2], bound[0].row_count(), bound[1]])
	return errors
