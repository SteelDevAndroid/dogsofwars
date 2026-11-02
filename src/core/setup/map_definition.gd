# A map file (GDD 2 rules 10 to 17, ADR-0009), parsed and checked before it can be played:
# a map that fails a check is refused, never repaired. Pure data; the match setup
# (GameStateFactory) copies it into a new state and draws what the file leaves open.
#
# Provisional additions to the GDD 2 content list: `units` (the units each faction starts
# with, the GDD leaves them open) and `same_as` on a dormant (the draw of a mirrored
# dormant is reproduced, rule 13bis).
class_name MapDefinition
extends RefCounted

const SCHEMA_VERSION := 1
const MAX_SIZE := 16
## GDD 2 rule 11, in Chebyshev distance.
const MIN_NODE_GAP := 4
const MIN_START_GAP := 3
const FACTION_NAMES := ["meute", "gardiens"]
const FACTION_VALUES := [Faction.PLAYER, Faction.AI]
const GLYPHS := {".": TerrainGrid.PLAIN, "f": TerrainGrid.FOREST, "^": TerrainGrid.MOUNTAIN, "~": TerrainGrid.WATER}

const SCHEMA := {
	"schema_version": {"kind": &"int", "min": SCHEMA_VERSION, "max": SCHEMA_VERSION},
	"id": {"kind": &"string"},
	"width": {"kind": &"int", "min": 4, "max": MAX_SIZE},
	"height": {"kind": &"int", "min": 4, "max": MAX_SIZE},
	"terrain": {"kind": &"array", "min": 4, "max": MAX_SIZE, "item": {"kind": &"string"}},
	"symmetry": {"kind": &"enum", "names": ["none", "rotation180"], "values": [0, 1]},
	"memory_faction": {"kind": &"enum", "names": FACTION_NAMES, "values": FACTION_VALUES},
	"starts": {"kind": &"array", "min": 2, "max": 2, "item": {"kind": &"object", "fields": {
		"faction": {"kind": &"enum", "names": FACTION_NAMES, "values": FACTION_VALUES},
		"x": {"kind": &"int", "min": 0, "max": MAX_SIZE - 1}, "y": {"kind": &"int", "min": 0, "max": MAX_SIZE - 1},
	}}},
	"nodes": {"kind": &"array", "min": 0, "max": 16, "item": {"kind": &"object", "fields": {
		"x": {"kind": &"int", "min": 0, "max": MAX_SIZE - 1}, "y": {"kind": &"int", "min": 0, "max": MAX_SIZE - 1},
		"level": {"kind": &"int", "min": 1, "max": 3},
	}}},
	"units": {"kind": &"array", "min": 0, "max": 32, "item": {"kind": &"object", "fields": {
		"type": {"kind": &"string"},
		"faction": {"kind": &"enum", "names": FACTION_NAMES, "values": FACTION_VALUES},
		"x": {"kind": &"int", "min": 0, "max": MAX_SIZE - 1}, "y": {"kind": &"int", "min": 0, "max": MAX_SIZE - 1},
		"post_x": {"kind": &"int", "min": -1, "max": MAX_SIZE - 1}, "post_y": {"kind": &"int", "min": -1, "max": MAX_SIZE - 1},
	}}},
	"dormants": {"kind": &"array", "min": 0, "max": 16, "item": {"kind": &"object", "fields": {
		"x": {"kind": &"int", "min": 0, "max": MAX_SIZE - 1}, "y": {"kind": &"int", "min": 0, "max": MAX_SIZE - 1},
		"types": {"kind": &"array", "min": 1, "max": 8, "item": {"kind": &"string"}},
		"same_as": {"kind": &"int", "min": -1, "max": 15},
	}}},
	"ruin_zones": {"kind": &"array", "min": 1, "max": 8, "item": {"kind": &"object", "fields": {
		"draw": {"kind": &"int", "min": 1, "max": 4},
		"candidates": {"kind": &"array", "min": 2, "max": 12, "item": {"kind": &"object", "fields": {
			"x": {"kind": &"int", "min": 0, "max": MAX_SIZE - 1}, "y": {"kind": &"int", "min": 0, "max": MAX_SIZE - 1},
		}}},
	}}},
}

var id := ""
var width := 0
var height := 0
var symmetric := false
var memory_faction := Faction.PLAYER
## Terrain codes (TerrainGrid.*), row by row.
var cells := PackedByteArray()
var start_tile := {}  # faction -> tile
## Neutral nodes: [tile, level].
var nodes: Array = []
## Starting units: [type key, faction, tile, post tile or -1].
var units: Array = []
## Dormants: [tile, Array[String] type keys, same_as index or -1].
var dormants: Array = []
## Ruin zones: [draw count, PackedInt32Array candidate tiles].
var ruin_zones: Array = []
var _rows: Array = []


