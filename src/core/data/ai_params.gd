# AI tuning (GDD 9, domain `ai`): the track lifetime and the protocol calendar of GDD 12 rule 15:
# at the start of the AI phase of `turn`, `protocol` is acquired, with no energy and
# no prerequisite. The planner weights join with the AI planner (ADR-0005).
class_name AiParams
extends RefCounted

const SCHEMA_VERSION := 1

const SCHEMA := {
	"schema_version": {"kind": &"int", "min": SCHEMA_VERSION, "max": SCHEMA_VERSION},
	"track_ttl": {"kind": &"int", "min": 1, "max": 30},
	# [PROP] planner tuning (GDD 9 F1 and tuning knobs); weights are integers.
	"planner": {"kind": &"object", "fields": {
		"w_damage": {"kind": &"int", "min": 0, "max": 100},
		"w_lethal": {"kind": &"int", "min": 0, "max": 100},
		"w_loss": {"kind": &"int", "min": 0, "max": 100},
		"w_danger": {"kind": &"int", "min": 0, "max": 100},
		"w_node": {"kind": &"int", "min": 0, "max": 100},
		"w_leash": {"kind": &"int", "min": 0, "max": 100},
		"w_progress": {"kind": &"int", "min": 0, "max": 100},
		"leash": {"kind": &"int", "min": 2, "max": 6},
		"k_dest": {"kind": &"int", "min": 2, "max": 8},
		"state_margin": {"kind": &"int", "min": 0, "max": 50},
		"return_after": {"kind": &"int", "min": 1, "max": 6},
		"evals_per_call": {"kind": &"int", "min": 100, "max": 20000},
		# EVALS_MAX (GDD 9 rule 19): the turn bound that every map is checked against (ADR-0005 §4).
		"evals_max": {"kind": &"int", "min": 10000, "max": 40000},
		"refusals_max": {"kind": &"int", "min": 1, "max": 64},
	}},
	"protocol_calendar": {"kind": &"array", "min": 0, "max": ProtocolTree.MAX_PROTOCOLS,
		"item": {"kind": &"object", "fields": {
			"turn": {"kind": &"int", "min": 1, "max": 30},
			"protocol": {"kind": &"int", "min": 0, "max": ProtocolTree.MAX_PROTOCOLS - 1},
		}}},
}

var _track_ttl := 0
var _planner := {}
var _calendar_turn := PackedInt32Array()
var _calendar_protocol := PackedInt32Array()
var _difficulty := NORMAL

## Difficulty levels (a player setting). EASY: the AI weighs damage, kills and nodes at half
## and receives no calendar protocol; HARD: those weights at 150 %. NORMAL is the tuned data.
const EASY := 0
const NORMAL := 1
const HARD := 2
const AGGRESSION_KEYS := ["w_damage", "w_lethal", "w_node"]


static func build(data: Dictionary, file: String, errors: Array[DataError]) -> AiParams:
	var params := AiParams.new()
	params._track_ttl = data["track_ttl"]
	params._planner = data["planner"]
	var rows: Array = data["protocol_calendar"]
	for k in rows.size():
		var row: Dictionary = rows[k]
		if k > 0 and row["turn"] < params._calendar_turn[k - 1]:
			errors.append(DataError.new(file, "protocol_calendar[%d].turn" % k, "turns must not decrease"))
		params._calendar_turn.append(row["turn"])
		params._calendar_protocol.append(row["protocol"])
	return params


## A planner tuning value by name (see the `planner` object of ai.json).
func planner(name: String) -> int:
	var value: int = _planner[name]
	if name in AGGRESSION_KEYS and _difficulty != NORMAL:
		return value / 2 if _difficulty == EASY else value * 3 / 2
	return value


## Sets the difficulty from the player's setting; the next AI decisions use it. A stored match
## keeps working: the AI's choices are the only thing that changes, the state is saved as is.
func set_difficulty(level: int) -> void:
	_difficulty = clampi(level, EASY, HARD)


## PISTES_TTL (GDD 9 rule 9): turns a track survives without being seen again.
func track_ttl() -> int:
	return _track_ttl


## Protocols the AI receives at the start of its phase of `turn`, in calendar order.
func calendar_protocols(turn: int) -> PackedInt32Array:
	var ids := PackedInt32Array()
	if _difficulty == EASY:
		return ids
	for k in _calendar_turn.size():
		if _calendar_turn[k] == turn:
			ids.append(_calendar_protocol[k])
	return ids


## Every protocol id of the calendar (cross-checked against the tree).
func calendar_ids() -> PackedInt32Array:
	return _calendar_protocol.duplicate()
