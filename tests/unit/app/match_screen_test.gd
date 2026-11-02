extends GdUnitTestSuite

const SCENE := "res://src/app/match_screen.tscn"


func _screen() -> MatchScreen:
	var screen: MatchScreen = load(SCENE).instantiate()
	add_child(screen)
	return screen


func test_the_scene_carries_the_runner_at_priority_20_and_the_other_nodes() -> void:
	var screen := _screen()

	assert_int(screen.ai_runner.process_priority).is_equal(20)
	assert_object(screen.world).is_instanceof(Node2D)
	assert_object(screen.hud_layer).is_instanceof(CanvasLayer)
	assert_object(screen.input_surface).is_instanceof(Control)
	screen.free()


func test_binding_starts_the_match_and_the_runner_plays_the_enemy_phase() -> void:
	var t := TestSessionFactory.new()
	var screen := _screen()
	var session := SessionFactory.new_game(t.app, t.map(), 6, screen.ports(t.sink), screen.runner_port())

	screen.bind(session)
	assert_array([session.state.turn(), session.state.header.value(HeaderSlice.PHASE)]).is_equal([1, HeaderSlice.PHASE_PLAYER])
	assert_bool(screen.end_turn().permitted).is_true()
	assert_bool(screen.ai_runner.is_running()).is_true()
	for step in 600:
		if not screen.ai_runner.is_running():
			break
		screen.ai_runner.advance()

	assert_array([session.state.turn(), session.state.header.value(HeaderSlice.PHASE)]).is_equal([2, HeaderSlice.PHASE_PLAYER])
	screen.shutdown()
	t.dispose()
	await await_idle_frame()


func test_shutdown_follows_the_adr_sequence_and_frees_the_screen() -> void:
	var t := TestSessionFactory.new()
	var screen := _screen()
	var session := SessionFactory.new_game(t.app, t.map(), 6, screen.ports(t.sink), screen.runner_port())
	screen.bind(session)
	screen.end_turn()

	screen.shutdown()

	assert_bool(screen.ai_runner.is_running()).is_false()
	assert_object(screen.session).is_null()
	assert_object(session.state).is_null()
	assert_bool(screen.is_queued_for_deletion()).is_true()
	assert_bool(screen.end_turn().permitted).is_false()
	screen.shutdown()  # idempotent
	t.dispose()
	await await_idle_frame()


func test_a_loaded_match_in_the_enemy_phase_is_resumed_by_the_screen() -> void:
	var t := TestSessionFactory.new()
	var first := _screen()
	var session := SessionFactory.new_game(t.app, t.map(), 6, first.ports(t.sink), first.runner_port())
	first.bind(session)
	first.end_turn()
	first.ai_runner.advance()
	first.ai_runner.advance()
	first.shutdown()
	t.dispose()

	var again := TestSessionFactory.new(t.files.restarted())
	var screen := _screen()
	var reason := [LoadResult.NONE]
	var loaded := SessionFactory.resume(again.app, screen.ports(again.sink), screen.runner_port(), reason)
	screen.bind(loaded)

	assert_str(reason[0]).is_equal(LoadResult.OK)
	assert_bool(screen.ai_runner.is_running()).is_true()
	screen.shutdown()
	again.dispose()
	await await_idle_frame()


func test_shutdown_releases_the_players_locks() -> void:
	var t := TestSessionFactory.new()
	var screen := _screen()
	var session := SessionFactory.new_game(t.app, t.map(), 6, screen.ports(t.sink), screen.runner_port())
	screen.bind(session)
	var gate := session.gate
	gate.lock(&"attack_animation")
	assert_bool(gate.is_locked(Faction.PLAYER, Command.EMITTER_PLAYER)).is_true()

	screen.shutdown()

	assert_bool(gate.is_locked(Faction.PLAYER, Command.EMITTER_PLAYER)).is_false()
	t.dispose()
	await await_idle_frame()


func _started(seed_value: int = 6) -> Array:
	var t := TestSessionFactory.new()
	var screen := _screen()
	var session := SessionFactory.new_game(t.app, t.map(), seed_value, screen.ports(t.sink), screen.runner_port())
	screen.bind(session)
	return [t, screen, session]


func test_binding_draws_the_map_and_fills_the_hud() -> void:
	var started := _started()
	var screen: MatchScreen = started[1]

	assert_object(screen.renderer.snapshot).is_not_null()
	assert_str(screen.hud.turn_label.text).is_equal("Tour 1 / 30")
	assert_bool(screen.hud.end_turn_button.disabled).is_false()
	assert_float(screen.renderer.layout.tile_size).is_greater(0.0)
	screen.shutdown()
	started[0].dispose()
	await await_idle_frame()


func test_tapping_a_unit_of_the_player_selects_it_and_shows_where_it_can_go() -> void:
	var started := _started()
	var screen: MatchScreen = started[1]
	var state: GameState = started[2].state
	var scout := state.view().unit_at(state.tile_index(2, 1))

	screen.on_tap_tile(state.tile_index(2, 1))

	assert_int(screen.selected_unit).is_equal(scout)
	assert_bool(screen.reachable.size() > 0).is_true()
	assert_bool(screen.reachable.has(state.tile_index(2, 1))).is_false()
	assert_str(screen.hud.unit_title.text).is_equal("Eclaireur")
	assert_int(screen.renderer.selected_tile).is_equal(state.tile_index(2, 1))
	screen.shutdown()
	started[0].dispose()
	await await_idle_frame()


