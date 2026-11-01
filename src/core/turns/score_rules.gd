# Scores (GDD 3 rules 9 and 13, formula 1), owned by the turn system: computed from
# the state, never stored. The decisive score is formula 1 with F = 0 and, at the
# MVP, w_p = 0; the domination bonus D only counts for a match ended by domination.
# A public aggregate on hidden data: the one exception to the fog (GDD 5 rule 24bis).
class_name ScoreRules
extends RefCounted


static func decisive(state: GameState, faction: int, weights: ScoreParams, domination_bonus: int = 0) -> int:
	var tiles := 0
	for tile in state.tile_count():
		if state.map.owner_at(tile) == faction:
			tiles += 1
	var nodes := 0
	var levels := 0
	for row in state.nodes.row_count():
		if state.nodes.owner_of(row) == faction:
			nodes += 1
			levels += state.nodes.level_of(row)
	var protocols := 0
	for row in state.protocols.row_count():
		if state.protocols.faction_of(row) == faction:
			protocols += 1
	var units := 0
	for row in state.units.live_rows():
		if state.units.faction_of(row) == faction:
			units += 1
	return weights.w_tiles() * tiles + weights.w_nodes() * nodes + weights.w_levels() * levels \
		+ weights.w_protocols() * protocols + weights.w_units() * mini(units, weights.unit_cap()) + domination_bonus


## End status of a match that reaches the end of turn T_MAX (GDD 3 rule 9): the
## higher decisive score wins, a tie is a draw; from the player's side.
static func turn_limit_status(state: GameState, weights: ScoreParams) -> int:
	var player := decisive(state, Faction.PLAYER, weights)
	var ai := decisive(state, Faction.AI, weights)
	if player > ai:
		return HeaderSlice.END_TURNS_WON
	if player < ai:
		return HeaderSlice.END_TURNS_LOST
	return HeaderSlice.END_TURNS_DRAW
