# Port to the game data files (ADR-0009 §4): real implementation over FileAccess,
# MemoryDataSource in tests. Interface by convention: every method is overridden.
class_name DataSource
extends RefCounted

## OK, or ERR_FILE_NOT_FOUND after a read of a missing path (ADR-0009: "vide + erreur si absent").
var last_error: Error = OK


## File content; empty and `last_error = ERR_FILE_NOT_FOUND` when the path is missing.
## Source of `content_hash` (ADR-0009 §7).
func read_bytes(_path: String) -> PackedByteArray:
	assert(false, "DataSource.read_bytes is not implemented")
	return PackedByteArray()


func read_text(path: String) -> String:
	return read_bytes(path).get_string_from_utf8()


## Names of the files directly in `dir`, sorted (PackedStringArray.sort, ADR-0009 §7).
func list(_dir: String) -> PackedStringArray:
	assert(false, "DataSource.list is not implemented")
	return PackedStringArray()
