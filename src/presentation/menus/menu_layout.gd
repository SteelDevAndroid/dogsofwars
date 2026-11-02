# Shared layout of the menu screens: one column of fixed width, centred in the screen (a box
# anchored on the centre grows to the right and down and leaves the screen on a phone), and
# touch-sized buttons (hud.md: 48 pt at least).
class_name MenuLayout
extends RefCounted

const WIDTH := 300.0
const BUTTON_HEIGHT := 56.0


## The column of `screen`, centred, `width` wide (never wider than the screen allows: the
## labels inside wrap).
static func column(screen: Control, width: float = WIDTH) -> VBoxContainer:
	var center := CenterContainer.new()
	center.set_anchors_preset(Control.PRESET_FULL_RECT)
	center.mouse_filter = Control.MOUSE_FILTER_IGNORE
	screen.add_child(center)
	var box := VBoxContainer.new()
	box.custom_minimum_size = Vector2(width, 0)
	box.add_theme_constant_override("separation", 10)
	center.add_child(box)
	return box


static func button(parent: Control, text: String, action: Callable) -> Button:
	var button := Button.new()
	button.text = text
	button.custom_minimum_size = Vector2(0, BUTTON_HEIGHT)
	button.pressed.connect(action)
	parent.add_child(button)
	return button


## A label that wraps inside the column.
static func label(parent: Control, text: String = "") -> Label:
	var label := Label.new()
	label.text = text
	label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	parent.add_child(label)
	return label
