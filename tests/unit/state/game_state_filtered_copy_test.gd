extends GdUnitTestSuite

const SEED := 1789
const STATES := 60


func test_filtered_copy_holds_no_hidden_unit() -> void:
	for state in StateFactory.random_states(STATES, SEED):
		for f in StateFactory.FACTIONS:
			var copy := state.filtered_copy(f)
			for unit_id in copy.view().unit_ids():
				var seen := copy.view().unit_faction(unit_id) == f \
					or VisionService.can_see(state.view_cache, f, copy.view().unit_tile(unit_id))
				assert_bool(seen).override_failure_message("seed %d, faction %d, unit %d" % [SEED, f, unit_id]).is_true()
			for unit_id in state.view().unit_ids():
				if VisionService.can_see_unit(state, state.view_cache, f, unit_id):
					assert_int(copy.view().unit_tile(unit_id)).is_equal(state.view().unit_tile(unit_id))


func test_undiscovered_tiles_are_plains_without_owner_nor_anchor() -> void:
	for state in StateFactory.random_states(STATES, SEED):
		for f in StateFactory.FACTIONS:
			var copy := state.filtered_copy(f)
			for tile in state.tile_count():
				if VisionService.tile_state(state, f, tile) == VisionService.UNKNOWN:
					assert_int(copy.terrain.at(tile)).is_equal(TerrainGrid.PLAIN)
					assert_int(copy.map.owner_at(tile)).is_equal(Faction.NONE)
					assert_int(copy.map.anchor_at(tile)).is_equal(MapSlice.ANCHOR_NONE)
				elif VisionService.tile_state(state, f, tile) == VisionService.VISIBLE:
					assert_int(copy.map.owner_at(tile)).is_equal(state.map.owner_at(tile))


func test_other_faction_knowledge_is_absent() -> void:
	var state := StateFactory.minimal()

	var copy := state.filtered_copy(Faction.PLAYER)

	var ai_rows := copy.visibility._vis_discovered.slice(state.tile_count())
	assert_int(ai_rows.count(1)).is_equal(0)
	assert_int(copy.view_cache.seen[Faction.AI].count(1)).is_equal(0)
	assert_int(copy.view_cache.seen[Faction.PLAYER].count(1)).is_greater(0)


func test_node_out_of_view_shows_last_owner_seen_and_no_level() -> void:
	var state := StateFactory.minimal()
	var tile := state.tile_index(7, 0)
	GameStateSetup.set_tile_owner(state, tile, Faction.AI)
	var node_id := GameStateSetup.add_node(state, tile, Faction.AI, 3)
	var ctx := StateFactory.vision_context(state)
	VisionService.setup(state, ctx)
	VisionService.reveal_step(state, ctx, 0, state.tile_index(4, 1))
	VisionService.recompute(state, ctx)
	assert_int(VisionService.tile_state(state, Faction.PLAYER, tile)).is_equal(VisionService.EXPLORED)

	var copy := state.filtered_copy(Faction.PLAYER)
	var own := state.filtered_copy(Faction.AI)

	var row := copy.nodes.find_row(node_id)
	assert_int(copy.nodes.owner_of(row)).is_equal(Faction.AI)
	assert_int(copy.nodes.level_of(row)).is_equal(0)
	assert_int(own.nodes.level_of(own.nodes.find_row(node_id))).is_equal(3)


func test_undiscovered_node_is_absent() -> void:
	var state := StateFactory.minimal()
	GameStateSetup.add_node(state, state.tile_index(7, 0), Faction.AI, 1)
	VisionService.setup(state, StateFactory.vision_context(state))

	assert_array(state.filtered_copy(Faction.PLAYER).view().node_ids()).is_empty()


func test_ruins_are_kept_for_the_player_only() -> void:
	var state := StateFactory.minimal()
	GameStateSetup.add_ruin(state, state.tile_index(4, 0), 0, Faction.PLAYER)
	VisionService.setup(state, StateFactory.vision_context(state))

	assert_int(state.filtered_copy(Faction.PLAYER).ruins.row_count()).is_equal(1)
	var ai_copy := state.filtered_copy(Faction.AI)
	assert_int(ai_copy.ruins.row_count()).is_equal(0)
	assert_int(ai_copy.map.anchor_at(state.tile_index(4, 0))).is_equal(MapSlice.ANCHOR_NONE)


func test_private_slices_follow_their_faction() -> void:
	var state := StateFactory.minimal()

	var player_copy := state.filtered_copy(Faction.PLAYER)
	var ai_copy := state.filtered_copy(Faction.AI)

	for k in state.slices().size():
		var owner := state.slices()[k].private_to()
		if owner == Faction.AI:
			assert_bool(player_copy.slices()[k].equals(state.slices()[k].get_script().new())).is_true()
			assert_bool(ai_copy.slices()[k].equals(state.slices()[k])).is_true()


func test_filtered_copy_leaves_the_real_state_untouched() -> void:
	for state in StateFactory.random_states(STATES, SEED):
		var before := state.to_bytes()

		state.filtered_copy(Faction.AI)

		assert_array(state.to_bytes()).is_equal(before)
		assert_bool(is_same(state.filtered_copy(Faction.AI).terrain, state.terrain)).is_false()
