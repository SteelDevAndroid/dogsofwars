extends GdUnitTestSuite


func _store(files: FileStore) -> ProfileStore:
	var store := ProfileStore.new(files)
	store.load_profile()
	return store


func test_a_new_profile_has_the_default_settings() -> void:
	var store := _store(FaultInjectingFileStore.new())

	assert_dict(store.settings()).is_equal({
		GameSettings.TEXT_SCALE: 100, GameSettings.COLORBLIND: 0, GameSettings.REDUCED_MOTION: 0,
		GameSettings.SHOW_RANGE: 1, GameSettings.ENEMY_SPEED: 0, GameSettings.LEFT_PANEL: 0, GameSettings.HINTS: 1, GameSettings.VOLUME_EFFECTS: 80, GameSettings.VOLUME_UI: 80,
		GameSettings.VIBRATION: 1})


func test_a_setting_survives_a_restart_and_a_reset_of_the_progress() -> void:
	var files := FaultInjectingFileStore.new()
	var store := _store(files)

	assert_bool(store.set_setting(GameSettings.TEXT_SCALE, 125)).is_true()
	assert_bool(store.set_setting(GameSettings.COLORBLIND, 1)).is_true()
	store.apply(RecordFragmentEffect.new(0, 1))
	store.reset_progress()

	var again := _store(files.restarted())
	assert_int(again.setting(GameSettings.TEXT_SCALE)).is_equal(125)
	assert_int(again.setting(GameSettings.COLORBLIND)).is_equal(1)
	assert_array(again.chronicle()).is_empty()


func test_an_invalid_change_is_refused_and_nothing_is_written() -> void:
	var files := FaultInjectingFileStore.new()
	var store := _store(files)
	var before := files.paths().size()

	assert_bool(store.set_setting(GameSettings.TEXT_SCALE, 151)).is_false()
	assert_bool(store.set_setting(GameSettings.TEXT_SCALE, 99)).is_false()
	assert_bool(store.set_setting(GameSettings.ENEMY_SPEED, 3)).is_false()
	assert_bool(store.set_setting(GameSettings.COLORBLIND, "yes")).is_false()
	assert_bool(store.set_setting(GameSettings.COLORBLIND, 1.0)).is_false()
	assert_bool(store.set_setting(&"volume", 1)).is_false()

	assert_int(store.setting(GameSettings.TEXT_SCALE)).is_equal(100)
	assert_int(files.paths().size()).is_equal(before)


func test_the_bounds_are_accepted() -> void:
	var store := _store(FaultInjectingFileStore.new())

	assert_bool(store.set_setting(GameSettings.TEXT_SCALE, 100)).is_true()
	assert_bool(store.set_setting(GameSettings.TEXT_SCALE, 150)).is_true()
	assert_bool(store.set_setting(GameSettings.ENEMY_SPEED, 2)).is_true()
	assert_bool(store.set_setting(GameSettings.SHOW_RANGE, 0)).is_true()


func test_a_failed_write_leaves_the_setting_unchanged() -> void:
	var files := FaultInjectingFileStore.new()
	var store := _store(files)
	files.storage_full = true

	assert_bool(store.set_setting(GameSettings.LEFT_PANEL, 1)).is_false()

	assert_int(store.setting(GameSettings.LEFT_PANEL)).is_equal(0)


func test_a_read_only_profile_refuses_a_setting() -> void:
	var files := FaultInjectingFileStore.new()
	files.write("user://profile.sav", SaveEnvelope.encode(var_to_bytes({}), ProfileStore.SCHEMA_VERSION + 1, 0))
	var store := _store(files)

	assert_bool(store.set_setting(GameSettings.LEFT_PANEL, 1)).is_false()


func test_a_profile_without_settings_or_with_bad_ones_takes_the_defaults_key_by_key() -> void:
	var files := FaultInjectingFileStore.new()
	var base := {"fragments": [], "best": {}, "recent": [], "epoch": 0, "next_match": 1}
	files.write("user://profile.sav", SaveEnvelope.encode(var_to_bytes(base), ProfileStore.SCHEMA_VERSION, 0))
	assert_int(_store(files).setting(GameSettings.TEXT_SCALE)).is_equal(100)

	base["settings"] = {GameSettings.TEXT_SCALE: 130, GameSettings.COLORBLIND: 7, GameSettings.ENEMY_SPEED: "x", &"future": 5}
	files.write("user://profile.sav", SaveEnvelope.encode(var_to_bytes(base), ProfileStore.SCHEMA_VERSION, 0))
	var store := _store(files)

	assert_int(store.setting(GameSettings.TEXT_SCALE)).is_equal(130)
	assert_int(store.setting(GameSettings.COLORBLIND)).is_equal(0)
	assert_int(store.setting(GameSettings.ENEMY_SPEED)).is_equal(0)
	assert_bool(store.settings().has(&"future")).is_false()


func test_the_settings_returned_are_a_copy() -> void:
	var store := _store(FaultInjectingFileStore.new())

	var copy := store.settings()
	copy[GameSettings.TEXT_SCALE] = 150

	assert_int(store.setting(GameSettings.TEXT_SCALE)).is_equal(100)


func test_the_volumes_are_percentages() -> void:
	var store := _store(FaultInjectingFileStore.new())

	assert_bool(store.set_setting(GameSettings.VOLUME_EFFECTS, 0)).is_true()
	assert_bool(store.set_setting(GameSettings.VOLUME_UI, 100)).is_true()
	assert_bool(store.set_setting(GameSettings.VOLUME_EFFECTS, 101)).is_false()
	assert_bool(store.set_setting(GameSettings.VOLUME_UI, -1)).is_false()
	assert_int(store.setting(GameSettings.VOLUME_EFFECTS)).is_equal(0)
