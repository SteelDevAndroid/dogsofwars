# EventSink that keeps every batch, in order (ADR-0011 §4).
class_name RecordingSink
extends EventSink

var batches: Array[EventBatch] = []


func push(batch: EventBatch) -> void:
	batches.append(batch)
