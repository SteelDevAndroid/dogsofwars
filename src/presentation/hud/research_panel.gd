# The research panel (hud.md, GDD 12): one row per protocol of the tree with its price and
# duration, greyed with the reason when the pipeline would refuse it. It only emits signals.
class_name ResearchPanel
extends PanelContainer

signal row_pressed(id: StringName)
signal close_pressed

var rows_box := VBoxContainer.new()
var reason_label := Label.new()
var close_button := Button.new()


func _init() -> void:
	visible = false
	set_anchors_preset(Control.PRESET_CENTER)
	grow_horizontal = Control.GROW_DIRECTION_BOTH
	grow_vertical = Control.GROW_DIRECTION_BOTH
	custom_minimum_size = Vector2(330, 0)
	var style := StyleBoxFlat.new()
	style.bg_color = Color("1E2329")
	style.border_color = Color("C8955A")
	style.set_border_width_all(2)
	style.set_content_margin_all(12)
	add_theme_stylebox_override("panel", style)
	var box := VBoxContainer.new()
	add_child(box)
	var title := Label.new()
	title.text = "Recherche"
	box.add_child(title)
	box.add_child(rows_box)
	box.add_child(reason_label)
	close_button.text = "Fermer"
	close_button.custom_minimum_size = Vector2(0, 48)
	close_button.pressed.connect(func() -> void: close_pressed.emit())
	box.add_child(close_button)


func show_rows(rows: Array[ContextAction]) -> void:
	for child in rows_box.get_children():
		rows_box.remove_child(child)
		child.queue_free()
	var reason := ""
	for row in rows:
		var button := Button.new()
		button.text = row.label
		button.disabled = not row.enabled
		button.custom_minimum_size = Vector2(0, 48)
		button.pressed.connect(func() -> void: row_pressed.emit(row.id))
		rows_box.add_child(button)
		if not row.enabled and reason == "" and row.reason != "Déjà acquis":
			reason = row.reason
	reason_label.text = reason
