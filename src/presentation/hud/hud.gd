# The HUD control (design/ux/hud.md): top bar (turn, energy, ruins read, pause), decisive
# score row, alert row (threat, losses, ruin), and the context panel (selected unit, journal
# of the enemy turn, the end-turn button). It only copies a HudModel to its widgets and
# emits signals; no game rule lives here.
class_name Hud
extends Control

signal end_turn_pressed
signal pause_pressed
signal speed_pressed
signal attack_pressed
signal confirm_pressed
signal cancel_pressed
signal action_pressed(id: StringName)
signal research_pressed
signal research_row_pressed(id: StringName)
signal research_closed
signal zoom_in_pressed
signal zoom_out_pressed
signal recenter_pressed

var turn_label := Label.new()
var energy_label := Label.new()
var fragments_label := Label.new()
var score_label := Label.new()
## Player share of the two decisive scores (teal against violet): the numbers say it too.
var score_bar := ProgressBar.new()
var alert_row := HBoxContainer.new()
var unit_title := Label.new()
var unit_lines := Label.new()
## The unit card: a gauge of hit points (a mark at half) and the four stats as pills.
var hp_bar := ProgressBar.new()
var hp_label := Label.new()
var stats_row := HBoxContainer.new()
## A refusal told for a moment under the top bar (the reason also stays greyed in the panel).
var toast_label := Label.new()
var toast_panel: PanelContainer
var journal_label := Label.new()
var end_turn_button := Button.new()
var pause_button := Button.new()
var speed_button := Button.new()
var hint_label := Label.new()
var notice_label := Label.new()
var fragment_panel := FragmentPanel.new()
var preview_label := Label.new()
var attack_button := Button.new()
var confirm_button := Button.new()
var cancel_button := Button.new()
var extra_row := HBoxContainer.new()
var reason_label := Label.new()
var research_button := Button.new()
var research_panel := ResearchPanel.new()
var zoom_in_button := Button.new()
var zoom_out_button := Button.new()
var recenter_button := Button.new()
var camera_box := VBoxContainer.new()
var top_panel: PanelContainer
var bottom_panel: PanelContainer
## The rows that stack when the rail is narrow (landscape).
var bar := BoxContainer.new()
var _toast_until := 0.0
var second := BoxContainer.new()


