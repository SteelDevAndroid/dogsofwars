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

var turn_label := Label.new()
var energy_label := Label.new()
var fragments_label := Label.new()
var score_label := Label.new()
var alert_row := HBoxContainer.new()
var unit_title := Label.new()
var unit_lines := Label.new()
var journal_label := Label.new()
var end_turn_button := Button.new()
var pause_button := Button.new()
var speed_button := Button.new()
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


func _init() -> void:
	set_anchors_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	var top := VBoxContainer.new()
	var top_panel := backdrop(top)
	top_panel.set_anchors_preset(Control.PRESET_TOP_WIDE)
	add_child(top_panel)
	var bar := HBoxContainer.new()
	for label in [turn_label, energy_label, fragments_label]:
		label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		label.clip_text = true  # a long text never pushes the buttons off the screen
		label.add_theme_font_size_override("font_size", 15)
		label.custom_minimum_size = Vector2(0, 32)
		label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		bar.add_child(label)
	pause_button.text = "Pause"
	pause_button.custom_minimum_size = Vector2(64, 48)
	pause_button.pressed.connect(func() -> void: pause_pressed.emit())
	research_button.text = "Recherche"
	research_button.custom_minimum_size = Vector2(88, 48)
	research_button.pressed.connect(func() -> void: research_pressed.emit())
	top.add_child(bar)
	var second := HBoxContainer.new()
	score_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	score_label.clip_text = true
	score_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	second.add_child(score_label)
	second.add_child(research_button)
	second.add_child(pause_button)
	top.add_child(second)
	top.add_child(notice_label)
	top.add_child(alert_row)
	var bottom := VBoxContainer.new()
	var bottom_panel := backdrop(bottom)
	bottom_panel.set_anchors_preset(Control.PRESET_BOTTOM_WIDE)
	bottom_panel.grow_vertical = Control.GROW_DIRECTION_BEGIN  # the panel grows upward from the bottom edge
	add_child(bottom_panel)
	bottom.add_child(unit_title)
	bottom.add_child(unit_lines)
	bottom.add_child(journal_label)
	bottom.add_child(preview_label)
	var actions := HBoxContainer.new()
	for pair in [[attack_button, "Attaquer", attack_pressed], [confirm_button, "Confirmer", confirm_pressed], [cancel_button, "Annuler", cancel_pressed]]:
		var button: Button = pair[0]
		button.text = pair[1]
		button.custom_minimum_size = Vector2(0, 48)
		button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		button.pressed.connect(func() -> void: (pair[2] as Signal).emit())
		actions.add_child(button)
	bottom.add_child(actions)
	bottom.add_child(extra_row)
	bottom.add_child(reason_label)
	end_turn_button.text = "Fin du tour"
	end_turn_button.custom_minimum_size = Vector2(0, 50)
	end_turn_button.pressed.connect(func() -> void: end_turn_pressed.emit())
	bottom.add_child(end_turn_button)
	speed_button.text = "Vitesse : normale"
	speed_button.custom_minimum_size = Vector2(0, 40)
	speed_button.pressed.connect(func() -> void: speed_pressed.emit())
	bottom.add_child(speed_button)
	add_child(fragment_panel)
	add_child(research_panel)
	research_panel.row_pressed.connect(func(id: StringName) -> void: research_row_pressed.emit(id))
	research_panel.close_pressed.connect(func() -> void: research_closed.emit())


## A panel with an opaque dark background around `content`: the HUD bars and panels never
## let the map show through their text.
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


func show_model(model: HudModel, notice: String = "") -> void:
	notice_label.text = notice
	turn_label.text = model.turn_text
	energy_label.text = model.energy_text
	fragments_label.text = model.fragments_text
	score_label.text = model.score_text
	end_turn_button.disabled = not model.can_end_turn
	end_turn_button.text = "Tour ennemi…" if model.enemy_turn else "Fin du tour"
	for child in alert_row.get_children():
		alert_row.remove_child(child)
		child.queue_free()
	var chips: Array[String] = []
	if model.threat_chip != "":
		chips.append(model.threat_chip)
	chips.append_array(model.loss_chips)
	if model.ruin_chip != "":
		chips.append(model.ruin_chip)
	for chip in chips.slice(0, 2):  # two chips at most, the rest folded into a counter (section 3.2)
		var label := Label.new()
		label.text = chip
		alert_row.add_child(label)
	if chips.size() > 2:
		var more := Label.new()
		more.text = "+%d" % (chips.size() - 2)
		alert_row.add_child(more)
	unit_title.text = "" if model.unit_panel.is_empty() else model.unit_panel["title"]
	unit_lines.text = "" if model.unit_panel.is_empty() else "\n".join(model.unit_panel["lines"])
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
