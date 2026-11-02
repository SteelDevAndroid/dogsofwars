# What the presentation provides before the session exists (ADR-0008 §3): where the events
# go and what paces the AI.
class_name SessionPorts
extends RefCounted

var event_sink: EventSink
var pacing_gate: PacingGate


func _init(p_event_sink: EventSink, p_pacing_gate: PacingGate) -> void:
	event_sink = p_event_sink
	pacing_gate = p_pacing_gate
