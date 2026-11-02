# The title screen: the artwork of the boot splash, then "Touchez pour jouer" for real. The engine's
# own boot splash disappears by itself when loading ends; this screen takes over with the same
# picture and waits for a touch (or a click), then announces `started` once.
class_name TitleScreen
extends Control

signal started

const ARTWORK := "res://assets/ui/splash.png"

var _done := false


func _init() -> void:
	set_anchors_preset(Control.PRESET_FULL_RECT)
	var backdrop := ColorRect.new()
	backdrop.color = Color(0.0863, 0.0863, 0.1098)
	backdrop.set_anchors_preset(Control.PRESET_FULL_RECT)
	backdrop.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(backdrop)
	var picture := TextureRect.new()
	picture.texture = load(ARTWORK)
	picture.set_anchors_preset(Control.PRESET_FULL_RECT)
	picture.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	picture.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
	picture.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(picture)


func _gui_input(event: InputEvent) -> void:
	var pressed := (event is InputEventScreenTouch and (event as InputEventScreenTouch).pressed) \
			or (event is InputEventMouseButton and (event as InputEventMouseButton).pressed)
	if pressed and not _done:
		_done = true  # a touch and the click the engine derives from it count once
		accept_event()
		started.emit()
