# Port to the file system for saves (ADR-0006 §4): real implementation over
# FileAccess / DirAccess, FaultInjectingFileStore in tests. Interface by convention.
class_name FileStore
extends RefCounted


## Error of the first failed store_*; OK otherwise.
func write(_path: String, _bytes: PackedByteArray) -> Error:
	assert(false, "FileStore.write is not implemented")
	return ERR_UNAVAILABLE


## Content, or empty when the file is missing or unreadable.
func read(_path: String) -> PackedByteArray:
	assert(false, "FileStore.read is not implemented")
	return PackedByteArray()


func rename(_from: String, _to: String) -> Error:
	assert(false, "FileStore.rename is not implemented")
	return ERR_UNAVAILABLE


func delete(_path: String) -> Error:
	assert(false, "FileStore.delete is not implemented")
	return ERR_UNAVAILABLE


func exists(_path: String) -> bool:
	assert(false, "FileStore.exists is not implemented")
	return false