func _init() -> void:
	set_anchors_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	var top := VBoxContainer.new()
	top_panel = backdrop(top)
	add_child(top_panel)
	for entry in [[turn_label, "ui_icon_tour", "Tour"], [energy_label, "ui_icon_energie", "Énergie"], [fragments_label, "ui_icon_ruine", "Ruines lues"]]:
		var label: Label = entry[0]
		label.clip_text = true  # a long text never pushes the buttons off the screen
		label.add_theme_font_size_override("font_size", 17)
		label.custom_minimum_size = Vector2(0, 32)
		label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		var stat := _stat(entry[1], label, entry[2])
		stat.size_flags_stretch_ratio = 1.8 if label == turn_label else 1.0  # "Tour 12 / 30" is the longest
		bar.add_child(stat)
	pause_button.text = "Pause"
	UiIcons.put(pause_button, "pause")
	pause_button.custom_minimum_size = Vector2(64, 48)
	pause_button.tooltip_text = "Pause"
	pause_button.accessibility_name = "Pause"
	pause_button.pressed.connect(func() -> void: pause_pressed.emit())
	research_button.text = "Recherche"
	UiIcons.put(research_button, "recherche")
	research_button.custom_minimum_size = Vector2(88, 48)
	research_button.tooltip_text = "Recherche"
	research_button.accessibility_name = "Recherche"
	research_button.pressed.connect(func() -> void: research_pressed.emit())
	top.add_child(bar)
	score_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	score_label.clip_text = true
	score_label.add_theme_font_size_override("font_size", 15)
	score_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	var score_box := VBoxContainer.new()
	score_box.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	score_box.add_theme_constant_override("separation", 2)
	score_box.add_child(score_label)
	score_bar.show_percentage = false
	score_bar.custom_minimum_size = Vector2(0, 8)
	score_bar.min_value = 0
	score_bar.max_value = 100
	score_bar.value = 50
	var fill := StyleBoxFlat.new()
	fill.bg_color = Color("1FA38F")
	var back := StyleBoxFlat.new()
	back.bg_color = Color("C49BEA")
	score_bar.add_theme_stylebox_override("fill", fill)
	score_bar.add_theme_stylebox_override("background", back)
	score_box.add_child(score_bar)
	second.add_child(score_box)
	second.add_child(research_button)
	second.add_child(pause_button)
	top.add_child(second)
	top.add_child(notice_label)
	top.add_child(alert_row)
	var bottom := VBoxContainer.new()
	bottom_panel = backdrop(bottom)
	add_child(bottom_panel)
	unit_title.add_theme_font_size_override("font_size", 20)
	bottom.add_child(unit_title)
	hp_bar.show_percentage = false
	hp_bar.custom_minimum_size = Vector2(0, 8)
	var hp_fill := StyleBoxFlat.new()
	hp_fill.bg_color = Color("EADFC8")
	var hp_back := StyleBoxFlat.new()
	hp_back.bg_color = Color("2B323A")
	hp_bar.add_theme_stylebox_override("fill", hp_fill)
	hp_bar.add_theme_stylebox_override("background", hp_back)
	hp_label.add_theme_font_size_override("font_size", 14)
	stats_row.add_theme_constant_override("separation", 6)
	for node in [hp_label, hp_bar, stats_row]:
		node.visible = false
		bottom.add_child(node)
	bottom.add_child(unit_lines)
	bottom.add_child(journal_label)
	bottom.add_child(preview_label)
	var actions := HBoxContainer.new()
	for pair in [[attack_button, "Attaquer", attack_pressed], [confirm_button, "Confirmer", confirm_pressed], [cancel_button, "Annuler", cancel_pressed]]:
		var button: Button = pair[0]
		button.text = pair[1]
		if button == attack_button:
			UiIcons.put(button, "attaque")
		button.custom_minimum_size = Vector2(0, 48)
		button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		button.pressed.connect(func() -> void: (pair[2] as Signal).emit())
		actions.add_child(button)
	bottom.add_child(actions)
	bottom.add_child(extra_row)
	bottom.add_child(reason_label)
	hint_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	hint_label.modulate = Color(1, 1, 1, 0.8)
	bottom.add_child(hint_label)
	end_turn_button.text = "Fin du tour"
	end_turn_button.custom_minimum_size = Vector2(0, 56)
	MenuLayout.make_primary(end_turn_button)  # the one main action of the panel
	end_turn_button.pressed.connect(func() -> void: end_turn_pressed.emit())
	bottom.add_child(end_turn_button)
	speed_button.text = "Vitesse : normale"
	UiIcons.put(speed_button, "vitesse")
	speed_button.custom_minimum_size = Vector2(0, 40)
	speed_button.pressed.connect(func() -> void: speed_pressed.emit())
	bottom.add_child(speed_button)
	for entry in [[zoom_in_button, "zoom_plus", "Zoom avant", zoom_in_pressed], [zoom_out_button, "zoom_moins", "Zoom arrière", zoom_out_pressed],
			[recenter_button, "recentrer", "Recentrer", recenter_pressed]]:
		var button: Button = entry[0]
		button.icon = UiIcons.texture(entry[1])
		button.expand_icon = true
		button.icon_alignment = HORIZONTAL_ALIGNMENT_CENTER
		button.add_theme_constant_override("icon_max_width", 28)
		button.tooltip_text = entry[2]
		button.accessibility_name = entry[2]
		button.custom_minimum_size = Vector2(HudLayout.BUTTON, HudLayout.BUTTON)
		button.pressed.connect(func() -> void: (entry[3] as Signal).emit())
		camera_box.add_child(button)
	camera_box.add_theme_constant_override("separation", int(HudLayout.BUTTON_GAP))
	add_child(camera_box)
	toast_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	toast_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	toast_label.custom_minimum_size = Vector2(200, 0)
	toast_panel = backdrop(toast_label)
	toast_panel.visible = false
	toast_panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(toast_panel)
	add_child(fragment_panel)
	add_child(research_panel)
	research_panel.row_pressed.connect(func(id: StringName) -> void: research_row_pressed.emit(id))
	research_panel.close_pressed.connect(func() -> void: research_closed.emit())


