# One data loading error (ADR-0009 §3): file, field path, message.
class_name DataError
extends RefCounted

var file: String
var path: String
var message: String


func _init(p_file: String, p_path: String, p_message: String) -> void:
	file = p_file
	path = p_path
	message = p_message


func _to_string() -> String:
	return "%s: %s: %s" % [file, path, message]
