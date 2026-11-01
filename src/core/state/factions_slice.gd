# owner: src/core/state/ src/core/energy/ src/core/protocols/ src/core/turns/
# Per-faction data (GDD 1): energy stock (system 10), research in progress
# (system 12), eliminated flag (system 3). Acquired protocols: ProtocolsSlice.
class_name FactionsSlice
extends SliceBase

const COLUMNS := [
	[&"_fac_energy", TYPE_PACKED_INT32_ARRAY],
	[&"_fac_research_id", TYPE_PACKED_INT32_ARRAY],
	[&"_fac_research_turns", TYPE_PACKED_INT32_ARRAY],
	[&"_fac_eliminated", TYPE_PACKED_BYTE_ARRAY],
]

var _fac_energy := PackedInt32Array()
## Protocol under research, -1 when none.
var _fac_research_id := PackedInt32Array()
var _fac_research_turns := PackedInt32Array()
var _fac_eliminated := PackedByteArray()


func columns() -> Array:
	return COLUMNS


func length_error(_tiles: int, factions: int) -> String:
	for spec: Array in COLUMNS:
		var error := _sized_error(spec[0], factions)
		if not error.is_empty():
			return error
	return ""


func setup(factions: int) -> void:
	_fac_energy.resize(factions)
	_fac_research_id.resize(factions)
	_fac_research_id.fill(-1)
	_fac_research_turns.resize(factions)
	_fac_eliminated.resize(factions)
