# Game data, loaded once at startup and injected (ADR-0009): one JSON file per
# domain, integers only, strict schema, typed read-only objects. A loading error is
# a startup error, never a silent default. No static access: the composition root
# builds it (ADR-0008) and passes it on.
class_name DataCatalog
extends RefCounted


## SHA-256 of the data files (ADR-0009 §7), written in the CommandLog header.
var content_hash: String
var units: UnitTypes
var fog: FogParams
var nodes: NodeParams
var terrain: TerrainParams
var energy: EnergyParams
var protocols: ProtocolTree
var ai: AiParams


## Domain files expected at the data root, with the class that checks (SCHEMA) and
## builds (build) each one. Any other .json at the root is refused.
static func domains() -> Dictionary:
	return {
		"ai.json": AiParams, "brouillard.json": FogParams, "energie.json": EnergyParams, "noeuds.json": NodeParams,
		"protocoles.json": ProtocolTree, "terrain.json": TerrainParams, "units.json": UnitTypes,
	}


static func load_all(source: DataSource) -> DataCatalogResult:
	var errors: Array[DataError] = []
	var known := domains()
	var names := source.list("")
	var files := {}
	for name in names:
		if not name.ends_with(".json"):
			continue
		files[name] = source.read_bytes(name)
		if not known.has(name):
			errors.append(DataError.new(name, "(file)", "unknown data file"))
	var built := {}
	var expected := PackedStringArray(known.keys())
	expected.sort()
	for name in expected:
		if not files.has(name):
			errors.append(DataError.new(name, "(file)", "missing data file"))
			continue
		var parsed: Variant = _parse(name, files[name], errors)
		if parsed == null:
			continue
		var data: Variant = DataSchema.check(parsed, {"kind": &"object", "fields": known[name].SCHEMA}, name, "", errors)
		if data != null:
			built[name] = known[name].build(data, name, errors)
	if errors.is_empty():
		_cross_check(built, errors)
	if not errors.is_empty():
		return DataCatalogResult.new(null, errors)
	var catalog := DataCatalog.new()
	catalog.ai = built["ai.json"]
	catalog.energy = built["energie.json"]
	catalog.protocols = built["protocoles.json"]
	catalog.fog = built["brouillard.json"]
	catalog.nodes = built["noeuds.json"]
	catalog.terrain = built["terrain.json"]
	catalog.units = built["units.json"]
	catalog.content_hash = content_hash_of(files)
	return DataCatalogResult.new(catalog, errors)


## References between domains (ADR-0009 §3).
static func _cross_check(built: Dictionary, errors: Array[DataError]) -> void:
	var energy: EnergyParams = built["energie.json"]
	var nodes: NodeParams = built["noeuds.json"]
	if energy.level_count() != nodes.max_level():
		errors.append(DataError.new("energie.json", "income_by_level",
			"%d levels, noeuds.json has %d" % [energy.level_count(), nodes.max_level()]))
	var tree: ProtocolTree = built["protocoles.json"]
	var units: UnitTypes = built["units.json"]
	for effect in tree.effect_count():
		for key in tree.effect_types(effect):
			if units.type_of_key(key) < 0:
				errors.append(DataError.new("protocoles.json", "protocols[%d].effects" % tree.effect_protocol(effect),
					"unknown unit type %s" % key))
	var calendar := (built["ai.json"] as AiParams).calendar_ids()
	for k in calendar.size():
		if calendar[k] >= tree.count():
			errors.append(DataError.new("ai.json", "protocol_calendar[%d].protocol" % k, "unknown protocol %d" % calendar[k]))


## SHA-256 over, for each file in explicit alphabetical order: its name, "\n", its
## length in bytes (decimal), "\n", its bytes. Name and length make the
## concatenation unambiguous; bytes, never text, so "\r" counts (ADR-0009 §7).
static func content_hash_of(files: Dictionary) -> String:
	var names := PackedStringArray(files.keys())
	names.sort()
	var hashing := HashingContext.new()
	hashing.start(HashingContext.HASH_SHA256)
	for name in names:
		var bytes: PackedByteArray = files[name]
		hashing.update(("%s\n%d\n" % [name, bytes.size()]).to_utf8_buffer())
		hashing.update(bytes)
	return hashing.finish().hex_encode()


## JSON.new().parse, never JSON.parse_string (which prints and returns null).
static func _parse(name: String, bytes: PackedByteArray, errors: Array[DataError]) -> Variant:
	var json := JSON.new()
	if json.parse(bytes.get_string_from_utf8()) != OK:
		var line := json.get_error_line()
		var where := "line %d" % line if line > 0 else "(root)"
		errors.append(DataError.new(name, where, json.get_error_message()))
		return null
	return json.data
