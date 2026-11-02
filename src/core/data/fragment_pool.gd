# Fragment pool (GDD 13 rules 17 to 19 and 27, domain `fragments`): the stable ids of the
# fragments of each faction, in chronicle order (ascending ids), their texts and the radius
# of the recoloured zone of a ruin. A text is content: it never enters the profile, carries
# no game number and has no effect (rules 27 to 30). The chronicle rules of rule 28 are
# data of the pool, checked at load: a pool that fails them is refused.
class_name FragmentPool
extends RefCounted

const SCHEMA_VERSION := 1
const MAX_FRAGMENTS := 64
const MAX_TITLE := 28
const MAX_TEXT := 140
const MAX_SOURCE := 24
const LINK_NONE := 0
const LINK_VERB := 1
const LINK_QUESTION := 2
## The recolouring verb, which a linked fragment must use.
const VERB_STEM := "allum"

const SCHEMA := {
	"schema_version": {"kind": &"int", "min": SCHEMA_VERSION, "max": SCHEMA_VERSION},
	"zone_radius": {"kind": &"int", "min": 1, "max": 4},
	"act3_link_percent": {"kind": &"int", "min": 0, "max": 100},
	"act1_verb_min": {"kind": &"int", "min": 0, "max": MAX_FRAGMENTS},
	"fragments": {"kind": &"array", "min": 1, "max": MAX_FRAGMENTS, "item": {"kind": &"object", "fields": {
		"id": {"kind": &"int", "min": 1, "max": 9999},
		"faction": {"kind": &"enum", "names": ["meute", "gardiens"], "values": [Faction.PLAYER, Faction.AI]},
		"act": {"kind": &"int", "min": 1, "max": 3},
		"title": {"kind": &"string"},
		"text": {"kind": &"string"},
		"source": {"kind": &"string"},
		"tones": {"kind": &"array", "min": 1, "max": 2, "item": {"kind": &"enum",
				"names": ["obeissance", "usure", "doute", "absence", "question"], "values": [0, 1, 2, 3, 4]}},
		"link": {"kind": &"enum", "names": ["aucun", "verbe", "question"], "values": [LINK_NONE, LINK_VERB, LINK_QUESTION]},
	}}},
}

var _zone_radius := 0
var _ids := PackedInt32Array()
var _factions := PackedInt32Array()
var _acts := PackedInt32Array()
var _links := PackedInt32Array()
var _titles := PackedStringArray()
var _texts := PackedStringArray()
var _sources := PackedStringArray()


static func build(data: Dictionary, file: String, errors: Array[DataError]) -> FragmentPool:
	var pool := FragmentPool.new()
	pool._zone_radius = data["zone_radius"]
	var rows: Array = data["fragments"]
	for k in rows.size():
		var row: Dictionary = rows[k]
		if pool._ids.has(row["id"]):
			errors.append(DataError.new(file, "fragments[%d].id" % k, "duplicate id %d" % row["id"]))
		elif k > 0 and row["id"] < pool._ids[k - 1]:
			errors.append(DataError.new(file, "fragments[%d].id" % k, "ids must ascend"))
		pool._ids.append(row["id"])
		pool._factions.append(row["faction"])
		pool._acts.append(row["act"])
		pool._links.append(row["link"])
		pool._titles.append(row["title"])
		pool._texts.append(row["text"])
		pool._sources.append(row["source"])
		_check_row(row, k, file, errors)
	_check_chronicle(pool, data, file, errors)
	return pool


