# Base of the presentation events published after a command (ADR-0002).
class_name PresentationEvent
extends RefCounted

## (revision, index in the batch).
var event_id: Vector2i
