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
	# GDD 15 F4 and Tuning Knobs: T_FONDU 200..400, T_ANNEAU 150..200, K_MAX 1..5, T_TOTAL_MAX 600..1200.
	"recolor_ms": {"kind": &"int", "min": 200, "max": 400},
	"wave_ring_ms": {"kind": &"int", "min": 150, "max": 200},
	"wave_rings_max": {"kind": &"int", "min": 1, "max": 5},
	"wave_total_max_ms": {"kind": &"int", "min": 600, "max": 1200},
	"panel_delay_ms": {"kind": &"int", "min": 0, "max": 1000},
	"close_delay_ms": {"kind": &"int", "min": 0, "max": 2000},
	"attack_lock_ms": {"kind": &"int", "min": 500, "max": 3000},
	"damage_number_ms": {"kind": &"int", "min": 0, "max": 2000},
	"enemy_action_ms": {"kind": &"int", "min": 0, "max": 2000},
	"recenter_ms": {"kind": &"int", "min": 0, "max": 1000},
	"reduced_slot_ms": {"kind": &"int", "min": 100, "max": 1000},
	"queue_max": {"kind": &"int", "min": 8, "max": 1024},
}

var _values := {}


static func build(data: Dictionary, _file: String, _errors: Array[DataError]) -> PresentationParams:
	var params := PresentationParams.new()
	for key: String in data:
		if key != "schema_version":
			params._values[key] = data[key]
	var trace := params.ring_trace()
	if trace != "":
		push_warning(trace)
	return params


## GDD 15 F4 and AC-RC10: when K_MAX x T_ANNEAU + T_FONDU exceeds T_TOTAL_MAX the ring delay is
## shortened to fit (WaveSchedule.ring_ms); the loading says so. Empty when nothing is shortened.
func ring_trace() -> String:
	var ring: int = value("wave_ring_ms")
	var rings: int = value("wave_rings_max")
	var fade: int = value("recolor_ms")
	var total: int = value("wave_total_max_ms")
	if rings * ring + fade <= total:
		return ""
	return "presentation.json: %d rings x %d ms + %d ms exceed wave_total_max_ms %d: the ring delay is shortened to %d ms" \
			% [rings, ring, fade, total, mini(ring, maxi(0, total - fade) / rings)]


## A duration or bound by its key in presentation.json.
func value(key: String) -> int:
	return _values[key]
