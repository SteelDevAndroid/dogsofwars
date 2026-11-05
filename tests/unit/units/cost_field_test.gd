extends GdUnitTestSuite


func _view(rows: PackedStringArray) -> StateView:
	return MapBuilder.ready(MapBuilder.state(rows)).view()


func test_on_a_plain_the_cost_is_the_king_move_distance() -> void:
	var view := _view(PackedStringArray([".....", ".....", "....."]))

	var field := MovementRules.cost_field(view, 0, CatalogFactory.standard(), false)

	assert_int(field[view.tile_count() - 1]).is_equal(4)  # (4, 2): four diagonal-or-straight steps
	assert_int(field[0]).is_equal(0)


func test_water_is_walked_around_and_a_mountain_costs_its_entry() -> void:
	var view := _view(PackedStringArray(["..~..", "..~..", "....."]))
	var catalog := CatalogFactory.standard()

	var field := MovementRules.cost_field(view, 0, catalog, false)

	assert_int(field[2]).is_equal(MovementRules.UNREACHED)  # water
	assert_int(field[4]).is_equal(4)  # (4, 0): down to row 2 under the water, then up

	var hill := _view(PackedStringArray([".^."]))
	assert_int(MovementRules.cost_field(hill, 0, catalog, false)[1]).is_equal(catalog.terrain.entry_cost(TerrainGrid.MOUNTAIN))


func test_toward_counts_the_entry_of_the_tiles_on_the_way_to_the_origin() -> void:
	var view := _view(PackedStringArray([".^."]))
	var catalog := CatalogFactory.standard()
	var mountain := catalog.terrain.entry_cost(TerrainGrid.MOUNTAIN)

	var toward := MovementRules.cost_field(view, 2, catalog, true)

	assert_int(toward[1]).is_equal(1)  # from the mountain, one plain to enter
	assert_int(toward[0]).is_equal(mountain + 1)


func test_no_diagonal_between_two_impassable_tiles() -> void:
	var view := _view(PackedStringArray([".~", "~."]))

	assert_int(MovementRules.cost_field(view, 0, CatalogFactory.standard(), false)[3]).is_equal(MovementRules.UNREACHED)
