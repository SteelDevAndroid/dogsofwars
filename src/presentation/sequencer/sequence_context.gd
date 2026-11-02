# What a handler is given with an event (ADR-0002): the presentation time at which the step
# started, whether to show the result at once (resynchronisation) and the clock.
class_name SequenceContext
extends RefCounted

var t0: float
var direct: bool
var clock: ClockSource
## Reduced animations (HUD section 10.3): fixed attack steps, merged waves.
var reduced: bool


func _init(p_t0: float, p_clock: ClockSource, p_direct: bool = false, p_reduced: bool = false) -> void:
	t0 = p_t0
	clock = p_clock
	direct = p_direct
	reduced = p_reduced
