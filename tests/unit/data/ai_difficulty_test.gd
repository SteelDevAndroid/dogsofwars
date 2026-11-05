extends GdUnitTestSuite


func test_normal_is_the_tuned_data() -> void:
	var ai := CatalogFactory.standard().ai

	assert_int(ai.planner("w_damage")).is_equal(10)
	assert_int(ai.planner("w_danger")).is_equal(6)


func test_easy_halves_the_aggression_weights_and_drops_the_calendar() -> void:
	var ai := CatalogFactory.standard().ai
	var calendar_turn := 12
	assert_int(ai.calendar_protocols(calendar_turn).size()).is_greater(0)

	ai.set_difficulty(AiParams.EASY)

	assert_int(ai.planner("w_damage")).is_equal(5)
	assert_int(ai.planner("w_lethal")).is_equal(15)
	assert_int(ai.planner("w_node")).is_equal(6)
	assert_int(ai.planner("w_danger")).is_equal(6)  # prudence is not touched
	assert_int(ai.calendar_protocols(calendar_turn).size()).is_equal(0)


func test_hard_raises_them_by_half_and_keeps_the_calendar() -> void:
	var ai := CatalogFactory.standard().ai

	ai.set_difficulty(AiParams.HARD)

	assert_int(ai.planner("w_damage")).is_equal(15)
	assert_int(ai.planner("w_lethal")).is_equal(45)
	assert_int(ai.calendar_protocols(12).size()).is_greater(0)


func test_an_unknown_level_is_clamped() -> void:
	var ai := CatalogFactory.standard().ai

	ai.set_difficulty(9)

	assert_int(ai.planner("w_damage")).is_equal(15)


func test_the_setting_is_bounded_and_defaults_to_normal() -> void:
	assert_int(GameSettings.defaults()[GameSettings.DIFFICULTY]).is_equal(AiParams.NORMAL)
	assert_bool(GameSettings.is_valid(GameSettings.DIFFICULTY, 3)).is_false()
