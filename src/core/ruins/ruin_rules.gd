# Ruin reading (GDD 13 rules 7 to 17), owned by the ruins system. Called by the
# application of DÉPLACER when the player's unit ends its move on an unread ruin.
class_name RuinRules
extends RefCounted


## GDD 13 rule 17: the smallest pool id of the faction found neither in the chronicle
## snapshot of the match nor in its journal; 0 when the pool is exhausted. The state
## alone decides: no rule reads the profile.
static func next_fragment(state: GameState, faction: int, pool: FragmentPool) -> int:
	for fragment_id in pool.ids_of(faction):
		if not state.chronicle.has(faction, fragment_id) and not state.ruin_journal.has_fragment(faction, fragment_id):
			return fragment_id
	return 0


## The sequence of rule 14, in the same command: marking, next fragment, journal entry,
## zone recoloured, then the event and the profile effect, rendered as values. Only a
## unit of the player reads (a dormant never moves), on the tile where it ends its move (rules 7, 9, 11).
static func read_on_arrival(state: GameState, unit_id: int, rules: RuleTable, result: ApplyResult) -> void:
	var view := state.view()
	if view.unit_faction(unit_id) != Faction.PLAYER:
		return
	var tile := view.unit_tile(unit_id)
	var row := state.ruins.row_at_tile(tile)
	if row < 0 or state.ruins.is_read(row):
		return
	var ruin_id := state.ruins.id_of(row)
	var fragment_id := next_fragment(state, Faction.PLAYER, rules.catalog.fragments)
	RuinWrites.mark_read(state, row, Faction.PLAYER)
	RuinWrites.journal_add(state, ruin_id, Faction.PLAYER, fragment_id)
	var changed := TerritoryRules.recolor_zone(state, Faction.PLAYER, _zone_tiles(state, tile, rules.catalog.fragments.zone_radius()), MapSlice.CAUSE_RUIN)
	result.ruin_read = true
	result.events.append(RuinReadEvent.new(Faction.PLAYER, ruin_id, fragment_id, tile))
	if not changed.is_empty():
		result.events.append(TileOwnersChangedEvent.new(changed, Faction.NONE, Faction.PLAYER))
	if fragment_id > 0:
		result.profile_effects.append(RecordFragmentEffect.new(Faction.PLAYER, fragment_id, ruin_id))


## Square of the given radius around the ruin, clipped by the map edges (rule 4).
static func _zone_tiles(state: GameState, center: int, radius: int) -> PackedInt32Array:
	var width := state.view().width()
	var tiles := PackedInt32Array()
	for y in range(maxi(0, center / width - radius), mini(state.view().height(), center / width + radius + 1)):
		for x in range(maxi(0, center % width - radius), mini(width, center % width + radius + 1)):
			tiles.append(y * width + x)
	return tiles
