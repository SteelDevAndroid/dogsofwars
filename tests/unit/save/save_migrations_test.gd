extends GdUnitTestSuite

const PLAYER_V2 := "res://tests/fixtures/saves/schema2_player.sav"
const ENEMY_V2 := "res://tests/fixtures/saves/schema2_enemy.sav"


func _store(files: FileStore) -> SaveStore:
	return SaveStore.new(files, CatalogFactory.standard(), "user://")


func _files_with(path: String) -> FaultInjectingFileStore:
	var files := FaultInjectingFileStore.new()
	files.write("user://match.sav", FileAccess.get_file_as_bytes(path))
	return files


func test_every_schema_increment_has_a_migration() -> void:
	for schema in range(SaveMigrations.FIRST_SUPPORTED, GameState.SCHEMA_VERSION):
		assert_bool(SaveMigrations.has_step(schema)).is_true()


func test_the_fixtures_are_real_files_of_schema_two() -> void:
	for path in [PLAYER_V2, ENEMY_V2]:
		var code := [SaveEnvelope.OK]
		var envelope := SaveEnvelope.decode(FileAccess.get_file_as_bytes(path), code)
		assert_object(envelope).is_not_null()
		assert_int(envelope.content_schema).is_equal(2)
		assert_object(GameState.from_bytes(envelope.payload, GameState.SCHEMA_VERSION)).is_null()


func test_a_schema_two_match_in_the_player_phase_is_migrated_and_resumes() -> void:
	var loaded := _store(_files_with(PLAYER_V2)).load_match()

	assert_str(loaded.code).is_equal(LoadResult.OK)
	assert_int(loaded.migrated_from).is_equal(2)
	assert_int(loaded.state.header.value(HeaderSlice.PHASE)).is_equal(HeaderSlice.PHASE_PLAYER)
	assert_array([loaded.state.ai_cursor.cursor(), loaded.state.ai_cursor.announced_turn()]).is_equal([0, -1])
	assert_array(VisionService.consistency_errors(loaded.state)).is_empty()
	assert_array(loaded.state.validate()).is_empty()


func test_the_migration_changes_only_the_cursor_column() -> void:
	var envelope := SaveEnvelope.decode(FileAccess.get_file_as_bytes(PLAYER_V2), [SaveEnvelope.OK])
	var old: Array = bytes_to_var(envelope.payload)

	var migrated: Array = bytes_to_var(SaveMigrations.migrate(envelope.payload, 2))

	var differing := []
	for k in old.size():
		if old[k] != migrated[k]:
			differing.append(k)
	assert_int(differing.size()).is_equal(1)
	assert_array(Array(migrated[differing[0]])).is_equal([0, -1])
	assert_array(Array(old[differing[0]])).is_equal([0])
	assert_bool(envelope.payload == SaveEnvelope.decode(FileAccess.get_file_as_bytes(PLAYER_V2), [SaveEnvelope.OK]).payload).is_true()  # input untouched


func test_a_migrated_match_is_written_back_in_the_current_schema() -> void:
	var files := _files_with(PLAYER_V2)
	var store := _store(files)
	var loaded := store.load_match()

	assert_int(store.save_match(loaded.state)).is_equal(OK)

	var again := _store(files).load_match()
	assert_int(again.migrated_from).is_equal(0)
	assert_bool(again.state.equals(loaded.state)).is_true()
	var envelope := SaveEnvelope.decode(files.read("user://match.sav"), [SaveEnvelope.OK])
	assert_int(envelope.content_schema).is_equal(GameState.SCHEMA_VERSION)
	assert_bool(files.read("user://match.bak") == FileAccess.get_file_as_bytes(PLAYER_V2)).is_true()  # the old file is kept


func test_a_match_saved_in_the_enemy_phase_is_set_aside_not_migrated() -> void:
	var files := _files_with(ENEMY_V2)
	var original := files.read("user://match.sav")

	var loaded := _store(files).load_match()

	assert_str(loaded.code).is_equal(LoadResult.OLDER)
	assert_object(loaded.state).is_null()
	assert_bool(files.exists("user://match.sav")).is_false()
	assert_bool(files.read("user://match.bad1") == original).is_true()  # renamed, never deleted


