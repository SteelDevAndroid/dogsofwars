# What the gesture interpreter makes of the fingers (ADR-0010 §2).
class_name Gesture
extends RefCounted

enum Kind { TAP, SCROLL, PINCH_UPDATE, PINCH_END, CANCEL }

var kind: int
var position := Vector2.ZERO
## Scroll: how far the content follows the finger.
var delta := Vector2.ZERO
## Pinch: the ratio of the distance between the fingers to the last one.
var factor := 1.0


func _init(p_kind: int, p_position: Vector2 = Vector2.ZERO, p_delta: Vector2 = Vector2.ZERO, p_factor: float = 1.0) -> void:
	kind = p_kind
	position = p_position
	delta = p_delta
	factor = p_factor
