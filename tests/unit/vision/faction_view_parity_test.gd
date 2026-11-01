# Parity of FactionView(real state, f) and filtered_copy(f).view() (ADR-0004 §3,
# ADR-0007 §5): every query, every tile, every id (unknown ones included), terrain
# included. A new faction query must be added here.
extends GdUnitTestSuite

const SEED := 31415
const STATES := 1000
## Ids probed beyond the allocated ones, to compare the answers on unknown ids.
const EXTRA_IDS := 2


func test_faction_view_answers_like_the_filtered_copy() -> void:
	var states := StateFactory.random_states(STATES, SEED)
	for k in states.size():
		var state := states[k]
		for f in StateFactory.FACTIONS:
			var divergence := _first_divergence(FactionView.new(state, f), state.filtered_copy(f).view(), state)
			assert_str(divergence).override_failure_message(
				"seed %d, state %d, faction %d: %s" % [SEED, k, f, divergence]).is_empty()


func test_parity_detects_a_divergent_view() -> void:
	var state := StateFactory.minimal()

	var divergence := _first_divergence(state.view(), state.filtered_copy(Faction.PLAYER).view(), state)

	assert_str(divergence).is_not_empty()


func _first_divergence(view: StateView, copy_view: StateView, state: GameState) -> String:
	for query in [&"width", &"height", &"tile_count", &"faction_count", &"turn", &"phase", &"max_turn", &"active_faction",
			&"revision", &"unit_ids", &"node_ids", &"ruin_ids"]:
		if view.call(query) != copy_view.call(query):
			return "%s: %s != %s" % [query, view.call(query), copy_view.call(query)]
	for tile in state.tile_count():
		for query in [&"terrain_at", &"tile_owner", &"tile_anchor", &"unit_at", &"node_at"]:
			if view.call(query, tile) != copy_view.call(query, tile):
				return "%s(%d): %s != %s" % [query, tile, view.call(query, tile), copy_view.call(query, tile)]
	for f in state.faction_count():
		for query in [&"energy", &"research"]:
			if view.call(query, f) != copy_view.call(query, f):
				return "%s(%d): %s != %s" % [query, f, view.call(query, f), copy_view.call(query, f)]
		for protocol in CatalogFactory.standard().protocols.count():
			if view.has_protocol(f, protocol) != copy_view.has_protocol(f, protocol):
				return "has_protocol(%d, %d)" % [f, protocol]
	var families := [
		[HeaderSlice.NEXT_UNIT_ID, [&"unit_tile", &"unit_faction", &"unit_hp", &"unit_type", &"unit_moved", &"unit_acted", &"unit_asleep"]],
		[HeaderSlice.NEXT_NODE_ID, [&"node_tile", &"node_owner", &"node_level"]],
		[HeaderSlice.NEXT_RUIN_ID, [&"ruin_tile"]],
	]
	for family: Array in families:
		for id in state.header.value(family[0]) + EXTRA_IDS:
			for query: StringName in family[1]:
				if view.call(query, id) != copy_view.call(query, id):
					return "%s(%d): %s != %s" % [query, id, view.call(query, id), copy_view.call(query, id)]
	return ""
