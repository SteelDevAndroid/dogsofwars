# Tracks of the AI (GDD 9 rule 9), owned by the AI system. At the start of its turn the
# AI updates its tracks from what its view shows: a player unit seen now is recorded
# (tile, turn, type); a track whose unit is not seen is dropped when its tile is
# visible (and so empty) or when it is older than PISTES_TTL turns; at most MAX_TRACKS
# are kept, the oldest sighting dropped first (lowest unit id on a tie). Rows stay
# sorted by unit id. A track feeds moves and exposure, never an attack target.
class_name PerceptionRules
extends RefCounted


static func update(state: GameState, params: AiParams) -> void:
	var cache := state.view_cache
	var by_unit := {}
	var tracks := state.ai_tracks
	for row in tracks.row_count():
		by_unit[tracks.unit_of(row)] = [tracks.unit_of(row), tracks.tile_of(row), tracks.seen_turn_of(row), tracks.kind_of(row)]
	for unit_id in by_unit.keys():
		var track: Array = by_unit[unit_id]
		if state.turn() - track[2] > params.track_ttl() or VisionService.can_see(cache, Faction.AI, track[1]):
			by_unit.erase(unit_id)
	var view := state.view()
	for unit_id in view.unit_ids():
		if view.unit_faction(unit_id) == Faction.PLAYER and not view.unit_asleep(unit_id) \
				and VisionService.can_see(cache, Faction.AI, view.unit_tile(unit_id)):
			by_unit[unit_id] = [unit_id, view.unit_tile(unit_id), state.turn(), view.unit_type(unit_id)]
	var rows: Array = by_unit.values()
	rows.sort_custom(func(a: Array, b: Array) -> bool: return a[0] < b[0])
	while rows.size() > GameState.MAX_TRACKS:
		var oldest := 0
		for k in rows.size():
			if rows[k][2] < rows[oldest][2]:
				oldest = k
		rows.remove_at(oldest)
	AiWrites.set_tracks(state, rows)