## What the two bars need in portrait: (top height, bottom height).
func measure() -> Vector2:
	return Vector2(top_panel.get_combined_minimum_size().y, bottom_panel.get_combined_minimum_size().y)


## Puts the bars, the rail or the panel and the camera buttons where the layout says (hud.md 3.1).
func apply_layout(layout: HudLayout) -> void:
	bar.vertical = layout.landscape
	second.vertical = layout.landscape
	# the narrow rail has room for the icons of these two buttons, not for their words
	pause_button.text = "" if layout.landscape else "Pause"
	research_button.text = "" if layout.landscape else "Recherche"
	# the narrow rail wraps the score on a width it is given; the wide bar clips it instead
	score_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART if layout.landscape else TextServer.AUTOWRAP_OFF
	score_label.custom_minimum_size.x = HudLayout.RAIL_WIDTH - 24.0 if layout.landscape else 0.0
	# an autowrapping label asks for a huge height until its width is known: give it one
	hint_label.custom_minimum_size.x = HudLayout.PANEL_WIDTH - 24.0 if layout.landscape else 300.0
	_place(top_panel, layout.top_zone)
	_place(bottom_panel, layout.panel_zone)
	_place(camera_box, layout.camera_buttons)
	toast_panel.position = layout.map_area.position + Vector2(8, 8)
	toast_panel.size = Vector2(layout.map_area.size.x - 16.0, 0.0)


static func _place(control: Control, rect: Rect2) -> void:
	control.set_anchors_preset(Control.PRESET_TOP_LEFT)
	control.position = rect.position
	control.size = rect.size


## A panel with an opaque dark background around `content`: the HUD bars and panels never
## let the map show through their text.
## A refusal, told for `duration` seconds from `now` of the presentation clock.
func show_toast(text: String, now: float, duration: float = 2.0) -> void:
	toast_label.text = text
	toast_panel.visible = text != ""
	_toast_until = now + duration


func tick_toast(now: float) -> void:
	if toast_panel.visible and now >= _toast_until:
		toast_panel.visible = false


static func _pill(text: String) -> PanelContainer:
	var label := Label.new()
	label.text = text
	label.add_theme_font_size_override("font_size", 14)
	var pill := PanelContainer.new()
	var style := StyleBoxFlat.new()
	style.bg_color = Color("2B323A")
	style.set_corner_radius_all(4)
	style.content_margin_left = 8
	style.content_margin_right = 8
	style.content_margin_top = 3
	style.content_margin_bottom = 3
	pill.add_theme_stylebox_override("panel", style)
	pill.add_child(label)
	return pill


## An icon (white SVG, tinted by the label's colour) beside a value; the whole box is named for the accessibility tree.
## An alert chip: its icon, then its words (the icon says the kind, the words say what).
static func _chip(icon_name: String, text: String) -> HBoxContainer:
	var box := HBoxContainer.new()
	box.add_theme_constant_override("separation", 4)
	var icon := TextureRect.new()
	icon.texture = UiIcons.texture(icon_name)
	icon.custom_minimum_size = Vector2(UiIcons.SIZE, UiIcons.SIZE)
	icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	icon.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	icon.mouse_filter = Control.MOUSE_FILTER_IGNORE
	box.add_child(icon)
	var label := Label.new()
	label.text = text
	label.add_theme_font_size_override("font_size", 14)  # a chip is a note: the rail holds "Ruine repérée" beside its icon
	label.tooltip_text = text
	box.add_child(label)
	return box


static func _stat(icon_name: String, label: Label, name: String) -> HBoxContainer:
	var box := HBoxContainer.new()
	box.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	box.add_theme_constant_override("separation", 6)
	box.tooltip_text = name
	box.accessibility_name = name
	var icon := TextureRect.new()
	icon.texture = UiIcons.texture(icon_name.trim_prefix("ui_icon_"))
	icon.custom_minimum_size = Vector2(UiIcons.SIZE, UiIcons.SIZE)
	icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	icon.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	icon.mouse_filter = Control.MOUSE_FILTER_IGNORE
	box.add_child(icon)
	label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	box.add_child(label)
	return box


