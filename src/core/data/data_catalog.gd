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
var score: ScoreParams
var combat: CombatParams
var wake: WakeParams
var fragments: FragmentPool
var presentation: PresentationParams


## Domain files expected at the data root, with the class that checks (SCHEMA) and
## builds (build) each one. Any other .json at the root is refused.
static func domains() -> Dictionary:
	return {
		"ai.json": AiParams, "brouillard.json": FogParams, "combat.json": CombatParams, "energie.json": EnergyParams,
		"noeuds.json": NodeParams, "reveil.json": WakeParams, "fragments.json": FragmentPool, "presentation.json": PresentationParams,
		"protocoles.json": ProtocolTree, "score.json": ScoreParams, "terrain.json": TerrainParams, "units.json": UnitTypes,
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
	catalog.score = built["score.json"]
	catalog.combat = built["combat.json"]
	catalog.wake = built["reveil.json"]
	catalog.fragments = built["fragments.json"]
	catalog.presentation = built["presentation.json"]
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
	for level in range(1, nodes.max_level()):
		if nodes.upgrade_price(level) > energy.max_stock():
			errors.append(DataError.new("noeuds.json", "upgrade_price[%d]" % (level - 1),
				"%d above the energy cap %d" % [nodes.upgrade_price(level), energy.max_stock()]))
	var units: UnitTypes = built["units.json"]
	_check_wake_prices(built["reveil.json"], units, energy, errors)
	for effect in tree.effect_count():
		for key in tree.effect_types(effect):
			if units.type_of_key(key) < 0:
				errors.append(DataError.new("protocoles.json", "protocols[%d].effects" % tree.effect_protocol(effect),
					"unknown unit type %s" % key))
	var calendar := (built["ai.json"] as AiParams).calendar_ids()
	for k in calendar.size():
		if calendar[k] >= tree.count():
			errors.append(DataError.new("ai.json", "protocol_calendar[%d].protocol" % k, "unknown protocol %d" % calendar[k]))


## GDD 7 rule 1: every pack type has a price, each price fits the energy cap, and
## only pack types are priced (a dormant is a pack type).
static func _check_wake_prices(wake: WakeParams, units: UnitTypes, energy: EnergyParams, errors: Array[DataError]) -> void:
	for k in wake.count():
		var type := units.type_of_key(wake.key_at(k))
		if type < 0:
			errors.append(DataError.new("reveil.json", "prices[%d].type" % k, "unknown unit type %s" % wake.key_at(k)))
		elif units.side(type) != Faction.PLAYER:
			errors.append(DataError.new("reveil.json", "prices[%d].type" % k, "%s is not a pack type" % wake.key_at(k)))
		if wake.price_at(k) > energy.max_stock():
			errors.append(DataError.new("reveil.json", "prices[%d].price" % k,
				"%d above the energy cap %d" % [wake.price_at(k), energy.max_stock()]))
	for type in units.count():
		if units.side(type) == Faction.PLAYER and wake.base_price(units.key(type)) == 0:
			errors.append(DataError.new("reveil.json", "prices", "no price for pack type %s" % units.key(type)))


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
