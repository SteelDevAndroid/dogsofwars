# Core port that paces the AI runner on the presentation (ADR-0005 §3): ready when
# the sequencer is idle and the queue is empty. Interface by convention.
class_name PacingGate
extends RefCounted


func is_ready() -> bool:
	assert(false, "PacingGate.is_ready is not implemented")
	return false
