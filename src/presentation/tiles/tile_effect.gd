# A transient effect on the map (ADR-0002, hud.md section 8): drawn over the snapshot for a
# duration of presentation time, then forgotten. Pure data; the renderer draws it.
class_name TileEffect
extends RefCounted

enum Kind { MOVE, LINE, FLOAT_TEXT, GHOST, WAVE }

var kind: int
var start: float
var duration: float
var tile := -1
var tile2 := -1
var unit_id := -1
var unit_type := 0
var faction := Faction.NONE
var text := ""
var tiles := PackedInt32Array()
var color := Color.WHITE


func _init(p_kind: int, p_start: float, p_duration: float) -> void:
	kind = p_kind
	start = p_start
	duration = p_duration


## 0 at the start, 1 once over (an effect of no duration is over at once).
func progress(now: float) -> float:
	return 1.0 if duration <= 0.0 else clampf((now - start) / duration, 0.0, 1.0)


func is_over(now: float) -> bool:
	return now >= start + duration
