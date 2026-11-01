# Protocol tree (GDD 12 rules 1 and 2, domain `protocoles`): ids 0..n-1; within a
# branch, levels 1..k in order, each level's prerequisite being the previous one.
# Each protocol carries additive effects (GDD 12 rule 2): a stat, a delta, and the
# unit type keys it applies to (empty: every type), read by ProtocolEffects.
class_name ProtocolTree
extends RefCounted

const SCHEMA_VERSION := 1
const MAX_PROTOCOLS := 32

const SCHEMA := {
	"schema_version": {"kind": &"int", "min": SCHEMA_VERSION, "max": SCHEMA_VERSION},
	"protocols": {"kind": &"array", "min": 1, "max": MAX_PROTOCOLS, "item": {"kind": &"object", "fields": {
		"id": {"kind": &"int", "min": 0, "max": MAX_PROTOCOLS - 1},
		"key": {"kind": &"string"},
		"branch": {"kind": &"string"},
		"level": {"kind": &"int", "min": 1, "max": 3},
		"price": {"kind": &"int", "min": 1, "max": 99},
		"duration": {"kind": &"int", "min": 1, "max": 5},
		"effects": {"kind": &"array", "min": 1, "max": 4, "item": {"kind": &"object", "fields": {
			"stat": {"kind": &"enum", "names": STAT_NAMES, "values": [0, 1, 2, 3, 4, 5]},
			"delta": {"kind": &"int", "min": -3, "max": 3},
			"types": {"kind": &"array", "min": 0, "max": UnitTypes.MAX_TYPES, "item": {"kind": &"string"}},
		}}},
	}}},
}

## Stats a protocol modifies (GDD 12 rule 11), index = ProtocolEffects stat id.
const STAT_NAMES := ["vision", "move", "attack", "defense", "rest_heal", "wake_price"]

var _keys := PackedStringArray()
var _branch := PackedStringArray()
var _level := PackedInt32Array()
var _price := PackedInt32Array()
var _duration := PackedInt32Array()
## Flat effect rows, by protocol id then file order.
var _effect_protocol := PackedInt32Array()
var _effect_stat := PackedInt32Array()
var _effect_delta := PackedInt32Array()
var _effect_types: Array[PackedStringArray] = []


static func build(data: Dictionary, file: String, errors: Array[DataError]) -> ProtocolTree:
	var tree := ProtocolTree.new()
	var rows: Array = data["protocols"]
	for k in rows.size():
		var row: Dictionary = rows[k]
		if row["id"] != k:
			errors.append(DataError.new(file, "protocols[%d].id" % k, "expected %d: ids are 0..n-1 in order" % k))
		if tree._keys.has(row["key"]):
			errors.append(DataError.new(file, "protocols[%d].key" % k, "duplicate key %s" % row["key"]))
		var previous := tree._last_level(row["branch"])
		if row["level"] != previous + 1:
			errors.append(DataError.new(file, "protocols[%d].level" % k,
				"expected %d: levels of branch %s follow 1..k" % [previous + 1, row["branch"]]))
		tree._keys.append(row["key"])
		tree._branch.append(row["branch"])
		tree._level.append(row["level"])
		tree._price.append(row["price"])
		tree._duration.append(row["duration"])
		for effect: Dictionary in row["effects"]:
			tree._effect_protocol.append(k)
			tree._effect_stat.append(effect["stat"])
			tree._effect_delta.append(effect["delta"])
			tree._effect_types.append(PackedStringArray(effect["types"]))
	return tree


func count() -> int:
	return _keys.size()


func key(protocol: int) -> String:
	return _keys[protocol]


func price(protocol: int) -> int:
	return _price[protocol]


func duration(protocol: int) -> int:
	return _duration[protocol]


## The previous level of the same branch, -1 for a first level (GDD 12 rule 1).
func prerequisite(protocol: int) -> int:
	for other in count():
		if _branch[other] == _branch[protocol] and _level[other] == _level[protocol] - 1:
			return other
	return -1


func effect_count() -> int:
	return _effect_protocol.size()


func effect_protocol(effect: int) -> int:
	return _effect_protocol[effect]


func effect_stat(effect: int) -> int:
	return _effect_stat[effect]


func effect_delta(effect: int) -> int:
	return _effect_delta[effect]


## Unit type keys of an effect; empty means every type.
func effect_types(effect: int) -> PackedStringArray:
	return _effect_types[effect]


func _last_level(branch: String) -> int:
	var last := 0
	for k in _branch.size():
		if _branch[k] == branch:
			last = maxi(last, _level[k])
	return last
