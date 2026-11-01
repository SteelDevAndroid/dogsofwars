# Game states for tests (ADR-0011 §4): named minimal states, and seeded random
# states drawn with GameState.hash32 (never randi()), built only through the setup
# and the owners' write functions, then VisionService.setup (rule 22 of GDD 5): the
# Visibility slice is filled and the view cache valid. Intentions, AI data and
# journals stay empty until their systems exist.
class_name StateFactory
extends RefCounted

const MINIMAL_SIZE := 8
const FACTIONS := 2
const UNIT_TYPES := 3
const FULL_HP := 10
const MAX_NODE_LEVEL := 3
const RUIN_COUNT := 3
const FRAGMENT_POOL := 12
const TERRAIN_CODES := 4
## One live unit in DESTROY_ONE_IN is destroyed, to leave dead rows.
const DESTROY_ONE_IN := 5
const EXTRA_DRAWS := 8


## Vision context of `state` over the standard test catalog (types 0..2: Éclaireur
## view 4, Assaut 2, Rempart 2).
static func vision_context(state: GameState) -> VisionContext:
	return VisionContext.for_map(CatalogFactory.standard(), state)


## 8 x 8 plains, two factions, one player unit at (1, 1), one AI unit at (6, 6).
static func minimal(seed_value: int = 1) -> GameState:
	var state := _plains(MINIMAL_SIZE, MINIMAL_SIZE, seed_value)
	GameStateSetup.add_unit(state, 0, Faction.PLAYER, state.tile_index(1, 1), FULL_HP)
	GameStateSetup.add_unit(state, 0, Faction.AI, state.tile_index(MINIMAL_SIZE - 2, MINIMAL_SIZE - 2), FULL_HP)
	VisionService.setup(state, vision_context(state))
	return state


## 8 x 8 plains with `per_faction` units each: the player on the first rows, the
## AI on the last ones.
static func with_units(per_faction: int, seed_value: int = 1) -> GameState:
	assert(per_faction <= MINIMAL_SIZE * MINIMAL_SIZE / FACTIONS, "more units than tiles")
	var state := _plains(MINIMAL_SIZE, MINIMAL_SIZE, seed_value)
	for k in per_faction:
		GameStateSetup.add_unit(state, 0, Faction.PLAYER, k, FULL_HP)
	for k in per_faction:
		GameStateSetup.add_unit(state, 0, Faction.AI, state.tile_count() - 1 - k, FULL_HP)
	VisionService.setup(state, vision_context(state))
	return state


## `count` states, the same for the same seed (print the seed when a property fails).
static func random_states(count: int, seed_value: int) -> Array[GameState]:
	var dice := _Dice.new(seed_value)
	var states: Array[GameState] = []
	for k in count:
		states.append(_random_state(dice))
	return states


static func _plains(map_width: int, map_height: int, seed_value: int) -> GameState:
	var cells := PackedByteArray()
	cells.resize(map_width * map_height)
	cells.fill(TerrainGrid.PLAIN)
	return GameStateSetup.create(map_width, map_height, FACTIONS, seed_value, cells)


static func _random_state(dice: _Dice) -> GameState:
	var map_width := MINIMAL_SIZE + dice.roll(GameState.MAX_MAP_SIZE - MINIMAL_SIZE + 1)
	var map_height := MINIMAL_SIZE + dice.roll(GameState.MAX_MAP_SIZE - MINIMAL_SIZE + 1)
	var cells := PackedByteArray()
	for tile in map_width * map_height:
		cells.append(dice.roll(TERRAIN_CODES))
	var state := GameStateSetup.create(map_width, map_height, FACTIONS, dice.raw(), cells, dice.raw())
	for tile in state.tile_count():
		GameStateSetup.set_tile_owner(state, tile, _owner_or_none(dice))
	var free := PackedInt32Array(range(state.tile_count()))
	for k in dice.roll(GameState.MAX_NODES + 1):
		GameStateSetup.add_node(state, _take(free, dice), _owner_or_none(dice), 1 + dice.roll(MAX_NODE_LEVEL))
	for zone in RUIN_COUNT:
		GameStateSetup.add_ruin(state, _take(free, dice), zone, dice.roll(FACTIONS))
	for k in dice.roll(mini(GameState.MAX_UNITS, free.size()) + 1):
		GameStateSetup.add_unit(state, dice.roll(UNIT_TYPES), dice.roll(FACTIONS), _take(free, dice),
				1 + dice.roll(FULL_HP), dice.roll(2) == 1)
	for unit_id in state.view().unit_ids():
		if dice.roll(DESTROY_ONE_IN) == 0:
			UnitWrites.destroy(state, unit_id)
	for faction in FACTIONS:
		for fragment in FRAGMENT_POOL:
			if dice.roll(2) == 1:
				GameStateSetup.add_chronicle_fragment(state, faction, fragment)
	GameStateSetup.set_turn(state, dice.roll(GameState.MAX_TURN + 1))
	for k in dice.roll(EXTRA_DRAWS):
		state.draw(GameState.DRAW_MAX)
	VisionService.setup(state, vision_context(state))
	return state


static func _owner_or_none(dice: _Dice) -> int:
	var pick := dice.roll(FACTIONS + 1)
	return Faction.NONE if pick == FACTIONS else pick


static func _take(free: PackedInt32Array, dice: _Dice) -> int:
	var k := dice.roll(free.size())
	var tile := free[k]
	free.remove_at(k)
	return tile


class _Dice:
	var _seed: int
	var _counter := 0

	func _init(seed_value: int) -> void:
		_seed = seed_value & 0xFFFFFFFF

	func raw() -> int:
		_counter += 1
		return GameState.hash32(_seed, _counter - 1)

	func roll(n: int) -> int:
		return raw() % n
