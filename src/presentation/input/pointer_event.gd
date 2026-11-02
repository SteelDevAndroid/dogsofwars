# One finger, normalised (ADR-0010 §1): the touch device and the tests speak this.
class_name PointerEvent
extends RefCounted

enum Phase { DOWN, MOVE, UP, CANCEL }

var index: int
var phase: int
## In viewport units (one unit is one dp).
var position: Vector2


func _init(p_index: int, p_phase: int, p_position: Vector2 = Vector2.ZERO) -> void:
	index = p_index
	phase = p_phase
	position = p_position
