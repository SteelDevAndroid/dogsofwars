# Write functions of the presentation recalls (GDD 1, HUD rule 22): what the player
# lost during the last enemy phase. No game effect: nothing but the HUD reads them.
# Units lost (tile, side) are written by the units system, tiles lost by the nodes
# system; both only during the enemy phase. The slice is emptied when the next enemy
# phase begins and at the end of the player's following turn.
class_name RecallWrites
extends RefCounted


static func unit_lost(state: GameState, tile: int, side: int) -> void:
	if state.header.value(HeaderSlice.PHASE) != HeaderSlice.PHASE_ENEMY_EXECUTION:
		return
	state.recalls._recall_unit_tile.append(tile)
	state.recalls._recall_unit_side.append(side)


static func tile_lost(state: GameState, tile: int) -> void:
	if state.header.value(HeaderSlice.PHASE) != HeaderSlice.PHASE_ENEMY_EXECUTION:
		return
	if not state.recalls._recall_lost_tile.has(tile):
		state.recalls._recall_lost_tile.append(tile)


static func clear(state: GameState) -> void:
	state.recalls.clear()
