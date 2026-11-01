# Current vision per faction (ADR-0007 §2): transient companion of the state,
# copied deeply with it, never serialized nor compared. Only VisionService writes it.
class_name ViewCache
extends RefCounted

## Per faction, W x H bytes: vue_maintenant.
var seen: Array[PackedByteArray] = []
## False after from_bytes, true after VisionService.rebuild.
var valid := false


func _init(factions: int = 0, tiles: int = 0) -> void:
	for f in factions:
		var row := PackedByteArray()
		row.resize(tiles)
		seen.append(row)


## Deep copy: each PackedByteArray is duplicated (Array.duplicate() alone shares them).
func duplicate() -> ViewCache:
	var copy := ViewCache.new()
	for row in seen:
		copy.seen.append(row.duplicate())
	copy.valid = valid
	return copy
