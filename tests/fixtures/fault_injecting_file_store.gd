# In-memory FileStore with fault injection (ADR-0006 §4, ADR-0011 §4).
# Every operation is one step, numbered from 1 and logged in `calls`.
# - fail_at(n): step n fails; a failed write leaves the first half of the bytes
#   (torn write), so the read-back check of the .tmp is exercised.
# - stop_after(n): simulated power cut after step n; later steps fail with
#   ERR_UNAVAILABLE and change nothing. restarted() gives the files as they were.
# - storage_full: every write fails with ERR_FILE_CANT_WRITE and writes nothing.
# rename() refuses an existing target (ERR_ALREADY_EXISTS): the real store deletes
# the target first on every platform (ADR-0006 §6), so the double enforces it.
class_name FaultInjectingFileStore
extends FileStore

var calls: PackedStringArray = []
var storage_full := false

var _files: Dictionary = {}
var _fail_steps: Dictionary = {}
var _stop_after := -1
var _stopped := false


func fail_at(step: int, error: Error = ERR_FILE_CANT_WRITE) -> void:
	_fail_steps[step] = error


func stop_after(step: int) -> void:
	_stop_after = step


## A new store holding the files left at the stop, without faults: the next launch.
func restarted() -> FaultInjectingFileStore:
	var next := FaultInjectingFileStore.new()
	next._files = _files.duplicate(true)
	return next


func paths() -> PackedStringArray:
	var names := PackedStringArray(_files.keys())
	names.sort()
	return names


func write(path: String, bytes: PackedByteArray) -> Error:
	var fault := _step("write " + path)
	if fault != OK:
		if not _stopped:
			_files[path] = bytes.slice(0, bytes.size() / 2)
		return fault
	if storage_full:
		return ERR_FILE_CANT_WRITE
	_files[path] = bytes.duplicate()
	return OK


func read(path: String) -> PackedByteArray:
	if _step("read " + path) != OK or not _files.has(path):
		return PackedByteArray()
	return _files[path].duplicate()


func rename(from: String, to: String) -> Error:
	var fault := _step("rename " + from + " " + to)
	if fault != OK:
		return fault
	if not _files.has(from):
		return ERR_FILE_NOT_FOUND
	if _files.has(to):
		return ERR_ALREADY_EXISTS
	_files[to] = _files[from]
	_files.erase(from)
	return OK


func delete(path: String) -> Error:
	var fault := _step("delete " + path)
	if fault != OK:
		return fault
	if not _files.erase(path):
		return ERR_FILE_NOT_FOUND
	return OK


func exists(path: String) -> bool:
	return _step("exists " + path) == OK and _files.has(path)


func _step(call: String) -> Error:
	calls.append(call)
	var n := calls.size()
	_stopped = _stop_after >= 0 and n > _stop_after
	if _stopped:
		return ERR_UNAVAILABLE
	return _fail_steps.get(n, OK) as Error
