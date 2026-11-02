extends GdUnitTestSuite


func test_the_map_is_fitted_and_centred_in_its_area() -> void:
	var layout := TileLayout.fitting(12, 12, Rect2(0, 118, 390, 520))

	assert_float(layout.tile_size).is_equal(32.0)  # limited by the height: floor(520 / 12) = 43 ... width 390 / 12 = 32
	assert_vector(layout.origin).is_equal(Vector2(3, 118 + (520 - 384) / 2.0))
	assert_vector(layout.rect_of(0).position).is_equal(layout.origin)
	assert_vector(layout.rect_of(13).position).is_equal(layout.origin + Vector2(32, 32))
	assert_vector(layout.center_of(0)).is_equal(layout.origin + Vector2(16, 16))


func test_a_point_maps_back_to_its_tile_and_outside_gives_minus_one() -> void:
	var layout := TileLayout.new(12, 12, 32.0, Vector2(3, 100))

	for tile in [0, 11, 12, 77, 143]:
		assert_int(layout.tile_at(layout.center_of(tile))).is_equal(tile)
	assert_int(layout.tile_at(Vector2(2.9, 100))).is_equal(-1)
	assert_int(layout.tile_at(Vector2(3, 99.9))).is_equal(-1)
	assert_int(layout.tile_at(Vector2(3 + 384, 100))).is_equal(-1)
	assert_int(layout.tile_at(Vector2(3, 100 + 384))).is_equal(-1)
	assert_int(layout.tile_at(Vector2(3 + 383.9, 100 + 383.9))).is_equal(143)


func test_a_tiny_area_still_gives_a_positive_tile() -> void:
	assert_float(TileLayout.fitting(12, 12, Rect2(0, 0, 3, 3)).tile_size).is_equal(1.0)
