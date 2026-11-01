extends GdUnitTestSuite

const SEED := 77
const STATES := 100


func test_factory_states_are_valid() -> void:
	assert_array(StateFactory.minimal().validate()).is_empty()
	for state in StateFactory.random_states(STATES, SEED):
		assert_array(state.validate()).override_failure_message("seed %d" % SEED).is_empty()


func test_two_units_on_one_tile_are_reported() -> void:
	var state := StateFactory.minimal()
	var same_tile := PackedInt32Array([state.tile_index(1, 1), state.tile_index(1, 1)])

	var loaded := StatePayload.decoded_with(state, &"_unit_tile", same_tile)

	assert_array(loaded.validate()).has_size(1)


func test_destroyed_unit_does_not_occupy_its_tile() -> void:
	var state := StateFactory.minimal()
	UnitWrites.destroy(state, 1)
	var same_tile := PackedInt32Array([state.tile_index(1, 1), state.tile_index(1, 1)])

	var loaded := StatePayload.decoded_with(state, &"_unit_tile", same_tile)

	assert_array(loaded.validate()).is_empty()


func test_unit_off_the_map_and_bad_owner_are_reported() -> void:
	var state := StateFactory.minimal()
	var off_map := PackedInt32Array([state.tile_count(), 0])
	var owners := PackedByteArray()
	owners.resize(state.tile_count())
	owners.fill(Faction.NONE)
	owners[3] = StateFactory.FACTIONS

	assert_array(StatePayload.decoded_with(state, &"_unit_tile", off_map).validate()).has_size(1)
	assert_array(StatePayload.decoded_with(state, &"_tile_owner", owners).validate()).has_size(1)


func test_turn_beyond_t_max_is_reported() -> void:
	var state := StateFactory.minimal()
	GameStateSetup.set_turn(state, GameState.MAX_TURN + 1)

	assert_array(state.validate()).has_size(1)


func test_tile_index_refuses_coordinates_off_the_map() -> void:
	var state := StateFactory.minimal()

	assert_int(state.tile_index(5, 3)).is_equal(3 * StateFactory.MINIMAL_SIZE + 5)
	assert_int(state.tile_index(StateFactory.MINIMAL_SIZE, 0)).is_equal(-1)
	assert_int(state.tile_index(0, -1)).is_equal(-1)
