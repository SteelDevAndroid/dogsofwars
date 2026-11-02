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


func _snapshot(fog: Array, columns: int, rows: int) -> TileSnapshot:
	var snapshot := TileSnapshot.new()
	snapshot.columns = columns
	snapshot.rows = rows
	snapshot.fog = PackedByteArray(fog)
	return snapshot


func test_the_grain_is_fixed_bounded_and_not_flat() -> void:
	var seen := {}
	for tile in 144:
		var grain := TileRenderer.grain(tile)
		assert_float(grain).is_between(-TileRenderer.GRAIN, TileRenderer.GRAIN)
		assert_float(TileRenderer.grain(tile)).is_equal(grain)  # the same tile, the same value
		seen[snappedf(grain, 0.005)] = true
	assert_int(seen.size()).is_greater(6)  # varied: it is not one constant
	var low := 0
	var high := 0
	for tile in 144:
		low += 1 if TileRenderer.grain(tile) < 0.0 else 0
		high += 1 if TileRenderer.grain(tile) > 0.0 else 0
	assert_bool(low > 20 and high > 20).is_true()  # darker and lighter alike


func test_a_tile_touching_the_fog_knows_which_sides() -> void:
	var renderer := TileRenderer.new()
	# 3 x 3: the centre column is the unknown, the left column is seen
	var undiscovered := VisionService.FOG_UNDISCOVERED
	var visible := VisionService.FOG_VISIBLE
	renderer.snapshot = _snapshot([visible, undiscovered, undiscovered, visible, visible, undiscovered, visible, visible, visible], 3, 3)

	assert_int(renderer.fog_sides(0)).is_equal(TileRenderer.SIDE_RIGHT)
	assert_int(renderer.fog_sides(1)).is_equal(0)  # an undiscovered tile has no edge to soften
	assert_int(renderer.fog_sides(4)).is_equal(TileRenderer.SIDE_UP | TileRenderer.SIDE_RIGHT)
	assert_int(renderer.fog_sides(6)).is_equal(0)
	assert_int(renderer.fog_sides(5 - 3)).is_equal(0)
	renderer.snapshot = _snapshot([visible, undiscovered, visible, undiscovered, visible, visible, visible, visible, visible], 3, 3)
	assert_int(renderer.fog_sides(0)).is_equal(TileRenderer.SIDE_RIGHT | TileRenderer.SIDE_DOWN)
	assert_int(renderer.fog_sides(2)).is_equal(TileRenderer.SIDE_LEFT)
	assert_int(renderer.fog_sides(4)).is_equal(TileRenderer.SIDE_UP | TileRenderer.SIDE_LEFT)
	renderer.free()


func test_the_map_edge_is_not_a_fog_edge() -> void:
	var renderer := TileRenderer.new()
	renderer.snapshot = _snapshot([VisionService.FOG_VISIBLE, VisionService.FOG_VISIBLE, VisionService.FOG_VISIBLE, VisionService.FOG_VISIBLE], 2, 2)

	for tile in 4:
		assert_int(renderer.fog_sides(tile)).is_equal(0)
	renderer.snapshot = null
	assert_int(renderer.fog_sides(0)).is_equal(0)  # no snapshot
	renderer.free()
