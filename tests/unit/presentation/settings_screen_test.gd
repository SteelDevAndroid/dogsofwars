extends GdUnitTestSuite


func _screen() -> SettingsScreen:
	var screen := SettingsScreen.new()
	add_child(screen)
	screen.configure(GameSettings.defaults())
	return screen


func test_it_shows_the_given_settings_without_announcing_a_change() -> void:
	var screen := SettingsScreen.new()
	add_child(screen)
	var seen := []
	screen.changed.connect(func(key: StringName, value: int) -> void: seen.append([key, value]))
	var settings := GameSettings.defaults()
	settings[GameSettings.TEXT_SCALE] = 150
	settings[GameSettings.ENEMY_SPEED] = 2
	settings[GameSettings.COLORBLIND] = 1
	settings[GameSettings.SHOW_RANGE] = 0

	screen.configure(settings)

	assert_int(screen.scale_option.selected).is_equal(2)
	assert_int(screen.speed_option.selected).is_equal(2)
	assert_bool(screen.colorblind_check.button_pressed).is_true()
	assert_bool(screen.show_range_check.button_pressed).is_false()
	assert_bool(screen.reduced_motion_check.button_pressed).is_false()
	assert_bool(screen.left_panel_check.button_pressed).is_false()
	assert_bool(screen.hints_check.button_pressed).is_true()
	assert_array(seen).is_empty()
	screen.free()


func test_each_control_announces_its_key_and_value() -> void:
	var screen := _screen()
	var seen := []
	screen.changed.connect(func(key: StringName, value: int) -> void: seen.append([key, value]))

	screen.scale_option.item_selected.emit(1)
	screen.speed_option.item_selected.emit(1)
	screen.reduced_motion_check.button_pressed = true
	screen.show_range_check.button_pressed = false
	screen.colorblind_check.button_pressed = true
	screen.left_panel_check.button_pressed = true
	screen.left_panel_check.button_pressed = false
	screen.hints_check.button_pressed = false

	assert_array(seen).is_equal([
		[GameSettings.TEXT_SCALE, 125], [GameSettings.ENEMY_SPEED, 1], [GameSettings.REDUCED_MOTION, 1],
		[GameSettings.SHOW_RANGE, 0], [GameSettings.COLORBLIND, 1], [GameSettings.LEFT_PANEL, 1], [GameSettings.LEFT_PANEL, 0], [GameSettings.HINTS, 0]])
	screen.free()


func test_back_is_announced() -> void:
	var screen := _screen()
	var backs := [0]
	screen.back_requested.connect(func() -> void: backs[0] += 1)

	screen.back_button.pressed.emit()

	assert_int(backs[0]).is_equal(1)
	screen.free()


func test_the_menus_offer_the_settings() -> void:
	var menu := MainMenu.new()
	var pause := PauseMenu.new()
	var asked := [0, 0]
	menu.settings_requested.connect(func() -> void: asked[0] += 1)
	pause.settings_requested.connect(func() -> void: asked[1] += 1)

	menu.settings_button.pressed.emit()
	pause.settings_button.pressed.emit()

	assert_array(asked).is_equal([1, 1])
	menu.free()
	pause.free()


func test_the_main_menu_puts_the_play_buttons_first_and_the_rest_in_the_background() -> void:
	var menu := MainMenu.new()
	add_child(menu)

	assert_int(menu.new_game_button.get_theme_font_size("font_size")).is_equal(20)
	assert_int(menu.continue_button.get_theme_font_size("font_size")).is_equal(20)
	assert_int(menu.settings_button.get_theme_font_size("font_size")).is_not_equal(20)
	assert_bool(menu.quit_button.flat).is_true()
	assert_bool(menu.chronicle_button.flat).is_false()
	assert_float(menu.chronicle_button.custom_minimum_size.y).is_greater_equal(48.0)
	var pictures := menu.get_children().filter(func(child: Node) -> bool: return child is TextureRect)
	assert_int(pictures.size()).is_equal(1)  # the illustration, behind the column
	assert_object((pictures[0] as TextureRect).texture).is_not_null()
	menu.free()
