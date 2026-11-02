# The touch surface over the map (ADR-0010, reduced to the tap for now): a tap, or a click,
# is turned into a screen position; the match screen maps it to a tile.
class_name InputSurface
extends Control

signal tapped(position: Vector2)


func _gui_input(event: InputEvent) -> void:
	if event is InputEventScreenTouch and event.pressed:
		tapped.emit(event.position)
		accept_event()
	elif event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		tapped.emit(event.position)
		accept_event()
