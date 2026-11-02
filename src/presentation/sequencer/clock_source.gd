# Presentation time port (ADR-0002 §4): PresentationClock in the game, FakeClock in
# tests. Interface by convention.
class_name ClockSource
extends RefCounted


## Presentation time, in seconds.
func current() -> float:
	assert(false, "ClockSource.current is not implemented")
	return 0.0
