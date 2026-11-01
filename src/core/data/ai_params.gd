# AI tuning (GDD 9, domain `ai`). For now the protocol calendar of GDD 12 rule 15:
# at the start of the AI phase of `turn`, `protocol` is acquired, with no energy and
# no prerequisite. The planner weights join with the AI planner (ADR-0005).
class_name AiParams
extends RefCounted

const SCHEMA_VERSION := 1

const SCHEMA := {
	"schema_version": {"kind": &"int", "min": SCHEMA_VERSION, "max": SCHEMA_VERSION},
	"protocol_calendar": {"kind": &"array", "min": 0, "max": ProtocolTree.MAX_PROTOCOLS,
		"item": {"kind": &"object", "fields": {
			"turn": {"kind": &"int", "min": 1, "max": 30},
			"protocol": {"kind": &"int", "min": 0, "max": ProtocolTree.MAX_PROTOCOLS - 1},
		}}},
}

var _calendar_turn := PackedInt32Array()
var _calendar_protocol := PackedInt32Array()


static func build(data: Dictionary, file: String, errors: Array[DataError]) -> AiParams:
	var params := AiParams.new()
	var rows: Array = data["protocol_calendar"]
	for k in rows.size():
		var row: Dictionary = rows[k]
		if k > 0 and row["turn"] < params._calendar_turn[k - 1]:
			errors.append(DataError.new(file, "protocol_calendar[%d].turn" % k, "turns must not decrease"))
		params._calendar_turn.append(row["turn"])
		params._calendar_protocol.append(row["protocol"])
	return params


## Protocols the AI receives at the start of its phase of `turn`, in calendar order.
func calendar_protocols(turn: int) -> PackedInt32Array:
	var ids := PackedInt32Array()
	for k in _calendar_turn.size():
		if _calendar_turn[k] == turn:
			ids.append(_calendar_protocol[k])
	return ids


## Every protocol id of the calendar (cross-checked against the tree).
func calendar_ids() -> PackedInt32Array:
	return _calendar_protocol.duplicate()
