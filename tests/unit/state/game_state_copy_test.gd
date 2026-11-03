extends GdUnitTestSuite

const SEED := 20261101
const STATES := 100


func test_copy_equals_original_and_shares_no_column() -> void:
	for state in StateFactory.random_states(STATES, SEED):
		var copy := state.duplicate_state()

		assert_bool(copy.equals(state)).override_failure_message("seed %d" % SEED).is_true()
		var mine := state.slices()
		var theirs := copy.slices()
		for k in mine.size():
			assert_array(mine[k].shared_columns(theirs[k])) \
				.override_failure_message("seed %d, slice %d" % [SEED, k]).is_empty()


func test_shared_columns_detects_a_shared_buffer() -> void:
	var state := StateFactory.minimal()

	assert_array(state.units.shared_columns(state.units)).has_size(UnitsSlice.COLUMNS.size())


func test_write_in_copy_leaves_original_untouched() -> void:
	var state := StateFactory.minimal()
	var copy := state.duplicate_state()

	UnitWrites.destroy(copy, 0)
	GameStateSetup.set_tile_owner(copy, 0, Faction.AI)

	assert_int(state.view().unit_tile(0)).is_equal(state.tile_index(1, 1))
	assert_int(state.view().tile_owner(0)).is_equal(Faction.NONE)
	assert_bool(copy.equals(state)).is_false()


func test_terrain_is_shared_read_only_between_real_copies() -> void:
	var state := StateFactory.minimal()

	assert_bool(is_same(state.duplicate_state().terrain, state.terrain)).is_true()


func test_view_cache_is_copied_deeply() -> void:
	var state := StateFactory.minimal()
	state.view_cache.seen[Faction.PLAYER][0] = 1

	var copy := state.duplicate_state()
	copy.view_cache.seen[Faction.PLAYER][0] = 0

	assert_int(state.view_cache.seen[Faction.PLAYER][0]).is_equal(1)


func test_restore_from_returns_to_snapshot_and_keeps_revision() -> void:
	var snapshot := StateFactory.minimal()
	var state := StatePayload.decoded_with(snapshot, &"_cmd_revision", PackedInt64Array([7]))
	UnitWrites.destroy(state, 0)

	state.restore_from(snapshot)

	assert_int(state.view().unit_tile(0)).is_equal(snapshot.view().unit_tile(0))
	assert_int(state.revision()).is_equal(7)
	assert_bool(is_same(state.terrain, snapshot.terrain)).is_true()


## Review 2026-11-01, B4: restore_from brings back the snapshot's cache, valid and owned,
## without a rebuild (it has no VisionContext).
func test_restore_from_copies_the_view_cache_of_the_snapshot() -> void:
	var state := StateFactory.minimal()
	var snapshot := state.duplicate_state()
	state.view_cache.seen[Faction.PLAYER][0] = 1 - snapshot.view_cache.seen[Faction.PLAYER][0]
	state.view_cache.valid = false

	state.restore_from(snapshot)

	assert_array(state.view_cache.seen).is_equal(snapshot.view_cache.seen)
	assert_bool(state.view_cache.valid).is_equal(snapshot.view_cache.valid)
	state.view_cache.seen[Faction.PLAYER][0] = 1 - snapshot.view_cache.seen[Faction.PLAYER][0]
	assert_bool(state.view_cache.seen[Faction.PLAYER][0] == snapshot.view_cache.seen[Faction.PLAYER][0]).is_false()
