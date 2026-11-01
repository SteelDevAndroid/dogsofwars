# Write functions of the combat system (system 8) on the score counters.
class_name CombatWrites
extends RefCounted


## GDD 8 rule 9: +1 destroyed unit for the faction whose strike destroyed it. An
## elimination's destructions do not count (they do not go through the combat).
static func count_destroyed(state: GameState, faction: int) -> void:
	state.score._score_units_destroyed[faction] += 1
