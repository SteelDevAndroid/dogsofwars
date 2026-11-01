extends GdUnitTestSuite


func test_compaction_drops_dead_rows_and_keeps_equality() -> void:
	var state := StateFactory.with_units(3)
	UnitWrites.destroy(state, 1)
	UnitWrites.destroy(state, 4)
	var before := state.duplicate_state()

	state.compact()

	assert_int(state.units.row_count()).is_equal(4)
	assert_array(state.view().unit_ids()).is_equal(PackedInt32Array([0, 2, 3, 5]))
	assert_bool(state.equals(before)).is_true()
	assert_array(state.to_bytes()).is_not_equal(before.to_bytes())


func test_ids_are_not_reused_after_compaction() -> void:
	var state := StateFactory.with_units(1)
	UnitWrites.destroy(state, 1)
	state.compact()

	var id := GameStateSetup.add_unit(state, 0, Faction.AI, 9, StateFactory.FULL_HP)

	assert_int(id).is_equal(2)


func test_destroy_unknown_or_dead_unit_is_refused() -> void:
	var state := StateFactory.minimal()

	assert_bool(UnitWrites.destroy(state, 1)).is_true()
	assert_bool(UnitWrites.destroy(state, 1)).is_false()
	assert_bool(UnitWrites.destroy(state, 99)).is_false()
