# ClockSource moved by hand (ADR-0011 §4): no system time in tests.
class_name FakeClock
extends ClockSource

## Presentation seconds per real second, as the enemy-turn speed sets it.
var speed_scale := 1.0

var _now := 0.0


func _init(start: float = 0.0) -> void:
	_now = start


func current() -> float:
	return _now


func scale() -> float:
	return speed_scale


func advance(seconds: float) -> void:
	assert(seconds >= 0.0, "presentation time never goes back")
	_now += seconds
