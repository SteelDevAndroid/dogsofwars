extends GdUnitTestSuite


func _hud() -> Hud:
	var hud := Hud.new()
	add_child(hud)
	return hud


func _model() -> HudModel:
	var model := HudModel.new()
	model.turn_text = "Tour 3 / 30"
	model.energy_text = "9"
	model.fragments_text = "1 / 3"
	model.score_text = "40 contre 38"
	model.score_player = 40
	model.score_ai = 38
	model.can_end_turn = true
	return model


func test_the_hud_copies_the_model_to_its_widgets() -> void:
	var hud := _hud()
	var model := _model()
	model.unit_panel = {"title": "Assaut", "lines": ["PV 8 / 8", "A bougé"]}

	hud.show_model(model)

	assert_array([hud.turn_label.text, hud.energy_label.text, hud.fragments_label.text, hud.score_label.text]) \
			.is_equal(["Tour 3 / 30", "9", "1 / 3", "40 contre 38"])
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

	var texts := hud.alert_row.get_children().map(func(chip: Node) -> String: return (chip as Label).text if chip is Label else (chip as Button).text)
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


func test_the_input_surface_turns_fingers_into_pointer_events_and_ignores_the_mouse() -> void:
	var surface := InputSurface.new()
	var events: Array[PointerEvent] = []
	surface.pointer.connect(func(event: PointerEvent) -> void: events.append(event))
	var down := InputEventScreenTouch.new()
	down.index = 1
	down.position = Vector2(10, 20)
	down.pressed = true
	var drag := InputEventScreenDrag.new()
	drag.index = 1
	drag.position = Vector2(15, 25)
	var up := InputEventScreenTouch.new()
	up.index = 1
	up.position = Vector2(15, 25)
	up.pressed = false
	var lost := InputEventScreenTouch.new()
	lost.canceled = true
	var click := InputEventMouseButton.new()
	click.pressed = true
	click.button_index = MOUSE_BUTTON_LEFT

	for event in [down, drag, up, lost, click]:
		surface._gui_input(event)
	surface.cancel_all()

	assert_array(events.map(func(e: PointerEvent) -> int: return e.phase)).is_equal([
		PointerEvent.Phase.DOWN, PointerEvent.Phase.MOVE, PointerEvent.Phase.UP, PointerEvent.Phase.CANCEL, PointerEvent.Phase.CANCEL, PointerEvent.Phase.CANCEL])
	assert_array([events[0].index, events[0].position]).is_equal([1, Vector2(10, 20)])
	assert_vector(events[1].position).is_equal(Vector2(15, 25))
	surface.free()


func test_the_layout_places_the_zones_and_switches_the_rows_between_portrait_and_rail() -> void:
	var hud := _hud()
	var portrait := HudLayout.compute(Vector2(390, 844), Rect2(0, 0, 390, 844), 130.0, 300.0)
	var landscape := HudLayout.compute(Vector2(844, 390), Rect2(0, 0, 844, 390), 130.0, 300.0)

	hud.apply_layout(portrait)
	assert_vector(hud.top_panel.position).is_equal(Vector2(0, 0))
	assert_vector(hud.top_panel.size).is_equal(Vector2(390, 130))
	assert_vector(hud.camera_box.position).is_equal(portrait.camera_buttons.position)
	assert_bool(hud.camera_box.vertical).is_false()  # a row in the panel, beside the title
	assert_float(hud.unit_title.custom_minimum_size.y).is_equal(HudLayout.BUTTON)
	assert_bool(hud.bar.vertical).is_false()
	hud.apply_layout(landscape)
	assert_bool(hud.camera_box.vertical).is_true()  # floating over the map, as before

	assert_vector(hud.top_panel.size).is_equal(Vector2(140, 390))
	assert_vector(hud.bottom_panel.position).is_equal(Vector2(620, 0))
	assert_bool(hud.bar.vertical).is_true()
	assert_bool(hud.measure().x > 0.0 and hud.measure().y > 0.0).is_true()
	hud.free()


func test_the_camera_buttons_emit_their_signals() -> void:
	var hud := _hud()
	var pressed := [0, 0, 0]
	hud.zoom_in_pressed.connect(func() -> void: pressed[0] += 1)
	hud.zoom_out_pressed.connect(func() -> void: pressed[1] += 1)
	hud.recenter_pressed.connect(func() -> void: pressed[2] += 1)

	hud.zoom_in_button.pressed.emit()
	hud.zoom_out_button.pressed.emit()
	hud.recenter_button.pressed.emit()
	hud.recenter_button.pressed.emit()

	assert_array(pressed).is_equal([1, 1, 2])
	assert_int(hud.zoom_in_button.accessibility_name.length()).is_greater(0)
	assert_float(hud.zoom_in_button.custom_minimum_size.x).is_equal(48.0)
	hud.free()


