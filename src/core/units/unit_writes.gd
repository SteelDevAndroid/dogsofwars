# Write functions of the units system (GDD 1 rule 2: system 6 is the sole writer
# of the Units slice; combat and wake-up call these functions).
class_name UnitWrites
extends RefCounted


## Moves a live unit to a free tile (DÉPLACER applies it step by step).
static func move_to(state: GameState, unit_id: int, tile: int) -> void:
	var row := state.units.find_row(unit_id)
	assert(row >= 0 and state.units.live_row_at(tile) < 0, "move onto an occupied tile")
	state.units._unit_tile[row] = tile


## GDD 3 rule 2: "a bougé" and "a agi" back to false for every unit of the faction.
static func start_turn(state: GameState, faction: int) -> void:
	for row in state.units.row_count():
		if state.units.faction_of(row) == faction:
			state.units._unit_moved[row] = 0
			state.units._unit_acted[row] = 0


## réveiller (GDD 6, GDD 7 rule 3 step 2): the dormant becomes the waker's faction,
## awake, having moved and acted; the waker has acted. Type, HP and tile unchanged.
static func wake(state: GameState, waker_id: int, target_id: int) -> void:
	var waker := state.units.find_row(waker_id)
	var target := state.units.find_row(target_id)
	state.units._unit_asleep[target] = 0
	state.units._unit_faction[target] = state.units._unit_faction[waker]
	state.units._unit_moved[target] = 1
	state.units._unit_acted[target] = 1
	state.units._unit_acted[waker] = 1


## GDD 6 rule 4: the unit has acted this turn (capture, attack, wake-up).
static func set_acted(state: GameState, unit_id: int) -> void:
	state.units._unit_acted[state.units.find_row(unit_id)] = 1


## GDD 6 rule 4: the unit has used its move this turn.
static func set_moved(state: GameState, unit_id: int) -> void:
	state.units._unit_moved[state.units.find_row(unit_id)] = 1


## modifier_pv (GDD 6 rule 9): `delta` < 0 damages, > 0 heals, the result is bounded
## to 0..PV_max and a unit at 0 is destroyed in the same call. Computes no damage and
## draws nothing; the unit must be a live, awake unit.
static func modify_hp(state: GameState, unit_id: int, delta: int, units: UnitTypes) -> HpChange:
	var row := state.units.find_row(unit_id)
	assert(row >= 0 and state.units.is_alive(row) and not state.units.is_asleep(row),
			"modify_hp on an unknown, destroyed or sleeping unit")
	var before := state.units.hp_of(row)
	var after := clampi(before + delta, 0, units.hp(state.units.type_of(row)))
	if after != before:
		state.units._unit_hp[row] = after
	if after == 0:
		destroy(state, unit_id)
	return HpChange.new(before, after)


## Marks a unit destroyed; its row stays until the end-of-turn compaction and its
## id is never reused. False when the id is unknown or already destroyed.
static func destroy(state: GameState, unit_id: int) -> bool:
	var row := state.units.find_row(unit_id)
	if row < 0 or state.units._unit_alive[row] == 0:
		return false
	state.units._unit_alive[row] = 0
	RecallWrites.unit_lost(state, state.units.tile_of(row), state.units.faction_of(row))
	return true
