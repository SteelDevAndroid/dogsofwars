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


## Plays what the sequencer has queued, as the frames would.
func _settle(screen: MatchScreen) -> void:
	for step in 400:
		screen.clock.advance(0.5)
		screen.sequencer.advance()
		if screen.sequencer.is_idle():
			return


func _started(seed_value: int = 6) -> Array:
	var t := TestSessionFactory.new()
	var screen := _screen()
	var session := SessionFactory.new_game(t.app, t.map(), seed_value, screen.ports(t.sink), screen.runner_port())
	screen.bind(session)
	_settle(screen)
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
	_settle(screen)

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
	_settle(screen)

	assert_int(state.turn()).is_equal(2)
	assert_str(screen.hud.turn_label.text).is_equal("Tour 2 / 30")
	assert_bool(screen.hud.end_turn_button.disabled).is_false()
	screen.shutdown()
	started[0].dispose()
	await await_idle_frame()


func test_the_journal_keeps_twelve_lines_and_clears_when_the_player_plays() -> void:
	var started := _started()
	var screen: MatchScreen = started[1]
	var context := SequenceContext.new(0.0, screen.sequencer.clock)

	for k in 15:
		screen.presenter.handle(IntentionAnnouncedEvent.new(k, 1, 0, 0, 5, 0, 0), context)
	assert_int(screen.presenter.journal.size()).is_equal(HudModel.JOURNAL_LINES)
	screen.presenter.handle(TurnStartedEvent.new(2, Faction.PLAYER, HeaderSlice.PHASE_PLAYER), context)

	assert_int(screen.presenter.journal.size()).is_equal(0)
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


## What the frames do: time passes, the sequencer plays, the AI sends a command when the gate is ready.
func _frames(screen: MatchScreen, count: int, step: float = 0.1) -> void:
	for k in count:
		screen.clock.advance(step)
		screen.sequencer.advance()
		if screen.ai_runner.is_running() and screen.sequencer.is_idle():
			screen.ai_runner.advance()


func test_the_enemy_turn_takes_presentation_time_and_hands_the_turn_back() -> void:
	var started := _started()
	var screen: MatchScreen = started[1]
	var state: GameState = started[2].state
	var before := screen.clock.current()

	screen.end_turn()
	_frames(screen, 2000)

	assert_int(state.turn()).is_equal(2)
	assert_bool(screen.sequencer.is_idle()).is_true()
	assert_bool(screen.ai_runner.is_running()).is_false()
	assert_float(screen.clock.current()).is_greater(before)
	assert_bool(screen.hud.end_turn_button.disabled).is_false()
	assert_str(screen.hud.turn_label.text).is_equal("Tour 2 / 30")
	screen.shutdown()
	started[0].dispose()
	await await_idle_frame()


func test_taps_and_the_end_turn_button_wait_for_the_sequencer() -> void:
	var started := _started()
	var screen: MatchScreen = started[1]
	var state: GameState = started[2].state
	var scout := state.view().unit_at(state.tile_index(2, 1))
	screen.on_tap_tile(state.tile_index(2, 1))
	var destination := screen.reachable[0]
	screen.on_tap_tile(destination)  # the move is applied; its batch is queued, not yet played

	assert_bool(screen.sequencer.is_idle()).is_false()
	assert_bool(screen.hud.end_turn_button.disabled).is_true()  # buttons are dead outside idle (hud.md rule 6)
	screen.on_tap_tile(state.tile_index(3, 2))  # another unit of the player
	assert_int(screen.selected_unit).is_equal(-1)  # ignored while the move plays
	_settle(screen)
	assert_bool(screen.sequencer.is_idle()).is_true()
	assert_int(state.view().unit_tile(scout)).is_equal(destination)
	screen.shutdown()
	started[0].dispose()
	await await_idle_frame()


