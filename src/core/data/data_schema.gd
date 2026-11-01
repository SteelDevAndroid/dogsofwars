# Strict schema of a data file, declared in code (ADR-0009 §2 and §3).
# A spec is a constant Dictionary with a "kind" (a StringName):
#   {"kind": &"int", "min": a, "max": b}
#   {"kind": &"string"}
#   {"kind": &"enum", "names": [String], "values": [int]}
#   {"kind": &"array", "item": spec, "min": n, "max": m}
#   {"kind": &"object", "fields": {key: spec}}   every key required, no other key
# A file schema is the "fields" of its top-level object. check() validates a value
# parsed by JSON and returns it converted (integers as int), or null after
# appending every error found: unknown or missing key, wrong type, fraction,
# out of bounds, value outside an enumeration, wrong array size.
class_name DataSchema
extends RefCounted

const INT_LIMIT := 2147483647

const _INT := &"int"
const _STRING := &"string"
const _ENUM := &"enum"
const _ARRAY := &"array"
const _OBJECT := &"object"


static func check(value: Variant, spec: Dictionary, file: String, path: String, errors: Array[DataError]) -> Variant:
	match spec["kind"]:
		_INT:
			return _check_int(value, spec, file, path, errors)
		_STRING:
			if typeof(value) != TYPE_STRING:
				return _fail(errors, file, path, "expected a string")
			return value
		_ENUM:
			if typeof(value) != TYPE_STRING or not spec["names"].has(value):
				return _fail(errors, file, path, "expected one of %s" % ", ".join(PackedStringArray(spec["names"])))
			return spec["values"][spec["names"].find(value)]
		_ARRAY:
			return _check_array(value, spec, file, path, errors)
		_OBJECT:
			return _check_object(value, spec, file, path, errors)
	assert(false, "unknown spec kind %s" % spec["kind"])
	return null


static func _check_int(value: Variant, spec: Dictionary, file: String, path: String, errors: Array[DataError]) -> Variant:
	# JSON numbers come back as float: an integer is checked, never assumed, never rounded.
	if typeof(value) != TYPE_FLOAT:
		return _fail(errors, file, path, "expected an integer")
	var number: float = value
	if is_inf(number) or is_nan(number) or absf(number) > INT_LIMIT:
		return _fail(errors, file, path, "integer outside -2^31+1..2^31-1")
	if number != floorf(number):
		return _fail(errors, file, path, "expected an integer, got %s" % number)
	var integer_value := int(number)
	if integer_value < spec["min"] or integer_value > spec["max"]:
		return _fail(errors, file, path, "%d outside %d..%d" % [integer_value, spec["min"], spec["max"]])
	return integer_value


static func _check_array(value: Variant, spec: Dictionary, file: String, path: String, errors: Array[DataError]) -> Variant:
	if typeof(value) != TYPE_ARRAY:
		return _fail(errors, file, path, "expected an array")
	var items: Array = value
	var ok := true
	if items.size() < spec["min"] or items.size() > spec["max"]:
		_fail(errors, file, path, "%d items, expected %d..%d" % [items.size(), spec["min"], spec["max"]])
		ok = false
	var converted := []
	for k in items.size():
		var item: Variant = check(items[k], spec["item"], file, "%s[%d]" % [path, k], errors)
		ok = ok and item != null
		converted.append(item)
	return converted if ok else null


static func _check_object(value: Variant, spec: Dictionary, file: String, path: String, errors: Array[DataError]) -> Variant:
	if typeof(value) != TYPE_DICTIONARY:
		return _fail(errors, file, path, "expected an object")
	var source: Dictionary = value
	var fields: Dictionary = spec["fields"]
	var ok := true
	var keys := PackedStringArray(source.keys())
	keys.sort()
	for key in keys:
		if not fields.has(key):
			_fail(errors, file, _join(path, key), "unknown key")
			ok = false
	var converted := {}
	for key: String in fields:
		if not source.has(key):
			_fail(errors, file, _join(path, key), "missing key")
			ok = false
			continue
		var field: Variant = check(source[key], fields[key], file, _join(path, key), errors)
		ok = ok and field != null
		converted[key] = field
	return converted if ok else null


static func _join(path: String, key: String) -> String:
	return key if path.is_empty() else path + "." + key


static func _fail(errors: Array[DataError], file: String, path: String, message: String) -> Variant:
	errors.append(DataError.new(file, path if not path.is_empty() else "(root)", message))
	return null
