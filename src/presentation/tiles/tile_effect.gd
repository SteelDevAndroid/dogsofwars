# A transient effect on the map (ADR-0002, hud.md section 8): drawn over the snapshot for a
# duration of presentation time, then forgotten. Pure data; the renderer draws it.
class_name TileEffect
extends RefCounted

enum Kind { MOVE, LINE, FLOAT_TEXT, GHOST, WAVE, PULSE }

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
## WAVE: the tint each tile shows when the wave is written (from_owner, from_s 0..1000, parallel
## to `tiles`) and the tint it goes to. A rewrite during a fade passes the tint shown at that
## moment, so the tile never jumps (GDD 15 rule 15).
var from_owner := PackedInt32Array()
var from_s := PackedInt32Array()
var to_owner := Faction.NONE


func _init(p_kind: int, p_start: float, p_duration: float) -> void:
	kind = p_kind
	start = p_start
	duration = p_duration


## 0 at the start, 1 once over (an effect of no duration is over at once).
func progress(now: float) -> float:
	return 1.0 if duration <= 0.0 else clampf((now - start) / duration, 0.0, 1.0)


func is_over(now: float) -> bool:
	return now >= start + duration


## WAVE: (tint, saturation 0..1000) of the tile at index `index` of `tiles` at presentation time
## `now`: its starting tint until the effect starts, its final one once it is over.
func wave_state(index: int, now: float) -> Vector2i:
	var fade_ms := roundi(duration * 1000.0)
	var u := roundi(clampf((now - start) * 1000.0, 0.0, float(fade_ms)))  # to the nearest ms: 0.3 - 0.2 is 99.99999999999997 ms in floats
	return WaveFade.shown(from_owner[index], from_s[index], to_owner, u, fade_ms)

