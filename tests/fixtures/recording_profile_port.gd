# ProfilePort that records every call and keeps the written fragments, idempotent
# by (faction, fragment id) like the real profile (ADR-0011 §4).
# - fail_writes: every write fails (file error): false, nothing kept;
# - read_only: profile of a newer version (ADR-0006 §3): false, nothing kept.
class_name RecordingProfilePort
extends ProfilePort

var calls: Array[ProfileEffect] = []
var fail_writes := false
var read_only := false

## Rows sorted by (faction, fragment id), no duplicate.
var _factions := PackedInt32Array()
var _fragments := PackedInt32Array()


func apply(effect: ProfileEffect) -> bool:
	calls.append(effect)
	if fail_writes or read_only:
		return false
	var record := effect as RecordFragmentEffect
	assert(record != null, "unknown profile effect")
	if not has_fragment(record.faction, record.fragment_id):
		var at := 0
		while at < _factions.size() and (_factions[at] < record.faction
				or (_factions[at] == record.faction and _fragments[at] < record.fragment_id)):
			at += 1
		_factions.insert(at, record.faction)
		_fragments.insert(at, record.fragment_id)
	return true


func has_fragment(faction: int, fragment_id: int) -> bool:
	for k in _factions.size():
		if _factions[k] == faction and _fragments[k] == fragment_id:
			return true
	return false


## Fragment ids written for a faction, ascending.
func fragments_of(faction: int) -> PackedInt32Array:
	var ids := PackedInt32Array()
	for k in _factions.size():
		if _factions[k] == faction:
			ids.append(_fragments[k])
	return ids
