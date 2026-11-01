# Data catalogs for tests (ADR-0011 §4): the standard documents below hold the GDD
# values (GDD 2, 5, 6 and 11), loaded through MemoryDataSource; tests derive broken
# variants from documents().
class_name CatalogFactory
extends RefCounted

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
	}


static func _unit(id: int, key: String, side: String, hp: int, attack: int, defense: int,
		move: int, vision: int) -> Dictionary:
	return {"id": id, "key": key, "side": side, "hp": hp, "attack": attack, "defense": defense,
		"move": move, "range": 1, "vision": vision}
