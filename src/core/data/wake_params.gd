# Wake-up prices (GDD 7 rule 1, domain `reveil`) [PROP]: the dormant's type gives the
# price, fixed during the match. Protocols adjust it at read time (WakeRules.price).
class_name WakeParams
extends RefCounted

const SCHEMA_VERSION := 1

const SCHEMA := {
	"schema_version": {"kind": &"int", "min": SCHEMA_VERSION, "max": SCHEMA_VERSION},
	"prices": {"kind": &"array", "min": 1, "max": UnitTypes.MAX_TYPES, "item": {"kind": &"object", "fields": {
		"type": {"kind": &"string"},
		"price": {"kind": &"int", "min": 1, "max": 99},
	}}},
}

var _type_keys := PackedStringArray()
var _prices := PackedInt32Array()


static func build(data: Dictionary, file: String, errors: Array[DataError]) -> WakeParams:
	var params := WakeParams.new()
	var rows: Array = data["prices"]
	for k in rows.size():
		var row: Dictionary = rows[k]
		if params._type_keys.has(row["type"]):
			errors.append(DataError.new(file, "prices[%d].type" % k, "duplicate type %s" % row["type"]))
		params._type_keys.append(row["type"])
		params._prices.append(row["price"])
	return params


func count() -> int:
	return _prices.size()


func key_at(index: int) -> String:
	return _type_keys[index]


func price_at(index: int) -> int:
	return _prices[index]


## Base price of a unit type key, 0 when the type has none (cross-checked at load:
## every pack type has one).
func base_price(type_key: String) -> int:
	var index := _type_keys.find(type_key)
	return 0 if index < 0 else _prices[index]