func test_tapping_a_reachable_tile_moves_the_selected_unit() -> void:
	var started := _started()
	var screen: MatchScreen = started[1]
	var state: GameState = started[2].state
	var scout := state.view().unit_at(state.tile_index(2, 1))
	screen.on_tap_tile(state.tile_index(2, 1))
	var destination := screen.reachable[screen.reachable.size() - 1]

	screen.on_tap_tile(destination)

	assert_int(state.view().unit_tile(scout)).is_equal(destination)
	assert_bool(state.view().unit_moved(scout)).is_true()
	assert_int(screen.selected_unit).is_equal(-1)
	assert_bool(screen.reachable.is_empty()).is_true()
	screen.shutdown()
	started[0].dispose()
	await await_idle_frame()


func test_tapping_elsewhere_or_on_an_unreachable_tile_deselects() -> void:
	var started := _started()
	var screen: MatchScreen = started[1]
	var state: GameState = started[2].state
	screen.on_tap_tile(state.tile_index(2, 1))

	screen.on_tap_tile(state.tile_index(11, 11))

	assert_int(screen.selected_unit).is_equal(-1)
	screen.on_tap_tile(-1)  # outside the map: ignored
	assert_int(state.revision()).is_equal(1)
	screen.shutdown()
	started[0].dispose()
	await await_idle_frame()


func test_a_unit_that_has_moved_shows_no_move_range() -> void:
	var started := _started()
	var screen: MatchScreen = started[1]
	var state: GameState = started[2].state
	var scout := state.view().unit_at(state.tile_index(2, 1))
	UnitWrites.set_moved(state, scout)

	screen.on_tap_tile(state.tile_index(2, 1))

	assert_int(screen.selected_unit).is_equal(scout)
	assert_bool(screen.reachable.is_empty()).is_true()
	screen.shutdown()
	started[0].dispose()
	await await_idle_frame()


func test_no_range_is_offered_during_the_enemy_phase() -> void:
	var started := _started()
	var screen: MatchScreen = started[1]
	var state: GameState = started[2].state
	screen.end_turn()

	screen.on_tap_tile(state.tile_index(2, 1))

	assert_bool(screen.reachable.is_empty()).is_true()
	assert_bool(screen.hud.end_turn_button.disabled).is_true()
	screen.shutdown()
	started[0].dispose()
	await await_idle_frame()


func test_the_end_turn_button_hands_the_turn_to_the_ai_and_back() -> void:
	var started := _started()
	var screen: MatchScreen = started[1]
	var state: GameState = started[2].state

	screen.hud.end_turn_button.pressed.emit()
	for step in 600:
		if not screen.ai_runner.is_running():
			break
		screen.ai_runner.advance()
	screen._process(0.0)

	assert_int(state.turn()).is_equal(2)
	assert_str(screen.hud.turn_label.text).is_equal("Tour 2 / 30")
	assert_bool(screen.hud.end_turn_button.disabled).is_false()
	screen.shutdown()
	started[0].dispose()
	await await_idle_frame()


func test_the_journal_keeps_twelve_lines_and_clears_when_the_player_plays() -> void:
	var started := _started()
	var screen: MatchScreen = started[1]

	for k in 15:
		screen._note(IntentionExecutedEvent.new(k, 1, 0, 5))
	assert_int(screen._journal.size()).is_equal(HudModel.JOURNAL_LINES)
	screen._note(TurnStartedEvent.new(2, Faction.PLAYER, HeaderSlice.PHASE_PLAYER))

	assert_int(screen._journal.size()).is_equal(0)
	screen.shutdown()
	started[0].dispose()
	await await_idle_frame()


func test_the_pause_button_asks_the_app_for_the_pause() -> void:
	var started := _started()
	var screen: MatchScreen = started[1]
	var asked := [0]
	screen.pause_requested.connect(func() -> void: asked[0] += 1)

	screen.hud.pause_button.pressed.emit()

	assert_int(asked[0]).is_equal(1)
	screen.shutdown()
	started[0].dispose()
	await await_idle_frame()


func test_tapping_a_visible_enemy_unit_selects_nothing() -> void:
	var started := _started()
	var screen: MatchScreen = started[1]
	var state: GameState = started[2].state
	var enemy := GameStateSetup.add_unit(state, 5, Faction.AI, state.tile_index(3, 1), 8)
	VisionService.recompute(state, VisionContext.for_map(started[0].app.catalog, state))

	screen.on_tap_tile(state.tile_index(3, 1))

	assert_int(screen.selected_unit).is_equal(-1)
	assert_bool(state.view().unit_at(state.tile_index(3, 1)) == enemy).is_true()
	screen.shutdown()
	started[0].dispose()
	await await_idle_frame()
