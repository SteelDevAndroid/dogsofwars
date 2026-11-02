extends GdUnitTestSuite


func _hud() -> Hud:
	var hud := Hud.new()
	add_child(hud)
	return hud


func _model() -> HudModel:
	var model := HudModel.new()
	model.turn_text = "Tour 3 / 30"
	model.energy_text = "Énergie 9"
	model.fragments_text = "Ruines lues 1"
	model.score_text = "Victoire : 40 contre 38"
	model.can_end_turn = true
	return model


func test_the_hud_copies_the_model_to_its_widgets() -> void:
	var hud := _hud()
	var model := _model()
	model.unit_panel = {"title": "Assaut", "lines": ["PV 8 / 8", "A bougé"]}

	hud.show_model(model)

	assert_array([hud.turn_label.text, hud.energy_label.text, hud.fragments_label.text, hud.score_label.text]) \
			.is_equal(["Tour 3 / 30", "Énergie 9", "Ruines lues 1", "Victoire : 40 contre 38"])
	assert_str(hud.unit_title.text).is_equal("Assaut")
	assert_str(hud.unit_lines.text).is_equal("PV 8 / 8\nA bougé")
	assert_bool(hud.end_turn_button.disabled).is_false()
	hud.free()


func test_the_end_turn_button_greys_out_in_the_enemy_turn_and_shows_the_journal() -> void:
	var hud := _hud()
	var model := _model()
	model.can_end_turn = false
	model.enemy_turn = true
	model.journal = ["Un Gardien se déplace"]

	hud.show_model(model)

	assert_bool(hud.end_turn_button.disabled).is_true()
	assert_str(hud.end_turn_button.text).is_equal("Tour ennemi…")
	assert_str(hud.journal_label.text).is_equal("Un Gardien se déplace")
	model.enemy_turn = false
	hud.show_model(model)
	assert_str(hud.journal_label.text).is_empty()
	hud.free()


func test_at_most_two_alert_chips_show_and_the_rest_is_counted() -> void:
	var hud := _hud()
	var model := _model()
	model.threat_chip = "Menace"
	model.loss_chips.append("Drone perdu")
	model.ruin_chip = "Ruine repérée"

	hud.show_model(model)
	await await_idle_frame()

	var texts := hud.alert_row.get_children().map(func(label: Label) -> String: return label.text)
	assert_array(texts).is_equal(["Menace", "Drone perdu", "+1"])
	model.threat_chip = ""
	model.loss_chips.clear()
	hud.show_model(model)
	await await_idle_frame()
	assert_int(hud.alert_row.get_child_count()).is_equal(1)
	hud.free()


func test_the_buttons_emit_their_signals() -> void:
	var hud := _hud()
	var pressed := [0, 0]
	hud.end_turn_pressed.connect(func() -> void: pressed[0] += 1)
	hud.pause_pressed.connect(func() -> void: pressed[1] += 1)

	hud.end_turn_button.pressed.emit()
	hud.pause_button.pressed.emit()
	hud.pause_button.pressed.emit()

	assert_array(pressed).is_equal([1, 2])
	hud.free()


func test_the_input_surface_turns_a_tap_into_a_position() -> void:
	var surface := InputSurface.new()
	var taps: Array[Vector2] = []
	surface.tapped.connect(func(position: Vector2) -> void: taps.append(position))
	var touch := InputEventScreenTouch.new()
	touch.position = Vector2(10, 20)
	touch.pressed = true
	var click := InputEventMouseButton.new()
	click.position = Vector2(30, 40)
	click.pressed = true
	click.button_index = MOUSE_BUTTON_LEFT
	var release := InputEventMouseButton.new()
	release.pressed = false
	release.button_index = MOUSE_BUTTON_LEFT

	surface._gui_input(touch)
	surface._gui_input(click)
	surface._gui_input(release)

	assert_array(taps).is_equal([Vector2(10, 20), Vector2(30, 40)])
	surface.free()
