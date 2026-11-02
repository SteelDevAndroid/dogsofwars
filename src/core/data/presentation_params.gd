# Presentation durations (ADR-0002, design/ux/hud.md section 11, domain `presentation`) [PROP]:
# in milliseconds, plus the event queue bound. The order of the steps is code, the
# durations are data; the attack lock is one value (GDD 23 says 1.6 s, GDD 17 1.5 s).
class_name PresentationParams
extends RefCounted

const SCHEMA_VERSION := 1

const SCHEMA := {
	"schema_version": {"kind": &"int", "min": SCHEMA_VERSION, "max": SCHEMA_VERSION},
	"move_step_ms": {"kind": &"int", "min": 0, "max": 500},
	"attack_line_ms": {"kind": &"int", "min": 0, "max": 1000},
	"hit_ms": {"kind": &"int", "min": 0, "max": 1000},
	"destroy_ms": {"kind": &"int", "min": 0, "max": 800},
	"recolor_ms": {"kind": &"int", "min": 0, "max": 1000},
	"panel_delay_ms": {"kind": &"int", "min": 0, "max": 1000},
	"close_delay_ms": {"kind": &"int", "min": 0, "max": 2000},
	"attack_lock_ms": {"kind": &"int", "min": 500, "max": 3000},
	"damage_number_ms": {"kind": &"int", "min": 0, "max": 2000},
	"enemy_action_ms": {"kind": &"int", "min": 0, "max": 2000},
	"reduced_slot_ms": {"kind": &"int", "min": 100, "max": 1000},
	"queue_max": {"kind": &"int", "min": 8, "max": 1024},
}

var _values := {}


static func build(data: Dictionary, _file: String, _errors: Array[DataError]) -> PresentationParams:
	var params := PresentationParams.new()
	for key: String in data:
		if key != "schema_version":
			params._values[key] = data[key]
	return params


## A duration or bound by its key in presentation.json.
func value(key: String) -> int:
	return _values[key]
