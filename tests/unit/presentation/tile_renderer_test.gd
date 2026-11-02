extends GdUnitTestSuite


func _renderer() -> TileRenderer:
	var catalog := CatalogFactory.standard()
	var state := GameStateFactory.new_game(catalog, TestSessionFactory.shipped_map(catalog), 3)
	var renderer := TileRenderer.new()
	add_child(renderer)
	renderer.show_state(state, catalog)
	renderer.fit(Rect2(0, 118, 390, 520))
	return renderer


func test_the_renderer_draws_a_new_game_without_error() -> void:
	var renderer := _renderer()

	await await_idle_frame()
	renderer.set_selection(26, PackedInt32Array([27, 28]))
	await await_idle_frame()

	assert_int(renderer.process_priority).is_equal(10)
	assert_int(renderer.snapshot.columns).is_equal(12)
	assert_float(renderer.layout.tile_size).is_equal(32.0)
	renderer.free()


func test_a_renderer_without_a_snapshot_draws_nothing() -> void:
	var renderer := TileRenderer.new()
	add_child(renderer)

	await await_idle_frame()

	assert_object(renderer.snapshot).is_null()
	renderer.free()


func test_every_unit_type_has_its_own_silhouette() -> void:
	var sides := {}
	for type in 5:
		sides[TileRenderer._shape(type, Vector2.ZERO, 10.0).size()] = true

	assert_int(sides.size()).is_equal(5)


func test_terrain_and_owner_colours_follow_the_art_bible() -> void:
	assert_object(TilePalette.terrain(TerrainGrid.PLAIN)).is_equal(Color("4E5862"))
	assert_object(TilePalette.terrain(TerrainGrid.WATER)).is_not_equal(TilePalette.terrain(TerrainGrid.PLAIN))
	assert_object(TilePalette.owner(Faction.PLAYER)).is_equal(Color("1FA38F"))
	assert_object(TilePalette.owner(Faction.AI)).is_equal(Color("C49BEA"))
	assert_object(TilePalette.owner(Faction.NONE)).is_equal(TilePalette.NEUTRAL)
