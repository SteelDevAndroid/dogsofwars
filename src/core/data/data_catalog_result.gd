# Outcome of DataCatalog.load_all (ADR-0009 §4): the catalog, or every error found.
class_name DataCatalogResult
extends RefCounted

var ok: bool
## null when ok is false.
var catalog: DataCatalog
var errors: Array[DataError] = []


func _init(p_catalog: DataCatalog, p_errors: Array[DataError]) -> void:
	catalog = p_catalog
	errors = p_errors
	ok = p_catalog != null
