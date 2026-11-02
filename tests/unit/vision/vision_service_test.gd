extends GdUnitTestSuite

const SEED := 515
const STATES := 60


func _discovered(state: GameState, faction: int, tile: int) -> bool:
	return VisionService.tile_state(state, faction, tile) != VisionService.UNKNOWN


func test_setup_gives_consistent_views_on_random_states() -> void:
	for state in StateFactory.random_states(STATES, SEED):
		assert_bool(state.view_cache.valid).is_true()
		assert_array(VisionService.consistency_errors(state)).override_failure_message("seed %d" % SEED).is_empty()


func test_setup_shows_the_unit_field_and_hides_the_far_enemy() -> void:
	var state := StateFactory.minimal()

	assert_int(VisionService.tile_state(state, Faction.PLAYER, state.tile_index(5, 5))).is_equal(VisionService.VISIBLE)
	assert_int(VisionService.tile_state(state, Faction.PLAYER, state.tile_index(6, 6))).is_equal(VisionService.UNKNOWN)
	assert_bool(VisionService.can_see_unit(state, state.view_cache, Faction.PLAYER, 1)).is_false()
	assert_bool(VisionService.can_see_unit(state, state.view_cache, Faction.PLAYER, 0)).is_true()


func test_setup_memorizes_dormants_and_owned_territory() -> void:
	var state := StateFactory.minimal()
	var far := state.tile_index(7, 0)
	GameStateSetup.add_unit(state, 0, Faction.AI, far, StateFactory.FULL_HP, true)
	GameStateSetup.set_tile_owner(state, state.tile_index(7, 7), Faction.PLAYER)

	VisionService.setup(state, StateFactory.vision_context(state))

	for f in StateFactory.FACTIONS:
		assert_int(state.visibility._vis_dormant_memo[f * state.tile_count() + far]).is_equal(1)
	assert_int(VisionService.tile_state(state, Faction.PLAYER, state.tile_index(7, 7))).is_equal(VisionService.EXPLORED)
	assert_int(state.visibility._vis_last_owner_seen[state.tile_index(7, 7)]).is_equal(Faction.PLAYER)


func test_destroyed_source_leaves_its_tiles_explored() -> void:
	var state := StateFactory.minimal()
	var ctx := StateFactory.vision_context(state)
	UnitWrites.destroy(state, 0)

	var delta := VisionService.recompute(state, ctx)

	assert_int(VisionService.tile_state(state, Faction.PLAYER, state.tile_index(1, 1))).is_equal(VisionService.EXPLORED)
	assert_bool(delta.revealed).is_false()
	assert_array(delta.discovered_tiles).is_empty()


func test_reveal_step_adds_the_field_and_reports_new_units_and_tiles() -> void:
	var state := StateFactory.minimal()
	var ctx := StateFactory.vision_context(state)

	var delta := VisionService.reveal_step(state, ctx, 0, state.tile_index(3, 3))

	assert_bool(delta.revealed).is_true()
	assert_array(delta.newly_seen_units).is_equal(PackedInt32Array([1]))
	assert_bool(delta.discovered_tiles.has(state.tile_index(7, 7))).is_true()
	var sorted := delta.discovered_tiles.duplicate()
	sorted.sort()
	assert_array(delta.discovered_tiles).is_equal(sorted)
	assert_array(VisionService.consistency_errors(state)).is_empty()


func test_ai_learning_gives_the_player_no_delta() -> void:
	var state := StateFactory.minimal()
	var ctx := StateFactory.vision_context(state)

	var delta := VisionService.reveal_step(state, ctx, 1, state.tile_index(4, 4))

	assert_bool(delta.revealed).is_false()
	assert_array(delta.discovered_tiles).is_empty()
	assert_bool(_discovered(state, Faction.AI, state.tile_index(1, 1))).is_true()


func test_simulation_context_recomputes_nothing() -> void:
	var state := StateFactory.minimal()
	var ctx := StateFactory.vision_context(state).simulation()
	var before := state.duplicate_state()
	UnitWrites.destroy(state, 0)

	VisionService.recompute(state, ctx)
	VisionService.reveal_step(state, ctx, 1, state.tile_index(4, 4))

	assert_array(state.view_cache.seen[Faction.PLAYER]).is_equal(before.view_cache.seen[Faction.PLAYER])
	assert_array(state.visibility._vis_discovered).is_equal(before.visibility._vis_discovered)


func test_rebuild_after_load_gives_the_saved_view() -> void:
	for state in StateFactory.random_states(STATES, SEED):
		var loaded := GameState.from_bytes(state.to_bytes(), GameState.SCHEMA_VERSION)

		VisionService.rebuild(loaded, StateFactory.vision_context(loaded))

		for f in StateFactory.FACTIONS:
			assert_array(loaded.view_cache.seen[f]).is_equal(state.view_cache.seen[f])
		assert_array(VisionService.consistency_errors(loaded)).is_empty()


func test_visible_tile_left_undiscovered_is_a_corruption() -> void:
	var state := StateFactory.minimal()
	var undiscovered := PackedByteArray()
	undiscovered.resize(state.tile_count() * StateFactory.FACTIONS)
	var loaded := StatePayload.decoded_with(state, &"_vis_discovered", undiscovered)

	VisionService.rebuild(loaded, StateFactory.vision_context(loaded))

	assert_array(VisionService.consistency_errors(loaded)).is_not_empty()


func test_event_of_the_other_faction_needs_a_visible_tile() -> void:
	var state := StateFactory.minimal()
	var near := _PlacedEvent.new(Faction.AI, state.tile_index(2, 2))
	var far := _PlacedEvent.new(Faction.AI, state.tile_index(7, 7))
	var own := _PlacedEvent.new(Faction.PLAYER, state.tile_index(7, 7))
	var cache := state.view_cache

	assert_bool(VisionService.event_visible(cache, cache, Faction.PLAYER, near)).is_true()
	assert_bool(VisionService.event_visible(cache, cache, Faction.PLAYER, far)).is_false()
	assert_bool(VisionService.event_visible(cache, cache, Faction.PLAYER, own)).is_true()


class _PlacedEvent extends PresentationEvent:
	var _tile: int

	func _init(p_faction: int, tile: int) -> void:
		faction = p_faction
		_tile = tile

	func tiles() -> PackedInt32Array:
		return PackedInt32Array([_tile])
