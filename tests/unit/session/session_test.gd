extends GdUnitTestSuite


func test_a_new_game_opens_the_first_turn_of_the_player() -> void:
	var t := TestSessionFactory.new()
	var session := t.new_game(3)

	session.turns.start()

	assert_array([session.state.turn(), session.state.header.value(HeaderSlice.PHASE)]).is_equal([1, HeaderSlice.PHASE_PLAYER])
	assert_bool(t.files.exists("user://match.sav")).is_true()
	assert_int((session.post_commit as SaveCoordinator).writes).is_equal(session.state.revision())
	assert_int(t.sink.size()).is_equal(1)
	session.shutdown()
	t.dispose()


func test_a_whole_round_goes_through_the_ai_and_back_to_the_player() -> void:
	var t := TestSessionFactory.new()
	var session := t.new_game(3)
	session.turns.start()

	assert_bool(session.turns.end_player_turn().permitted).is_true()
	assert_int(session.state.header.value(HeaderSlice.PHASE)).is_equal(HeaderSlice.PHASE_ENEMY_EXECUTION)
	t.run_ai()

	assert_array([session.state.turn(), session.state.header.value(HeaderSlice.PHASE)]).is_equal([2, HeaderSlice.PHASE_PLAYER])
	assert_int((session.post_commit as SaveCoordinator).writes).is_equal(session.state.revision())
	assert_array(session.state.validate()).is_empty()
	session.shutdown()
	t.dispose()


func test_every_command_of_the_ai_is_saved_and_published() -> void:
	var t := TestSessionFactory.new()
	var session := t.new_game(3)
	session.turns.start()
	session.turns.end_player_turn()
	t.run_ai()

	var batches := t.sink.drain()

	assert_int(batches.size()).is_equal(session.state.revision())
	for k in batches.size():
		assert_int(batches[k].revision).is_equal(k + 1)
	session.shutdown()
	t.dispose()


func test_a_loaded_match_continues_exactly_where_the_saved_one_stopped() -> void:
	var t := TestSessionFactory.new()
	var session := t.new_game(5)
	session.turns.start()
	session.turns.end_player_turn()
	for step in 3:
		t.runner.advance()  # a stop in the middle of the enemy phase
	var saved := session.state.duplicate_state()
	t.runner.cancel()
	session.shutdown()

	# the reference: the same match without a stop
	var reference := TestSessionFactory.new()
	var whole := reference.new_game(5)
	whole.turns.start()
	whole.turns.end_player_turn()
	reference.run_ai()

	var resumed := TestSessionFactory.new(t.files.restarted())
	var again := resumed.resume()
	assert_object(again).is_not_null()
	assert_bool(again.state.equals(saved)).is_true()
	assert_int(again.state.header.value(HeaderSlice.PHASE)).is_equal(HeaderSlice.PHASE_ENEMY_EXECUTION)
	again.turns.start()
	resumed.run_ai()

	assert_bool(again.state.equals(whole.state)).is_true()
	again.shutdown()
	whole.shutdown()
	resumed.dispose()
	reference.dispose()
	t.dispose()


func test_resuming_without_a_save_gives_no_session() -> void:
	var t := TestSessionFactory.new()
	var reason := [LoadResult.OK]

	assert_object(SessionFactory.resume(t.app, t.ports, t.ai_port, reason)).is_null()
	assert_str(reason[0]).is_equal(LoadResult.NONE)
	t.dispose()


func test_a_new_game_erases_the_previous_save() -> void:
	var t := TestSessionFactory.new()
	t.new_game(1).turns.start()
	assert_bool(t.files.exists("user://match.sav")).is_true()

	var second := t.new_game(2)

	assert_array(t.files.paths()).is_empty()
	second.shutdown()
	t.dispose()


func test_the_session_is_built_from_the_catalog_and_the_ports() -> void:
	var t := TestSessionFactory.new()
	var session := t.new_game()

	assert_str(session.log.content_hash).is_equal(t.app.catalog.content_hash)
	assert_object(session.events).is_same(t.sink)
	assert_object(session.profile).is_same(t.profile)
	assert_int(session.rules.registered_types().size()).is_equal(CommandType.COUNT - 1)  # UNDO_MOVE belongs to the pipeline
	session.shutdown()
	t.dispose()


func test_the_end_of_the_match_stops_the_turn_system() -> void:
	var t := TestSessionFactory.new()
	var session := t.new_game(4)
	session.turns.start()
	assert_bool(session.pipeline.submit(AbandonCommand.new()).permitted).is_true()

	assert_bool(session.is_over()).is_true()
	assert_bool(session.turns.end_player_turn().permitted).is_false()
	session.shutdown()
	t.dispose()


func test_a_data_error_leaves_the_app_without_a_catalog() -> void:
	var documents := CatalogFactory.documents()
	documents["units.json"]["types"][0]["hp"] = 99
	var texts := {}
	for name: String in documents:
		texts[name] = JSON.stringify(documents[name])

	var app := AppContext.create(MemoryDataSource.new(texts), FaultInjectingFileStore.new(), RecordingProfilePort.new())

	assert_bool(app.is_ready()).is_false()
	assert_bool(app.errors.size() > 0).is_true()


func test_shutdown_breaks_the_references() -> void:
	var t := TestSessionFactory.new()
	var session := t.new_game()
	session.turns.start()

	session.shutdown()

	assert_object(session.state).is_null()
	assert_object(session.turns).is_null()
	assert_bool(t.ai_port.on_turn_finished.is_valid()).is_false()
	t.dispose()
