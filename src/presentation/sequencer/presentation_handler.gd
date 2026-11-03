# A presenter the sequencer calls for each event, in a fixed order (camera, tiles, HUD, sound;
# ADR-0002 §5). Interface by convention: a handler overrides what it shows.
class_name PresentationHandler
extends RefCounted


func handle(_event: PresentationEvent, _context: SequenceContext) -> PresentationHold:
	return PresentationHold.new(0)


## The batch is over: the state it described may now be drawn.
func on_batch_end(_state: GameState) -> void:
	pass


## The queue is empty and nothing is playing.
func on_idle(_state: GameState) -> void:
	pass


## Resynchronisation or load: show the state directly, no animation.
func rebuild_from_state(_state: GameState) -> void:
	pass
