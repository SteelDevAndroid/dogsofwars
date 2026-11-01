# Port through which the command pipeline publishes its batches (ADR-0002):
# EventQueue in the game, RecordingSink / NullSink in tests. Interface by convention.
class_name EventSink
extends RefCounted


func push(_batch: EventBatch) -> void:
	assert(false, "EventSink.push is not implemented")
