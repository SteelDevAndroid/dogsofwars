# The HUD control (design/ux/hud.md): top bar (turn, energy, ruins read, pause), decisive
# score row, alert row (threat, losses, ruin), and the context panel (selected unit, journal
# of the enemy turn, the end-turn button). It only copies a HudModel to its widgets and
# emits signals; no game rule lives here.
class_name Hud
extends Control

signal end_turn_pressed
signal pause_pressed
signal speed_pressed

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


func _init() -> void:
	set_anchors_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	var top := VBoxContainer.new()
	top.set_anchors_preset(Control.PRESET_TOP_WIDE)
	top.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(top)
	var bar := HBoxContainer.new()
	for label in [turn_label, energy_label, fragments_label]:
		label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		bar.add_child(label)
	pause_button.text = "Pause"
	pause_button.custom_minimum_size = Vector2(88, 48)
	pause_button.pressed.connect(func() -> void: pause_pressed.emit())
	bar.add_child(pause_button)
	top.add_child(bar)
	top.add_child(score_label)
	top.add_child(notice_label)
	top.add_child(alert_row)
	var bottom := VBoxContainer.new()
	bottom.set_anchors_preset(Control.PRESET_BOTTOM_WIDE)
	bottom.grow_vertical = Control.GROW_DIRECTION_BEGIN  # the panel grows upward from the bottom edge
	bottom.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(bottom)
	bottom.add_child(unit_title)
	bottom.add_child(unit_lines)
	bottom.add_child(journal_label)
	end_turn_button.text = "Fin du tour"
	end_turn_button.custom_minimum_size = Vector2(0, 50)
	end_turn_button.pressed.connect(func() -> void: end_turn_pressed.emit())
	bottom.add_child(end_turn_button)
	speed_button.text = "Vitesse : normale"
	speed_button.custom_minimum_size = Vector2(0, 40)
	speed_button.pressed.connect(func() -> void: speed_pressed.emit())
	bottom.add_child(speed_button)
	add_child(fragment_panel)


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
