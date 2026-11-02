# ClockSource over the PresentationClock node (a Node cannot also extend ClockSource): what the
# sequencer and the renderer read.
class_name ClockAdapter
extends ClockSource

var _clock: PresentationClock


func _init(clock: PresentationClock) -> void:
	_clock = clock


func current() -> float:
	return _clock.current()
