# Unit types (GDD 6 tables, domain `units`): read-only, indexed by type id 0..n-1.
class_name UnitTypes
extends RefCounted

const SCHEMA_VERSION := 1
const MAX_TYPES := 16

## GDD 6: PV_max 6..14, MVT 0..4; GDD 5: view radius 1..5; range 1 everywhere at
## the MVP; attack and defense bounded by the combat tables [PROP].
const SCHEMA := {
	"schema_version": {"kind": &"int", "min": SCHEMA_VERSION, "max": SCHEMA_VERSION},
	"types": {"kind": &"array", "min": 1, "max": MAX_TYPES, "item": {"kind": &"object", "fields": {
		"id": {"kind": &"int", "min": 0, "max": MAX_TYPES - 1},
		"key": {"kind": &"string"},
		"side": {"kind": &"enum", "names": ["meute", "gardiens"], "values": [Faction.PLAYER, Faction.AI]},
		"hp": {"kind": &"int", "min": 6, "max": 14},
		"attack": {"kind": &"int", "min": 0, "max": 5},
		"defense": {"kind": &"int", "min": 0, "max": 5},
		"move": {"kind": &"int", "min": 0, "max": 4},
		"range": {"kind": &"int", "min": 1, "max": 1},
		"vision": {"kind": &"int", "min": 1, "max": 5},
	}}},
}

var _keys := PackedStringArray()
var _side := PackedInt32Array()
var _hp := PackedInt32Array()
var _attack := PackedInt32Array()
var _defense := PackedInt32Array()
var _move := PackedInt32Array()
var _range := PackedInt32Array()
var _vision := PackedInt32Array()


## Builds from checked data; ids must be 0..n-1 in order and keys unique.
static func build(data: Dictionary, file: String, errors: Array[DataError]) -> UnitTypes:
	var types := UnitTypes.new()
	var rows: Array = data["types"]
	for k in rows.size():
		var row: Dictionary = rows[k]
		if row["id"] != k:
			errors.append(DataError.new(file, "types[%d].id" % k, "expected %d: ids are 0..n-1 in order" % k))
		if types._keys.has(row["key"]):
			errors.append(DataError.new(file, "types[%d].key" % k, "duplicate key %s" % row["key"]))
		types._keys.append(row["key"])
		types._side.append(row["side"])
		types._hp.append(row["hp"])
		types._attack.append(row["attack"])
		types._defense.append(row["defense"])
		types._move.append(row["move"])
		types._range.append(row["range"])
		types._vision.append(row["vision"])
	return types


func count() -> int:
	return _keys.size()


func key(type: int) -> String:
	return _keys[type]


## Faction that fields the type: Faction.PLAYER for the pack, Faction.AI for the Guardians.
func side(type: int) -> int:
	return _side[type]


func hp(type: int) -> int:
	return _hp[type]


func attack(type: int) -> int:
	return _attack[type]


func defense(type: int) -> int:
	return _defense[type]


func move(type: int) -> int:
	return _move[type]


func attack_range(type: int) -> int:
	return _range[type]


func vision(type: int) -> int:
	return _vision[type]


## View radius of every type, by type id (a copy).
func vision_radii() -> PackedInt32Array:
	return _vision.duplicate()
