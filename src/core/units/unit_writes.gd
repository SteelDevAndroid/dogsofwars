# Write functions of the units system (GDD 1 rule 2: system 6 is the sole writer
# of the Units slice; combat and wake-up call these functions).
class_name UnitWrites
extends RefCounted


## Moves a live unit to a free tile (DÉPLACER applies it step by step).
static func move_to(state: GameState, unit_id: int, tile: int) -> void:
	var row := state.units.find_row(unit_id)
	assert(row >= 0 and state.units.live_row_at(tile) < 0, "move onto an occupied tile")
	state.units._unit_tile[row] = tile


## GDD 6 rule 4: the unit has used its move this turn.
static func set_moved(state: GameState, unit_id: int) -> void:
	state.units._unit_moved[state.units.find_row(unit_id)] = 1


## Marks a unit destroyed; its row stays until the end-of-turn compaction and its
## id is never reused. False when the id is unknown or already destroyed.
static func destroy(state: GameState, unit_id: int) -> bool:
	var row := state.units.find_row(unit_id)
	if row < 0 or state.units._unit_alive[row] == 0:
		return false
	state.units._unit_alive[row] = 0
	return true
