# EventSink that drops every batch (replay, ADR-0004 §10).
class_name NullSink
extends EventSink


func push(_batch: EventBatch) -> void:
	pass
