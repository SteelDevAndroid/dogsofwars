extends GdUnitTestSuite


func _canyon() -> MapDefinition:
	var errors: Array[DataError] = []
	var map := MapDefinition.parse(FileAccess.get_file_as_string("res://assets/data/maps/canyon.json"), "canyon.json",
			CatalogFactory.standard(), errors)
	assert_array(errors).is_empty()
	return map


func test_the_canyon_is_a_playable_asymmetric_scenario() -> void:
	var map := _canyon()

	assert_bool(map.symmetric).is_false()
	assert_array([map.width, map.height]).is_equal([16, 16])
	assert_bool(Bootstrap.MAP_FILES.has("maps/canyon.json")).is_true()


func test_a_map_with_art_is_found_by_its_terrain() -> void:
	var map := _canyon()

	var colors := MapArt.colors_for(map.cells)

	assert_object(colors).is_not_null()
	assert_array([colors.get_width(), colors.get_height()]).is_equal([16, 16])


func test_a_map_without_art_and_a_missing_index_give_nothing() -> void:
	var plain := PackedByteArray()
	plain.resize(256)

	assert_object(MapArt.colors_for(plain)).is_null()
	assert_object(MapArt.colors_for(_canyon().cells, "res://assets/art/maps/absent.json")).is_null()
	assert_int(MapArt.ground(null, plain).size()).is_equal(0)


func test_the_signature_follows_the_terrain() -> void:
	var cells := _canyon().cells
	var changed := cells.duplicate()
	changed[0] = (changed[0] + 1) % 4

	assert_str(MapArt.signature(cells)).is_equal(MapArt.signature(cells.duplicate()))
	assert_str(MapArt.signature(cells)).is_not_equal(MapArt.signature(changed))
	assert_int(MapArt.signature(cells).length()).is_equal(64)


func test_the_ground_of_a_tile_stays_within_bounds_and_the_canyon_differs_from_the_salt() -> void:
	var map := _canyon()

	var ground := MapArt.ground(MapArt.colors_for(map.cells), map.cells)

	assert_int(ground.size()).is_equal(256)
	var low := lerpf(1.0, MapArt.RATIO_MIN, MapArt.STRENGTH) - 0.001
	var high := lerpf(1.0, MapArt.RATIO_MAX, MapArt.STRENGTH) + 0.001
	for color in ground:
		for channel in [color.r, color.g, color.b]:
			assert_bool(channel >= low and channel <= high).is_true()
	# two plain tiles of the picture: sand next to the canyon (2, 5), and the salt flat (9, 7)
	assert_bool(ground[5 * 16 + 2].is_equal_approx(ground[7 * 16 + 9])).is_false()


func test_a_map_view_gives_each_tile_the_ground_of_its_illustration() -> void:
	var view := MapView3D.new()
	add_child(view)
	var s := TileSnapshot.new()
	s.columns = 2
	s.rows = 1
	s.terrain = PackedByteArray([TerrainGrid.PLAIN, TerrainGrid.PLAIN])
	s.fog = PackedByteArray([VisionService.FOG_VISIBLE, VisionService.FOG_VISIBLE])
	s.owners = PackedByteArray([Faction.NONE, Faction.NONE])
	view.ground = PackedColorArray([Color(1.2, 1.0, 0.8), Color(0.9, 0.9, 0.9)])

	view.show_snapshot(s)

	var first := (view.tiles[0].material_override as ShaderMaterial).get_shader_parameter(&"ground") as Vector3
	assert_bool(first.is_equal_approx(Vector3(1.2, 1.0, 0.8))).is_true()
	view.free()


func test_the_thumbnail_takes_the_illustrations_colours_when_it_has_them() -> void:
	var map := _canyon()
	var thumbnail := MapThumbnail.new()
	thumbnail.size = Vector2(128, 128)
	add_child(thumbnail)

	thumbnail.show_map(map, MapArt.colors_for(map.cells))
	await await_idle_frame()  # drawn without error
	thumbnail.show_map(map, Image.create(4, 4, false, Image.FORMAT_RGB8))  # a wrong size falls back to the greys
	await await_idle_frame()

	thumbnail.free()


func test_the_ravines_are_a_symmetric_map_with_its_own_art() -> void:
	var errors: Array[DataError] = []
	var map := MapDefinition.parse(FileAccess.get_file_as_string("res://assets/data/maps/ravines.json"), "ravines.json",
			CatalogFactory.standard(), errors)

	assert_array(errors).is_empty()
	assert_bool(map.symmetric).is_true()
	assert_object(MapArt.colors_for(map.cells)).is_not_null()
	assert_bool(MapArt.signature(map.cells) != MapArt.signature(_canyon().cells)).is_true()
