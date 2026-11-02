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
