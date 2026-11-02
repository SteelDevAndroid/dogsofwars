# Small hand-made maps for rule tests: an ASCII grid, one character per tile.
# "." plain, "f" forest, "^" mountain, "~" water.
class_name MapBuilder
extends RefCounted

const CODES := {".": TerrainGrid.PLAIN, "f": TerrainGrid.FOREST, "^": TerrainGrid.MOUNTAIN, "~": TerrainGrid.WATER}


## A two-faction state over `rows` (all of the same length), seed 1.
static func state(rows: PackedStringArray) -> GameState:
	var cells := PackedByteArray()
	for row in rows:
		for ch in row:
			cells.append(CODES[ch])
	return GameStateSetup.create(rows[0].length(), rows.size(), StateFactory.FACTIONS, 1, cells)


## Adds a unit at (x, y) and returns its id; `hp` -1 means full HP.
static func unit(at_state: GameState, type: int, faction: int, x: int, y: int, asleep: bool = false,
		hp: int = -1) -> int:
	return GameStateSetup.add_unit(at_state, type, faction, at_state.tile_index(x, y),
			hp if hp >= 0 else CatalogFactory.standard().units.hp(type), asleep)


## The same state with the factions' energy stocks replaced (the view is rebuilt).
static func with_energy(at_state: GameState, player: int, ai: int) -> GameState:
	var loaded := StatePayload.decoded_with(at_state, &"_fac_energy", PackedInt32Array([player, ai]))
	VisionService.rebuild(loaded, StateFactory.vision_context(loaded))
	return loaded


## Vision set up: call after the units and nodes are placed.
static func ready(at_state: GameState) -> GameState:
	VisionService.setup(at_state, StateFactory.vision_context(at_state))
	return at_state
