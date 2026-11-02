# Fog tuning (GDD 5 Tuning Knobs, domain `brouillard`).
class_name FogParams
extends RefCounted

const SCHEMA_VERSION := 1

## Node view = max(node_view_min, territory radius), 2..4; mountain bonus 0..2.
const SCHEMA := {
	"schema_version": {"kind": &"int", "min": SCHEMA_VERSION, "max": SCHEMA_VERSION},
	"node_view_min": {"kind": &"int", "min": 2, "max": 4},
	"mountain_view_bonus": {"kind": &"int", "min": 0, "max": 2},
}

var _node_view_min: int
var _mountain_view_bonus: int


static func build(data: Dictionary, _file: String, _errors: Array[DataError]) -> FogParams:
	var params := FogParams.new()
	params._node_view_min = data["node_view_min"]
	params._mountain_view_bonus = data["mountain_view_bonus"]
	return params


func node_view_min() -> int:
	return _node_view_min


func mountain_view_bonus() -> int:
	return _mountain_view_bonus
