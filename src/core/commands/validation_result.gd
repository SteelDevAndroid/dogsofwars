# Outcome of a validation (GDD 23 rule 2): permitted, or refused with a code and
# integer parameters; no text.
class_name ValidationResult
extends RefCounted

var permitted: bool
var code: StringName
var params: PackedInt64Array


func _init(p_code: StringName = &"", p_params: PackedInt64Array = PackedInt64Array()) -> void:
	permitted = p_code == &""
	code = p_code
	params = p_params


static func ok() -> ValidationResult:
	return ValidationResult.new()


static func refused(p_code: StringName, p_params: PackedInt64Array = PackedInt64Array()) -> ValidationResult:
	return ValidationResult.new(p_code, p_params)


func equals(other: ValidationResult) -> bool:
	return permitted == other.permitted and code == other.code and params == other.params
