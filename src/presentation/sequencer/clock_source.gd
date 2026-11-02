# Presentation time port (ADR-0002 §4): PresentationClock in the game, FakeClock in
# tests. Interface by convention.
class_name ClockSource
extends RefCounted


## Presentation time, in seconds.
func current() -> float:
	assert(false, "ClockSource.current is not implemented")
	return 0.0


## Presentation seconds per real second (the enemy-turn speed): the 3 flashes a second cap of
## reduced animations is a real-time cap, so its slot is stretched by this factor.
func scale() -> float:
	return 1.0
