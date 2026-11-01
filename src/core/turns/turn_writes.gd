# Write functions of the turn system (system 3) on the header: turn, phase,
# active faction.
class_name TurnWrites
extends RefCounted


## The phase of `faction` begins; the turn number moves on when the player begins.
static func begin_phase(state: GameState, faction: int, phase: int, next_turn: bool) -> void:
	if next_turn:
		state.header._header[HeaderSlice.TURN] = state.turn() + 1
	state.header._header[HeaderSlice.PHASE] = phase
	state.header._header[HeaderSlice.ACTIVE_FACTION] = faction


static func end_phase(state: GameState) -> void:
	state.header._header[HeaderSlice.PHASE] = HeaderSlice.PHASE_END_OF_TURN
