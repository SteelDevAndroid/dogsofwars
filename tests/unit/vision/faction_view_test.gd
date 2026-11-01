extends GdUnitTestSuite


func test_hidden_enemy_is_absent_and_answers_like_an_unknown_id() -> void:
	var state := StateFactory.minimal()

	var view := FactionView.new(state, Faction.PLAYER)

	assert_array(view.unit_ids()).is_equal(PackedInt32Array([0]))
	assert_int(view.unit_tile(1)).is_equal(view.unit_tile(99))
	assert_int(view.unit_faction(1)).is_equal(view.unit_faction(99))
	assert_int(view.unit_hp(1)).is_equal(view.unit_hp(99))


func test_reads_follow_the_real_state_without_a_copy() -> void:
	var state := StateFactory.minimal()
	var view := FactionView.new(state, Faction.PLAYER)

	UnitWrites.destroy(state, 0)

	assert_array(view.unit_ids()).is_empty()


func test_undiscovered_terrain_reads_as_plain() -> void:
	var cells := PackedByteArray()
	cells.resize(StateFactory.MINIMAL_SIZE * StateFactory.MINIMAL_SIZE)
	cells.fill(TerrainGrid.WATER)
	var state := GameStateSetup.create(StateFactory.MINIMAL_SIZE, StateFactory.MINIMAL_SIZE,
			StateFactory.FACTIONS, 1, cells)
	GameStateSetup.add_unit(state, 0, Faction.PLAYER, 0, StateFactory.FULL_HP)
	VisionService.setup(state, StateFactory.vision_context(state))

	var view := FactionView.new(state, Faction.PLAYER)

	assert_int(view.terrain_at(0)).is_equal(TerrainGrid.WATER)
	assert_int(view.terrain_at(state.tile_count() - 1)).is_equal(TerrainGrid.PLAIN)
	assert_int(view.faction()).is_equal(Faction.PLAYER)
