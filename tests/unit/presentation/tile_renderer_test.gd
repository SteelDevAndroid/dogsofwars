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


func test_every_unit_type_has_its_sprite_and_the_catalog_maps_types_to_them() -> void:
	var renderer := _renderer()

	assert_array(Array(renderer._type_keys)).is_equal(TileRenderer.UNIT_KEYS)  # the catalog's order is the sprites' order
	var sizes := {}
	for key: String in TileRenderer.UNIT_KEYS:
		var texture: Texture2D = renderer._units[key]
		assert_array([texture.get_width(), texture.get_height()]).is_equal([256, 256])
		sizes[key] = FileAccess.get_file_as_bytes("res://assets/art/units/unit_%s.png" % key).size()
	assert_int(sizes.size()).is_equal(7)
	assert_int(renderer._nodes.size()).is_equal(3)
	assert_int(renderer._ruins.size()).is_equal(3)
	for texture: Texture2D in renderer._ruins:
		assert_array([texture.get_width(), texture.get_height()]).is_equal([256, 384])
	for fx in ["selection", "cible_crochets", "portee_point", "menace", "debris", "ruine_lueur"]:
		assert_object(renderer._fx[fx]).is_not_null()
	renderer.free()


func test_a_sprite_takes_the_colour_of_its_side_inside_its_silhouette_only() -> void:
	var renderer := _renderer()
	var grey: Texture2D = renderer._units["assaut"]
	var teal := TilePalette.owner(Faction.PLAYER)

	var tinted: Texture2D = renderer._unit_sprite(1, Faction.PLAYER, false)
	var plain := grey.get_image()
	var coloured := tinted.get_image()
	plain.convert(Image.FORMAT_RGBA8)
	coloured.convert(Image.FORMAT_RGBA8)

	assert_array([coloured.get_width(), coloured.get_height()]).is_equal([256, 256])
	var inside := Vector2i(128, 128)  # the body of the assault drone
	assert_float(plain.get_pixelv(inside).a).is_greater(0.9)
	assert_float(coloured.get_pixelv(inside).g - coloured.get_pixelv(inside).r).is_greater(plain.get_pixelv(inside).g - plain.get_pixelv(inside).r + 0.05)  # greener than the grey
	assert_float(coloured.get_pixelv(inside).a).is_equal_approx(plain.get_pixelv(inside).a, 0.01)
	assert_float(coloured.get_pixelv(Vector2i(2, 2)).a).is_equal(0.0)  # outside stays transparent
	assert_object(renderer._unit_sprite(1, Faction.PLAYER, false)).is_same(tinted)  # made once
	assert_object(renderer._unit_sprite(1, Faction.AI, false)).is_not_same(tinted)
	assert_object(renderer._unit_sprite(1, Faction.PLAYER, true)).is_same(grey)  # a dormant drone is nobody's
	assert_object(teal).is_not_null()
	renderer.free()


func test_the_colour_blind_palette_makes_another_tint() -> void:
	var renderer := _renderer()
	var normal: Texture2D = renderer._unit_sprite(3, Faction.PLAYER, false)

	renderer.colorblind = true
	var blind: Texture2D = renderer._unit_sprite(3, Faction.PLAYER, false)

	assert_object(blind).is_not_same(normal)
	assert_bool(blind.get_image().get_pixel(128, 128) != normal.get_image().get_pixel(128, 128)).is_true()
	renderer.free()


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


func test_a_diagonal_beyond_the_map_edge_is_not_the_next_row() -> void:
	var renderer := TileRenderer.new()
	var undiscovered := VisionService.FOG_UNDISCOVERED
	var visible := VisionService.FOG_VISIBLE
	# tile 6 (row 2, column 0) is unknown: for tile 2 (row 0, column 2) the index of "one right, one down" is 6 too
	renderer.snapshot = _snapshot([visible, visible, visible, visible, visible, visible, undiscovered, visible, visible], 3, 3)

	assert_int(renderer.fog_corners(2)).is_equal(0)
	assert_int(renderer.fog_corners(3)).is_equal(0)  # tile 3 meets tile 6 by a side, and its other diagonals are off the map or seen
	assert_int(renderer.fog_sides(3)).is_equal(TileRenderer.SIDE_DOWN)
	renderer.free()