func test_the_score_gauge_shows_the_players_share() -> void:
	var hud := Hud.new()
	add_child(hud)
	var model := HudModel.new()
	model.score_text = "30 contre 10"
	model.score_player = 30
	model.score_ai = 10

	hud.show_model(model)
	assert_float(hud.score_bar.value).is_equal(75.0)
	model.score_player = 0
	model.score_ai = 0
	hud.show_model(model)
	assert_float(hud.score_bar.value).is_equal(50.0)  # nothing yet: the middle
	model.score_player = 0
	model.score_ai = 8
	hud.show_model(model)
	assert_float(hud.score_bar.value).is_equal(0.0)
	hud.free()


func test_each_figure_of_the_top_bar_has_an_icon_and_a_name() -> void:
	var hud := Hud.new()
	add_child(hud)

	for label in [hud.turn_label, hud.energy_label, hud.fragments_label]:
		var box := (label as Label).get_parent() as HBoxContainer
		assert_str(box.tooltip_text).is_not_empty()
		var icon := box.get_child(0) as TextureRect
		assert_object(icon.texture).is_not_null()
	assert_array([hud.energy_label.get_parent().tooltip_text, hud.fragments_label.get_parent().tooltip_text]).is_equal(["Énergie", "Ruines lues"])
	hud.free()


func _unit_model() -> HudModel:
	var model := HudModel.new()
	model.unit_panel = {"title": "Assaut", "lines": ["PV 5 / 8", "MVT 3", "A bougé"], "hp": 5, "hp_max": 8,
			"stats": [["MVT", 3], ["ATQ", 3], ["DÉF", 1], ["VUE", 2]]}
	return model


func test_a_unit_is_a_card_with_a_gauge_and_four_pills_and_only_its_statuses_as_lines() -> void:
	var hud := Hud.new()
	add_child(hud)

	hud.show_model(_unit_model())

	assert_bool(hud.hp_bar.visible).is_true()
	assert_array([hud.hp_bar.value, hud.hp_bar.max_value]).is_equal([5.0, 8.0])
	assert_str(hud.hp_label.text).is_equal("PV 5 / 8")
	var pills := hud.stats_row.get_children().map(func(pill: Node) -> String: return ((pill.get_child(0) as HBoxContainer).get_child(-1) as Label).text)
	assert_array(pills).is_equal(["MVT 3", "ATQ 3", "DÉF 1", "VUE 2"])
	assert_str(hud.unit_lines.text).is_equal("A bougé")  # the first two lines are the card's; "MVT 3" above is one of them
	hud.free()


func test_a_node_panel_keeps_its_plain_lines_and_no_card() -> void:
	var hud := Hud.new()
	add_child(hud)
	var model := HudModel.new()
	model.unit_panel = {"title": "Nœud · niveau 1", "lines": ["Revenu 3", "Niveau maximal"]}

	hud.show_model(model)

	assert_bool(hud.hp_bar.visible).is_false()
	assert_bool(hud.stats_row.visible).is_false()
	assert_str(hud.unit_lines.text).is_equal("Revenu 3\nNiveau maximal")
	hud.free()


func test_the_speed_button_shows_only_in_the_enemy_turn() -> void:
	var hud := Hud.new()
	add_child(hud)
	var model := HudModel.new()

	hud.show_model(model)
	assert_bool(hud.speed_button.visible).is_false()
	model.enemy_turn = true
	hud.show_model(model)
	assert_bool(hud.speed_button.visible).is_true()
	hud.free()


func test_a_toast_shows_for_its_duration_then_goes() -> void:
	var hud := Hud.new()
	add_child(hud)

	hud.show_toast("Énergie insuffisante", 10.0, 2.0)
	assert_bool(hud.toast_panel.visible).is_true()
	assert_str(hud.toast_label.text).is_equal("Énergie insuffisante")
	hud.tick_toast(11.9)
	assert_bool(hud.toast_panel.visible).is_true()
	hud.tick_toast(12.0)
	assert_bool(hud.toast_panel.visible).is_false()
	hud.show_toast("", 20.0)
	assert_bool(hud.toast_panel.visible).is_false()  # nothing to tell
	hud.free()


