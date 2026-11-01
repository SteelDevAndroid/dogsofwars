# Write functions of the units system (GDD 1 rule 2: system 6 is the sole writer
# of the Units slice; combat and wake-up call these functions).
class_name UnitWrites
extends RefCounted


## Marks a unit destroyed; its row stays until the end-of-turn compaction and its
## id is never reused. False when the id is unknown or already destroyed.
static func destroy(state: GameState, unit_id: int) -> bool:
	var row := state.units.find_row(unit_id)
	if row < 0 or state.units._unit_alive[row] == 0:
		return false
	state.units._unit_alive[row] = 0
	return true