## The map in `text`, or null with the errors appended (parse, schema, then the checks of
## `errors_for` once the data catalog is known).
static func parse(text: String, file: String, catalog: DataCatalog, errors: Array[DataError]) -> MapDefinition:
	var json := JSON.new()
	if json.parse(text) != OK or typeof(json.data) != TYPE_DICTIONARY:
		errors.append(DataError.new(file, "(file)", "not a JSON object"))
		return null
	var parsed: Variant = json.data
	var count := errors.size()
	var data: Variant = DataSchema.check(parsed, {"kind": &"object", "fields": SCHEMA}, file, "", errors)
	if data == null:
		return null
	var map := MapDefinition.new()
	map._copy(data)
	for message in map.check(catalog):
		errors.append(DataError.new(file, "(map)", message))
	return map if errors.size() == count else null


func tile(x: int, y: int) -> int:
	return y * width + x


func terrain_at_tile(t: int) -> int:
	return cells[t]


func _copy(data: Dictionary) -> void:
	id = data["id"]
	width = data["width"]
	height = data["height"]
	symmetric = data["symmetry"] == 1
	memory_faction = data["memory_faction"]
	for row: String in data["terrain"]:
		for glyph in row:
			cells.append(GLYPHS.get(glyph, 255))
	for start: Dictionary in data["starts"]:
		start_tile[start["faction"]] = tile(start["x"], start["y"])
	for node: Dictionary in data["nodes"]:
		nodes.append([tile(node["x"], node["y"]), node["level"]])
	for unit: Dictionary in data["units"]:
		var post: int = tile(unit["post_x"], unit["post_y"]) if unit["post_x"] >= 0 and unit["post_y"] >= 0 else -1
		units.append([unit["type"], unit["faction"], tile(unit["x"], unit["y"]), post])
	for dormant: Dictionary in data["dormants"]:
		dormants.append([tile(dormant["x"], dormant["y"]), Array(dormant["types"]), dormant["same_as"]])
	for zone: Dictionary in data["ruin_zones"]:
		var candidates := PackedInt32Array()
		for candidate: Dictionary in zone["candidates"]:
			candidates.append(tile(candidate["x"], candidate["y"]))
		ruin_zones.append([zone["draw"], candidates])
	_rows = data["terrain"]



## Every validity error, one message each (GDD 2 rule 17); empty when the map can be played.
func check(catalog: DataCatalog) -> PackedStringArray:
	var errors := PackedStringArray()
	if _rows.size() != height:
		errors.append("terrain has %d rows, height is %d" % [_rows.size(), height])
		return errors
	for y in height:
		var row: String = _rows[y]
		if row.length() != width:
			errors.append("terrain row %d has %d tiles, width is %d" % [y, row.length(), width])
		for glyph in row:
			if not GLYPHS.has(glyph):
				errors.append("terrain row %d: unknown glyph '%s'" % [y, glyph])
	if not errors.is_empty():
		return errors
	_check_bounds(errors)
	if not errors.is_empty():
		return errors
	_check_starts_and_nodes(errors)
	_check_points_of_interest(catalog, errors)
	_check_units(catalog, errors)
	if symmetric:
		_check_symmetry(errors)
	_check_dormant_cover(catalog, errors)
	return errors


func _in_bounds(t: int) -> bool:
	return t >= 0 and t < width * height


func _distance(a: int, b: int) -> int:
	return CombatRules.distance(width, a, b)


func _check_bounds(errors: PackedStringArray) -> void:
	var tiles: Array = start_tile.values()
	for node: Array in nodes:
		tiles.append(node[0])
	for unit: Array in units:
		tiles.append(unit[2])
	for dormant: Array in dormants:
		tiles.append(dormant[0])
	for zone: Array in ruin_zones:
		tiles.append_array(Array(zone[1]))
	for t: int in tiles:
		if not _in_bounds(t):
			errors.append("a point of interest lies outside the %dx%d map" % [width, height])
			return


func _check_starts_and_nodes(errors: PackedStringArray) -> void:
	if start_tile.size() != 2:
		errors.append("expected one start per faction")
		return
	var node_tiles := PackedInt32Array(start_tile.values())
	for node: Array in nodes:
		node_tiles.append(node[0])
	for t in node_tiles:
		if cells[t] != TerrainGrid.PLAIN:
			errors.append("node or start at tile %d is not on plain (GDD 2 rule 10)" % t)
	for a in node_tiles.size():
		for b in range(a + 1, node_tiles.size()):
			if node_tiles[a] == node_tiles[b]:
				errors.append("two nodes or starts share tile %d" % node_tiles[a])
			elif _distance(node_tiles[a], node_tiles[b]) < MIN_NODE_GAP:
				errors.append("nodes at tiles %d and %d are closer than %d (GDD 2 rule 11)" % [node_tiles[a], node_tiles[b], MIN_NODE_GAP])


