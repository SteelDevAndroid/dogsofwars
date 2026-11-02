# Fragment pool (GDD 13 rules 17 to 19 and 27, domain `fragments`): the stable ids of the
# fragments of each faction, in chronicle order (ascending ids), and the radius of the
# recoloured zone of a ruin. The texts of the fragments belong to the presentation.
class_name FragmentPool
extends RefCounted

const SCHEMA_VERSION := 1
const MAX_FRAGMENTS := 64

const SCHEMA := {
	"schema_version": {"kind": &"int", "min": SCHEMA_VERSION, "max": SCHEMA_VERSION},
	"zone_radius": {"kind": &"int", "min": 1, "max": 4},
	"fragments": {"kind": &"array", "min": 1, "max": MAX_FRAGMENTS, "item": {"kind": &"object", "fields": {
		"id": {"kind": &"int", "min": 1, "max": 9999},
		"faction": {"kind": &"enum", "names": ["meute", "gardiens"], "values": [Faction.PLAYER, Faction.AI]},
		"act": {"kind": &"int", "min": 1, "max": 3},
	}}},
}

var _zone_radius := 0
var _ids := PackedInt32Array()
var _factions := PackedInt32Array()


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
	return pool


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
