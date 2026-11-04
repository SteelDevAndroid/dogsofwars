extends GdUnitTestSuite


func _texts(broken: bool = false) -> Dictionary:
	var documents := CatalogFactory.documents()
	if broken:
		documents["units.json"]["types"][0]["hp"] = 99
	var texts := {}
	for name: String in documents:
		texts[name] = JSON.stringify(documents[name])
	for file in Bootstrap.MAP_FILES:
		texts[file] = FileAccess.get_file_as_string("res://assets/data/" + file)
	return texts


func _boot(files: FaultInjectingFileStore = null, broken: bool = false, dpi: int = -1) -> Bootstrap:
	var boot := Bootstrap.new()
	boot.screen_dpi = dpi
	boot.show_title = false
	boot.data_source = MemoryDataSource.new(_texts(broken))
	boot.file_store = files if files != null else FaultInjectingFileStore.new()
	boot.forced_seed = 11
	add_child(boot)
	return boot


## "Nouvelle partie" then "Au hasard": the map is the one the seed points at, as before the choice screen.
func _start_random(boot: Bootstrap) -> void:
	(boot.screen as MainMenu).new_game_button.pressed.emit()
	(boot.screen as MapChoiceScreen).random_button.pressed.emit()


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

	_start_random(boot)

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


func test_a_setting_changed_in_the_menu_is_stored_applied_and_found_again_after_a_restart() -> void:
	var files := FaultInjectingFileStore.new()
	var boot := _boot(files, false, 240)
	(boot.screen as MainMenu).settings_button.pressed.emit()
	var screen := boot._settings_screen
	assert_object(screen).is_not_null()

	screen.colorblind_check.button_pressed = true
	screen.scale_option.item_selected.emit(2)

	assert_int(boot.profile.setting(GameSettings.COLORBLIND)).is_equal(1)
	assert_float(boot.get_window().content_scale_factor).is_equal_approx(2.25, 0.0001)  # 240 dpi x 150 %
	screen.back_button.pressed.emit()
	await await_idle_frame()
	assert_object(boot._settings_screen).is_null()
	await _finish(boot)

	get_window().content_scale_factor = 1.0  # the window outlives the first boot
	var again := _boot(files.restarted(), false, 240)
	assert_float(again.get_window().content_scale_factor).is_equal_approx(2.25, 0.0001)  # read before the first screen
	assert_int(again.profile.setting(GameSettings.COLORBLIND)).is_equal(1)
	assert_int(again.profile.setting(GameSettings.TEXT_SCALE)).is_equal(150)
	(again.screen as MainMenu).settings_button.pressed.emit()
	assert_bool(again._settings_screen.colorblind_check.button_pressed).is_true()
	assert_int(again._settings_screen.scale_option.selected).is_equal(2)
	get_window().content_scale_factor = 1.0
	await _finish(again)


func test_a_match_starts_with_the_stored_settings_and_changes_apply_to_it_at_once() -> void:
	var files := FaultInjectingFileStore.new()
	var first := _boot(files)
	first.profile.set_setting(GameSettings.REDUCED_MOTION, 1)
	first.profile.set_setting(GameSettings.ENEMY_SPEED, 1)
	await _finish(first)

	var boot := _boot(files.restarted())
	_start_random(boot)
	var screen := boot.match_screen
	assert_bool(screen.sequencer.reduced_motion).is_true()
	assert_int(screen.clock.speed).is_equal(PresentationClock.Speed.FAST)

	boot.toggle_pause()
	boot._pause.settings_button.pressed.emit()
	boot._settings_screen.colorblind_check.button_pressed = true
	assert_bool(screen.renderer.colorblind).is_true()

	screen.hud.speed_button.pressed.emit()  # fast -> instant, remembered
	assert_int(boot.profile.setting(GameSettings.ENEMY_SPEED)).is_equal(2)
	await _finish(boot)


func test_a_refused_change_puts_the_screen_back() -> void:
	var files := FaultInjectingFileStore.new()
	var boot := _boot(files)
	boot.show_settings()
	files.storage_full = true

	boot._settings_screen.reduced_motion_check.button_pressed = true

	assert_int(boot.profile.setting(GameSettings.REDUCED_MOTION)).is_equal(0)
	assert_bool(boot._settings_screen.reduced_motion_check.button_pressed).is_false()
	await _finish(boot)


func test_the_text_scale_is_applied_again_when_the_window_changes() -> void:
	var files := FaultInjectingFileStore.new()
	var first := _boot(files, false, 240)
	first.profile.set_setting(GameSettings.TEXT_SCALE, 150)
	get_window().content_scale_factor = 1.0

	get_window().size_changed.emit()

	assert_float(get_window().content_scale_factor).is_equal_approx(2.25, 0.0001)
	get_window().content_scale_factor = 1.0
	await _finish(first)


