# The title screen: the artwork of the boot splash (portrait or landscape, with its painted title),
# and "Touchez pour jouer" written by the game over it (the picture carries no caption). The
# engine's own boot splash disappears by itself when loading ends; this screen takes over with the
# same picture and waits for a touch (or a click), then announces `started` once.
class_name TitleScreen
extends Control

signal started

const PROMPT := "Touchez pour jouer"

var prompt_label := Label.new()
var _done := false


func _init() -> void:
	set_anchors_preset(Control.PRESET_FULL_RECT)
	var backdrop := ColorRect.new()
	backdrop.color = Color(0.0863, 0.0863, 0.1098)
	backdrop.set_anchors_preset(Control.PRESET_FULL_RECT)
	backdrop.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(backdrop)
	MenuLayout.artwork_picture(self, false)
	prompt_label.text = PROMPT
	prompt_label.set_anchors_preset(Control.PRESET_BOTTOM_WIDE)
	prompt_label.offset_top = -120.0
	prompt_label.offset_bottom = -48.0
	prompt_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	prompt_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	prompt_label.add_theme_font_size_override("font_size", 22)
	prompt_label.add_theme_color_override("font_color", Color("EADFC8"))
	prompt_label.add_theme_color_override("font_outline_color", Color("0E1422"))
	prompt_label.add_theme_constant_override("outline_size", 8)
	prompt_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(prompt_label)


func _gui_input(event: InputEvent) -> void:
	var pressed := (event is InputEventScreenTouch and (event as InputEventScreenTouch).pressed) \
			or (event is InputEventMouseButton and (event as InputEventMouseButton).pressed)
	if pressed and not _done:
		_done = true  # a touch and the click the engine derives from it count once
		accept_event()
		started.emit()
