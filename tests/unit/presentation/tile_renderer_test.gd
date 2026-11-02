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


func test_owner_colours_follow_the_art_bible() -> void:
	assert_object(TilePalette.owner(Faction.PLAYER)).is_equal(Color("1FA38F"))
	assert_object(TilePalette.owner(Faction.AI)).is_equal(Color("C49BEA"))
	assert_object(TilePalette.owner(Faction.NONE)).is_equal(TilePalette.NEUTRAL)


func _snapshot(fog: Array, columns: int, rows: int) -> TileSnapshot:
	var snapshot := TileSnapshot.new()
	snapshot.columns = columns
	snapshot.rows = rows
	snapshot.fog = PackedByteArray(fog)
	return snapshot


func test_a_tile_keeps_its_variant_and_the_three_are_used() -> void:
	var counts := [0, 0, 0]
	for tile in 144:
		var variant := TileRenderer.variant_of(tile)
		assert_int(variant).is_between(0, TileRenderer.VARIANTS - 1)
		assert_int(TileRenderer.variant_of(tile)).is_equal(variant)  # the same tile, the same variant
		counts[variant] += 1
	for count in counts:
		assert_int(count).is_greater(20)  # none is rare: 144 tiles, 48 each on average


func test_every_terrain_has_its_three_textures_a_fog_tile_and_the_strips() -> void:
	var renderer := TileRenderer.new()

	for code in [TerrainGrid.PLAIN, TerrainGrid.FOREST, TerrainGrid.MOUNTAIN, TerrainGrid.WATER]:
		var variants: Array = renderer._terrain[code]
		assert_int(variants.size()).is_equal(3)
		for texture: Texture2D in variants:
			assert_array([texture.get_width(), texture.get_height()]).is_equal([256, 256])
	for texture: Texture2D in [renderer._fog_texture, renderer._edge_texture, renderer._corner_out_texture, renderer._corner_in_texture]:
		assert_array([texture.get_width(), texture.get_height()]).is_equal([256, 256])
	assert_int(renderer.texture_filter).is_equal(CanvasItem.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS)
	renderer.free()


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


func test_the_arrow_of_the_first_turns_needs_a_tile_and_moves_unless_still() -> void:
	var renderer := _renderer()
	renderer.hint_tile = 26
	var clock := FakeClock.new()
	renderer.clock = clock

	await await_idle_frame()  # draws with the arrow, no error
	renderer.still = true
	await await_idle_frame()
	renderer.hint_tile = -1
	await await_idle_frame()

	assert_int(renderer.hint_tile).is_equal(-1)
	assert_bool(renderer.still).is_true()
	renderer.free()


func test_a_fog_only_on_the_diagonal_is_an_outer_corner() -> void:
	var renderer := TileRenderer.new()
	var undiscovered := VisionService.FOG_UNDISCOVERED
	var visible := VisionService.FOG_VISIBLE
	# 3 x 3, the top-left tile is unknown: the centre meets it by its corner only
	renderer.snapshot = _snapshot([undiscovered, visible, visible, visible, visible, visible, visible, visible, visible], 3, 3)

	assert_int(renderer.fog_corners(4)).is_equal(TileRenderer.CORNER_TL)
	assert_int(renderer.fog_sides(4)).is_equal(0)
	assert_int(renderer.fog_corners(1)).is_equal(0)  # the tile beside it has a side, not a corner
	assert_int(renderer.fog_sides(1)).is_equal(TileRenderer.SIDE_LEFT)
	assert_int(renderer.fog_corners(0)).is_equal(0)  # an unknown tile has none
	renderer.snapshot = _snapshot([visible, visible, visible, visible, visible, visible, visible, visible, undiscovered], 3, 3)
	assert_int(renderer.fog_corners(4)).is_equal(TileRenderer.CORNER_BR)
	renderer.snapshot = _snapshot([visible, visible, undiscovered, visible, visible, visible, undiscovered, visible, visible], 3, 3)
	assert_int(renderer.fog_corners(4)).is_equal(TileRenderer.CORNER_TR | TileRenderer.CORNER_BL)
	assert_int(renderer.fog_corners(0)).is_equal(0)
	renderer.snapshot = null
	assert_int(renderer.fog_corners(0)).is_equal(0)
	renderer.free()


func test_a_tile_beside_fog_on_a_side_has_no_outer_corner_for_that_side() -> void:
	var renderer := TileRenderer.new()
	var undiscovered := VisionService.FOG_UNDISCOVERED
	var visible := VisionService.FOG_VISIBLE
	# the left column is unknown: the middle tile has a left side, and neither left corner
	renderer.snapshot = _snapshot([undiscovered, visible, visible, undiscovered, visible, visible, undiscovered, visible, visible], 3, 3)

	assert_int(renderer.fog_sides(4)).is_equal(TileRenderer.SIDE_LEFT)
	assert_int(renderer.fog_corners(4)).is_equal(0)
	renderer.free()
