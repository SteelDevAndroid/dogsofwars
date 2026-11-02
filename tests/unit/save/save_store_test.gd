extends GdUnitTestSuite


func _state(seed_value: int = 1) -> GameState:
	var catalog := CatalogFactory.standard()
	return GameStateFactory.new_game(catalog, TestSessionFactory.shipped_map(catalog), seed_value)


func _store(files: FileStore) -> SaveStore:
	return SaveStore.new(files, CatalogFactory.standard(), "user://")


func test_a_saved_match_loads_back_equal_with_its_vision() -> void:
	var files := FaultInjectingFileStore.new()
	var state := _state()

	assert_int(_store(files).save_match(state)).is_equal(OK)
	var loaded := _store(files).load_match()

	assert_str(loaded.code).is_equal(LoadResult.OK)
	assert_bool(loaded.state.equals(state)).is_true()
	assert_array(VisionService.consistency_errors(loaded.state)).is_empty()
	assert_bool(loaded.from_backup).is_false()
	assert_array(files.paths()).is_equal(["user://match.sav"])


func test_no_file_means_no_match() -> void:
	assert_str(_store(FaultInjectingFileStore.new()).load_match().code).is_equal(LoadResult.NONE)


func test_the_previous_save_becomes_the_backup() -> void:
	var files := FaultInjectingFileStore.new()
	var store := _store(files)
	var first := _state(1)
	var second := _state(2)

	store.save_match(first)
	store.save_match(second)

	assert_array(files.paths()).is_equal(["user://match.bak", "user://match.sav"])
	assert_bool(_store(files).load_match().state.equals(second)).is_true()
	files.delete("user://match.sav")
	var from_backup := _store(files).load_match()
	assert_bool(from_backup.from_backup).is_true()
	assert_bool(from_backup.state.equals(first)).is_true()
	assert_int(from_backup.warnings.size()).is_equal(1)


func test_envelope_checks_come_in_order() -> void:
	var payload := _state().to_bytes()
	var bytes := SaveEnvelope.encode(payload, GameState.SCHEMA_VERSION, 7)
	var code := [SaveEnvelope.OK]

	var envelope := SaveEnvelope.decode(bytes, code)
	assert_array([code[0], envelope.revision, envelope.content_schema]).is_equal([SaveEnvelope.OK, 7, GameState.SCHEMA_VERSION])
	assert_bool(envelope.payload == payload).is_true()

	var bad_mark := bytes.duplicate()
	bad_mark[0] = 0x58
	SaveEnvelope.decode(bad_mark, code)
	assert_str(code[0]).is_equal(SaveEnvelope.BAD_MARK)
	SaveEnvelope.decode(bytes.slice(0, bytes.size() - 1), code)
	assert_str(code[0]).is_equal(SaveEnvelope.BAD_LENGTH)
	var flipped := bytes.duplicate()
	flipped[SaveEnvelope.PREFIX_SIZE + 3] ^= 1
	SaveEnvelope.decode(flipped, code)
	assert_str(code[0]).is_equal(SaveEnvelope.BAD_HASH)
	var version := bytes.duplicate()
	version[9] ^= 1  # a content-schema byte altered: caught by the hash before being read
	SaveEnvelope.decode(version, code)
	assert_str(code[0]).is_equal(SaveEnvelope.BAD_HASH)


func test_a_damaged_current_falls_back_to_the_backup_and_is_set_aside() -> void:
	var files := FaultInjectingFileStore.new()
	var store := _store(files)
	var first := _state(1)
	store.save_match(first)
	store.save_match(_state(2))
	var damaged := files.read("user://match.sav")
	damaged[30] ^= 1
	files.write("user://match.sav", damaged)

	var loaded := _store(files).load_match()

	assert_str(loaded.code).is_equal(LoadResult.OK)
	assert_bool(loaded.from_backup).is_true()
	assert_bool(loaded.state.equals(first)).is_true()
	assert_bool(files.exists("user://match.bad1")).is_true()
	assert_bool(files.exists("user://match.sav")).is_false()


func test_two_damaged_files_start_without_a_match() -> void:
	var files := FaultInjectingFileStore.new()
	files.write("user://match.sav", PackedByteArray([1, 2, 3]))
	files.write("user://match.bak", PackedByteArray([4, 5, 6]))

	assert_str(_store(files).load_match().code).is_equal(LoadResult.CORRUPT)


func test_a_newer_content_schema_is_refused_and_left_alone() -> void:
	var files := FaultInjectingFileStore.new()
	var bytes := SaveEnvelope.encode(_state().to_bytes(), GameState.SCHEMA_VERSION + 1, 1)
	files.write("user://match.sav", bytes)
	files.write("user://match.bak", SaveEnvelope.encode(_state().to_bytes(), GameState.SCHEMA_VERSION, 1))

	var loaded := _store(files).load_match()

	assert_str(loaded.code).is_equal(LoadResult.NEWER)
	assert_bool(files.read("user://match.sav") == bytes).is_true()
	assert_bool(files.exists("user://match.bad1")).is_false()


