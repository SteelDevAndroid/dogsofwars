# The screen shown when the game data cannot be loaded (ADR-0008 §2): nothing else starts.
class_name DataErrorScreen
extends Control

signal quit_requested

var errors_label: Label
var quit_button: Button


func _init() -> void:
	set_anchors_preset(Control.PRESET_FULL_RECT)
	var box := MenuLayout.column(self, 340.0)
	MenuLayout.label(box, "Les données du jeu sont illisibles")
	errors_label = MenuLayout.label(box)
	quit_button = MenuLayout.button(box, "Quitter", func() -> void: quit_requested.emit())


## At most `limit` errors are listed, the rest counted.
func show_errors(errors: Array[DataError], limit: int = 12) -> void:
	var lines := PackedStringArray()
	for k in mini(errors.size(), limit):
		lines.append(str(errors[k]))
	if errors.size() > limit:
		lines.append("… et %d autres" % (errors.size() - limit))
	errors_label.text = "\n".join(lines)