func test_a_match_that_cannot_be_resumed_is_explained_in_the_menu() -> void:
	var files := FaultInjectingFileStore.new()
	files.write("user://match.sav", FileAccess.get_file_as_bytes("res://tests/fixtures/saves/schema2_enemy.sav"))
	var boot := _boot(files)

	(boot.screen as MainMenu).continue_button.pressed.emit()

	assert_object(boot.screen).is_instanceof(MainMenu)
	assert_str((boot.screen as MainMenu).notice_label.text).contains("format de la partie")
	assert_bool((boot.screen as MainMenu).continue_button.disabled).is_true()
	await _finish(boot)


func test_the_notices_of_the_other_refusals() -> void:
	assert_str(Bootstrap._load_notice(LoadResult.NEWER)).contains("plus récente")
	assert_str(Bootstrap._load_notice(LoadResult.CORRUPT)).contains("abîmée")
	assert_str(Bootstrap._load_notice(LoadResult.NONE)).is_empty()


func test_a_schema_two_match_in_the_player_phase_resumes_from_the_menu() -> void:
	var files := FaultInjectingFileStore.new()
	files.write("user://match.sav", FileAccess.get_file_as_bytes("res://tests/fixtures/saves/schema2_player.sav"))
	var boot := _boot(files)

	(boot.screen as MainMenu).continue_button.pressed.emit()

	assert_object(boot.match_screen).is_not_null()
	await _finish(boot)


func test_the_menus_are_drawn_above_the_hud_of_the_match() -> void:
	var boot := _boot()
	_start_random(boot)

	assert_int(boot._ui.layer).is_greater(boot.match_screen.hud_layer.layer)
	await _finish(boot)


func test_the_chronicle_opens_from_the_menu_with_the_fragments_of_the_profile_and_closes() -> void:
	var files := FaultInjectingFileStore.new()
	var first := _boot(files)
	first.profile.apply(RecordFragmentEffect.new(Faction.PLAYER, 2))
	await _finish(first)
	var boot := _boot(files.restarted())

	(boot.screen as MainMenu).chronicle_button.pressed.emit()

	assert_object(boot._chronicle_screen).is_not_null()
	assert_str(boot._chronicle_screen.bar_label.text).is_equal("○●○○○   1 / 5")
	boot._chronicle_screen.back_button.pressed.emit()
	await await_idle_frame()
	assert_object(boot._chronicle_screen).is_null()
	await _finish(boot)


func _plain_boot() -> Bootstrap:
	var boot := Bootstrap.new()
	boot.data_source = MemoryDataSource.new(_texts())
	boot.file_store = FaultInjectingFileStore.new()
	add_child(boot)
	return boot


func test_the_title_screen_comes_first_and_a_touch_opens_the_menu_once() -> void:
	var boot := _plain_boot()
	assert_object(boot.screen).is_instanceof(TitleScreen)
	var touch := InputEventScreenTouch.new()
	touch.pressed = true

	boot.screen._gui_input(touch)
	assert_object(boot.screen).is_instanceof(MainMenu)
	await _finish(boot)


func test_a_click_also_opens_the_menu_and_a_release_does_not() -> void:
	var boot := _plain_boot()
	var release := InputEventScreenTouch.new()
	release.pressed = false
	boot.screen._gui_input(release)
	assert_object(boot.screen).is_instanceof(TitleScreen)
	var click := InputEventMouseButton.new()
	click.pressed = true
	click.button_index = MOUSE_BUTTON_LEFT

	boot.screen._gui_input(click)

	assert_object(boot.screen).is_instanceof(MainMenu)
	await _finish(boot)


func test_the_title_announces_the_start_only_once() -> void:
	var title := TitleScreen.new()
	add_child(title)
	var starts := [0]
	title.started.connect(func() -> void: starts[0] += 1)
	var touch := InputEventScreenTouch.new()
	touch.pressed = true
	var click := InputEventMouseButton.new()
	click.pressed = true

	title._gui_input(touch)
	title._gui_input(click)

	assert_int(starts[0]).is_equal(1)
	assert_object(title.get_child(1)).is_instanceof(TextureRect)
	assert_object((title.get_child(1) as TextureRect).texture).is_not_null()
	title.free()


func test_a_data_error_skips_the_title_screen() -> void:
	var documents := CatalogFactory.documents()
	documents["units.json"]["types"][0]["hp"] = 99
	var texts := {}
	for name: String in documents:
		texts[name] = JSON.stringify(documents[name])
	var boot := Bootstrap.new()
	boot.data_source = MemoryDataSource.new(texts)
	boot.file_store = FaultInjectingFileStore.new()
	add_child(boot)

	assert_object(boot.screen).is_instanceof(DataErrorScreen)
	await _finish(boot)


func test_how_to_play_opens_from_the_menu_and_closes() -> void:
	var boot := _boot()

	(boot.screen as MainMenu).how_to_play_button.pressed.emit()
	assert_object(boot._how_to_play_screen).is_not_null()
	boot._how_to_play_screen.back_button.pressed.emit()
	await await_idle_frame()

	assert_object(boot._how_to_play_screen).is_null()
	await _finish(boot)


