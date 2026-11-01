# owner: src/core/state/ src/core/ai/
# AI tracks (GDD 1, GDD 9 rule 9): at most MAX_TRACKS last sightings of player units.
class_name AiTracksSlice
extends SliceBase

const COLUMNS := [
	[&"_track_unit", TYPE_PACKED_INT32_ARRAY],
	[&"_track_tile", TYPE_PACKED_INT32_ARRAY],
	[&"_track_seen_turn", TYPE_PACKED_INT32_ARRAY],
	[&"_track_kind", TYPE_PACKED_BYTE_ARRAY],
]

var _track_unit := PackedInt32Array()
var _track_tile := PackedInt32Array()
var _track_seen_turn := PackedInt32Array()
var _track_kind := PackedByteArray()


func columns() -> Array:
	return COLUMNS


func length_error(_tiles: int, _factions: int) -> String:
	return _parallel_error()
