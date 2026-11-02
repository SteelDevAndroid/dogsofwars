extends GdUnitTestSuite


func _screen(found: Array) -> ChronicleScreen:
	var screen := ChronicleScreen.new()
	add_child(screen)
	screen.show_chronicle(CatalogFactory.standard().fragments, found)
	return screen


func _texts(screen: ChronicleScreen) -> Array:
	return screen.entries_box.get_children().map(func(label: Label) -> String: return label.text)


func test_an_empty_chronicle_shows_five_empty_slots() -> void:
	var screen := _screen([])

	assert_str(screen.bar_label.text).is_equal("○○○○○   0 / 5")
	assert_int(_texts(screen).size()).is_equal(5)
	assert_array(_texts(screen)).contains_exactly(["○  Fragment non trouvé", "○  Fragment non trouvé", "○  Fragment non trouvé", "○  Fragment non trouvé", "○  Fragment non trouvé"])
	screen.free()


func test_found_fragments_show_their_text_in_the_order_of_the_ids() -> void:
	var screen := _screen([[Faction.PLAYER, 3], [Faction.PLAYER, 1]])

	assert_str(screen.bar_label.text).is_equal("●○●○○   2 / 5")
	var texts := _texts(screen)
	assert_str(texts[0]).contains("Un ordre.").contains("Journal").contains("Fragment")
	assert_str(texts[1]).contains("non trouvé")
	assert_str(texts[2]).contains("On a allumé le relais.")
	screen.free()


func test_a_complete_chronicle_and_unknown_ids() -> void:
	var screen := _screen([[0, 1], [0, 2], [0, 3], [0, 4], [0, 5], [0, 99], [1, 1]])

	assert_str(screen.bar_label.text).is_equal("●●●●●   5 / 5")  # 99 (removed content) and the other faction are not counted
	assert_int(_texts(screen).size()).is_equal(5)
	screen.free()


func test_showing_again_replaces_the_entries() -> void:
	var screen := _screen([[0, 1]])
	screen.show_chronicle(CatalogFactory.standard().fragments, [])
	await await_idle_frame()

	assert_int(screen.entries_box.get_child_count()).is_equal(5)
	assert_str(screen.bar_label.text).is_equal("○○○○○   0 / 5")
	screen.free()


func test_back_is_announced_and_the_menu_offers_the_chronicle() -> void:
	var screen := _screen([])
	var menu := MainMenu.new()
	var seen := [0, 0]
	screen.back_requested.connect(func() -> void: seen[0] += 1)
	menu.chronicle_requested.connect(func() -> void: seen[1] += 1)

	screen.back_button.pressed.emit()
	menu.chronicle_button.pressed.emit()

	assert_array(seen).is_equal([1, 1])
	screen.free()
	menu.free()
