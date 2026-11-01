extends GdUnitTestSuite

const SEED := 9
const STATES := 20


func test_minimal_state_has_two_units_on_an_8x8_map() -> void:
	var state := StateFactory.minimal()

	assert_int(state.width()).is_equal(StateFactory.MINIMAL_SIZE)
	assert_int(state.faction_count()).is_equal(StateFactory.FACTIONS)
	assert_array(state.view().unit_ids()).is_equal(PackedInt32Array([0, 1]))


func test_same_seed_gives_the_same_states() -> void:
	var first := StateFactory.random_states(STATES, SEED)
	var second := StateFactory.random_states(STATES, SEED)

	for k in STATES:
		assert_array(second[k].to_bytes()).is_equal(first[k].to_bytes())


func test_states_differ_within_a_run_and_across_seeds() -> void:
	var states := StateFactory.random_states(2, SEED)
	var other := StateFactory.random_states(1, SEED + 1)

	assert_bool(states[0].equals(states[1])).is_false()
	assert_bool(other[0].equals(states[0])).is_false()


func test_random_states_contain_dead_rows_and_varied_sizes() -> void:
	var dead_rows := 0
	var widths := {}
	for state in StateFactory.random_states(STATES, SEED):
		dead_rows += state.units.row_count() - state.units.live_rows().size()
		widths[state.width()] = true

	assert_int(dead_rows).is_greater(0)
	assert_int(widths.size()).is_greater(1)
