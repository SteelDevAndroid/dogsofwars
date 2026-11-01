# Events of one applied command, published as one batch (ADR-0002, GDD 23 rule 8).
class_name EventBatch
extends RefCounted

var revision: int
var command_id: int
var events: Array[PresentationEvent] = []


func _init(p_revision: int = 0, p_events: Array[PresentationEvent] = []) -> void:
	revision = p_revision
	command_id = p_revision
	events = p_events
