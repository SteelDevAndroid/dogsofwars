# Undo of the player's last move (GDD 23 rule 15, ADR-0004 §8): a snapshot out of
# the state, the moved unit, and the reason when disarmed (the refusal code).
# Owned by the real pipeline only; never saved nor copied.
class_name UndoSlot
extends RefCounted

var snapshot: GameState
var unit_id := -1
var reason: StringName = Refusal.NOTHING_TO_UNDO


func arm(p_snapshot: GameState, p_unit_id: int) -> void:
	snapshot = p_snapshot
	unit_id = p_unit_id


func disarm(p_reason: StringName) -> void:
	snapshot = null
	unit_id = -1
	reason = p_reason


func is_armed() -> bool:
	return snapshot != null