func test_the_end_turn_button_is_the_filled_main_action() -> void:
	var hud := Hud.new()
	add_child(hud)

	assert_object(hud.end_turn_button.get_theme_stylebox("normal")).is_instanceof(StyleBoxFlat)
	assert_object((hud.end_turn_button.get_theme_stylebox("normal") as StyleBoxFlat).bg_color).is_equal(Color("1FA38F"))
	assert_float(hud.end_turn_button.custom_minimum_size.y).is_greater_equal(56.0)
	hud.free()


func test_the_buttons_of_the_hud_carry_their_icons_and_the_camera_buttons_only_icons() -> void:
	var hud := Hud.new()
	add_child(hud)

	assert_object(hud.pause_button.icon).is_same(UiIcons.texture("pause"))
	assert_object(hud.research_button.icon).is_same(UiIcons.texture("recherche"))
	assert_object(hud.attack_button.icon).is_same(UiIcons.texture("attaque"))
	assert_object(hud.speed_button.icon).is_same(UiIcons.texture("vitesse"))
	assert_object(hud.zoom_in_button.icon).is_same(UiIcons.texture("zoom_plus"))
	assert_object(hud.zoom_out_button.icon).is_same(UiIcons.texture("zoom_moins"))
	assert_object(hud.recenter_button.icon).is_same(UiIcons.texture("recentrer"))
	for button in [hud.zoom_in_button, hud.zoom_out_button, hud.recenter_button]:
		assert_str(button.text).is_empty()
		assert_str(button.accessibility_name).is_not_empty()
	hud.free()


func test_the_rail_keeps_the_icons_of_pause_and_research_and_drops_their_words() -> void:
	var hud := Hud.new()
	add_child(hud)
	var portrait := HudLayout.compute(Vector2(390, 844), Rect2(0, 0, 390, 844), 130.0, 300.0)
	var landscape := HudLayout.compute(Vector2(844, 390), Rect2(0, 0, 844, 390), 0.0, 0.0)

	hud.apply_layout(landscape)
	assert_array([hud.pause_button.text, hud.research_button.text]).is_equal(["", ""])
	assert_str(hud.pause_button.accessibility_name).is_equal("Pause")
	assert_str(hud.research_button.tooltip_text).is_equal("Recherche")
	hud.apply_layout(portrait)
	assert_array([hud.pause_button.text, hud.research_button.text]).is_equal(["Pause", "Recherche"])
	hud.free()


func test_each_chip_has_the_icon_of_its_kind() -> void:
	var hud := Hud.new()
	add_child(hud)
	var model := HudModel.new()
	model.threat_chip = "Menace"
	model.loss_chips = ["Drone perdu"]
	hud.show_model(model)

	var icons := hud.alert_row.get_children().map(func(chip: Node) -> Texture2D: return (chip as Button).icon)
	assert_array(icons).is_equal([UiIcons.texture("menace"), UiIcons.texture("perte")])
	model.threat_chip = ""
	model.loss_chips = []
	model.ruin_chip = "Ruine repérée"
	hud.show_model(model)
	assert_object((hud.alert_row.get_child(0) as Button).icon).is_same(UiIcons.texture("ruine"))
	hud.free()


func test_the_actions_of_the_panel_show_their_icons() -> void:
	var hud := Hud.new()
	add_child(hud)
	var model := HudModel.new()
	model.extra_actions = [ContextAction.new(&"capture", "Capturer", true, ""), ContextAction.new(&"wake", "Réveiller", true, ""), ContextAction.new(&"research:1", "Autre", true, "")]

	hud.show_model(model)

	var icons := hud.extra_row.get_children().map(func(button: Node) -> Texture2D: return (button as Button).icon)
	assert_object(icons[0]).is_same(UiIcons.texture("noeud"))
	assert_object(icons[1]).is_same(UiIcons.texture("reveil"))
	assert_object(icons[2]).is_null()
	hud.free()


func test_a_chip_takes_the_camera_to_its_tile_and_a_chip_without_one_is_inert() -> void:
	var hud := _hud()
	var model := _model()
	model.threat_chip = "Menace"
	model.threat_tile = 27
	model.ruin_chip = "Ruine repérée"
	var tiles: Array[int] = []
	hud.chip_pressed.connect(func(tile: int) -> void: tiles.append(tile))

	hud.show_model(model)
	var chips := hud.alert_row.get_children()
	(chips[0] as Button).pressed.emit()

	assert_array(tiles).is_equal([27])
	assert_bool((chips[0] as Button).disabled).is_false()
	assert_bool((chips[1] as Button).disabled).is_true()  # the ruin chip of this model has no tile
	assert_float((chips[0] as Button).custom_minimum_size.y).is_equal(HudLayout.BUTTON)
	hud.free()


