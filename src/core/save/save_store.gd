# Save of the match (ADR-0006): one writer, in series, over the FileStore port.
# Write sequence (§6): the new file goes to `match.tmp`, is read back and verified, the
# current file (if valid) becomes `match.bak`, a current of unknown validity is set aside
# (`match.bad1`, `match.bad2`: never deleted before the cap), the target is always deleted
# before the rename, then `match.tmp` becomes `match.sav`. Load (§3, §9): leftover `.tmp`
# files are removed and never promoted; the current file, then the backup, nothing else;
# a damaged current is set aside; a newer content schema is refused without fallback;
# after decoding, the vision is rebuilt and the invariants checked, a failure there being
# a corruption. A save of an older schema goes through SaveMigrations; when there is no chain,
# a step refuses or the result breaks an invariant, the file is set aside (renamed, never
# deleted) and the result says OLDER (GDD 16 rule 17bis). The migrated file is rewritten in the
# current schema by the next save.
class_name SaveStore
extends RefCounted

const BAD_FILE_CAP := 2

var _files: FileStore
var _catalog: DataCatalog
var _dir: String
## True after a load or a verified write of the current file; unknown after a failed rename.
var _current_known_valid := false


func _init(files: FileStore, catalog: DataCatalog, dir: String = "user://") -> void:
	_files = files
	_catalog = catalog
	_dir = dir


func save_match(state: GameState) -> Error:
	var bytes := SaveEnvelope.encode(state.to_bytes(), GameState.SCHEMA_VERSION, state.revision())
	var error := _files.write(_path("match.tmp"), bytes)
	if error != OK or not _verified(_files.read(_path("match.tmp"))):
		_files.delete(_path("match.tmp"))
		return error if error != OK else ERR_FILE_CORRUPT
	if _files.exists(_path("match.sav")):
		if _current_known_valid or _verified(_files.read(_path("match.sav"))):
			_files.delete(_path("match.bak"))
			error = _files.rename(_path("match.sav"), _path("match.bak"))
		else:
			error = _set_aside("match.sav")
		if error != OK:
			_current_known_valid = false
			return error
	error = _files.rename(_path("match.tmp"), _path("match.sav"))
	_current_known_valid = error == OK
	return error


## True when a current or backup save file exists (the menu offers Continue).
func has_match() -> bool:
	return _files.exists(_path("match.sav")) or _files.exists(_path("match.bak"))


func load_match() -> LoadResult:
	_files.delete(_path("match.tmp"))
	var result := LoadResult.new()
	var damaged := false
	var too_old := false
	for name in ["match.sav", "match.bak"]:
		if not _files.exists(_path(name)):
			continue
		var attempt := _try(name, result)
		if attempt == &"OK":
			result.from_backup = name == "match.bak"
			if result.from_backup:
				result.warnings.append("the current save was damaged: the backup was loaded")
			_current_known_valid = not result.from_backup
			result.code = LoadResult.OK
			return result
		if attempt == &"NEWER":
			result.state = null
			result.code = LoadResult.NEWER
			return result
		if attempt == &"OLDER":  # the next candidate may still be loadable
			too_old = true
			result.warnings.append("%s comes from an older version and was set aside" % name)
			_set_aside(name)
			continue
		damaged = true
		result.warnings.append("%s is damaged (%s)" % [name, attempt])
		if name == "match.sav":
			_set_aside("match.sav")
	result.state = null
	result.vision = null
	result.code = LoadResult.OLDER if too_old and not damaged else (LoadResult.CORRUPT if damaged else LoadResult.NONE)
	return result


## New game over an existing one (ADR-0006 §10): temporaries, backup, then current.
func delete_match() -> void:
	for name in ["match.tmp", "match.bak", "match.sav"]:
		_files.delete(_path(name))
	_current_known_valid = false


## The reason a file cannot be loaded, or "OK" with the state in `result`.
func _try(name: String, result: LoadResult) -> StringName:
	var code := [SaveEnvelope.OK]
	var envelope := SaveEnvelope.decode(_files.read(_path(name)), code)
	if envelope == null:
		return code[0]
	if envelope.content_schema > GameState.SCHEMA_VERSION:
		return &"NEWER"
	var payload := envelope.payload
	if envelope.content_schema < GameState.SCHEMA_VERSION:
		payload = SaveMigrations.migrate(payload, envelope.content_schema)
		if payload.is_empty():
			return &"OLDER"
		result.migrated_from = envelope.content_schema
	var state := GameState.from_bytes(payload, GameState.SCHEMA_VERSION)
	if state == null:
		result.migrated_from = 0
		return &"OLDER" if envelope.content_schema < GameState.SCHEMA_VERSION else &"BAD_STATE"
	var vision := VisionContext.for_map(_catalog, state)
	VisionService.rebuild(state, vision)
	if not state.validate().is_empty() or not VisionService.consistency_errors(state).is_empty():
		result.migrated_from = 0
		return &"OLDER" if envelope.content_schema < GameState.SCHEMA_VERSION else &"BAD_INVARIANTS"
	result.state = state
	result.vision = vision
	return &"OK"


func _verified(bytes: PackedByteArray) -> bool:
	return SaveEnvelope.decode(bytes, [SaveEnvelope.OK]) != null


## Renames a file nobody can trust to `match.bad1`, pushing the older ones (cap 2).
func _set_aside(name: String) -> Error:
	var base := name.get_basename()
	_files.delete(_path("%s.bad%d" % [base, BAD_FILE_CAP]))
	for k in range(BAD_FILE_CAP - 1, 0, -1):
		if _files.exists(_path("%s.bad%d" % [base, k])):
			_files.rename(_path("%s.bad%d" % [base, k]), _path("%s.bad%d" % [base, k + 1]))
	return _files.rename(_path(name), _path("%s.bad1" % base))


func _path(name: String) -> String:
	return _dir + name
