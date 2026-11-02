extends GdUnitTestSuite


func _state(turn: int) -> GameState:
	var catalog := CatalogFactory.standard()
	var state := GameStateFactory.new_game(catalog, TestSessionFactory.shipped_map(catalog), 1)
	while state.turn() < turn:
		TurnWrites.begin_phase(state, Faction.PLAYER, HeaderSlice.PHASE_PLAYER, true)
	return state


func test_it_says_what_to_touch_before_and_after_a_selection() -> void:
	var state := _state(1)

	assert_str(HudHint.text(state, true, true, -1, false)).contains("Touchez une de vos unités")
	assert_str(HudHint.text(state, true, true, 3, false)).contains("case en surbrillance")
	assert_str(HudHint.text(state, true, true, -1, false)).is_not_equal(HudHint.text(state, true, true, 3, false))


func test_it_shows_for_the_first_two_turns_only() -> void:
	assert_str(HudHint.text(_state(2), true, true, -1, false)).is_not_empty()
	assert_str(HudHint.text(_state(3), true, true, -1, false)).is_empty()


func test_it_is_silent_when_off_in_the_enemy_phase_or_while_targeting() -> void:
	var state := _state(1)

	assert_str(HudHint.text(state, false, true, -1, false)).is_empty()
	assert_str(HudHint.text(state, true, false, -1, false)).is_empty()
	assert_str(HudHint.text(state, true, true, 3, true)).is_empty()
