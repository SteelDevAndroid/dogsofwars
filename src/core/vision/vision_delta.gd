# What a vision update revealed to the player (ADR-0007 §4, GDD 5 rules 13 and 14).
class_name VisionDelta
extends RefCounted

## Cases a to c of GDD 5 rule 13 (d and e belong to the move and ruin rules).
var revealed := false
## Tiles of the player gone from unknown to discovered, ascending (TUILES_RÉVÉLÉES).
var discovered_tiles := PackedInt32Array()
## Units of another faction (dormants included) newly visible to the player,
## compared with the view before the call.
var newly_seen_units := PackedInt32Array()


func merge(other: VisionDelta) -> void:
	revealed = revealed or other.revealed
	discovered_tiles.append_array(other.discovered_tiles)
	discovered_tiles.sort()
	newly_seen_units.append_array(other.newly_seen_units)
	newly_seen_units.sort()
