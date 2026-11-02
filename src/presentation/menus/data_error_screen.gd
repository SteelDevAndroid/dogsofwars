# The screen shown when the game data cannot be loaded (ADR-0008 §2): nothing else starts.
class_name DataErrorScreen
extends Control

signal quit_requested

var errors_label: Label
var quit_button: Button


func _init() -> void:
	set_anchors_preset(Control.PRESET_FULL_RECT)
	var box := VBoxContainer.new()
	box.set_anchors_preset(Control.PRESET_CENTER)
	add_child(box)
	var title := Label.new()
	title.text = "Les données du jeu sont illisibles"
	box.add_child(title)
	errors_label = Label.new()
	box.add_child(errors_label)
	quit_button = Button.new()
	quit_button.text = "Quitter"
	quit_button.pressed.connect(func() -> void: quit_requested.emit())
	box.add_child(quit_button)


## At most `limit` errors are listed, the rest counted.
func show_errors(errors: Array[DataError], limit: int = 12) -> void:
	var lines := PackedStringArray()
	for k in mini(errors.size(), limit):
		lines.append(str(errors[k]))
	if errors.size() > limit:
		lines.append("… et %d autres" % (errors.size() - limit))
	errors_label.text = "\n".join(lines)
