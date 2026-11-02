# What the player may see of the AI's announced intentions (GDD 9 rule 18, GDD 5): a marker
# on the target tile of every announced intention whose target tile is visible, and on the
# target node even when it is not visible; the author's tile only when the author's tile is
# visible. The rest of the AI's data stays hidden. The only place that reads the AI's
# private slice on the player's behalf, and it publishes values, never rows.
class_name IntentionMarkers
extends RefCounted


## Rows [intention id, target kind, target tile, author tile or -1, motive], by id.
static func visible_to_player(state: GameState) -> Array:
	var markers := []
	var slice := state.intentions
	for row in slice.row_count():
		if slice.status_of(row) != IntentionsSlice.STATUS_ANNOUNCED:
			continue
		var target_tile := slice.target_tile_of(row)
		var is_node := slice.target_kind_of(row) == IntentionsSlice.TARGET_NODE
		if not is_node and VisionService.fog_level(state, Faction.PLAYER, target_tile) != VisionService.FOG_VISIBLE:
			continue
		var author_tile := slice.author_tile_of(row)
		if VisionService.fog_level(state, Faction.PLAYER, author_tile) != VisionService.FOG_VISIBLE:
			author_tile = -1
		markers.append([slice.id_of(row), slice.target_kind_of(row), target_tile, author_tile, slice.motive_of(row)])
	return markers
