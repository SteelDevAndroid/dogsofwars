# owner: src/core/state/ src/core/ruins/
# Chronicle snapshot (GDD 1 rule 10): stable fragment ids already found per
# faction, copied from the profile at match creation and never changed after.
# Rows sorted by (faction, fragment).
class_name ChronicleSlice
extends SliceBase

const COLUMNS := [
	[&"_chron_faction", TYPE_PACKED_BYTE_ARRAY],
	[&"_chron_fragment", TYPE_PACKED_INT32_ARRAY],
]

var _chron_faction := PackedByteArray()
var _chron_fragment := PackedInt32Array()


func columns() -> Array:
	return COLUMNS


func length_error(_tiles: int, _factions: int) -> String:
	return _parallel_error()


## Setup only (GameStateSetup); callers add rows in (faction, fragment) order.
func append(faction: int, fragment_id: int) -> void:
	_chron_faction.append(faction)
	_chron_fragment.append(fragment_id)


func faction_of(row: int) -> int:
	return _chron_faction[row]
