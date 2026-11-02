extends GdUnitTestSuite

const MAP_PATH := "res://assets/data/maps/plaine.json"
const PACK := ["eclaireur", "assaut", "rempart"]


func _map() -> MapDefinition:
	var errors: Array[DataError] = []
	var map := MapDefinition.parse(FileAccess.get_file_as_string(MAP_PATH), "plaine.json", CatalogFactory.standard(), errors)
	assert_int(errors.size()).is_equal(0)
	return map


func _new(seed_value: int = 7, ai_passive: bool = false, chronicle: Array = []) -> GameState:
	return GameStateFactory.new_game(CatalogFactory.standard(), _map(), seed_value, ai_passive, chronicle, 42, 3)


func test_the_new_game_is_a_valid_created_state() -> void:
	var state := _new()

	assert_array(state.validate()).is_empty()
	assert_array(VisionService.consistency_errors(state)).is_empty()
	assert_array([state.turn(), state.header.value(HeaderSlice.PHASE), state.header.value(HeaderSlice.ACTIVE_FACTION)]) \
			.is_equal([0, HeaderSlice.PHASE_CREATED, Faction.PLAYER])
	assert_array([state.header.value(HeaderSlice.MATCH_ID), state.header.value(HeaderSlice.PROFILE_EPOCH), state.header.value(HeaderSlice.SEED)]) \
			.is_equal([42, 3, 7])
	assert_int(state.header.value(HeaderSlice.T_MAX)).is_equal(GameState.MAX_TURN)


func test_the_map_is_copied_into_the_state() -> void:
	var state := _new()
	var view := state.view()

	assert_int(view.node_ids().size()).is_equal(6)
	assert_int(view.node_owner(0)).is_equal(Faction.PLAYER)
	assert_int(view.node_owner(1)).is_equal(Faction.AI)
	assert_int(view.node_tile(0)).is_equal(state.tile_index(1, 2))
	assert_int(view.node_level(2)).is_equal(1)
	assert_int(view.node_owner(2)).is_equal(Faction.NONE)
	var awake := Array(view.unit_ids()).filter(func(id: int) -> bool: return not view.unit_asleep(id))
	assert_int(awake.size()).is_equal(7)
	assert_int(view.unit_ids().size() - awake.size()).is_equal(6)
	for id in view.unit_ids():
		if view.unit_asleep(id):
			assert_int(view.unit_faction(id)).is_equal(Faction.NONE)
		assert_int(view.unit_hp(id)).is_equal(CatalogFactory.standard().units.hp(view.unit_type(id)))


func test_the_first_energy_and_the_first_territory_are_set() -> void:
	var state := _new()

	assert_int(EnergyRules.stock(state, Faction.PLAYER)).is_equal(CatalogFactory.standard().energy.start_stock())
	assert_int(EnergyRules.stock(state, Faction.AI)).is_equal(CatalogFactory.standard().energy.start_stock())
	assert_int(state.map.owner_at(state.tile_index(1, 2))).is_equal(Faction.PLAYER)
	assert_int(state.map.owner_at(state.tile_index(10, 9))).is_equal(Faction.AI)


func test_each_side_starts_with_its_own_view() -> void:
	var state := _new()

	assert_bool(VisionService.can_see(state.view_cache, Faction.PLAYER, state.tile_index(1, 2))).is_true()
	assert_bool(VisionService.can_see(state.view_cache, Faction.PLAYER, state.tile_index(10, 9))).is_false()
	assert_bool(VisionService.can_see(state.view_cache, Faction.AI, state.tile_index(10, 9))).is_true()


func test_dormant_types_are_drawn_from_their_list_and_mirrored_dormants_agree() -> void:
	var catalog := CatalogFactory.standard()
	var state := _new(11)
	var dormants := []
	for id in state.view().unit_ids():
		if state.view().unit_asleep(id):
			dormants.append(state.view().unit_type(id))

	assert_str(catalog.units.key(dormants[0])).is_equal("ouvrier")
	assert_str(catalog.units.key(dormants[1])).is_equal("ouvrier")
	for index in [2, 3, 4, 5]:
		assert_bool(PACK.has(catalog.units.key(dormants[index]))).is_true()
	assert_int(dormants[3]).is_equal(dormants[2])
	assert_int(dormants[5]).is_equal(dormants[4])


func test_three_ruins_are_drawn_one_per_zone_among_the_candidates() -> void:
	var map := _map()
	var state := _new(5)
	var view := state.view()

	assert_int(view.ruin_ids().size()).is_equal(3)
	for zone in 3:
		var row := zone
		assert_int(state.ruins.zone_of(row)).is_equal(zone)
		assert_bool((map.ruin_zones[zone][1] as PackedInt32Array).has(state.ruins.tile_of(row))).is_true()
		assert_int(state.ruins.memory_faction_of(row)).is_equal(Faction.PLAYER)
		assert_bool(state.ruins.is_read(row)).is_false()


