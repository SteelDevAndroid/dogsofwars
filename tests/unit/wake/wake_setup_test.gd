extends GdUnitTestSuite

const ECLAIREUR := 0
const ASSAUT := 1
const REMPART := 2
const OUVRIER := 3
const CHASSEUR := 5
const PACK := [0, 1, 2]


func _state(seed_value: int) -> GameState:
	return GameStateSetup.create(4, 4, StateFactory.FACTIONS, seed_value, PackedByteArray([0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0]))


func test_each_zone_draws_one_candidate_in_order_and_moves_the_counter() -> void:
	var state := _state(7)
	var zones := [PackedInt32Array(PACK), PackedInt32Array(PACK)]

	var types := WakeRules.draw_zone_types(state, zones)

	assert_int(types.size()).is_equal(2)
	for type in types:
		assert_bool(PACK.has(type)).is_true()
	assert_int(state.header.value(HeaderSlice.DRAW_COUNTER)).is_equal(2)


func test_the_draw_is_reproduced_from_the_seed() -> void:
	var zones := [PackedInt32Array(PACK), PackedInt32Array(PACK)]

	var first := WakeRules.draw_zone_types(_state(99), zones)
	var second := WakeRules.draw_zone_types(_state(99), zones)

	assert_array(Array(first)).is_equal(Array(second))


func test_every_pack_type_can_come_out_with_replacement() -> void:
	var seen := {}
	for seed_value in 60:
		var types := WakeRules.draw_zone_types(_state(seed_value), [PackedInt32Array(PACK), PackedInt32Array(PACK)])
		for type in types:
			seen[type] = true
		if types[0] == types[1]:
			seen["twice"] = true

	assert_array(seen.keys()).contains([ECLAIREUR, ASSAUT, REMPART, "twice"])


func test_a_zone_without_candidate_draws_nothing() -> void:
	var state := _state(1)

	var types := WakeRules.draw_zone_types(state, [PackedInt32Array()])

	assert_int(types.size()).is_equal(0)
	assert_int(state.header.value(HeaderSlice.DRAW_COUNTER)).is_equal(0)


func test_a_single_candidate_zone_is_fixed() -> void:
	var types := WakeRules.draw_zone_types(_state(3), [PackedInt32Array([OUVRIER])])

	assert_array(Array(types)).is_equal([OUVRIER])


func test_the_map_check_accepts_pack_dormants_and_names_a_guardian() -> void:
	var state := _state(1)
	MapBuilder.unit(state, OUVRIER, Faction.NONE, 0, 0, true)
	MapBuilder.unit(state, REMPART, Faction.NONE, 1, 0, true)
	var catalog := CatalogFactory.standard()
	assert_int(WakeRules.map_errors(state, catalog).size()).is_equal(0)

	var bad := MapBuilder.unit(state, CHASSEUR, Faction.NONE, 2, 0, true)

	assert_array(Array(WakeRules.map_errors(state, catalog))).is_equal(["dormant unit %d: type chasseur is not a pack type" % bad])


func test_awake_units_are_not_checked() -> void:
	var state := _state(1)
	MapBuilder.unit(state, CHASSEUR, Faction.AI, 0, 0)

	assert_int(WakeRules.map_errors(state, CatalogFactory.standard()).size()).is_equal(0)
