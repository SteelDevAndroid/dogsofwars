# Fingers to gestures (ADR-0010 §2), pure: no node, no clock, no engine. One finger that stays
# within `TAP_SLOP_MILLI` thousandths of a tile of where it went down, then lifts, is a tap;
# one that goes beyond scrolls; two fingers pinch; a finger left over after a pinch does
# nothing until it lifts. A distance equal to the slop is still a tap. A cancel resets all.
# There is no double tap, long press or drag and drop (GDD 4 rule 6).
class_name GestureInterpreter
extends RefCounted

const TAP_SLOP_MILLI := 500

enum State { FREE, TAP_POSSIBLE, SCROLLING, PINCHING, ORPHAN }

## The size of a tile on screen, so the slop follows the zoom.
var tile_size := 48.0

var _state := State.FREE
var _down := {}      # index -> start position
var _last := {}      # index -> last position
var _pinch_distance := 0.0


## The gestures one pointer event produces (usually none, rarely two).
func feed(event: PointerEvent) -> Array[Gesture]:
	var out: Array[Gesture] = []
	match event.phase:
		PointerEvent.Phase.DOWN:
			if _down.has(event.index):
				out.append_array(_cancel())
			_on_down(event, out)
		PointerEvent.Phase.MOVE:
			_on_move(event, out)
		PointerEvent.Phase.UP:
			_on_up(event, out)
		PointerEvent.Phase.CANCEL:
			out.append_array(_cancel())
	return out


func is_free() -> bool:
	return _state == State.FREE


func _slop() -> float:
	return TAP_SLOP_MILLI * tile_size / 1000.0


func _on_down(event: PointerEvent, out: Array[Gesture]) -> void:
	if _state == State.FREE:
		_state = State.TAP_POSSIBLE
	elif _state == State.TAP_POSSIBLE or _state == State.SCROLLING:
		_state = State.PINCHING  # a second finger turns the touch into a pinch
		_down[event.index] = event.position
		_last[event.index] = event.position
		_pinch_distance = _distance()
		return
	_down[event.index] = event.position
	_last[event.index] = event.position


func _on_move(event: PointerEvent, out: Array[Gesture]) -> void:
	if not _down.has(event.index):
		return
	var previous: Vector2 = _last[event.index]
	_last[event.index] = event.position
	match _state:
		State.TAP_POSSIBLE:
			if event.position.distance_to(_down[event.index]) > _slop():
				_state = State.SCROLLING
				out.append(Gesture.new(Gesture.Kind.SCROLL, event.position, event.position - _down[event.index]))
		State.SCROLLING:
			out.append(Gesture.new(Gesture.Kind.SCROLL, event.position, event.position - previous))
		State.PINCHING:
			var distance := _distance()
			if _pinch_distance > 0.0 and distance > 0.0:
				out.append(Gesture.new(Gesture.Kind.PINCH_UPDATE, _center(), Vector2.ZERO, distance / _pinch_distance))
			_pinch_distance = distance


func _on_up(event: PointerEvent, out: Array[Gesture]) -> void:
	if not _down.has(event.index):
		return
	match _state:
		State.TAP_POSSIBLE:
			out.append(Gesture.new(Gesture.Kind.TAP, event.position))
		State.PINCHING:
			out.append(Gesture.new(Gesture.Kind.PINCH_END))
	_down.erase(event.index)
	_last.erase(event.index)
	if _state == State.PINCHING:
		_state = State.ORPHAN if not _down.is_empty() else State.FREE
	elif _down.is_empty():
		_state = State.FREE


func _cancel() -> Array[Gesture]:
	var out: Array[Gesture] = []
	if _state != State.FREE:
		out.append(Gesture.new(Gesture.Kind.CANCEL))
	_down.clear()
	_last.clear()
	_state = State.FREE
	return out


func _distance() -> float:
	var points: Array = _last.values()
	return (points[0] as Vector2).distance_to(points[1]) if points.size() >= 2 else 0.0


func _center() -> Vector2:
	var points: Array = _last.values()
	return ((points[0] as Vector2) + (points[1] as Vector2)) / 2.0