func test_an_unsupported_old_schema_is_set_aside() -> void:
	var payload := FileAccess.get_file_as_bytes(PLAYER_V2)
	var files := FaultInjectingFileStore.new()
	files.write("user://match.sav", SaveEnvelope.encode(SaveEnvelope.decode(payload, [SaveEnvelope.OK]).payload, 1, 5))

	var loaded := _store(files).load_match()

	assert_str(loaded.code).is_equal(LoadResult.OLDER)
	assert_bool(files.exists("user://match.bad1")).is_true()
	var good := SaveEnvelope.decode(payload, [SaveEnvelope.OK]).payload
	assert_bool(SaveMigrations.migrate(good, 1).is_empty()).is_true()
	assert_bool(SaveMigrations.migrate(good, 2).is_empty()).is_false()
	assert_bool(SaveMigrations.migrate(good, GameState.SCHEMA_VERSION).is_empty()).is_true()  # nothing to migrate


func test_a_migration_whose_result_breaks_an_invariant_sets_the_file_aside() -> void:
	var envelope := SaveEnvelope.decode(FileAccess.get_file_as_bytes(PLAYER_V2), [SaveEnvelope.OK])
	var data: Array = bytes_to_var(envelope.payload)
	data[0] = PackedByteArray([1, 2, 3])  # the terrain no longer matches the map
	var files := FaultInjectingFileStore.new()
	files.write("user://match.sav", SaveEnvelope.encode(var_to_bytes(data), 2, 5))

	var loaded := _store(files).load_match()

	assert_str(loaded.code).is_equal(LoadResult.OLDER)
	assert_bool(files.exists("user://match.bad1")).is_true()


func test_a_damaged_payload_of_an_old_schema_is_not_migrated() -> void:
	var files := FaultInjectingFileStore.new()
	files.write("user://match.sav", SaveEnvelope.encode(var_to_bytes("not an array"), 2, 5))

	assert_str(_store(files).load_match().code).is_equal(LoadResult.OLDER)


func test_an_old_current_with_a_migratable_backup_loads_the_backup() -> void:
	var files := _files_with(ENEMY_V2)
	files.write("user://match.bak", FileAccess.get_file_as_bytes(PLAYER_V2))

	var loaded := _store(files).load_match()

	assert_str(loaded.code).is_equal(LoadResult.OK)
	assert_bool(loaded.from_backup).is_true()
	assert_int(loaded.migrated_from).is_equal(2)
	assert_bool(files.exists("user://match.bad1")).is_true()


func test_a_migrated_state_that_breaks_an_invariant_is_set_aside_as_too_old_not_corrupt() -> void:
	var envelope := SaveEnvelope.decode(FileAccess.get_file_as_bytes(PLAYER_V2), [SaveEnvelope.OK])
	var data: Array = bytes_to_var(envelope.payload)
	data[1][HeaderSlice.TURN] = 9999  # structurally fine, outside 0..T_MAX
	var files := FaultInjectingFileStore.new()
	files.write("user://match.sav", SaveEnvelope.encode(var_to_bytes(data), 2, 5))

	var loaded := _store(files).load_match()

	assert_str(loaded.code).is_equal(LoadResult.OLDER)
	assert_int(loaded.migrated_from).is_equal(0)
	assert_bool(files.exists("user://match.bad1")).is_true()


func test_a_migrated_payload_that_is_not_a_state_is_set_aside_as_too_old() -> void:
	var envelope := SaveEnvelope.decode(FileAccess.get_file_as_bytes(PLAYER_V2), [SaveEnvelope.OK])
	var data: Array = bytes_to_var(envelope.payload)
	data.append(PackedInt32Array([1]))  # one column too many: the step accepts, from_bytes refuses
	var files := FaultInjectingFileStore.new()
	files.write("user://match.sav", SaveEnvelope.encode(var_to_bytes(data), 2, 5))

	assert_str(_store(files).load_match().code).is_equal(LoadResult.OLDER)


func test_too_old_and_damaged_together_read_as_damaged() -> void:
	var files := _files_with(ENEMY_V2)
	files.write("user://match.bak", PackedByteArray([1, 2, 3]))

	assert_str(_store(files).load_match().code).is_equal(LoadResult.CORRUPT)