func _check_points_of_interest(catalog: DataCatalog, errors: PackedStringArray) -> void:
	var taken := {}
	for t in start_tile.values():
		taken[t] = true
	for node: Array in nodes:
		taken[node[0]] = true
	var all_nodes: Array = start_tile.values()
	for node: Array in nodes:
		all_nodes.append(node[0])
	for k in dormants.size():
		var dormant: Array = dormants[k]
		var t: int = dormant[0]
		if taken.has(t):
			errors.append("dormant %d shares its tile with another point of interest" % k)
		taken[t] = true
		if cells[t] != TerrainGrid.PLAIN and cells[t] != TerrainGrid.FOREST:
			errors.append("dormant %d is not on plain or forest" % k)
		for start: int in start_tile.values():
			if _distance(t, start) < MIN_START_GAP:
				errors.append("dormant %d is closer than %d to a start (GDD 2 rule 11)" % [k, MIN_START_GAP])
		for node_tile: int in all_nodes:
			if _distance(t, node_tile) <= 1:
				errors.append("dormant %d is next to a node" % k)
		for type_key: String in dormant[1]:
			var type := catalog.units.type_of_key(type_key)
			if type < 0 or catalog.wake.base_price(type_key) <= 0:
				errors.append("dormant %d: %s is not a pack type with a wake price" % [k, type_key])
		var same_as: int = dormant[2]
		if same_as >= k:
			errors.append("dormant %d: same_as must name an earlier dormant" % k)
		elif same_as >= 0 and dormants[same_as][1] != dormant[1]:
			errors.append("dormant %d: same_as needs the same type list as dormant %d" % [k, same_as])
	for z in ruin_zones.size():
		var zone: Array = ruin_zones[z]
		var candidates: PackedInt32Array = zone[1]
		if zone[0] > candidates.size():
			errors.append("ruin zone %d draws more ruins than it has candidates" % z)
		for t in candidates:
			if taken.has(t):
				errors.append("ruin candidate at tile %d shares its tile with another point of interest" % t)
			taken[t] = true
			if cells[t] != TerrainGrid.PLAIN and cells[t] != TerrainGrid.FOREST:
				errors.append("ruin candidate at tile %d is not on plain or forest" % t)
			for start: int in start_tile.values():
				if _distance(t, start) < MIN_START_GAP:
					errors.append("ruin candidate at tile %d is closer than %d to a start (GDD 2 rule 11)" % [t, MIN_START_GAP])


func _check_units(catalog: DataCatalog, errors: PackedStringArray) -> void:
	var taken := {}
	for t in start_tile.values():
		taken[t] = true
	for node: Array in nodes:
		taken[node[0]] = true
	for dormant: Array in dormants:
		taken[dormant[0]] = true
	var has_worker := false
	for k in units.size():
		var unit: Array = units[k]
		var type := catalog.units.type_of_key(unit[0])
		if type < 0:
			errors.append("unit %d: unknown type %s" % [k, unit[0]])
			continue
		if catalog.units.side(type) != unit[1]:
			errors.append("unit %d: %s does not belong to that faction" % [k, unit[0]])
		if taken.has(unit[2]):
			errors.append("unit %d shares its tile with a start, a node, a dormant or another unit" % k)
		taken[unit[2]] = true
		if cells[unit[2]] == TerrainGrid.WATER or cells[unit[2]] == TerrainGrid.MOUNTAIN:
			errors.append("unit %d stands on water or a mountain" % k)
		if unit[3] >= 0 and not _in_bounds(unit[3]):
			errors.append("unit %d: post outside the map" % k)
		if unit[1] == Faction.PLAYER and catalog.units.can_capture(type):
			has_worker = true
	if not has_worker:
		errors.append("the player starts without a unit that can capture (unites-drones, open question 1)")


## GDD 2 rule 14: a declared symmetry is verified tile by tile, never assumed.
func _check_symmetry(errors: PackedStringArray) -> void:
	var count := width * height
	for t in count:
		if cells[t] != cells[count - 1 - t]:
			errors.append("terrain is not symmetric at tile %d" % t)
			return
	for node: Array in nodes:
		var partner := -1
		for other: Array in nodes:
			if other[0] == count - 1 - node[0]:
				partner = other[1]
		if partner != node[1]:
			errors.append("node at tile %d has no symmetric partner of the same level" % node[0])
	for dormant: Array in dormants:
		var found := false
		for other: Array in dormants:
			if other[0] == count - 1 - dormant[0] and other[1] == dormant[1]:
				found = true
		if not found:
			errors.append("dormant at tile %d has no symmetric partner" % dormant[0])


## GDD 9 rule 11 and F3: every dormant on the AI's half has at least one armed Guardian
## that can reach it (move + range >= distance). The AI's half: no farther from its start.
func _check_dormant_cover(catalog: DataCatalog, errors: PackedStringArray) -> void:
	for k in dormants.size():
		var t: int = dormants[k][0]
		if _distance(t, start_tile[Faction.AI]) > _distance(t, start_tile[Faction.PLAYER]):
			continue
		var covered := false
		for unit: Array in units:
			var type := catalog.units.type_of_key(unit[0])
			if type >= 0 and unit[1] == Faction.AI and catalog.units.attack(type) > 0 \
					and catalog.units.move(type) + catalog.units.attack_range(type) >= _distance(unit[2], t):
				covered = true
		if not covered:
			errors.append("dormant %d on the AI side is not covered by an armed Guardian (GDD 9 rule 11)" % k)
