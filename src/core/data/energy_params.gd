# Energy tuning (GDD 10 rule 2, domain `energie`) [PROP].
class_name EnergyParams
extends RefCounted

const SCHEMA_VERSION := 1

const SCHEMA := {
	"schema_version": {"kind": &"int", "min": SCHEMA_VERSION, "max": SCHEMA_VERSION},
	"max": {"kind": &"int", "min": 1, "max": 999},
	"start": {"kind": &"int", "min": 0, "max": 999},
	"income_by_level": {"kind": &"array", "min": 1, "max": NodeParams.MAX_LEVELS,
		"item": {"kind": &"int", "min": 0, "max": 99}},
}

var _max: int
var _start: int
## Index level - 1.
var _income := PackedInt32Array()


static func build(data: Dictionary, file: String, errors: Array[DataError]) -> EnergyParams:
	var params := EnergyParams.new()
	params._max = data["max"]
	params._start = data["start"]
	for income: int in data["income_by_level"]:
		params._income.append(income)
	if params._start > params._max:
		errors.append(DataError.new(file, "start", "%d above max %d" % [params._start, params._max]))
	return params


func max_stock() -> int:
	return _max


func start_stock() -> int:
	return _start


func level_count() -> int:
	return _income.size()


## REVENU_NIVEAU of a level 1..level_count().
func income(level: int) -> int:
	return _income[level - 1]
