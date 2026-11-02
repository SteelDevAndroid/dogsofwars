# The FileStore over the real file system (ADR-0006 §4): the only place that calls
# FileAccess and DirAccess for saves. Paths are complete `user://` paths.
class_name RealFileStore
extends FileStore


func write(path: String, bytes: PackedByteArray) -> Error:
	var file := FileAccess.open(path, FileAccess.WRITE)
	if file == null:
		return FileAccess.get_open_error()
	var stored := file.store_buffer(bytes)  # ADR-0006: every store_* result is checked
	var error := file.get_error()
	file.close()
	if not stored and error == OK:
		return ERR_FILE_CANT_WRITE
	return error


func read(path: String) -> PackedByteArray:
	return FileAccess.get_file_as_bytes(path) if FileAccess.file_exists(path) else PackedByteArray()


func rename(from: String, to: String) -> Error:
	return DirAccess.rename_absolute(from, to)


func delete(path: String) -> Error:
	return DirAccess.remove_absolute(path) if FileAccess.file_exists(path) else OK


func exists(path: String) -> bool:
	return FileAccess.file_exists(path)
