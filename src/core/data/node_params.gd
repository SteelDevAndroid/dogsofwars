# Node tuning (GDD 11, domain `noeuds`): territory radius by level (RAYON_NIVEAU).
class_name NodeParams
extends RefCounted

const SCHEMA_VERSION := 1
const MAX_LEVELS := 5

const SCHEMA := {
	"schema_version": {"kind": &"int", "min": SCHEMA_VERSION, "max": SCHEMA_VERSION},
	"territory_radius": {"kind": &"array", "min": 1, "max": MAX_LEVELS,
		"item": {"kind": &"int", "min": 1, "max": 4}},
}

## Index level - 1.
var _territory_radius := PackedInt32Array()


static func build(data: Dictionary, file: String, errors: Array[DataError]) -> NodeParams:
	var params := NodeParams.new()
	var radii: Array = data["territory_radius"]
	for k in radii.size():
		if k > 0 and radii[k] < radii[k - 1]:
			errors.append(DataError.new(file, "territory_radius[%d]" % k, "radius decreases with the level"))
		params._territory_radius.append(radii[k])
	return params


func max_level() -> int:
	return _territory_radius.size()


## Territory radius of a level 1..max_level().
func territory_radius(level: int) -> int:
	return _territory_radius[level - 1]