static func _check_row(row: Dictionary, k: int, file: String, errors: Array[DataError]) -> void:
	var at := "fragments[%d]" % k
	_check_text(row["title"], MAX_TITLE, at + ".title", file, errors)
	_check_text(row["text"], MAX_TEXT, at + ".text", file, errors)
	_check_text(row["source"], MAX_SOURCE, at + ".source", file, errors)
	if _has_digit(row["title"]) or _has_digit(row["text"]) or _has_digit(row["source"]):
		errors.append(DataError.new(file, at, "a fragment holds no number (rule 29)"))
	var source: String = row["source"].to_lower()
	for name in ["meute", "gardien", "ruine"]:
		if source.contains(name):
			errors.append(DataError.new(file, at + ".source", "the source names no faction and no ruin (rule 27)"))
	if row["link"] != LINK_NONE and not row["text"].to_lower().contains(VERB_STEM):
		errors.append(DataError.new(file, at + ".text", "a linked fragment uses the verb \"allumer\" (rule 27)"))
	if row["link"] == LINK_QUESTION and not row["text"].contains("?"):
		errors.append(DataError.new(file, at + ".text", "a QUESTION link asks a question (rule 27)"))
	if row["tones"].size() == 2 and row["tones"][0] == row["tones"][1]:
		errors.append(DataError.new(file, at + ".tones", "the two tones differ"))


static func _check_text(value: String, limit: int, path: String, file: String, errors: Array[DataError]) -> void:
	if value.strip_edges().is_empty():
		errors.append(DataError.new(file, path, "must not be empty"))
	elif value.length() > limit:
		errors.append(DataError.new(file, path, "%d characters, at most %d" % [value.length(), limit]))


static func _has_digit(value: String) -> bool:
	for k in value.length():
		if value.unicode_at(k) >= 48 and value.unicode_at(k) <= 57:
			return true
	return false


## Rule 28, per faction: the acts never go back along the ids; act 3 has at least a share of
## linked fragments and ends on a QUESTION; act 1 has at least a number of VERB fragments.
static func _check_chronicle(pool: FragmentPool, data: Dictionary, file: String, errors: Array[DataError]) -> void:
	for faction in [Faction.PLAYER, Faction.AI]:
		var last_act := 0
		var act3 := 0
		var act3_linked := 0
		var act1_verbs := 0
		var last_link := -1
		for k in pool._ids.size():
			if pool._factions[k] != faction:
				continue
			if pool._acts[k] < last_act:
				errors.append(DataError.new(file, "fragments[%d].act" % k, "acts never go back along the ids"))
			last_act = pool._acts[k]
			last_link = pool._links[k]
			if pool._acts[k] == 3:
				act3 += 1
				act3_linked += 1 if pool._links[k] != LINK_NONE else 0
			elif pool._acts[k] == 1 and pool._links[k] == LINK_VERB:
				act1_verbs += 1
		if last_link < 0:
			continue
		if last_link != LINK_QUESTION:
			errors.append(DataError.new(file, "fragments", "the last fragment of a faction is a QUESTION link (rule 28)"))
		if act3_linked * 100 < act3 * data["act3_link_percent"]:
			errors.append(DataError.new(file, "fragments", "too few linked fragments in act 3 (rule 28)"))
		if act1_verbs < data["act1_verb_min"]:
			errors.append(DataError.new(file, "fragments", "too few VERB fragments in act 1 (rule 28)"))


## RAYON_ZONE_RUINE (GDD 13 rule 4).
func zone_radius() -> int:
	return _zone_radius


## Fragment ids of a faction, ascending.
func ids_of(faction: int) -> PackedInt32Array:
	var ids := PackedInt32Array()
	for k in _ids.size():
		if _factions[k] == faction:
			ids.append(_ids[k])
	return ids


func has_fragment(fragment_id: int) -> bool:
	return _ids.has(fragment_id)


## Title, text and source of a fragment; empty strings for an unknown id.
func title_of(fragment_id: int) -> String:
	return _titles[_ids.find(fragment_id)] if has_fragment(fragment_id) else ""


func text_of(fragment_id: int) -> String:
	return _texts[_ids.find(fragment_id)] if has_fragment(fragment_id) else ""


func source_of(fragment_id: int) -> String:
	return _sources[_ids.find(fragment_id)] if has_fragment(fragment_id) else ""
