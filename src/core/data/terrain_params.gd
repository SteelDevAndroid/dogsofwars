# Terrain tuning (GDD 2 table and Tuning Knobs, domain `terrain`): entry cost and
# defense class by terrain code (TerrainGrid order); cost 0 means impassable (water
# at the MVP). The defense class feeds the combat (GDD 8 formula F1).
class_name TerrainParams
extends RefCounted

const SCHEMA_VERSION := 1
const IMPASSABLE := 0

const SCHEMA := {
	"schema_version": {"kind": &"int", "min": SCHEMA_VERSION, "max": SCHEMA_VERSION},
	"entry_cost": {"kind": &"array", "min": 4, "max": 4, "item": {"kind": &"int", "min": 0, "max": 4}},
	"defense_class": {"kind": &"array", "min": 4, "max": 4, "item": {"kind": &"int", "min": 0, "max": 2}},
}

var _entry_cost := PackedInt32Array()
var _defense_class := PackedInt32Array()


static func build(data: Dictionary, file: String, errors: Array[DataError]) -> TerrainParams:
	var params := TerrainParams.new()
	for cost: int in data["entry_cost"]:
		params._entry_cost.append(cost)
	for tile_class: int in data["defense_class"]:
		params._defense_class.append(tile_class)
	if params._entry_cost[TerrainGrid.PLAIN] == IMPASSABLE:
		errors.append(DataError.new(file, "entry_cost[0]", "the plain must be passable"))
	return params


## Entry cost of a terrain code, IMPASSABLE (0) when it cannot be entered.
func entry_cost(terrain: int) -> int:
	return _entry_cost[terrain]


## Class of defense of a terrain: plain 0, forest 1, mountain 2.
func defense_class(terrain: int) -> int:
	return _defense_class[terrain]


func is_passable(terrain: int) -> bool:
	return _entry_cost[terrain] != IMPASSABLE
