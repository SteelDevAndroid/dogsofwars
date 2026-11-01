# owner: src/core/state/ src/core/commands/
# Command journal (GDD 1, GDD 23 rule 14): the state revision, number of the last
# applied command; owned by the command pipeline, kept by restore_from.
class_name CommandLogSlice
extends SliceBase

const COLUMNS := [[&"_cmd_revision", TYPE_PACKED_INT64_ARRAY]]

var _cmd_revision := PackedInt64Array([0])


func columns() -> Array:
	return COLUMNS


func length_error(_tiles: int, _factions: int) -> String:
	return _sized_error(&"_cmd_revision", 1)


func revision() -> int:
	return _cmd_revision[0]
