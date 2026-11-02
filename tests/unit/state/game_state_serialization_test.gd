extends GdUnitTestSuite

const SEED := 4242
const STATES := 100


func test_round_trip_gives_an_equal_state() -> void:
	for state in StateFactory.random_states(STATES, SEED):
		var loaded := GameState.from_bytes(state.to_bytes(), GameState.SCHEMA_VERSION)

		assert_object(loaded).override_failure_message("seed %d" % SEED).is_not_null()
		assert_bool(loaded.equals(state)).override_failure_message("seed %d" % SEED).is_true()


func test_to_bytes_is_deterministic_for_equal_states() -> void:
	for state in StateFactory.random_states(STATES, SEED):
		assert_array(state.duplicate_state().to_bytes()).is_equal(state.to_bytes())


func test_loaded_view_cache_is_invalid_and_sized() -> void:
	var loaded := GameState.from_bytes(StateFactory.minimal().to_bytes(), GameState.SCHEMA_VERSION)

	assert_bool(loaded.view_cache.valid).is_false()
	assert_int(loaded.view_cache.seen.size()).is_equal(StateFactory.FACTIONS)
	assert_int(loaded.view_cache.seen[0].size()).is_equal(loaded.tile_count())


func test_other_schema_is_refused() -> void:
	var bytes := StateFactory.minimal().to_bytes()

	assert_object(GameState.from_bytes(bytes, GameState.SCHEMA_VERSION + 1)).is_null()
	assert_object(GameState.from_bytes(bytes, GameState.SCHEMA_VERSION - 1)).is_null()


func test_payload_that_is_not_a_column_list_is_refused() -> void:
	assert_object(GameState.from_bytes(var_to_bytes({"units": 1}), GameState.SCHEMA_VERSION)).is_null()
	assert_object(GameState.from_bytes(var_to_bytes([]), GameState.SCHEMA_VERSION)).is_null()


func test_column_of_wrong_type_is_refused() -> void:
	var state := StateFactory.minimal()

	assert_object(StatePayload.decoded_with(state, &"_unit_hp", PackedByteArray([1, 1]))).is_null()


func test_column_of_wrong_length_is_refused() -> void:
	var state := StateFactory.minimal()

	assert_object(StatePayload.decoded_with(state, &"_unit_hp", PackedInt32Array([1]))).is_null()
	assert_object(StatePayload.decoded_with(state, &"_tile_owner", PackedByteArray([0]))).is_null()


func test_unsorted_or_unallocated_ids_are_refused() -> void:
	var state := StateFactory.minimal()

	assert_object(StatePayload.decoded_with(state, &"_unit_id", PackedInt32Array([1, 0]))).is_null()
	assert_object(StatePayload.decoded_with(state, &"_unit_id", PackedInt32Array([0, 9]))).is_null()


func test_terrain_of_wrong_size_is_refused() -> void:
	var data: Array = bytes_to_var(StateFactory.minimal().to_bytes())
	data[0] = PackedByteArray([0])

	assert_object(GameState.from_bytes(var_to_bytes(data), GameState.SCHEMA_VERSION)).is_null()
