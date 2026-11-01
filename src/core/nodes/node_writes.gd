# Write functions of the nodes system (system 11) on the Nodes slice.
class_name NodeWrites
extends RefCounted


## GDD 11 rules 5 and 6: new owner since this turn, upgrade counter reset, level
## down one step (minimum 1).
static func capture(state: GameState, node_id: int, faction: int) -> void:
	var row := state.nodes.find_row(node_id)
	state.nodes._node_owner[row] = faction
	state.nodes._node_since_turn[row] = state.turn()
	state.nodes._node_upgraded_turn[row] = -1
	state.nodes._node_level[row] = maxi(1, state.nodes._node_level[row] - 1)
