# What a handler returns for an event: how long the sequence waits before the next step
# (ADR-0002 §5). Zero means no wait.
class_name PresentationHold
extends RefCounted

var duration_ms: int


func _init(p_duration_ms: int = 0) -> void:
	duration_ms = p_duration_ms
