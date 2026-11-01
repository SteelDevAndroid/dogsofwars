# owner: src/core/state/ src/core/ruins/
# Ruin reading journal (GDD 1 rule 10): ruin, faction, stable fragment id, status.
class_name RuinJournalSlice
extends SliceBase

const PENDING := 0
const VALIDATED := 1

const COLUMNS := [
	[&"_jrn_ruin", TYPE_PACKED_INT32_ARRAY],
	[&"_jrn_faction", TYPE_PACKED_BYTE_ARRAY],
	[&"_jrn_fragment", TYPE_PACKED_INT32_ARRAY],
	[&"_jrn_status", TYPE_PACKED_BYTE_ARRAY],
]

var _jrn_ruin := PackedInt32Array()
var _jrn_faction := PackedByteArray()
var _jrn_fragment := PackedInt32Array()
var _jrn_status := PackedByteArray()


func columns() -> Array:
	return COLUMNS


func length_error(_tiles: int, _factions: int) -> String:
	return _parallel_error()


func faction_of(row: int) -> int:
	return _jrn_faction[row]
