# Evaluation budget of one planner call (ADR-0005 §4): a hard cap at the MVP. Recreated
# at every call, so a resume has no counter to recover.
class_name AiBudget
extends RefCounted

var evals_left: int


func _init(max_evals: int) -> void:
	evals_left = max_evals


## Counts one evaluation; false once the cap is reached (the planner then stops looking).
func spend() -> bool:
	if evals_left <= 0:
		return false
	evals_left -= 1
	return true
