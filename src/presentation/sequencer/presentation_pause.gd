# A step of the sequence that only waits (the delay before the fragment panel).
class_name PresentationPause
extends PresentationEvent

var duration_ms: int


func _init(p_duration_ms: int) -> void:
	duration_ms = p_duration_ms
