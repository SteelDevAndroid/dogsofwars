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


func ruin_of(row: int) -> int:
	return _jrn_ruin[row]


func fragment_of(row: int) -> int:
	return _jrn_fragment[row]


func status_of(row: int) -> int:
	return _jrn_status[row]


## True when this match's journal already holds the fragment for the faction.
func has_fragment(faction: int, fragment_id: int) -> bool:
	for row in _jrn_faction.size():
		if _jrn_faction[row] == faction and _jrn_fragment[row] == fragment_id:
			return true
	return false


## Row of the pending entry of a ruin, -1 when none.
func pending_row(ruin_id: int) -> int:
	for row in _jrn_ruin.size():
		if _jrn_ruin[row] == ruin_id and _jrn_status[row] == PENDING:
			return row
	return -1


## Ruins read by the faction in this match (GDD 3 formula 1, F).
func read_by(faction: int) -> int:
	var count := 0
	for row in _jrn_faction.size():
		if _jrn_faction[row] == faction:
			count += 1
	return count


func faction_of(row: int) -> int:
	return _jrn_faction[row]
