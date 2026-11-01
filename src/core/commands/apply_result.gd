# What an application returns as values (ADR-0004 §2): flags for the undo, the
# vision delta, the events in write order and the profile effects. Only the
# command layer applies the events and effects; simulations drop them.
class_name ApplyResult
extends RefCounted

## Case a to d of GDD 5 rule 13 for the player (undo: DÉPLACEMENT_A_RÉVÉLÉ).
var revealed := false
var ruin_read := false
var vision := VisionDelta.new()
var events: Array[PresentationEvent] = []
var profile_effects: Array[ProfileEffect] = []