static func backdrop(content: Control) -> PanelContainer:
	var panel := PanelContainer.new()
	var style := StyleBoxFlat.new()
	style.bg_color = Color(TilePalette.FOG, 0.96)
	style.content_margin_left = 8.0
	style.content_margin_right = 8.0
	style.content_margin_top = 4.0
	style.content_margin_bottom = 4.0
	panel.add_theme_stylebox_override("panel", style)
	panel.add_child(content)
	return panel


func show_model(model: HudModel, notice: String = "", hint: String = "") -> void:
	hint_label.text = hint
	hint_label.visible = hint != ""
	notice_label.text = notice
	turn_label.text = model.turn_text
	energy_label.text = model.energy_text
	fragments_label.text = model.fragments_text
	score_label.text = model.score_text
	var total := model.score_player + model.score_ai
	score_bar.value = 50.0 if total <= 0 else 100.0 * model.score_player / total
	end_turn_button.disabled = not model.can_end_turn
	end_turn_button.text = "Tour ennemi…" if model.enemy_turn else "Fin du tour"
	for child in alert_row.get_children():
		alert_row.remove_child(child)
		child.queue_free()
	var chips: Array = []  # [icon, text]
	if model.threat_chip != "":
		chips.append(["menace", model.threat_chip])
	for loss in model.loss_chips:
		chips.append(["perte", loss])
	if model.ruin_chip != "":
		chips.append(["ruine", model.ruin_chip])
	for chip in chips.slice(0, 2):  # two chips at most, the rest folded into a counter (section 3.2)
		alert_row.add_child(_chip(chip[0], chip[1]))
	if chips.size() > 2:
		var more := Label.new()
		more.text = "+%d" % (chips.size() - 2)
		alert_row.add_child(more)
	unit_title.text = "" if model.unit_panel.is_empty() else model.unit_panel["title"]
	var card: bool = model.unit_panel.has("hp")
	hp_bar.visible = card
	hp_label.visible = card
	stats_row.visible = card
	for pill in stats_row.get_children():
		stats_row.remove_child(pill)
		pill.queue_free()
	if card:
		hp_bar.max_value = model.unit_panel["hp_max"]
		hp_bar.value = model.unit_panel["hp"]
		hp_label.text = "PV %d / %d" % [model.unit_panel["hp"], model.unit_panel["hp_max"]]
		for stat: Array in model.unit_panel["stats"]:
			stats_row.add_child(_pill("%s %d" % [stat[0], stat[1]]))
	# the first two lines (hit points, stats) are the card; the others are statuses
	var lines: Array = model.unit_panel.get("lines", [])
	unit_lines.text = "" if model.unit_panel.is_empty() else "\n".join(lines.slice(2) if card else lines)
	unit_lines.visible = unit_lines.text != ""
	speed_button.visible = model.enemy_turn  # the speed only matters while the enemy plays
	journal_label.text = "\n".join(model.journal) if model.enemy_turn else ""
	preview_label.text = model.preview_text
	attack_button.visible = model.can_attack
	confirm_button.visible = model.confirming
	cancel_button.visible = model.targeting or model.confirming
	for child in extra_row.get_children():
		extra_row.remove_child(child)
		child.queue_free()
	for action in model.extra_actions:
		var button := Button.new()
		button.text = action.label
		button.icon = UiIcons.of_action(action.id)
		button.expand_icon = button.icon != null
		button.add_theme_constant_override("icon_max_width", UiIcons.SIZE)
		button.disabled = not action.enabled
		button.custom_minimum_size = Vector2(0, 48)
		button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		button.pressed.connect(func() -> void: action_pressed.emit(action.id))
		extra_row.add_child(button)
	reason_label.text = model.reason_text
	research_button.disabled = model.enemy_turn
	research_panel.visible = model.research_open
	if model.research_open:
		research_panel.show_rows(model.research_rows)
