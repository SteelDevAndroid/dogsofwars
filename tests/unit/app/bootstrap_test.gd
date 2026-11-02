extends GdUnitTestSuite


func _texts(broken: bool = false) -> Dictionary:
	var documents := CatalogFactory.documents()
	if broken:
		documents["units.json"]["types"][0]["hp"] = 99
	var texts := {}
	for name: String in documents:
		texts[name] = JSON.stringify(documents[name])
	texts["maps/plaine.json"] = FileAccess.get_file_as_string("res://assets/data/maps/plaine.json")
	return texts


func _boot(files: FaultInjectingFileStore = null, broken: bool = false) -> Bootstrap:
	var boot := Bootstrap.new()
	boot.data_source = MemoryDataSource.new(_texts(broken))
	boot.file_store = files if files != null else FaultInjectingFileStore.new()
	boot.forced_seed = 11
	add_child(boot)
	return boot


func _finish(boot: Bootstrap) -> void:
	boot.free()
	await await_idle_frame()


func test_the_main_menu_comes_first_and_continue_needs_a_save() -> void:
	var boot := _boot()

	assert_object(boot.screen).is_instanceof(MainMenu)
	assert_bool((boot.screen as MainMenu).continue_button.disabled).is_true()
	assert_object(boot.match_screen).is_null()
	await _finish(boot)


func test_a_data_error_stops_everything_but_the_error_screen() -> void:
	var boot := _boot(null, true)

	assert_object(boot.screen).is_instanceof(DataErrorScreen)
	assert_bool((boot.screen as DataErrorScreen).errors_label.text.contains("units.json")).is_true()
	assert_bool(boot.app.is_ready()).is_false()
	await _finish(boot)


func test_a_new_game_opens_a_match_at_the_first_turn_of_the_player() -> void:
	var boot := _boot()

	(boot.screen as MainMenu).new_game_button.pressed.emit()

	assert_object(boot.match_screen).is_not_null()
	var state := boot.match_screen.session.state
	assert_array([state.turn(), state.header.value(HeaderSlice.PHASE), state.header.value(HeaderSlice.SEED)]) \
			.is_equal([1, HeaderSlice.PHASE_PLAYER, 11])
	assert_object(boot.screen).is_null()
	await _finish(boot)


func test_continue_resumes_the_saved_match() -> void:
	var files := FaultInjectingFileStore.new()
	var first := _boot(files)
	first.start_new_game()
	first.match_screen.end_turn()
	first.match_screen.ai_runner.advance()
	var saved := first.match_screen.session.state.duplicate_state()
	await _finish(first)

	var second := _boot(files.restarted())
	var menu := second.screen as MainMenu
	assert_bool(menu.continue_button.disabled).is_false()
	menu.continue_button.pressed.emit()

	assert_bool(second.match_screen.session.state.equals(saved)).is_true()
	assert_bool(second.match_screen.ai_runner.is_running()).is_true()
	await _finish(second)


func test_a_new_game_over_a_save_asks_before_erasing_it() -> void:
	var files := FaultInjectingFileStore.new()
	var first := _boot(files)
	first.start_new_game()
	await _finish(first)
	var boot := _boot(files.restarted())
	var menu := boot.screen as MainMenu
	var requests := [0]
	menu.new_game_requested.connect(func() -> void: requests[0] += 1)

	menu.new_game_button.pressed.emit()
	assert_array([requests[0], menu.confirm_button.visible, menu.new_game_button.visible, menu.continue_button.disabled]) \
			.is_equal([0, true, false, true])
	menu.cancel_button.pressed.emit()
	assert_array([requests[0], menu.confirm_button.visible, menu.new_game_button.visible, menu.continue_button.disabled]) \
			.is_equal([0, false, true, false])
	menu.new_game_button.pressed.emit()
	menu.confirm_button.pressed.emit()

	assert_int(requests[0]).is_equal(1)
	await _finish(boot)


func test_pause_leaves_to_the_menu_keeping_the_match() -> void:
	var files := FaultInjectingFileStore.new()
	var boot := _boot(files)
	boot.start_new_game()

	boot.toggle_pause()
	boot._pause.menu_button.pressed.emit()

	assert_object(boot.match_screen).is_null()
	assert_object(boot.screen).is_instanceof(MainMenu)
	assert_bool(files.exists("user://match.sav")).is_true()
	assert_bool((boot.screen as MainMenu).continue_button.disabled).is_false()
	await _finish(boot)


