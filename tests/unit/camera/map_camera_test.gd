extends GdUnitTestSuite

const AREA := Rect2(0, 118, 390, 520)


func _camera() -> MapCamera:
	return MapCamera.new(12, 12, AREA)


func test_the_default_zoom_shows_eight_columns() -> void:
	var camera := _camera()

	assert_float(camera.tile_size).is_equal(48.0)  # floor(390 / 8)
	assert_vector(camera.center).is_equal(Vector2(6, 6))


func test_the_layout_projects_tiles_and_back() -> void:
	var camera := _camera()
	camera.center = Vector2(6, 6)

	for tile in [0, 11, 66, 143]:
		assert_int(camera.screen_to_tile(camera.tile_to_screen(tile))).is_equal(tile)
	assert_vector(camera.layout().origin + Vector2(6, 6) * 48.0).is_equal(AREA.get_center())


func test_scrolling_follows_the_finger_and_stops_at_the_margin() -> void:
	var camera := _camera()
	camera.center = Vector2(6, 6)

	camera.scroll(Vector2(-48, 0))  # the finger goes left: the map goes left, the centre goes right
	assert_vector(camera.center).is_equal(Vector2(7, 6))
	camera.scroll(Vector2(-10000, 0))
	var half_x := AREA.size.x / (2.0 * camera.tile_size)
	assert_float(camera.center.x).is_equal_approx(12 - half_x + MapCamera.EDGE_MARGIN_TILES, 0.0001)
	camera.scroll(Vector2(10000, 0))
	assert_float(camera.center.x).is_equal_approx(half_x - MapCamera.EDGE_MARGIN_TILES, 0.0001)


func test_a_map_smaller_than_the_area_stays_centred() -> void:
	var camera := MapCamera.new(4, 4, AREA)

	camera.scroll(Vector2(500, 500))

	assert_vector(camera.center).is_equal(Vector2(2, 2))


func test_the_zoom_is_bounded_and_keeps_the_tile_under_the_fingers() -> void:
	var camera := _camera()
	var anchor := Vector2(300, 250)
	var before := camera.layout().tile_at(anchor)

	camera.zoom(1.2, anchor)
	assert_float(camera.tile_size).is_equal_approx(57.6, 0.001)
	assert_int(camera.layout().tile_at(anchor)).is_equal(before)
	camera.zoom(100.0, anchor)
	assert_float(camera.tile_size).is_equal(MapCamera.MAX_TILE)
	assert_bool(camera.can_zoom_in()).is_false()
	camera.zoom(0.0001, anchor)
	assert_float(camera.tile_size).is_equal(MapCamera.MIN_TILE)
	assert_bool(camera.can_zoom_out()).is_false()
	assert_bool(camera.can_zoom_in()).is_true()


func test_a_tile_out_of_view_is_brought_in_by_the_smallest_shift() -> void:
	var camera := _camera()
	camera.center = Vector2(3, 3)
	assert_bool(camera.is_visible(11 * 12 + 11)).is_false()

	camera.ensure_visible(11 * 12 + 11, 1.0)

	assert_bool(camera.is_visible(11 * 12 + 11)).is_true()
	var visible := camera.center
	camera.ensure_visible(11 * 12 + 11, 1.0)  # already in view: no shift
	assert_vector(camera.center).is_equal(visible)


func test_a_recentre_is_animated_on_the_clock_and_instant_without_duration() -> void:
	var camera := _camera()
	camera.center = Vector2(6, 6)
	var target := 2 * 12 + 3  # tile (3, 2)

	camera.start_recenter(target, 10.0, 0.4)
	assert_vector(camera.center).is_equal(Vector2(6, 6))
	assert_bool(camera.tick(10.2)).is_true()
	assert_float(camera.center.x).is_less(6.0)
	assert_float(camera.center.x).is_greater(3.5)
	assert_bool(camera.tick(10.4)).is_false()
	var target_center := Vector2(3.5, 2.5)
	var half := AREA.size / (2.0 * camera.tile_size)
	assert_float(camera.center.x).is_equal_approx(maxf(target_center.x, half.x - MapCamera.EDGE_MARGIN_TILES), 0.0001)
	camera.center = Vector2(6, 6)
	camera.start_recenter(target, 0.0, 0.0)
	assert_float(camera.center.y).is_equal_approx(maxf(2.5, AREA.size.y / (2.0 * camera.tile_size) - MapCamera.EDGE_MARGIN_TILES), 0.0001)


func test_the_camera_is_remembered_and_given_back() -> void:
	var camera := _camera()
	camera.scroll(Vector2(-100, -100))
	camera.zoom(1.3, Vector2(200, 300))
	camera.remember()
	var centre := camera.center
	var size := camera.tile_size
	camera.scroll(Vector2(200, 200))
	camera.zoom(0.7, Vector2(100, 200))

	camera.restore()

	assert_vector(camera.center).is_equal(centre)
	assert_float(camera.tile_size).is_equal(size)


func test_restoring_without_a_memory_changes_nothing() -> void:
	var camera := _camera()
	var centre := camera.center

	camera.restore()

	assert_vector(camera.center).is_equal(centre)


func test_a_tile_already_in_view_does_not_move_the_camera() -> void:
	var camera := _camera()
	camera.center = Vector2(6, 6)
	var centre := camera.center

	camera.ensure_visible(6 * 12 + 6)
	camera.ensure_visible(5 * 12 + 5)

	assert_vector(camera.center).is_equal(centre)


## The tilted 3D map (ADR-0014): a row of screen covers `depth_scale` rows of ground.
func test_with_a_tilted_ground_a_vertical_drag_covers_more_rows_and_the_clamp_sees_deeper() -> void:
	var camera := MapCamera.new(12, 20, AREA)
	camera.depth_scale = 1.5
	camera.center = Vector2(6, 10)

	camera.scroll(Vector2(48, -48))  # one tile of screen each way

	assert_vector(camera.center).is_equal(Vector2(5, 11.5))  # one column, one and a half rows
	camera.center = Vector2(6, 0)
	camera.set_area(AREA)
	# half the ground seen: 520 / 48 / 2 * 1.5 rows, less the one-tile margin
	assert_float(camera.center.y).is_equal_approx(520.0 / 48.0 / 2.0 * 1.5 - MapCamera.EDGE_MARGIN_TILES, 0.0001)


func test_with_a_tilted_ground_a_pinch_keeps_the_ground_under_the_fingers() -> void:
	var camera := MapCamera.new(30, 30, AREA)
	camera.depth_scale = 1.5
	camera.center = Vector2(15, 15)
	var anchor := AREA.get_center() + Vector2(40, 60)
	var before := camera.center + Vector2(40.0, 60.0 * 1.5) / camera.tile_size

	camera.zoom(1.25, anchor)

	var after := camera.center + Vector2(40.0, 60.0 * 1.5) / camera.tile_size
	assert_vector(after).is_equal_approx(before, Vector2(0.0001, 0.0001))
