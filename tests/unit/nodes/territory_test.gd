extends GdUnitTestSuite


func _map(width: int) -> GameState:
	var row := ""
	for k in width:
		row += "."
	return MapBuilder.state(PackedStringArray([row, row, row]))


func _recompute(state: GameState) -> Array:
	return TerritoryRules.recompute(state, CatalogFactory.standard().nodes, MapSlice.CAUSE_CAPTURE)


func test_owned_node_projects_its_radius_and_neutral_node_none() -> void:
	var state := _map(7)
	GameStateSetup.add_node(state, state.tile_index(1, 1), Faction.PLAYER, 1)
	GameStateSetup.add_node(state, state.tile_index(5, 1), Faction.NONE, 3)

	_recompute(state)

	assert_int(state.map.owner_at(state.tile_index(2, 2))).is_equal(Faction.PLAYER)
	assert_int(state.map.anchor_at(state.tile_index(2, 2))).is_equal(MapSlice.ANCHOR_NODE)
	assert_int(state.map.owner_at(state.tile_index(3, 1))).is_equal(Faction.NONE)
	assert_int(state.map.owner_at(state.tile_index(5, 1))).is_equal(Faction.NONE)
	assert_int(state.map.anchor_at(state.tile_index(3, 1))).is_equal(MapSlice.ANCHOR_NONE)


func test_closest_node_wins_and_a_tie_keeps_the_current_owner_else_the_lowest_id() -> void:
	var state := _map(7)
	GameStateSetup.add_node(state, state.tile_index(1, 1), Faction.AI, 2)
	GameStateSetup.add_node(state, state.tile_index(5, 1), Faction.PLAYER, 2)
	_recompute(state)
	assert_int(state.map.owner_at(state.tile_index(2, 1))).is_equal(Faction.AI)
	assert_int(state.map.owner_at(state.tile_index(3, 1))).is_equal(Faction.AI)

	GameStateSetup.set_tile_owner(state, state.tile_index(3, 1), Faction.PLAYER)
	_recompute(state)

	assert_int(state.map.owner_at(state.tile_index(3, 1))).is_equal(Faction.PLAYER)
	assert_int(state.map.owner_at(state.tile_index(4, 1))).is_equal(Faction.PLAYER)


func test_changes_are_recorded_and_grouped_neutral_first() -> void:
	var state := _map(7)
	GameStateSetup.add_node(state, state.tile_index(1, 1), Faction.PLAYER, 1)
	GameStateSetup.set_tile_owner(state, state.tile_index(6, 0), Faction.AI)
	GameStateSetup.set_turn(state, 4)

	var groups := _recompute(state)

	assert_int(groups.size()).is_equal(2)
	assert_array([groups[0][1], groups[0][2]]).is_equal([Faction.NONE, Faction.PLAYER])
	assert_int(groups[0][0].size()).is_equal(9)
	assert_array([groups[1][1], groups[1][2]]).is_equal([Faction.AI, Faction.NONE])
	var tile := state.tile_index(0, 0)
	assert_int(state.map._tile_change_turn[tile]).is_equal(4)
	assert_int(state.map._tile_prev_owner[tile]).is_equal(Faction.NONE)
	assert_int(state.map._tile_change_cause[tile]).is_equal(MapSlice.CAUSE_CAPTURE)
	assert_array(_recompute(state)).is_empty()


func test_ruin_tile_survives_its_nodes_and_falls_to_another_faction_only() -> void:
	var state := _map(7)
	var tile := state.tile_index(3, 1)
	TerritoryRules.recolor_zone(state, Faction.PLAYER, PackedInt32Array([tile]), MapSlice.CAUSE_RUIN)
	_recompute(state)
	assert_int(state.map.owner_at(tile)).is_equal(Faction.PLAYER)
	assert_int(state.map.anchor_at(tile)).is_equal(MapSlice.ANCHOR_RUIN)

	GameStateSetup.add_node(state, state.tile_index(4, 1), Faction.AI, 1)
	_recompute(state)

	assert_int(state.map.owner_at(tile)).is_equal(Faction.AI)
	assert_int(state.map.anchor_at(tile)).is_equal(MapSlice.ANCHOR_NODE)


func test_ruin_tile_under_a_node_of_its_own_faction_stays_a_ruin_tile() -> void:
	var state := _map(7)
	var tile := state.tile_index(3, 1)
	TerritoryRules.recolor_zone(state, Faction.PLAYER, PackedInt32Array([tile]), MapSlice.CAUSE_RUIN)
	GameStateSetup.add_node(state, state.tile_index(4, 1), Faction.PLAYER, 1)

	_recompute(state)

	assert_int(state.map.owner_at(tile)).is_equal(Faction.PLAYER)
	assert_int(state.map.anchor_at(tile)).is_equal(MapSlice.ANCHOR_RUIN)


func test_recolor_zone_writes_neutral_non_node_tiles_only() -> void:
	var state := _map(7)
	GameStateSetup.add_node(state, state.tile_index(0, 0), Faction.AI, 1)
	GameStateSetup.add_node(state, state.tile_index(6, 2), Faction.NONE, 1)
	_recompute(state)
	var zone := PackedInt32Array([state.tile_index(3, 1), state.tile_index(1, 1), state.tile_index(6, 2), state.tile_index(2, 1)])

	var changed := TerritoryRules.recolor_zone(state, Faction.PLAYER, zone, MapSlice.CAUSE_RUIN)

	assert_array(changed).is_equal(PackedInt32Array([state.tile_index(2, 1), state.tile_index(3, 1)]))
	assert_int(state.map.owner_at(state.tile_index(1, 1))).is_equal(Faction.AI)
	assert_int(state.map.anchor_at(state.tile_index(3, 1))).is_equal(MapSlice.ANCHOR_RUIN)
	assert_int(state.map._tile_change_cause[state.tile_index(3, 1)]).is_equal(MapSlice.CAUSE_RUIN)
