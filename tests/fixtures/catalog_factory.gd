# Data catalogs for tests (ADR-0011 §4): the standard documents below hold the GDD
# values (GDD 2, 5, 6, 9, 10, 11 and 12), loaded through MemoryDataSource; tests derive broken
# variants from documents().
class_name CatalogFactory
extends RefCounted

## Pack types with view 2 (GDD 12: Veille élargie, Cadence de marche).
const LOURDS := ["assaut", "rempart", "ouvrier"]

static var _standard: DataCatalog


## The standard catalog, loaded once (it is immutable).
static func standard() -> DataCatalog:
	if _standard == null:
		var result := load_documents(documents())
		assert(result.ok, "the standard test catalog must load")
		_standard = result.catalog
	return _standard


static func load_documents(docs: Dictionary) -> DataCatalogResult:
	var files := {}
	for name: String in docs:
		files[name] = docs[name] if docs[name] is String else JSON.stringify(docs[name])
	return DataCatalog.load_all(MemoryDataSource.new(files))


## File name -> document; a fresh copy on every call.
static func documents() -> Dictionary:
	return {
		"units.json": {"schema_version": 1, "types": [
			_unit(0, "eclaireur", "meute", 6, 1, 0, 4, 4),
			_unit(1, "assaut", "meute", 8, 3, 1, 3, 2),
			_unit(2, "rempart", "meute", 14, 1, 2, 2, 2),
			_unit(3, "ouvrier", "meute", 7, 1, 0, 3, 2),
			_unit(4, "sentinelle", "gardiens", 10, 0, 2, 0, 3),
			_unit(5, "chasseur", "gardiens", 8, 3, 0, 3, 3),
			_unit(6, "bastion", "gardiens", 14, 2, 2, 1, 2),
		]},
		"brouillard.json": {"schema_version": 1, "node_view_min": 2, "mountain_view_bonus": 1},
		"noeuds.json": {"schema_version": 1, "territory_radius": [1, 2, 3]},
		"terrain.json": {"schema_version": 1, "entry_cost": [1, 2, 3, 0]},
		"energie.json": {"schema_version": 1, "max": 99, "start": 6, "income_by_level": [3, 4, 5]},
		"protocoles.json": {"schema_version": 1, "protocols": [
			_protocol(0, "veille_elargie", "reseau", 1, 15, 2, "vision", 1, LOURDS),
			_protocol(1, "reveil_sobre", "reseau", 2, 20, 2, "wake_price", -1, []),
			_protocol(2, "cadence_de_marche", "reseau", 3, 30, 3, "move", 1, LOURDS),
			_protocol(3, "repos_reglementaire", "meute", 1, 15, 2, "rest_heal", 1, []),
			_protocol(4, "blindage_appoint", "meute", 2, 25, 2, "defense", 1, []),
			_protocol(5, "rempart_arme", "meute", 3, 35, 3, "attack", 1, ["rempart"]),
		]},
		"ai.json": {"schema_version": 1, "protocol_calendar": [
			{"turn": 12, "protocol": 4}, {"turn": 18, "protocol": 5}]},
	}


static func _protocol(id: int, key: String, branch: String, level: int, price: int, duration: int,
		stat: String, delta: int, types: Array) -> Dictionary:
	return {"id": id, "key": key, "branch": branch, "level": level, "price": price, "duration": duration,
		"effects": [{"stat": stat, "delta": delta, "types": types}]}


static func _unit(id: int, key: String, side: String, hp: int, attack: int, defense: int,
		move: int, vision: int) -> Dictionary:
	return {"id": id, "key": key, "side": side, "hp": hp, "attack": attack, "defense": defense,
		"move": move, "range": 1, "vision": vision}
