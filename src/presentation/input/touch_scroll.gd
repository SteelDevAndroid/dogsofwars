# Finger scrolling for a ScrollContainer. The project turns off the mouse emulation of touch
# (ADR-0010 §1: every touch would otherwise come twice), and Godot's ScrollContainer only drags
# with mouse events: on a phone a list could not be scrolled at all. This node, a child of the
# container, reads the touches in `_input`: a finger put down inside the container and moved
# beyond DEADZONE scrolls it: the touch is cancelled for the control it started on (a button is
# not pressed) and the rest of it is consumed. A touch that does not move stays a tap.
class_name TouchScroll
extends Node

## Points a finger may move before a tap becomes a scroll.
const DEADZONE := 12.0

var _scroll: ScrollContainer
var _index := -1
var _start := Vector2.ZERO
var _start_offset := 0
var _dragging := false


## Adds finger scrolling to `scroll` (vertical).
static func attach(scroll: ScrollContainer) -> TouchScroll:
	var node := TouchScroll.new()
	node._scroll = scroll
	scroll.add_child(node, false, Node.INTERNAL_MODE_BACK)
	return node


func is_dragging() -> bool:
	return _dragging


func _input(event: InputEvent) -> void:
	if _scroll == null or not _scroll.is_visible_in_tree():
		return
	var touch := event as InputEventScreenTouch
	if touch != null:
		if touch.pressed and _index < 0 and _scroll.get_global_rect().has_point(touch.position):
			_index = touch.index
			_start = touch.position
			_start_offset = _scroll.scroll_vertical
			_dragging = false
		elif not touch.pressed and touch.index == _index:
			_index = -1
			if _dragging:
				_dragging = false
				get_viewport().set_input_as_handled()
		return
	var drag := event as InputEventScreenDrag
	if drag == null or drag.index != _index:
		return
	var delta := drag.position - _start
	if not _dragging and absf(delta.y) > DEADZONE:
		_dragging = true
		_cancel_touch(drag.index, drag.position)
	if _dragging:
		_scroll.scroll_vertical = _start_offset - int(delta.y)
		get_viewport().set_input_as_handled()


## The control the finger started on (a button) is told the touch is cancelled: it lets go
## without being pressed, and the release that will follow is consumed here.
func _cancel_touch(index: int, position: Vector2) -> void:
	var cancel := InputEventScreenTouch.new()
	cancel.index = index
	cancel.pressed = false
	cancel.canceled = true
	cancel.position = position
	set_process_input(false)  # the cancel is for the controls, not for this node
	get_viewport().push_input(cancel)
	set_process_input(true)