func test_the_draw_counter_counts_exactly_the_open_choices() -> void:
	# two random dormants (the mirrored ones repeat them) and three ruins
	assert_int(_new().header.value(HeaderSlice.DRAW_COUNTER)).is_equal(5)


func test_the_same_seed_gives_the_same_state_and_other_seeds_vary() -> void:
	assert_bool(_new(9).equals(_new(9))).is_true()
	assert_bool(_new(9).to_bytes() == _new(9).to_bytes()).is_true()
	var layouts := {}
	for seed_value in 40:
		var state := _new(seed_value)
		var layout := []
		for id in state.view().unit_ids():
			if state.view().unit_asleep(id):
				layout.append(state.view().unit_type(id))
		for row in 3:
			layout.append(state.ruins.tile_of(row))
		layouts[str(layout)] = true
	assert_int(layouts.size()).is_greater(10)


func test_the_chronicle_snapshot_is_copied_sorted() -> void:
	var state := _new(1, false, [[0, 3], [0, 1], [1, 2]])

	assert_bool(state.chronicle.has(0, 1)).is_true()
	assert_bool(state.chronicle.has(0, 3)).is_true()
	assert_bool(state.chronicle.has(1, 2)).is_true()
	assert_bool(state.chronicle.has(0, 2)).is_false()
	assert_array(state.validate()).is_empty()


func test_the_passive_flag_and_the_guardians_posts_are_set() -> void:
	var state := _new(1, true)
	var view := state.view()
	var catalog := CatalogFactory.standard()

	assert_bool(view.ai_passive()).is_true()
	assert_bool(_new(1, false).view().ai_passive()).is_false()
	var roles := {}
	for id in view.unit_ids():
		if view.unit_faction(id) == Faction.AI:
			var row := state.ai_agents.find_row(id)
			roles[catalog.units.key(view.unit_type(id))] = state.ai_agents.role_of(row)
			assert_int(state.ai_agents.post_tile_of(row)).is_equal(view.unit_tile(id))
	assert_int(roles["bastion"]).is_equal(AiAgentsSlice.ROLE_CAPTURE)
	assert_int(roles["chasseur"]).is_equal(AiAgentsSlice.ROLE_POST)
	assert_int(roles["sentinelle"]).is_equal(AiAgentsSlice.ROLE_IMMOBILE)


func test_the_map_check_of_the_dormants_agrees_with_the_state() -> void:
	assert_array(Array(WakeRules.map_errors(_new(), CatalogFactory.standard()))).is_empty()


func test_the_factory_fixes_the_content_of_the_state_for_the_filtered_copies() -> void:
	var state := _new(3)

	for faction in [Faction.PLAYER, Faction.AI]:
		assert_array(state.filtered_copy(faction).validate()).is_empty()


func _state_of(document: Dictionary, seed_value: int = 1) -> GameState:
	var errors: Array[DataError] = []
	var map := MapDefinition.parse(JSON.stringify(document), "plaine.json", CatalogFactory.standard(), errors)
	assert_int(errors.size()).is_equal(0)
	return GameStateFactory.new_game(CatalogFactory.standard(), map, seed_value)


func test_a_zone_that_draws_several_ruins_never_picks_a_tile_twice() -> void:
	for seed_value in 20:
		var document: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(MAP_PATH))
		document["ruin_zones"][0]["draw"] = 3
		var state := _state_of(document, seed_value)

		var tiles := {}
		for row in state.ruins.row_count():
			tiles[state.ruins.tile_of(row)] = true
		assert_int(state.ruins.row_count()).is_equal(5)
		assert_int(tiles.size()).override_failure_message("seed %d" % seed_value).is_equal(5)


func test_a_guardian_post_from_the_file_is_kept() -> void:
	var document: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(MAP_PATH))
	document["units"][4]["post_x"] = 8
	document["units"][4]["post_y"] = 5
	var state := _state_of(document)

	var chasseur := state.view().unit_at(state.tile_index(8, 6))

	assert_int(state.ai_agents.post_tile_of(state.ai_agents.find_row(chasseur))).is_equal(state.tile_index(8, 5))


func test_the_order_of_the_chronicle_rows_does_not_matter() -> void:
	var sorted := _new(1, false, [[0, 1], [0, 3], [1, 2]])
	var shuffled := _new(1, false, [[1, 2], [0, 3], [0, 1]])

	assert_bool(sorted.to_bytes() == shuffled.to_bytes()).is_true()
