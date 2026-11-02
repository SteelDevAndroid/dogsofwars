# The presentation time (ADR-0002 §4): the one owner of "now" for the sequencer and the
# renderer. It advances in `_process` (priority -20, before everyone) and stops when paused;
# `create_timer` is never used, so nothing keeps running during a pause. The scale gives the
# speeds (normal, fast, instant for the enemy turn).
class_name PresentationClock
extends Node

enum Speed { NORMAL, FAST, INSTANT }

const SCALES := [1.0, 2.0, 1000.0]

var paused := false
var speed := Speed.NORMAL

var _now := 0.0


func _init() -> void:
	process_priority = -20


func current() -> float:
	return _now


func scale() -> float:
	return SCALES[speed]


func _process(delta: float) -> void:
	advance(delta)


func advance(delta: float) -> void:
	if not paused:
		_now += delta * scale()