func test_the_speed_button_cycles_normal_fast_instant() -> void:
	var started := _started()
	var screen: MatchScreen = started[1]

	screen.hud.speed_button.pressed.emit()
	assert_int(screen.clock.speed).is_equal(PresentationClock.Speed.FAST)
	assert_str(screen.hud.speed_button.text).is_equal("Vitesse : rapide")
	screen.hud.speed_button.pressed.emit()
	assert_int(screen.clock.speed).is_equal(PresentationClock.Speed.INSTANT)
	screen.hud.speed_button.pressed.emit()

	assert_int(screen.clock.speed).is_equal(PresentationClock.Speed.NORMAL)
	screen.shutdown()
	started[0].dispose()
	await await_idle_frame()


func test_reading_a_ruin_opens_the_panel_after_the_wave_and_locks_the_player_until_it_is_closed() -> void:
	var started := _started()
	var screen: MatchScreen = started[1]
	var state: GameState = started[2].state
	var scout := state.view().unit_at(state.tile_index(2, 1))
	var ruin := state.ruins.tile_of(0)
	var next_to := ruin + 1 if ruin % 12 < 11 else ruin - 1
	UnitWrites.move_to(state, scout, next_to)
	VisionService.recompute(state, VisionContext.for_map(started[0].app.catalog, state))
	screen.refresh()
	started[2].pipeline.submit(MoveCommand.new(Faction.PLAYER, Command.EMITTER_PLAYER, scout, ruin))

	_frames(screen, 3)
	assert_bool(screen.hud.fragment_panel.is_open).is_false()  # the wave and the delay come first
	_frames(screen, 30)

	assert_bool(screen.hud.fragment_panel.is_open).is_true()
	assert_bool(started[2].gate.is_locked(Faction.PLAYER, Command.EMITTER_PLAYER)).is_true()
	assert_bool(screen.hud.end_turn_button.disabled).is_true()
	screen.hud.fragment_panel.continue_button.pressed.emit()
	assert_bool(screen.hud.fragment_panel.is_open).is_true()  # too early
	_frames(screen, 8)
	screen._process(0.0)
	screen.hud.fragment_panel.continue_button.pressed.emit()

	assert_bool(screen.hud.fragment_panel.is_open).is_false()
	assert_bool(started[2].gate.is_locked(Faction.PLAYER, Command.EMITTER_PLAYER)).is_false()
	assert_bool(screen.hud.end_turn_button.disabled).is_false()
	screen.shutdown()
	started[0].dispose()
	await await_idle_frame()


func test_taps_are_ignored_under_a_player_lock() -> void:
	var started := _started()
	var screen: MatchScreen = started[1]
	var state: GameState = started[2].state
	started[2].gate.lock(PresentationSequencer.FRAGMENT_PANEL)

	screen.on_tap_tile(state.tile_index(2, 1))

	assert_int(screen.selected_unit).is_equal(-1)
	started[2].gate.unlock(PresentationSequencer.FRAGMENT_PANEL)
	screen.on_tap_tile(state.tile_index(2, 1))
	assert_bool(screen.selected_unit >= 0).is_true()
	screen.shutdown()
	started[0].dispose()
	await await_idle_frame()


## A started match with an enemy Chasseur placed next to the player's Assaut (3, 2), seen.
func _duel() -> Array:
	var started := _started()
	var state: GameState = started[2].state
	var enemy := GameStateSetup.add_unit(state, 5, Faction.AI, state.tile_index(4, 2), 8)
	VisionService.recompute(state, VisionContext.for_map(started[0].app.catalog, state))
	started[1].refresh(true)
	return started + [enemy]


