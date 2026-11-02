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


## GDD 3 formula 2: w_d x remaining turns when the match ended by domination.
static func domination_bonus(state: GameState, weights: ScoreParams) -> int:
	return weights.w_domination() * (state.header.value(HeaderSlice.T_MAX) - state.turn())


## GDD 3 rule 14 and formula 1 in full: the decisive score plus w_f x F (ruins read by
## the faction, validated or not, GDD 3 formula 1), plus D for a domination.
static func profile_score(state: GameState, faction: int, weights: ScoreParams, dominated: bool) -> int:
	var bonus := domination_bonus(state, weights) if dominated else 0
	return decisive(state, faction, weights, bonus) + weights.w_fragments() * state.ruin_journal.read_by(faction)


## The profile effect of a match that has just ended, or null: only a domination or
## the end of turn T_MAX submits a score; an elimination or an abandon does not.
static func submission(state: GameState, weights: ScoreParams) -> SubmitScoreEffect:
	var status := state.header.value(HeaderSlice.END_STATUS)
	if status != HeaderSlice.END_DOMINATION and status != HeaderSlice.END_TURNS_WON \
			and status != HeaderSlice.END_TURNS_LOST and status != HeaderSlice.END_TURNS_DRAW:
		return null
	return SubmitScoreEffect.new(state.header.value(HeaderSlice.MATCH_ID), Faction.PLAYER,
			SubmitScoreEffect.DIFFICULTY_STANDARD, profile_score(state, Faction.PLAYER, weights, status == HeaderSlice.END_DOMINATION))


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
