# What modifier_pv returns (GDD 6 rule 9): HP before and after, and whether the call
# destroyed the unit.
class_name HpChange
extends RefCounted

var before: int
var after: int
var destroyed: bool


func _init(p_before: int, p_after: int) -> void:
	before = p_before
	after = p_after
	destroyed = p_after == 0 and p_before > 0


## HP really lost (negative for a heal): what the UNITÉ_TOUCHÉE event carries.
func lost() -> int:
	return before - after