func test_attack_targeting_shows_the_preview_then_strikes_on_confirmation() -> void:
	var started := _duel()
	var screen: MatchScreen = started[1]
	var state: GameState = started[2].state
	var enemy: int = started[3]
	var assault := state.view().unit_at(state.tile_index(3, 2))
	screen.on_tap_tile(state.tile_index(3, 2))
	assert_bool(screen.hud.attack_button.visible).is_true()

	screen.hud.attack_button.pressed.emit()
	assert_int(screen.mode).is_equal(MatchScreen.Mode.TARGETING)
	assert_array(Array(screen.target_tiles)).is_equal([state.tile_index(4, 2)])
	assert_bool(screen.reachable.is_empty()).is_true()
	assert_bool(screen.hud.cancel_button.visible).is_true()
	screen.on_tap_tile(state.tile_index(4, 2))

	assert_int(screen.mode).is_equal(MatchScreen.Mode.CONFIRMING)
	assert_str(screen.hud.preview_label.text).starts_with("Inflige −")
	assert_bool(screen.hud.confirm_button.visible).is_true()
	assert_int(screen.renderer.chosen_target).is_equal(state.tile_index(4, 2))
	var expected := screen.preview.target_hp_after
	var revision := state.revision()
	assert_int(state.view().unit_hp(enemy)).is_equal(8)  # nothing struck yet

	screen.hud.confirm_button.pressed.emit()

	assert_int(state.revision()).is_equal(revision + 1)
	assert_int(state.view().unit_hp(enemy)).is_equal(expected)  # the preview was the real blow
	assert_bool(state.view().unit_acted(assault)).is_true()
	assert_int(screen.mode).is_equal(MatchScreen.Mode.IDLE)
	assert_bool(screen.hud.attack_button.visible).is_false()
	screen.shutdown()
	started[0].dispose()
	await await_idle_frame()


func test_a_second_tap_on_the_chosen_target_strikes() -> void:
	var started := _duel()
	var screen: MatchScreen = started[1]
	var state: GameState = started[2].state
	screen.on_tap_tile(state.tile_index(3, 2))
	screen.begin_targeting()
	screen.on_tap_tile(state.tile_index(4, 2))

	screen.on_tap_tile(state.tile_index(4, 2))

	assert_int(state.view().unit_hp(started[3])).is_less(8)
	screen.shutdown()
	started[0].dispose()
	await await_idle_frame()


func test_tapping_elsewhere_or_cancelling_leaves_targeting_without_a_blow() -> void:
	var started := _duel()
	var screen: MatchScreen = started[1]
	var state: GameState = started[2].state
	screen.on_tap_tile(state.tile_index(3, 2))
	screen.begin_targeting()

	screen.on_tap_tile(state.tile_index(0, 11))
	assert_int(screen.mode).is_equal(MatchScreen.Mode.SELECTED)
	assert_bool(screen.reachable.size() > 0).is_true()  # the move range is back
	screen.begin_targeting()
	screen.on_tap_tile(state.tile_index(4, 2))
	screen.hud.cancel_button.pressed.emit()

	assert_int(screen.mode).is_equal(MatchScreen.Mode.SELECTED)
	assert_int(screen.target_unit).is_equal(-1)
	assert_int(state.view().unit_hp(started[3])).is_equal(8)
	assert_int(state.revision()).is_equal(1)
	screen.shutdown()
	started[0].dispose()
	await await_idle_frame()


func test_the_attack_button_needs_a_target_in_range_and_an_unacted_unit() -> void:
	var started := _started()
	var screen: MatchScreen = started[1]
	var state: GameState = started[2].state

	screen.on_tap_tile(state.tile_index(3, 2))
	assert_bool(screen.hud.attack_button.visible).is_false()  # nobody to strike
	screen.begin_targeting()
	assert_int(screen.mode).is_equal(MatchScreen.Mode.SELECTED)
	screen.shutdown()
	started[0].dispose()
	await await_idle_frame()

	var duel := _duel()
	var acted: MatchScreen = duel[1]
	UnitWrites.set_acted(duel[2].state, duel[2].state.view().unit_at(duel[2].state.tile_index(3, 2)))
	acted.on_tap_tile(duel[2].state.tile_index(3, 2))
	assert_bool(acted.hud.attack_button.visible).is_false()
	acted.shutdown()
	duel[0].dispose()
	await await_idle_frame()


func test_a_strike_locks_the_player_while_it_plays_then_frees_them() -> void:
	var started := _duel()
	var screen: MatchScreen = started[1]
	var state: GameState = started[2].state
	screen.on_tap_tile(state.tile_index(3, 2))
	screen.begin_targeting()
	screen.on_tap_tile(state.tile_index(4, 2))
	screen.confirm_attack()

	screen.sequencer.advance()
	assert_bool(started[2].gate.is_locked(Faction.PLAYER, Command.EMITTER_PLAYER)).is_true()
	assert_bool(screen.hud.end_turn_button.disabled).is_true()
	_settle(screen)

	assert_bool(started[2].gate.is_locked(Faction.PLAYER, Command.EMITTER_PLAYER)).is_false()
	assert_bool(screen.hud.end_turn_button.disabled).is_false()
	screen.shutdown()
	started[0].dispose()
	await await_idle_frame()


