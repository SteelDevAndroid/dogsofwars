# The profile (GDD 22, ADR-0006): what survives a match. The settings, the chronicle (fragments found, per
# faction), the best scores per (faction, difficulty), the match counter and the reset epoch.
# It is the real ProfilePort: a fragment is kept once (idempotent by id), a score keeps the
# maximum and is ignored for a match id already taken (the last 8 are remembered). Each change
# is written at once through the FileStore (tmp, verified, backup, rename); a profile of a
# newer content schema is read-only and refuses every write (ADR-0006 §3). A damaged file
# falls back to its backup, then to a fresh profile.
class_name ProfileStore
extends ProfilePort

const SCHEMA_VERSION := 1
const RECENT_MATCHES := 8

var epoch := 0
var read_only := false
var warnings := PackedStringArray()
var last_error: Error = OK

var _files: FileStore
var _path: String
## Rows [faction, fragment id], ascending.
var _fragments: Array = []
## faction * 16 + difficulty -> score.
var _best := {}
var _recent: Array = []
var _next_match := 1
var _settings := GameSettings.defaults()


func _init(files: FileStore, dir: String = "user://") -> void:
	_files = files
	_path = dir + "profile"


func load_profile() -> void:
	_files.delete(_path + ".tmp")
	for name in [".sav", ".bak"]:
		if not _files.exists(_path + name):
			continue
		var code := [SaveEnvelope.OK]
		var envelope := SaveEnvelope.decode(_files.read(_path + name), code)
		if envelope == null:
			warnings.append("profile%s is damaged (%s)" % [name, code[0]])
			continue
		if envelope.content_schema > SCHEMA_VERSION:
			read_only = true
			warnings.append("the profile comes from a newer version: it stays read-only")
			return
		var data: Variant = bytes_to_var(envelope.payload)
		if typeof(data) == TYPE_DICTIONARY and _adopt(data):
			if name == ".bak":
				warnings.append("the profile was damaged: the backup was loaded")
			return
		warnings.append("profile%s holds unreadable data" % name)


func chronicle() -> Array:
	return _fragments.duplicate(true)


func has_fragment(faction: int, fragment_id: int) -> bool:
	return _fragments.has([faction, fragment_id])


## Best score for (faction, difficulty), -1 when none.
func best_score(faction: int, difficulty: int) -> int:
	return _best.get(faction * 16 + difficulty, -1)


## The identifier of the next match (idempotence of the score submission), persisted.
func next_match_id() -> int:
	var id := _next_match
	_next_match += 1
	_write()
	return id


## A copy of the settings (every key of GameSettings.TABLE).
func settings() -> Dictionary:
	return _settings.duplicate()


func setting(key: StringName) -> int:
	return _settings[key]


## Changes one setting and writes it at once. False for an unknown key, an invalid value or a
## read-only profile; the setting is then left as it was.
func set_setting(key: StringName, value: Variant) -> bool:
	if read_only or not GameSettings.is_valid(key, value):
		return false
	if _settings[key] == value:
		return true
	var before: int = _settings[key]
	_settings[key] = value
	if _write():
		return true
	_settings[key] = before
	return false


func apply(effect: ProfileEffect) -> bool:
	if read_only:
		return false
	if effect is RecordFragmentEffect:
		var fragment := effect as RecordFragmentEffect
		if not has_fragment(fragment.faction, fragment.fragment_id):
			_fragments.append([fragment.faction, fragment.fragment_id])
			_fragments.sort_custom(func(a: Array, b: Array) -> bool: return a[0] < b[0] or (a[0] == b[0] and a[1] < b[1]))
			return _write()
		return true
	if effect is SubmitScoreEffect:
		var submission := effect as SubmitScoreEffect
		if _recent.has(submission.match_id):
			return true
		_recent.append(submission.match_id)
		if _recent.size() > RECENT_MATCHES:
			_recent.remove_at(0)
		var key := submission.faction * 16 + submission.difficulty
		_best[key] = maxi(_best.get(key, 0), submission.score)
		return _write()
	assert(false, "unknown profile effect")
	return false


## Progress reset (GDD 22): chronicle and scores gone, the epoch moves on, the settings stay.
func reset_progress() -> bool:
	_fragments = []
	_best = {}
	_recent = []
	epoch += 1
	return _write()


func _adopt(data: Dictionary) -> bool:
	if not (data.get("fragments") is Array and data.get("best") is Dictionary and data.get("recent") is Array \
			and data.get("epoch") is int and data.get("next_match") is int):
		return false
	_fragments = data["fragments"]
	_best = data["best"]
	_recent = data["recent"]
	epoch = data["epoch"]
	_next_match = data["next_match"]
	_settings = GameSettings.clean(data.get("settings"))
	return true


func _write() -> bool:
	var data := {"fragments": _fragments, "best": _best, "recent": _recent, "epoch": epoch, "next_match": _next_match, "settings": _settings}
	var bytes := SaveEnvelope.encode(var_to_bytes(data), SCHEMA_VERSION, 0)
	last_error = _files.write(_path + ".tmp", bytes)
	if last_error == OK and SaveEnvelope.decode(_files.read(_path + ".tmp"), [SaveEnvelope.OK]) == null:
		last_error = ERR_FILE_CORRUPT
	if last_error != OK:
		_files.delete(_path + ".tmp")
		return false
	if _files.exists(_path + ".sav"):
		_files.delete(_path + ".bak")
		last_error = _files.rename(_path + ".sav", _path + ".bak")
		if last_error != OK:
			return false
	last_error = _files.rename(_path + ".tmp", _path + ".sav")
	return last_error == OK
