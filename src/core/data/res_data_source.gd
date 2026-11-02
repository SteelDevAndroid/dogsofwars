# Real DataSource over res://assets/data/ (ADR-0009 §4). The .json files have no
# importer: the Android export must include them (filter "assets/data/*.json", §9).
class_name ResDataSource
extends DataSource

const ROOT := "res://assets/data/"


func read_bytes(path: String) -> PackedByteArray:
	if not FileAccess.file_exists(ROOT + path):
		last_error = ERR_FILE_NOT_FOUND
		return PackedByteArray()
	last_error = OK
	return FileAccess.get_file_as_bytes(ROOT + path)


func list(dir: String) -> PackedStringArray:
	var names := DirAccess.get_files_at(ROOT + dir)
	names.sort()
	return names
