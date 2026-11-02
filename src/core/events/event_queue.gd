# The EventSink of a match (ADR-0002): a FIFO of the batches the pipeline publishes, read by
# the presentation sequencer. Nothing is dropped; `drain` hands the batches over in order.
class_name EventQueue
extends EventSink

var _batches: Array[EventBatch] = []


func push(batch: EventBatch) -> void:
	_batches.append(batch)


func size() -> int:
	return _batches.size()


func drain() -> Array[EventBatch]:
	var out := _batches
	_batches = []
	return out
