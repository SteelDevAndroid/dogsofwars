extends GdUnitTestSuite


func test_three_cards_with_their_titles_and_a_way_back() -> void:
	var screen := HowToPlayScreen.new()
	add_child(screen)
	var backs := [0]
	screen.back_requested.connect(func() -> void: backs[0] += 1)

	assert_int(screen.cards_box.get_child_count()).is_equal(3)
	var heads := screen.cards_box.get_children().map(func(card: Node) -> String: return (card.get_child(0).get_child(0) as Label).text)
	assert_array(heads).is_equal(["Déplacer", "Attaquer et prendre", "Ruines et fragments"])
	screen.back_button.pressed.emit()
	assert_int(backs[0]).is_equal(1)
	screen.free()


func test_the_cards_say_something_and_name_no_number_of_the_rules() -> void:
	for card: Array in HowToPlayScreen.CARDS:
		assert_str(card[1]).is_not_empty()
		assert_bool(card[1].length() <= 200).is_true()  # readable at a glance


func test_the_menu_offers_it() -> void:
	var menu := MainMenu.new()
	add_child(menu)
	var seen := [0]
	menu.how_to_play_requested.connect(func() -> void: seen[0] += 1)

	menu.how_to_play_button.pressed.emit()

	assert_int(seen[0]).is_equal(1)
	assert_float(menu.how_to_play_button.custom_minimum_size.y).is_greater_equal(48.0)
	menu.free()


func test_the_menu_screens_share_the_navy() -> void:
	var settings := SettingsScreen.new()
	var chronicle := ChronicleScreen.new()
	var how := HowToPlayScreen.new()
	for screen in [settings, chronicle, how]:
		add_child(screen)
		assert_object((screen.get_child(0) as ColorRect).color).is_equal(MenuLayout.NAVY)
		screen.free()
