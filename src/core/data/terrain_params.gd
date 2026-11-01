# Terrain tuning (GDD 2 table and Tuning Knobs, domain `terrain`): entry cost by
# terrain code (TerrainGrid order), 0 meaning impassable (water at the MVP).
class_name TerrainParams
extends RefCounted

const SCHEMA_VERSION := 1
const IMPASSABLE := 0

const SCHEMA := {
	"schema_version": {"kind": &"int", "min": SCHEMA_VERSION, "max": SCHEMA_VERSION},
	"entry_cost": {"kind": &"array", "min": 4, "max": 4, "item": {"kind": &"int", "min": 0, "max": 4}},
}

var _entry_cost := PackedInt32Array()


static func build(data: Dictionary, file: String, errors: Array[DataError]) -> TerrainParams:
	var params := TerrainParams.new()
	for cost: int in data["entry_cost"]:
		params._entry_cost.append(cost)
	if params._entry_cost[TerrainGrid.PLAIN] == IMPASSABLE:
		errors.append(DataError.new(file, "entry_cost[0]", "the plain must be passable"))
	return params


## Entry cost of a terrain code, IMPASSABLE (0) when it cannot be entered.
func entry_cost(terrain: int) -> int:
	return _entry_cost[terrain]


func is_passable(terrain: int) -> bool:
	return _entry_cost[terrain] != IMPASSABLE
