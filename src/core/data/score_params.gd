# Score weights (GDD 3 formulas 1 and 2, domain `score`) [PROP]. The decisive score
# is formula 1 with F = 0 (GDD 3 rule 9); w_f and w_d serve the profile score and
# the domination bonus, with the design rule w_d <= w_f / 5.
class_name ScoreParams
extends RefCounted

const SCHEMA_VERSION := 1

const SCHEMA := {
	"schema_version": {"kind": &"int", "min": SCHEMA_VERSION, "max": SCHEMA_VERSION},
	"w_tiles": {"kind": &"int", "min": 0, "max": 99},
	"w_nodes": {"kind": &"int", "min": 0, "max": 99},
	"w_levels": {"kind": &"int", "min": 0, "max": 99},
	"w_protocols": {"kind": &"int", "min": 0, "max": 99},
	"w_units": {"kind": &"int", "min": 0, "max": 99},
	"unit_cap": {"kind": &"int", "min": 1, "max": 60},
	"w_fragments": {"kind": &"int", "min": 0, "max": 999},
	"w_domination": {"kind": &"int", "min": 0, "max": 99},
}

## Weight by SCHEMA key.
var _weights := {}


static func build(data: Dictionary, file: String, errors: Array[DataError]) -> ScoreParams:
	var params := ScoreParams.new()
	for key: String in data:
		if key != "schema_version":
			params._weights[key] = data[key]
	if params.w_domination() * 5 > params.w_fragments():
		errors.append(DataError.new(file, "w_domination", "a fragment must be worth at least 5 turns of domination bonus (w_d <= w_f / 5)"))
	return params


func w_tiles() -> int:
	return _weights["w_tiles"]


func w_nodes() -> int:
	return _weights["w_nodes"]


func w_levels() -> int:
	return _weights["w_levels"]


func w_protocols() -> int:
	return _weights["w_protocols"]


func w_units() -> int:
	return _weights["w_units"]


func unit_cap() -> int:
	return _weights["unit_cap"]


func w_fragments() -> int:
	return _weights["w_fragments"]


func w_domination() -> int:
	return _weights["w_domination"]
