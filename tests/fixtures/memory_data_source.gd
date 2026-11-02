# DataSource over an in-memory dictionary (ADR-0011 §4): "path" -> String or
# PackedByteArray. Paths are relative to the data root, "/" separated.
class_name MemoryDataSource
extends DataSource

var _files: Dictionary = {}


func _init(files: Dictionary = {}) -> void:
	for path: String in files:
		put(path, files[path])


func put(path: String, content: Variant) -> void:
	_files[path] = content if content is PackedByteArray else String(content).to_utf8_buffer()


func read_bytes(path: String) -> PackedByteArray:
	if not _files.has(path):
		last_error = ERR_FILE_NOT_FOUND
		return PackedByteArray()
	last_error = OK
	return _files[path]


func list(dir: String) -> PackedStringArray:
	var prefix := dir.trim_suffix("/") + "/" if not dir.is_empty() else ""
	var names := PackedStringArray()
	for path: String in _files:
		if path.begins_with(prefix) and not path.substr(prefix.length()).contains("/"):
			names.append(path.substr(prefix.length()))
	names.sort()
	return names
