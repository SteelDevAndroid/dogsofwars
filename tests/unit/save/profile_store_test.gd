extends GdUnitTestSuite


func _store(files: FileStore) -> ProfileStore:
	var store := ProfileStore.new(files)
	store.load_profile()
	return store


func test_a_new_profile_is_empty_and_the_changes_survive_a_restart() -> void:
	var files := FaultInjectingFileStore.new()
	var store := _store(files)
	assert_array(store.chronicle()).is_empty()
	assert_int(store.best_score(0, 0)).is_equal(-1)

	assert_bool(store.apply(RecordFragmentEffect.new(0, 3))).is_true()
	assert_bool(store.apply(RecordFragmentEffect.new(0, 1))).is_true()
	assert_bool(store.apply(SubmitScoreEffect.new(5, 0, 0, 340))).is_true()

	var again := _store(files.restarted())
	assert_array(again.chronicle()).is_equal([[0, 1], [0, 3]])
	assert_int(again.best_score(0, 0)).is_equal(340)


func test_a_fragment_is_kept_once() -> void:
	var store := _store(FaultInjectingFileStore.new())

	store.apply(RecordFragmentEffect.new(0, 2))
	store.apply(RecordFragmentEffect.new(0, 2))

	assert_array(store.chronicle()).is_equal([[0, 2]])


func test_the_best_score_is_a_maximum_taken_once_per_match() -> void:
	var store := _store(FaultInjectingFileStore.new())

	store.apply(SubmitScoreEffect.new(1, 0, 0, 340))
	store.apply(SubmitScoreEffect.new(2, 0, 0, 410))
	store.apply(SubmitScoreEffect.new(3, 0, 0, 200))
	store.apply(SubmitScoreEffect.new(2, 0, 0, 900))

	assert_int(store.best_score(0, 0)).is_equal(410)


func test_only_the_last_eight_match_ids_are_remembered() -> void:
	var store := _store(FaultInjectingFileStore.new())
	store.apply(SubmitScoreEffect.new(1, 0, 0, 10))
	for id in range(2, 10):
		store.apply(SubmitScoreEffect.new(id, 0, 0, 1))

	store.apply(SubmitScoreEffect.new(1, 0, 0, 500))  # match 1 fell out of the ring

	assert_int(store.best_score(0, 0)).is_equal(500)


func test_match_ids_never_repeat_across_restarts() -> void:
	var files := FaultInjectingFileStore.new()
	var store := _store(files)

	var first := store.next_match_id()
	var second := store.next_match_id()

	assert_int(second).is_equal(first + 1)
	assert_int(_store(files.restarted()).next_match_id()).is_equal(second + 1)


func test_a_failed_write_is_reported_and_retried_by_the_next_change() -> void:
	var files := FaultInjectingFileStore.new()
	var store := _store(files)
	files.storage_full = true

	assert_bool(store.apply(RecordFragmentEffect.new(0, 1))).is_false()
	files.storage_full = false
	assert_bool(store.apply(RecordFragmentEffect.new(0, 2))).is_true()

	assert_array(_store(files.restarted()).chronicle()).is_equal([[0, 1], [0, 2]])


func test_a_damaged_profile_falls_back_to_the_backup_then_to_a_fresh_one() -> void:
	var files := FaultInjectingFileStore.new()
	var store := _store(files)
	store.apply(RecordFragmentEffect.new(0, 1))
	store.apply(RecordFragmentEffect.new(0, 2))
	files.write("user://profile.sav", PackedByteArray([1, 2, 3]))

	var from_backup := _store(files)
	assert_array(from_backup.chronicle()).is_equal([[0, 1]])
	assert_bool(from_backup.warnings.size() > 0).is_true()

	files.write("user://profile.bak", PackedByteArray([9]))
	assert_array(_store(files).chronicle()).is_empty()


func test_a_profile_of_a_newer_version_is_read_only() -> void:
	var files := FaultInjectingFileStore.new()
	var bytes := SaveEnvelope.encode(var_to_bytes({}), ProfileStore.SCHEMA_VERSION + 1, 0)
	files.write("user://profile.sav", bytes)

	var store := _store(files)

	assert_bool(store.read_only).is_true()
	assert_bool(store.apply(RecordFragmentEffect.new(0, 1))).is_false()
	assert_bool(files.read("user://profile.sav") == bytes).is_true()


func test_a_reset_empties_the_progress_and_moves_the_epoch() -> void:
	var files := FaultInjectingFileStore.new()
	var store := _store(files)
	store.apply(RecordFragmentEffect.new(0, 1))
	store.apply(SubmitScoreEffect.new(1, 0, 0, 50))

	assert_bool(store.reset_progress()).is_true()

	var again := _store(files.restarted())
	assert_array(again.chronicle()).is_empty()
	assert_int(again.best_score(0, 0)).is_equal(-1)
	assert_int(again.epoch).is_equal(1)
