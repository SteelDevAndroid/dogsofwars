# owner: src/core/state/ src/core/vision/
# Fog memory per faction (GDD 5, ADR-0007): faction f, tile t at index f * T + t.
# Current vision is not stored (ViewCache, outside the state).
class_name VisibilitySlice
extends SliceBase

const COLUMNS := [
	[&"_vis_discovered", TYPE_PACKED_BYTE_ARRAY],
	[&"_vis_last_owner_seen", TYPE_PACKED_BYTE_ARRAY],
	[&"_vis_dormant_memo", TYPE_PACKED_BYTE_ARRAY],
]

var _vis_discovered := PackedByteArray()
## "Octet 1": last owner seen by the faction, Faction.NONE when never seen owned.
var _vis_last_owner_seen := PackedByteArray()
var _vis_dormant_memo := PackedByteArray()


func columns() -> Array:
	return COLUMNS


func length_error(tiles: int, factions: int) -> String:
	for spec: Array in COLUMNS:
		var error := _sized_error(spec[0], tiles * factions)
		if not error.is_empty():
			return error
	return ""


func setup(tiles: int, factions: int) -> void:
	_vis_discovered.resize(tiles * factions)
	_vis_last_owner_seen.resize(tiles * factions)
	_vis_last_owner_seen.fill(Faction.NONE)
	_vis_dormant_memo.resize(tiles * factions)
