extends GdUnitTestSuite

const SEED := 2024
const STATES := 120


func _snapshot(state: GameState) -> TileSnapshot:
	return TileSnapshot.take(state, CatalogFactory.standard())


func _new_game() -> GameState:
	var catalog := CatalogFactory.standard()
	return GameStateFactory.new_game(catalog, TestSessionFactory.shipped_map(catalog), 3)


func test_at_the_start_most_of_the_map_is_undiscovered_and_blank() -> void:
	var state := _new_game()
	var snapshot := _snapshot(state)
	var dark := 0

	for tile in snapshot.columns * snapshot.rows:
		if snapshot.fog_at(tile) == VisionService.FOG_UNDISCOVERED:
			dark += 1
			assert_int(snapshot.owners[tile]).is_equal(Faction.NONE)
			assert_int(snapshot.terrain[tile]).is_equal(TerrainGrid.PLAIN)  # the real terrain does not show

	assert_bool(dark > 60).is_true()
	assert_int(snapshot.fog_at(state.tile_index(1, 2))).is_equal(VisionService.FOG_VISIBLE)


func test_the_enemy_units_and_nodes_out_of_view_are_not_in_the_snapshot() -> void:
	var snapshot := _snapshot(_new_game())

	for unit: Array in snapshot.units:
		assert_int(unit[2]).is_not_equal(Faction.AI)
	for node: Array in snapshot.nodes:
		assert_int(node[1]).is_not_equal(Faction.AI)
	# the three drawn ruins are visible under the fog from the start (GDD 5 rule 6)
	assert_int(snapshot.ruins.size()).is_equal(3)


func test_an_explored_tile_keeps_its_memory_but_shows_no_unit() -> void:
	var state := MapBuilder.state(PackedStringArray(["............", "............", "............", "............", "............", "............"]))
	var scout := MapBuilder.unit(state, 0, Faction.PLAYER, 0, 0)
	MapBuilder.unit(state, 5, Faction.AI, 3, 0)
	MapBuilder.ready(state)
	var tile := state.tile_index(3, 0)
	var before := _snapshot(state)
	assert_int(before.fog_at(tile)).is_equal(VisionService.FOG_VISIBLE)
	assert_array(before.unit_on(tile)).is_not_empty()

	UnitWrites.move_to(state, scout, state.tile_index(11, 5))
	VisionService.recompute(state, StateFactory.vision_context(state))
	var after := _snapshot(state)

	assert_int(after.fog_at(tile)).is_equal(VisionService.FOG_EXPLORED)
	assert_array(after.unit_on(tile)).is_empty()  # the unit seen there is not remembered
	assert_int(after.terrain[tile]).is_equal(TerrainGrid.PLAIN)


func test_the_snapshot_of_random_states_never_shows_what_the_player_cannot_see() -> void:
	var states := StateFactory.random_states(STATES, SEED)
	var enemy_seen := 0
	for k in states.size():
		var state := states[k]
		var snapshot := _snapshot(state)
		var context := "seed %d state %d" % [SEED, k]
		for unit: Array in snapshot.units:
			if unit[2] != Faction.PLAYER:
				assert_int(snapshot.fog_at(unit[1])).override_failure_message(context + ": a unit out of view").is_equal(VisionService.FOG_VISIBLE)
				enemy_seen += 1
		for tile in snapshot.columns * snapshot.rows:
			if snapshot.fog_at(tile) == VisionService.FOG_UNDISCOVERED:
				assert_int(snapshot.owners[tile]).override_failure_message(context).is_equal(Faction.NONE)
		for node: Array in snapshot.nodes:
			assert_int(snapshot.fog_at(node[0])).override_failure_message(context + ": an undiscovered node").is_not_equal(VisionService.FOG_UNDISCOVERED)
	assert_int(enemy_seen).override_failure_message("no visible enemy unit in any state: vacuous").is_greater(10)


func test_the_fog_level_has_three_states() -> void:
	var state := _new_game()

	assert_int(VisionService.fog_level(state, Faction.PLAYER, state.tile_index(1, 2))).is_equal(VisionService.FOG_VISIBLE)
	assert_int(VisionService.fog_level(state, Faction.PLAYER, state.tile_index(10, 9))).is_equal(VisionService.FOG_UNDISCOVERED)
	assert_int(VisionService.fog_level(state, Faction.AI, state.tile_index(10, 9))).is_equal(VisionService.FOG_VISIBLE)
