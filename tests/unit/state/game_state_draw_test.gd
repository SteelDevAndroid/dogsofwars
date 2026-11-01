extends GdUnitTestSuite

## hash32(seed, 0..2), canonical SplitMix32 of ADR-0003, computed by an independent
## reference implementation (Python, 64-bit integers masked to 32 bits).
const REFERENCE := {
	0: [2462723854, 1020716019, 454327756],
	1: [2527132011, 314344336, 2535364964],
	1234: [1889054206, 3098527212, 4145563210],
	987654321: [4189443044, 1664431932, 889012035],
	4294967295: [920564995, 4230986166, 697614773],
}


func test_hash32_matches_reference_vectors() -> void:
	for seed_value: int in REFERENCE:
		for counter in 3:
			assert_int(GameState.hash32(seed_value, counter)) \
				.override_failure_message("seed %d counter %d" % [seed_value, counter]) \
				.is_equal(REFERENCE[seed_value][counter])


func test_hash32_has_no_fixed_point_at_zero() -> void:
	assert_int(GameState.hash32(0, 0)).is_not_equal(0)


func test_hash32_stays_unsigned_32_bit_at_the_bounds() -> void:
	var value := GameState.hash32(0xFFFFFFFF, GameState.ID_MAX - 1)

	assert_int(value).is_between(0, 0xFFFFFFFF)


func test_draw_returns_hash_mod_n_and_advances_counter() -> void:
	var state := StateFactory.minimal(1234)

	var first := state.draw(6)
	var second := state.draw(6)

	assert_int(first).is_equal(REFERENCE[1234][0] % 6)
	assert_int(second).is_equal(REFERENCE[1234][1] % 6)
	assert_int(state.header.value(HeaderSlice.DRAW_COUNTER)).is_equal(2)


func test_draw_outside_bounds_is_refused_without_moving_counter() -> void:
	var state := StateFactory.minimal()

	assert_int(state.draw(0)).is_equal(-1)
	assert_int(state.draw(GameState.DRAW_MAX + 1)).is_equal(-1)
	assert_int(state.header.value(HeaderSlice.DRAW_COUNTER)).is_equal(0)


func test_draws_in_a_copy_leave_the_original_counter() -> void:
	var state := StateFactory.minimal()
	var copy := state.duplicate_state()

	copy.draw(GameState.DRAW_MAX)

	assert_int(state.header.value(HeaderSlice.DRAW_COUNTER)).is_equal(0)
	assert_int(state.draw(GameState.DRAW_MAX)).is_equal(GameState.hash32(1, 0) % GameState.DRAW_MAX)


func test_allocate_id_is_increasing_per_family() -> void:
	var state := StateFactory.minimal()

	var unit_id := state.allocate_id(HeaderSlice.NEXT_UNIT_ID)
	var node_id := state.allocate_id(HeaderSlice.NEXT_NODE_ID)

	assert_int(unit_id).is_equal(2)
	assert_int(node_id).is_equal(0)
	assert_int(state.header.value(HeaderSlice.NEXT_UNIT_ID)).is_equal(3)
