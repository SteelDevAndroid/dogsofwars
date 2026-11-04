extends GdUnitTestSuite


func _maps() -> Array[MapDefinition]:
	var catalog := CatalogFactory.standard()
	var maps: Array[MapDefinition] = []
	for file in Bootstrap.MAP_FILES:
		var errors: Array[DataError] = []
		maps.append(MapDefinition.parse(FileAccess.get_file_as_string("res://assets/data/" + file), file, catalog, errors))
	return maps


func _screen() -> MapChoiceScreen:
	var screen := MapChoiceScreen.new()
	add_child(screen)
	screen.configure(_maps())
	return screen


func test_one_card_per_map_with_its_name_its_size_and_its_sentence() -> void:
	var screen := _screen()
	var maps := _maps()

	assert_int(screen.cards_box.get_child_count()).is_equal(maps.size())
	for index in maps.size():
		assert_str(screen.titles[index].text).is_equal(maps[index].title)
		var texts := screen.cards_box.get_child(index).find_children("*", "Label", true, false).map(func(label: Node) -> String: return (label as Label).text)
		assert_bool(texts.has("%d × %d" % [maps[index].width, maps[index].height])).is_true()
		assert_bool(texts.has(maps[index].summary)).is_true()
	screen.free()


func test_a_play_button_names_the_map_and_random_and_back_are_offered() -> void:
	var screen := _screen()
	var seen := []
	screen.map_chosen.connect(func(index: int) -> void: seen.append(index))
	var randoms := [0]
	screen.random_requested.connect(func() -> void: randoms[0] += 1)
	var backs := [0]
	screen.back_requested.connect(func() -> void: backs[0] += 1)

	screen.play_buttons[1].pressed.emit()
	screen.play_buttons[0].pressed.emit()
	screen.random_button.pressed.emit()
	screen.back_button.pressed.emit()

	assert_array(seen).is_equal([1, 0])
	assert_array([randoms[0], backs[0]]).is_equal([1, 1])
	for button in [screen.random_button, screen.back_button] + screen.play_buttons:
		assert_float((button as Button).custom_minimum_size.y).is_greater_equal(48.0)
	screen.free()


func test_configuring_again_replaces_the_cards() -> void:
	var screen := _screen()

	screen.configure([_maps()[0]] as Array[MapDefinition])
	await await_idle_frame()

	assert_int(screen.play_buttons.size()).is_equal(1)
	assert_int(screen.cards_box.get_child_count()).is_equal(1)
	screen.free()


func test_the_thumbnail_shows_the_relief_and_nothing_secret() -> void:
	var map := _maps()[0]
	var thumbnail := MapThumbnail.new()
	thumbnail.size = Vector2(96, 96)
	add_child(thumbnail)

	thumbnail.show_map(map)

	assert_float(thumbnail.cell_size()).is_equal(floorf(96.0 / maxf(map.width, map.height)))
	await await_idle_frame()  # drawn without error
	# what it draws: one square per tile from the terrain, never a node, a ruin or a start
	for source in ["nodes", "ruin_zones", "starts", "dormants", "units"]:
		assert_bool(FileAccess.get_file_as_string("res://src/presentation/menus/map_thumbnail.gd").contains("_map.%s" % source)).override_failure_message(source).is_false()
	thumbnail.free()


func test_the_shipped_maps_have_a_title_and_a_sentence_that_tell_no_secret() -> void:
	for map in _maps():
		assert_str(map.title).is_not_empty()
		assert_str(map.summary).is_not_empty()
		assert_bool(map.summary.length() <= 160).is_true()  # readable at a glance
		for secret in ["ruine", "fragment", "dormant"]:
			assert_bool(map.summary.to_lower().contains(secret)).override_failure_message("%s: %s" % [map.id, secret]).is_false()