func test_a_new_game_takes_the_map_its_seed_points_at() -> void:
	var sizes := []
	for seed_value in [0, 1]:
		var boot := _boot()
		boot.forced_seed = seed_value
		_start_random(boot)
		sizes.append(boot.match_screen.session.state.width())
		await _finish(boot)

	assert_array(sizes).is_equal([12, 14])


func test_the_volumes_of_the_profile_reach_the_sound_bank_and_every_button_taps() -> void:
	var files := FaultInjectingFileStore.new()
	var first := _boot(files)
	first.profile.set_setting(GameSettings.VOLUME_EFFECTS, 40)
	first.profile.set_setting(GameSettings.VOLUME_UI, 0)
	await _finish(first)

	var boot := _boot(files.restarted())
	assert_array([boot.sounds.volume_of(SoundBank.EFFECTS_BUS), boot.sounds.volume_of(SoundBank.INTERFACE_BUS)]).is_equal([40, 0])
	boot.show_settings()
	boot._settings_screen.effects_slider.value = 70
	assert_int(boot.sounds.volume_of(SoundBank.EFFECTS_BUS)).is_equal(70)
	boot.sounds.played.clear()
	(boot.screen as MainMenu).settings_button.pressed.emit()
	assert_array(boot.sounds.played).contains([&"ui_tap"])
	boot.sounds.set_volumes(100, 100)
	await _finish(boot)


func test_a_new_game_plays_its_sounds_and_the_end_screen_wins_or_loses() -> void:
	var boot := _boot()
	_start_random(boot)
	assert_object(boot.match_screen.sounds).is_same(boot.sounds)
	for frame in 40:  # the opening of the match plays out before a tap counts
		if boot.match_screen.is_idle():
			break
		await await_idle_frame()

	boot.sounds.played.clear()
	boot.match_screen.on_tap_tile(FactionView.new(boot.match_screen.session.state, Faction.PLAYER).unit_tile(0))
	assert_array(boot.sounds.played).contains([&"select"])
	await _finish(boot)


func test_the_end_screen_wins_loses_or_stays_silent_for_an_abandon() -> void:
	var cues := {}
	for status in [HeaderSlice.END_TURNS_WON, HeaderSlice.END_DOMINATION, HeaderSlice.END_ELIMINATED, HeaderSlice.END_TURNS_LOST, HeaderSlice.END_ABANDONED]:
		var boot := _boot()
		_start_random(boot)
		TurnWrites.finish(boot.match_screen.session.state, status)
		boot.sounds.played.clear()
		boot._show_end()
		cues[status] = Array(boot.sounds.played).filter(func(c: StringName) -> bool: return c == &"victory" or c == &"defeat")
		await _finish(boot)

	assert_array(cues[HeaderSlice.END_TURNS_WON]).is_equal([&"victory"])
	assert_array(cues[HeaderSlice.END_DOMINATION]).is_equal([&"victory"])
	assert_array(cues[HeaderSlice.END_ELIMINATED]).is_equal([&"defeat"])
	assert_array(cues[HeaderSlice.END_TURNS_LOST]).is_equal([&"defeat"])
	assert_array(cues[HeaderSlice.END_ABANDONED]).is_empty()


func test_a_new_game_asks_for_the_map_first_and_back_returns_to_the_menu() -> void:
	var boot := _boot()

	(boot.screen as MainMenu).new_game_button.pressed.emit()

	assert_object(boot.screen).is_instanceof(MapChoiceScreen)
	assert_object(boot.match_screen).is_null()  # nothing started yet
	var choice := boot.screen as MapChoiceScreen
	assert_int(choice.play_buttons.size()).is_equal(Bootstrap.MAP_FILES.size())
	choice.back_button.pressed.emit()
	await await_idle_frame()
	assert_object(boot.screen).is_instanceof(MainMenu)
	await _finish(boot)


func test_the_player_plays_the_map_they_chose_whatever_the_seed() -> void:
	var sizes := []
	for index in Bootstrap.MAP_FILES.size():
		var boot := _boot()
		boot.forced_seed = 0  # the seed alone would give the first map each time
		(boot.screen as MainMenu).new_game_button.pressed.emit()
		(boot.screen as MapChoiceScreen).play_buttons[index].pressed.emit()
		sizes.append(boot.match_screen.session.state.width())
		assert_int(boot.match_screen.session.state.header.value(HeaderSlice.SEED)).is_equal(0)
		await _finish(boot)

	assert_array(sizes).is_equal([12, 14])


func test_a_map_that_fails_its_checks_is_not_offered() -> void:
	var texts := _texts(false)
	texts[Bootstrap.MAP_FILES[1]] = texts[Bootstrap.MAP_FILES[1]].replace('"title": "Le Marais"', '"title": ""')
	var boot := Bootstrap.new()
	boot.show_title = false
	boot.data_source = MemoryDataSource.new(texts)
	boot.file_store = FaultInjectingFileStore.new()
	add_child(boot)

	(boot.screen as MainMenu).new_game_button.pressed.emit()

	assert_object(boot.screen).is_instanceof(DataErrorScreen)
	assert_bool((boot.screen as DataErrorScreen).errors_label.text.contains("marais.json")).is_true()
	await _finish(boot)
