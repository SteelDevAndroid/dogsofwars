# Unit types (GDD 6 tables, domain `units`): read-only, indexed by type id 0..n-1.
class_name UnitTypes
extends RefCounted

const SCHEMA_VERSION := 1
const MAX_TYPES := 16

## The active abilities (one per type at most). SPRINT: +MVT this turn. CHARGE: +ATQ this turn.
## HOLD: +DÉF until the unit's next turn, costs the action. REPAIR: heals the unit and its
## neighbours, costs the action.
const ABILITY_NONE := 0
const ABILITY_SPRINT := 1
const ABILITY_CHARGE := 2
const ABILITY_HOLD := 3
const ABILITY_REPAIR := 4

## GDD 6: PV_max 6..14, MVT 0..4; GDD 5: view radius 1..5;
## range 1 or 2 (distance weapons); attack and defense bounded by the combat tables [PROP].
const SCHEMA := {
	"schema_version": {"kind": &"int", "min": SCHEMA_VERSION, "max": SCHEMA_VERSION},
	"rest_heal": {"kind": &"int", "min": 1, "max": 3},
	"node_passive_heal": {"kind": &"int", "min": 0, "max": 2},
	# Active abilities (GDD 6, rule 12): the strength of each effect, in the units of its stat.
	"sprint_bonus": {"kind": &"int", "min": 1, "max": 3},
	"charge_bonus": {"kind": &"int", "min": 1, "max": 3},
	"hold_bonus": {"kind": &"int", "min": 1, "max": 3},
	"repair_amount": {"kind": &"int", "min": 1, "max": 5},
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
		"ability": {"kind": &"enum", "names": ["none", "sprint", "charge", "hold", "repair"],
			"values": [ABILITY_NONE, ABILITY_SPRINT, ABILITY_CHARGE, ABILITY_HOLD, ABILITY_REPAIR]},
		"cooldown": {"kind": &"int", "min": 0, "max": 6},
	}}},
}

var _rest_heal := 0
var _node_rest_bonus := 0
var _node_passive_heal := 0
var _sprint_bonus := 0
var _charge_bonus := 0
var _hold_bonus := 0
var _repair_amount := 0
var _keys := PackedStringArray()
var _side := PackedInt32Array()
var _hp := PackedInt32Array()
var _attack := PackedInt32Array()
var _defense := PackedInt32Array()
var _move := PackedInt32Array()
var _range := PackedInt32Array()
var _vision := PackedInt32Array()
var _captures := PackedByteArray()
var _ability := PackedInt32Array()
var _cooldown := PackedInt32Array()


## Builds from checked data; ids must be 0..n-1 in order and keys unique.
static func build(data: Dictionary, file: String, errors: Array[DataError]) -> UnitTypes:
	var types := UnitTypes.new()
	types._rest_heal = data["rest_heal"]
	types._node_rest_bonus = data["node_rest_bonus"]
	types._node_passive_heal = data["node_passive_heal"]
	types._sprint_bonus = data["sprint_bonus"]
	types._charge_bonus = data["charge_bonus"]
	types._hold_bonus = data["hold_bonus"]
	types._repair_amount = data["repair_amount"]
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
		types._ability.append(row["ability"])
		types._cooldown.append(row["cooldown"])
		if row["ability"] != ABILITY_NONE and row["cooldown"] == 0:
			errors.append(DataError.new(file, "types[%d].cooldown" % k, "an ability needs a cooldown of at least 1"))
	return types


## GDD 6 formula 3: base rest heal, and the bonus on a node the faction owns.
func rest_heal() -> int:
	return _rest_heal


## Heal of a unit that did not rest but stands on a node its faction owns.
func node_passive_heal() -> int:
	return _node_passive_heal


## The active ability of a type (ABILITY_*), and the turns it takes to be ready again.
func ability(type: int) -> int:
	return _ability[type]


func ability_cooldown(type: int) -> int:
	return _cooldown[type]


func sprint_bonus() -> int:
	return _sprint_bonus


func charge_bonus() -> int:
	return _charge_bonus


func hold_bonus() -> int:
	return _hold_bonus


func repair_amount() -> int:
	return _repair_amount


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