func test_the_toast_is_tappable_only_while_it_points_at_a_tile() -> void:
	var hud := _hud()
	hud.show_toast("Refus", 1.0)
	assert_int(hud.toast_panel.mouse_filter).is_equal(Control.MOUSE_FILTER_IGNORE)
	assert_int(hud.toast_tile()).is_equal(-1)

	hud.show_toast("Tour ennemi : 1 drone perdu", 1.0, 4.0, 33)

	assert_int(hud.toast_panel.mouse_filter).is_equal(Control.MOUSE_FILTER_STOP)
	assert_int(hud.toast_tile()).is_equal(33)
	hud.tick_toast(5.0)
	assert_int(hud.toast_tile()).is_equal(-1)
	assert_int(hud.toast_panel.mouse_filter).is_equal(Control.MOUSE_FILTER_IGNORE)
	hud.free()


func test_the_undo_button_follows_the_model() -> void:
	var hud := _hud()
	var model := _model()
	hud.show_model(model)
	assert_bool(hud.undo_button.visible).is_false()
	var pressed := [0]
	hud.undo_pressed.connect(func() -> void: pressed[0] += 1)

	model.undo_visible = true
	model.undo_enabled = true
	hud.show_model(model)
	hud.undo_button.pressed.emit()
	assert_array([hud.undo_button.visible, hud.undo_button.disabled, pressed[0]]).is_equal([true, false, 1])
	model.undo_enabled = false
	model.undo_reason = "Impossible d'annuler : le déplacement a révélé la carte ou lu une ruine"
	hud.show_model(model)

	assert_bool(hud.undo_button.disabled).is_true()
	assert_str(hud.reason_label.text).is_equal(model.undo_reason)
	hud.free()


func test_empty_lines_of_the_panel_take_no_room() -> void:
	var hud := _hud()
	hud.show_model(_model())

	for label in [hud.journal_label, hud.preview_label, hud.reason_label, hud.notice_label]:
		assert_bool(label.visible).is_false()
	hud.free()


func test_the_score_explains_itself_and_takes_the_colour_blind_tints() -> void:
	var hud := _hud()
	var pressed := [0]
	hud.score_pressed.connect(func() -> void: pressed[0] += 1)
	var release := InputEventMouseButton.new()
	release.button_index = MOUSE_BUTTON_LEFT
	release.pressed = false

	hud.score_box.gui_input.emit(release)
	hud.set_colorblind(true)

	assert_int(pressed[0]).is_equal(1)
	assert_str(hud.score_box.tooltip_text).is_equal(HudModel.SCORE_HELP)
	assert_object((hud.score_bar.get_theme_stylebox("fill") as StyleBoxFlat).bg_color).is_equal(TilePalette.PLAYER_ALT)
	assert_object((hud.score_bar.get_theme_stylebox("background") as StyleBoxFlat).bg_color).is_equal(TilePalette.ENEMY_ALT)
	hud.free()


func test_each_stat_pill_has_its_icon_and_a_tap_on_them_asks_for_their_meaning() -> void:
	var hud := _hud()
	var pressed := [0]
	hud.stats_pressed.connect(func() -> void: pressed[0] += 1)
	var release := InputEventMouseButton.new()
	release.button_index = MOUSE_BUTTON_LEFT
	release.pressed = false

	hud.show_model(_unit_model())
	hud.stats_row.gui_input.emit(release)

	var icons := hud.stats_row.get_children().map(func(pill: Node) -> Texture2D: return ((pill.get_child(0) as HBoxContainer).get_child(0) as TextureRect).texture)
	assert_array(icons).is_equal([UiIcons.texture("mouvement"), UiIcons.texture("attaque"), UiIcons.texture("defense"), UiIcons.texture("vue")])
	assert_int(pressed[0]).is_equal(1)
	assert_str(hud.stats_row.tooltip_text).is_equal(HudModel.STATS_HELP)
	hud.free()


func test_an_armed_end_of_turn_asks_to_confirm() -> void:
	var hud := _hud()
	var model := _model()
	model.end_turn_armed = true

	hud.show_model(model)

	assert_str(hud.end_turn_button.text).is_equal("Confirmer la fin du tour")
	hud.free()
