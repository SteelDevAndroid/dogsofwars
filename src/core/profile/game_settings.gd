# The player's settings (GDD 22 rule 14, hud.md 10.5): a table key -> int with a default and a
# range. A missing, mistyped or out-of-range value falls back to its default; an unknown key
# (from a newer version) is dropped. They go both ways, are never merged and survive a reset.
class_name GameSettings
extends RefCounted

const TEXT_SCALE := &"text_scale"
const COLORBLIND := &"colorblind"
const REDUCED_MOTION := &"reduced_motion"
const SHOW_RANGE := &"show_range"
const ENEMY_SPEED := &"enemy_speed"
const LEFT_PANEL := &"left_panel"

## key -> [default, min, max]. TEXT_SCALE is a percentage; ENEMY_SPEED is 0 normal, 1 fast,
## 2 instant; the others are flags.
const TABLE := {
	TEXT_SCALE: [100, 100, 150],
	COLORBLIND: [0, 0, 1],
	REDUCED_MOTION: [0, 0, 1],
	SHOW_RANGE: [1, 0, 1],
	ENEMY_SPEED: [0, 0, 2],
	LEFT_PANEL: [0, 0, 1],
}


static func defaults() -> Dictionary:
	var values := {}
	for key in TABLE:
		values[key] = TABLE[key][0]
	return values


static func is_valid(key: StringName, value: Variant) -> bool:
	return TABLE.has(key) and value is int and value >= TABLE[key][1] and value <= TABLE[key][2]


## The settings read from stored data: every key present, valid or defaulted.
static func clean(raw: Variant) -> Dictionary:
	var values := defaults()
	if raw is Dictionary:
		for key in TABLE:
			if raw.has(key) and is_valid(key, raw[key]):
				values[key] = raw[key]
	return values
