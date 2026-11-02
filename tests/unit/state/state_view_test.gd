extends GdUnitTestSuite


func test_unit_reads_skip_destroyed_units() -> void:
	var state := StateFactory.minimal()
	UnitWrites.destroy(state, 0)

	var view := state.view()

	assert_array(view.unit_ids()).is_equal(PackedInt32Array([1]))
	assert_int(view.unit_tile(0)).is_equal(-1)
	assert_int(view.unit_faction(1)).is_equal(Faction.AI)
	assert_int(view.unit_hp(1)).is_equal(StateFactory.FULL_HP)


func test_returned_arrays_are_copies() -> void:
	var state := StateFactory.minimal()
	GameStateSetup.add_node(state, 0, Faction.PLAYER, 1)

	var ids := state.view().unit_ids()
	ids[0] = 42
	var node_ids := state.view().node_ids()
	node_ids[0] = 42

	assert_array(state.view().unit_ids()).is_equal(PackedInt32Array([0, 1]))
	assert_array(state.view().node_ids()).is_equal(PackedInt32Array([0]))


func test_node_and_tile_reads() -> void:
	var state := StateFactory.minimal()
	var node_id := GameStateSetup.add_node(state, 5, Faction.AI, 2)
	GameStateSetup.set_tile_owner(state, 5, Faction.AI)

	var view := state.view()

	assert_int(view.node_tile(node_id)).is_equal(5)
	assert_int(view.node_owner(node_id)).is_equal(Faction.AI)
	assert_int(view.tile_owner(5)).is_equal(Faction.AI)
	assert_int(view.terrain_at(5)).is_equal(TerrainGrid.PLAIN)
	assert_int(view.node_tile(99)).is_equal(-1)
