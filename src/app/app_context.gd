# The objects that live as long as the process (ADR-0008 §2): the data catalog, the file
# store, the save store and the profile port. Built in this order; a data error stops
# everything (the error screen shows `errors`).
class_name AppContext
extends RefCounted

var catalog: DataCatalog
var file_store: FileStore
var save_store: SaveStore
var profile_port: ProfilePort
var errors: Array[DataError] = []


## The context, or one with `catalog == null` and the data errors.
static func create(data: DataSource, files: FileStore, profile: ProfilePort, save_dir: String = "user://") -> AppContext:
	var app := AppContext.new()
	var loaded := DataCatalog.load_all(data)
	if loaded.catalog == null:
		app.errors = loaded.errors
		return app
	app.catalog = loaded.catalog
	app.file_store = files
	app.save_store = SaveStore.new(files, app.catalog, save_dir)
	app.profile_port = profile
	return app


func is_ready() -> bool:
	return catalog != null
