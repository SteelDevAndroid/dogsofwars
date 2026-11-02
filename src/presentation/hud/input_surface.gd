# The touch surface over the map (ADR-0010 §1): the fingers become PointerEvents, nothing else.
# The mouse is ignored: on a computer the project turns the mouse into a finger
# (`emulate_touch_from_mouse`), so each click would otherwise arrive twice.
class_name InputSurface
extends Control

signal pointer(event: PointerEvent)


func _gui_input(event: InputEvent) -> void:
	if event is InputEventScreenTouch:
		var touch := event as InputEventScreenTouch
		var phase := PointerEvent.Phase.CANCEL if touch.canceled else (PointerEvent.Phase.DOWN if touch.pressed else PointerEvent.Phase.UP)
		pointer.emit(PointerEvent.new(touch.index, phase, touch.position))
		accept_event()
	elif event is InputEventScreenDrag:
		var drag := event as InputEventScreenDrag
		pointer.emit(PointerEvent.new(drag.index, PointerEvent.Phase.MOVE, drag.position))
		accept_event()


## Fingers lifted by the system: the app lost focus or was paused (ADR-0010 §1).
func cancel_all() -> void:
	for index in 2:
		pointer.emit(PointerEvent.new(index, PointerEvent.Phase.CANCEL))