func test_resuming_from_the_pause_closes_it() -> void:
	var boot := _boot()
	boot.start_new_game()

	boot.toggle_pause()
	assert_object(boot._pause).is_not_null()
	boot._pause.resume_requested.emit()

	assert_object(boot._pause).is_null()
	assert_object(boot.match_screen).is_not_null()
	await _finish(boot)


func test_abandoning_shows_the_end_screen_and_leaving_it_erases_the_save() -> void:
	var files := FaultInjectingFileStore.new()
	var boot := _boot(files)
	boot.start_new_game()
	boot.toggle_pause()

	boot._pause.abandon_requested.emit()
	boot._process(0.0)

	assert_object(boot.screen).is_instanceof(EndScreen)
	assert_str((boot.screen as EndScreen).title_label.text).is_equal("Partie abandonnée")
	assert_bool(files.exists("user://match.sav")).is_true()  # a stop here reopens the end screen
	(boot.screen as EndScreen).back_button.pressed.emit()
	assert_object(boot.match_screen).is_null()
	assert_object(boot.screen).is_instanceof(MainMenu)
	assert_bool(files.exists("user://match.sav")).is_false()
	assert_bool(files.exists("user://match.bak")).is_false()
	await _finish(boot)


func test_every_end_status_has_its_own_title() -> void:
	var titles := {}
	for status in [HeaderSlice.END_DOMINATION, HeaderSlice.END_ELIMINATED, HeaderSlice.END_TURNS_WON,
			HeaderSlice.END_TURNS_LOST, HeaderSlice.END_TURNS_DRAW, HeaderSlice.END_ABANDONED]:
		titles[EndScreen.title_for(status)] = true

	assert_int(titles.size()).is_equal(6)


func test_each_new_game_takes_a_new_match_id_from_the_profile() -> void:
	var files := FaultInjectingFileStore.new()
	var boot := _boot(files)
	boot.start_new_game()
	var first := boot.match_screen.session.state.header.value(HeaderSlice.MATCH_ID)
	boot.start_new_game()
	var second := boot.match_screen.session.state.header.value(HeaderSlice.MATCH_ID)

	assert_int(second).is_equal(first + 1)
	await _finish(boot)


func test_the_chronicle_of_the_profile_is_copied_into_the_new_match() -> void:
	var files := FaultInjectingFileStore.new()
	var boot := _boot(files)
	boot.profile.apply(RecordFragmentEffect.new(Faction.PLAYER, 1))

	boot.start_new_game()

	assert_bool(boot.match_screen.session.state.chronicle.has(Faction.PLAYER, 1)).is_true()
	await _finish(boot)


func test_the_app_going_to_the_background_retries_a_failed_save() -> void:
	var files := FaultInjectingFileStore.new()
	files.storage_full = true
	var boot := _boot(files)
	boot.start_new_game()
	var coordinator := boot.match_screen.session.post_commit as SaveCoordinator
	assert_int(coordinator.last_error).is_not_equal(OK)

	files.storage_full = false
	boot.notification(Node.NOTIFICATION_APPLICATION_PAUSED)

	assert_int(coordinator.last_error).is_equal(OK)
	assert_bool(files.exists("user://match.sav")).is_true()
	await _finish(boot)


func test_the_project_starts_on_the_bootstrap_scene() -> void:
	assert_str(ProjectSettings.get_setting("application/run/main_scene")).is_equal("res://src/app/bootstrap.tscn")
	var scene: Node = load("res://src/app/bootstrap.tscn").instantiate()
	assert_object(scene).is_instanceof(Bootstrap)
	scene.free()


func test_the_android_back_button_opens_and_closes_the_pause_in_a_match() -> void:
	var boot := _boot()
	boot.start_new_game()

	boot.notification(Node.NOTIFICATION_WM_GO_BACK_REQUEST)
	assert_object(boot._pause).is_not_null()
	boot.notification(Node.NOTIFICATION_WM_GO_BACK_REQUEST)

	assert_object(boot._pause).is_null()
	await _finish(boot)


func test_continue_without_a_save_falls_back_to_the_menu() -> void:
	var boot := _boot()

	boot.continue_match()

	assert_object(boot.match_screen).is_null()
	assert_object(boot.screen).is_instanceof(MainMenu)
	await _finish(boot)