func test_a_leftover_tmp_is_never_promoted() -> void:
	var files := FaultInjectingFileStore.new()
	files.write("user://match.tmp", SaveEnvelope.encode(_state().to_bytes(), GameState.SCHEMA_VERSION, 1))

	assert_str(_store(files).load_match().code).is_equal(LoadResult.NONE)
	assert_bool(files.exists("user://match.tmp")).is_false()


func test_a_failed_write_keeps_the_current_save() -> void:
	var files := FaultInjectingFileStore.new()
	var store := _store(files)
	var kept := _state(1)
	store.save_match(kept)
	files.fail_at(files.calls.size() + 1)

	assert_int(store.save_match(_state(2))).is_not_equal(OK)

	assert_bool(_store(files).load_match().state.equals(kept)).is_true()


func test_a_power_cut_at_any_step_leaves_a_loadable_match() -> void:
	var older := _state(1)
	var newer := _state(2)
	var probe := FaultInjectingFileStore.new()
	_store(probe).save_match(older)
	var before := probe.calls.size()
	_store(probe).save_match(newer)
	var steps := probe.calls.size() - before

	for cut in range(1, steps + 1):
		var files := FaultInjectingFileStore.new()
		var store := _store(files)
		store.save_match(older)
		files.stop_after(files.calls.size() + cut)
		store.save_match(newer)
		var loaded := _store(files.restarted()).load_match()
		var ok := loaded.code == LoadResult.OK and (loaded.state.equals(older) or loaded.state.equals(newer))
		# between the rotation and the final rename only the backup of the previous save remains
		assert_bool(ok).override_failure_message("power cut after step %d: %s" % [cut, loaded.code]).is_true()


func test_a_new_game_deletes_the_old_one() -> void:
	var files := FaultInjectingFileStore.new()
	var store := _store(files)
	store.save_match(_state(1))
	store.save_match(_state(2))

	store.delete_match()

	assert_array(files.paths()).is_empty()


func _state_of_epoch(epoch: int) -> GameState:
	var catalog := CatalogFactory.standard()
	return GameStateFactory.new_game(catalog, TestSessionFactory.shipped_map(catalog), 1, false, [], 0, epoch)


func test_a_match_of_an_older_epoch_is_set_aside_and_an_equal_or_newer_one_loads() -> void:
	var files := FaultInjectingFileStore.new()
	var store := _store(files)
	store.save_match(_state_of_epoch(1))

	var stale := _store(files).load_match(2)

	assert_str(stale.code).is_equal(LoadResult.STALE)
	assert_object(stale.state).is_null()
	assert_bool(files.exists("user://match.sav")).is_false()
	assert_bool(files.exists("user://match.bad1")).is_true()  # renamed, never deleted
	assert_array(Array(stale.warnings)).is_not_empty()

	var again := FaultInjectingFileStore.new()
	_store(again).save_match(_state_of_epoch(2))
	assert_str(_store(again).load_match(2).code).is_equal(LoadResult.OK)
	assert_str(_store(again).load_match(1).code).is_equal(LoadResult.OK)
	assert_str(_store(again).load_match().code).is_equal(LoadResult.OK)


func test_a_stale_current_falls_back_to_a_backup_of_the_right_epoch() -> void:
	var files := FaultInjectingFileStore.new()
	var store := _store(files)
	store.save_match(_state_of_epoch(2))
	store.save_match(_state_of_epoch(1))  # the current is now the older epoch, the backup the newer

	var loaded := _store(files).load_match(2)

	assert_str(loaded.code).is_equal(LoadResult.OK)
	assert_bool(loaded.from_backup).is_true()
	assert_int(loaded.state.header.value(HeaderSlice.PROFILE_EPOCH)).is_equal(2)


func test_the_session_refuses_a_match_saved_before_a_reset_of_the_profile() -> void:
	var t := TestSessionFactory.new()
	var screen_ports := SessionPorts.new(EventQueue.new(256), AlwaysReadyPacingGate.new())
	t.app.save_store.save_match(_state_of_epoch(0))
	var profile := ProfileStore.new(FaultInjectingFileStore.new())
	profile.load_profile()
	profile.reset_progress()
	t.app.profile_port = profile
	var reason := [LoadResult.NONE]

	var runner := AiRunner.new()
	var session := SessionFactory.resume(t.app, screen_ports, NodeAiRunnerPort.new(runner), reason)
	runner.free()

	assert_object(session).is_null()
	assert_str(reason[0]).is_equal(LoadResult.STALE)
	assert_str(Bootstrap._load_notice(LoadResult.STALE)).contains("remise à zéro")
	t.dispose()
