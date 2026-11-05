# Unit types (GDD 6 tables, domain `units`): read-only, indexed by type id 0..n-1.
class_name UnitTypes
extends RefCounted

const SCHEMA_VERSION := 1
const MAX_TYPES := 16

## GDD 6: PV_max 6..14, MVT 0..4; GDD 5: view radius 1..5;
## range 1 or 2 (distance weapons); attack and defense bounded by the combat tables [PROP].
const SCHEMA := {
	"schema_version": {"kind": &"int", "min": SCHEMA_VERSION, "max": SCHEMA_VERSION},
	"rest_heal": {"kind": &"int", "min": 1, "max": 3},
	"node_passive_heal": {"kind": &"int", "min": 0, "max": 2},
	"node_rest_bonus": {"kind": &"int", "min": 0, "max": 4},
	"types": {"kind": &"array", "min": 1, "max": MAX_TYPES, "item": {"kind": &"object", "fields": {
		"id": {"kind": &"int", "min": 0, "max": MAX_TYPES - 1},
		"key": {"kind": &"string"},
		"side": {"kind": &"enum", "names": ["meute", "gardiens"], "values": [Faction.PLAYER, Faction.AI]},
		"hp": {"kind": &"int", "min": 6, "max": 14},
		"attack": {"kind": &"int", "min": 0, "max": 5},
		"defense": {"kind": &"int", "min": 0, "max": 5},
		"move": {"kind": &"int", "min": 0, "max": 4},
		"range": {"kind": &"int", "min": 1, "max": 2},
		"vision": {"kind": &"int", "min": 1, "max": 5},
		"captures": {"kind": &"int", "min": 0, "max": 1},
	}}},
}

var _rest_heal := 0
var _node_rest_bonus := 0
var _node_passive_heal := 0
var _keys := PackedStringArray()
var _side := PackedInt32Array()
var _hp := PackedInt32Array()
var _attack := PackedInt32Array()
var _defense := PackedInt32Array()
var _move := PackedInt32Array()
var _range := PackedInt32Array()
var _vision := PackedInt32Array()
var _captures := PackedByteArray()


## Builds from checked data; ids must be 0..n-1 in order and keys unique.
static func build(data: Dictionary, file: String, errors: Array[DataError]) -> UnitTypes:
	var types := UnitTypes.new()
	types._rest_heal = data["rest_heal"]
	types._node_rest_bonus = data["node_rest_bonus"]
	types._node_passive_heal = data["node_passive_heal"]
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
		types._captures.append(row["captures"])
	return types


## GDD 6 formula 3: base rest heal, and the bonus on a node the faction owns.
func rest_heal() -> int:
	return _rest_heal


## Heal of a unit that did not rest but stands on a node its faction owns.
func node_passive_heal() -> int:
	return _node_passive_heal


func node_rest_bonus() -> int:
	return _node_rest_bonus


func count() -> int:
	return _keys.size()


## Type id of a key, -1 when unknown.
func type_of_key(type_key: String) -> int:
	return _keys.find(type_key)


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


## GDD 6 rule 7: only the Ouvrier (pack) and the Bastion (Guardians) capture nodes.
func can_capture(type: int) -> bool:
	return _captures[type] == 1


## View radius of every type, by type id (a copy).
func vision_radii() -> PackedInt32Array:
	return _vision.duplicate()
