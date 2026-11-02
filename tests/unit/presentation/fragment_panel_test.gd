extends GdUnitTestSuite


func test_it_shows_title_source_and_text_and_is_dead_until_the_delay() -> void:
	var panel := FragmentPanel.new()
	add_child(panel)

	panel.open(4, 10.0, 0.5, "La dernière lampe", "Pour qui allume-t-on ?", "Terminal")

	assert_str(panel.title_label.text).is_equal("La dernière lampe")
	assert_str(panel.source_label.text).is_equal("Terminal")
	assert_bool(panel.source_label.visible).is_true()
	assert_str(panel.body_label.text).is_equal("Pour qui allume-t-on ?")
	assert_bool(panel.is_open).is_true()
	panel.tick(10.4)
	assert_bool(panel.continue_button.disabled).is_true()
	panel.tick(10.5)
	assert_bool(panel.continue_button.disabled).is_false()
	panel.free()


func test_without_a_text_it_falls_back_to_the_number() -> void:
	var panel := FragmentPanel.new()
	add_child(panel)

	panel.open(7, 0.0, 0.5)

	assert_str(panel.title_label.text).is_equal("Fragment 7")
	assert_str(panel.body_label.text).is_equal("Un fragment rejoint la chronique.")
	assert_bool(panel.source_label.visible).is_false()
	panel.free()


func test_the_text_scrolls_inside_the_panel_and_starts_at_the_top() -> void:
	var panel := FragmentPanel.new()
	add_child(panel)
	assert_object(panel.body_label.get_parent()).is_same(panel.scroll)
	assert_int(panel.scroll.horizontal_scroll_mode).is_equal(ScrollContainer.SCROLL_MODE_DISABLED)

	panel.scroll.scroll_vertical = 50
	panel.open(1, 0.0, 0.5, "T", "texte", "S")

	assert_int(panel.scroll.scroll_vertical).is_equal(0)
	panel.free()
