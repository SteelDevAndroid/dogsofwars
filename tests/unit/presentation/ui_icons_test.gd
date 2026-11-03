extends GdUnitTestSuite


func test_the_twenty_one_icons_exist_are_white_svg_on_a_24_grid_and_are_all_different() -> void:
	assert_int(UiIcons.NAMES.size()).is_equal(21)
	var sources := {}
	for icon_name: String in UiIcons.NAMES:
		var path := UiIcons.DIR % icon_name
		var text := FileAccess.get_file_as_string(path)
		assert_bool(text.contains('viewBox="0 0 24 24"')).override_failure_message(icon_name).is_true()
		assert_bool(text.contains('stroke-width="2"') and text.contains('stroke-linecap="square"')).override_failure_message(icon_name).is_true()
		assert_bool(text.contains('stroke="#FFFFFF"')).override_failure_message(icon_name).is_true()
		sources[text] = true
		var texture := UiIcons.texture(icon_name)
		assert_object(texture).override_failure_message(icon_name).is_not_null()
		assert_int(texture.get_width()).override_failure_message("%s imported at 4x" % icon_name).is_equal(96)
	assert_int(sources.size()).is_equal(21)  # no two icons are the same drawing


func test_an_icon_goes_on_a_button_at_the_shown_size() -> void:
	var button := Button.new()

	UiIcons.put(button, "pause")

	assert_object(button.icon).is_same(UiIcons.texture("pause"))
	assert_bool(button.expand_icon).is_true()
	assert_int(button.get_theme_constant("icon_max_width")).is_equal(UiIcons.SIZE)
	button.free()


func test_each_action_of_the_panel_has_its_icon_and_research_rows_have_none() -> void:
	assert_object(UiIcons.of_action(&"capture")).is_same(UiIcons.texture("noeud"))
	assert_object(UiIcons.of_action(&"wake")).is_same(UiIcons.texture("reveil"))
	assert_object(UiIcons.of_action(&"upgrade")).is_same(UiIcons.texture("montee_niveau"))
	assert_object(UiIcons.of_action(&"research:3")).is_null()


func test_the_framed_panel_is_a_nine_patch_with_24_px_margins() -> void:
	var panel := MenuLayout.framed_panel()

	var style := panel.get_theme_stylebox("panel") as StyleBoxTexture
	assert_array([style.texture.get_width(), style.texture.get_height()]).is_equal([96, 96])
	assert_array([style.texture_margin_left, style.texture_margin_top, style.texture_margin_right, style.texture_margin_bottom]).is_equal([24.0, 24.0, 24.0, 24.0])
	panel.free()