func _finger(screen: MatchScreen, index: int, phase: int, position: Vector2) -> void:
	screen._on_pointer(PointerEvent.new(index, phase, position))


func test_the_camera_starts_on_the_first_unit_of_the_player_and_drives_the_renderer() -> void:
	var started := _started()
	var screen: MatchScreen = started[1]
	var state: GameState = started[2].state
	var first := state.view().unit_tile(0)

	assert_bool(screen.camera.is_visible(first)).is_true()
	assert_float(screen.renderer.layout.tile_size).is_equal(screen.camera.tile_size)
	assert_vector(screen.renderer.layout.origin).is_equal(screen.camera.layout().origin)
	assert_vector(screen.input_surface.size).is_equal(screen.camera.area.size)
	screen.shutdown()
	started[0].dispose()
	await await_idle_frame()


func test_a_drag_scrolls_a_pinch_zooms_and_a_touch_taps() -> void:
	var started := _started()
	var screen: MatchScreen = started[1]
	var state: GameState = started[2].state
	var centre := screen.camera.center
	var size := screen.camera.tile_size

	_finger(screen, 0, PointerEvent.Phase.DOWN, Vector2(200, 300))
	_finger(screen, 0, PointerEvent.Phase.MOVE, Vector2(260, 300))
	_finger(screen, 0, PointerEvent.Phase.UP, Vector2(260, 300))
	assert_float(screen.camera.center.x).is_less(centre.x)  # the map followed the finger to the right
	screen._process(0.0)
	assert_float(screen.renderer.layout.origin.x).is_equal_approx(screen.camera.layout().origin.x, 0.001)

	_finger(screen, 0, PointerEvent.Phase.DOWN, Vector2(150, 300))
	_finger(screen, 1, PointerEvent.Phase.DOWN, Vector2(250, 300))
	_finger(screen, 1, PointerEvent.Phase.MOVE, Vector2(350, 300))
	assert_float(screen.camera.tile_size).is_greater(size)
	_finger(screen, 1, PointerEvent.Phase.UP, Vector2(350, 300))
	_finger(screen, 0, PointerEvent.Phase.UP, Vector2(150, 300))

	var unit_tile := state.view().unit_tile(state.view().unit_at(state.tile_index(2, 1)))
	screen.camera.ensure_visible(unit_tile)
	screen._process(0.0)
	var at := screen.camera.tile_to_screen(unit_tile)
	_finger(screen, 0, PointerEvent.Phase.DOWN, at)
	_finger(screen, 0, PointerEvent.Phase.UP, at)
	assert_bool(screen.selected_unit >= 0).is_true()
	screen.shutdown()
	started[0].dispose()
	await await_idle_frame()


func test_the_camera_of_the_player_comes_back_after_the_enemy_turn() -> void:
	var started := _started()
	var screen: MatchScreen = started[1]
	screen.camera.scroll(Vector2(-90, -40))
	var before := screen.camera.center
	var size := screen.camera.tile_size

	screen.end_turn()
	_frames(screen, 2000)

	assert_int(started[2].state.turn()).is_equal(2)
	assert_vector(screen.camera.center).is_equal(before)
	assert_float(screen.camera.tile_size).is_equal(size)
	screen.shutdown()
	started[0].dispose()
	await await_idle_frame()


func test_confirming_without_a_chosen_target_does_nothing() -> void:
	var started := _duel()
	var screen: MatchScreen = started[1]
	var state: GameState = started[2].state
	screen.on_tap_tile(state.tile_index(3, 2))
	var selected := screen.selected_unit

	screen.confirm_attack()

	assert_int(screen.selected_unit).is_equal(selected)
	assert_int(state.revision()).is_equal(1)
	screen.shutdown()
	started[0].dispose()
	await await_idle_frame()
