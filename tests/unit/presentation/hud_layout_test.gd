extends GdUnitTestSuite

const PORTRAIT := Vector2(390, 844)
const LANDSCAPE := Vector2(844, 390)


func test_the_unit_follows_the_dpi_and_is_bounded() -> void:
	assert_float(UiScale.factor(320)).is_equal(2.0)
	assert_float(UiScale.factor(480)).is_equal(3.0)
	assert_float(UiScale.factor(96)).is_equal(1.0)  # never below 1
	assert_float(UiScale.factor(1000)).is_equal(4.0)  # never above 4
	assert_float(UiScale.factor(0)).is_equal(1.0)  # unknown
	assert_float(UiScale.factor(320, 1.5)).is_equal(3.0)


func test_a_window_takes_the_scale_of_its_screen() -> void:
	var window := Window.new()

	UiScale.apply(window, 400)

	assert_float(window.content_scale_factor).is_equal(2.5)
	window.free()


func test_an_empty_safe_area_means_the_whole_screen() -> void:
	assert_object(SafeArea.in_viewport(PORTRAIT, Rect2i(), Vector2i.ZERO, 1.0)).is_equal(Rect2(Vector2.ZERO, PORTRAIT))
	assert_object(SafeArea.in_viewport(PORTRAIT, Rect2i(0, 0, 0, 800), Vector2i.ZERO, 1.0)).is_equal(Rect2(Vector2.ZERO, PORTRAIT))


func test_the_safe_area_is_brought_into_viewport_units_and_clipped() -> void:
	# a 2x display 780 x 1688 px with a 96 px notch on top and a 68 px gesture bar below
	var safe := SafeArea.in_viewport(PORTRAIT, Rect2i(0, 96, 780, 1688 - 96 - 68), Vector2i.ZERO, 2.0)

	assert_object(safe).is_equal(Rect2(0, 48, 390, 762))
	# a window not at the origin of the screen
	var moved := SafeArea.in_viewport(PORTRAIT, Rect2i(100, 120, 780, 1500), Vector2i(100, 24), 2.0)
	assert_object(moved).is_equal(Rect2(0, 48, 390, 750))


func test_a_safe_area_outside_the_window_falls_back_to_the_whole_screen() -> void:
	assert_object(SafeArea.in_viewport(PORTRAIT, Rect2i(5000, 5000, 100, 100), Vector2i.ZERO, 1.0)).is_equal(Rect2(Vector2.ZERO, PORTRAIT))


func test_portrait_gives_the_map_what_the_bars_leave() -> void:
	var layout := HudLayout.compute(PORTRAIT, Rect2(Vector2.ZERO, PORTRAIT), 130.0, 300.0)

	assert_bool(layout.landscape).is_false()
	assert_object(layout.top_zone).is_equal(Rect2(0, 0, 390, 130))
	assert_object(layout.panel_zone).is_equal(Rect2(0, 544, 390, 300))
	assert_object(layout.map_area).is_equal(Rect2(0, 130, 390, 414))


func test_portrait_respects_the_safe_area() -> void:
	var safe := Rect2(0, 48, 390, 762)

	var layout := HudLayout.compute(PORTRAIT, safe, 130.0, 300.0)

	assert_float(layout.top_zone.position.y).is_equal(48.0)
	assert_float(layout.panel_zone.end.y).is_equal(810.0)
	assert_float(layout.map_area.position.y).is_equal(178.0)
	assert_float(layout.map_area.end.y).is_equal(510.0)


func test_a_tall_hud_never_takes_the_map_below_its_floor() -> void:
	var layout := HudLayout.compute(PORTRAIT, Rect2(Vector2.ZERO, PORTRAIT), 400.0, 600.0)

	assert_float(layout.map_area.size.y).is_greater_equal(PORTRAIT.y * HudLayout.MIN_MAP_SHARE - 0.01)
	assert_float(layout.top_zone.size.y + layout.panel_zone.size.y + layout.map_area.size.y).is_equal_approx(PORTRAIT.y, 0.01)


func test_landscape_puts_a_rail_on_the_left_and_the_panel_on_the_right() -> void:
	var layout := HudLayout.compute(LANDSCAPE, Rect2(Vector2.ZERO, LANDSCAPE), 130.0, 300.0)

	assert_bool(layout.landscape).is_true()
	assert_object(layout.top_zone).is_equal(Rect2(0, 0, 140, 390))
	assert_object(layout.panel_zone).is_equal(Rect2(844 - 224, 0, 224, 390))
	assert_object(layout.map_area).is_equal(Rect2(140, 0, 844 - 140 - 224, 390))


func test_landscape_keeps_out_of_the_notch() -> void:
	var safe := Rect2(44, 12, 844 - 44 - 20, 390 - 12)

	var layout := HudLayout.compute(LANDSCAPE, safe, 130.0, 300.0)

	assert_float(layout.top_zone.position.x).is_equal(44.0)
	assert_float(layout.panel_zone.end.x).is_equal(824.0)
	assert_float(layout.map_area.position.x).is_equal(184.0)
	assert_float(layout.map_area.end.x).is_equal(600.0)


func test_the_camera_buttons_sit_at_the_bottom_right_of_the_map() -> void:
	for screen in [PORTRAIT, LANDSCAPE]:
		var layout := HudLayout.compute(screen, Rect2(Vector2.ZERO, screen), 130.0, 300.0)

		assert_float(layout.camera_buttons.size.x).is_equal(48.0)
		assert_float(layout.camera_buttons.size.y).is_equal(3.0 * 48.0 + 2.0 * 8.0)
		assert_float(layout.camera_buttons.end.x).is_equal(layout.map_area.end.x - 8.0)
		assert_float(layout.camera_buttons.end.y).is_equal(layout.map_area.end.y - 8.0)
		assert_bool(layout.map_area.encloses(layout.camera_buttons)).is_true()
