# The EventSink of a match (ADR-0002 §3): a FIFO of batches bounded by `queue_max` events.
# When a batch would overflow it, the queue is emptied and holds one RESYNCHRONISER batch:
# the presentation redraws from the state instead of replaying a backlog. Never saved;
# the revisions it hands out are strictly increasing.
class_name EventQueue
extends EventSink

var queue_max: int
var resyncs := 0

var _batches: Array[EventBatch] = []
var _events := 0


func _init(p_queue_max: int = 256) -> void:
	queue_max = p_queue_max


func push(batch: EventBatch) -> void:
	if _events + batch.events.size() > queue_max:
		_batches.clear()
		var resync := EventBatch.new(batch.revision, [ResyncEvent.new()])
		_batches.append(resync)
		_events = 1
		resyncs += 1
		return
	_batches.append(batch)
	_events += batch.events.size()


func is_empty() -> bool:
	return _batches.is_empty()


func size() -> int:
	return _batches.size()


func event_count() -> int:
	return _events


## The oldest batch, or null.
func pop() -> EventBatch:
	if _batches.is_empty():
		return null
	var batch: EventBatch = _batches.pop_front()
	_events -= batch.events.size()
	return batch


func drain() -> Array[EventBatch]:
	var out := _batches
	_batches = []
	_events = 0
	return out
