# owner: src/core/state/ src/core/ai/
# curseur_ia (ADR-0005 §5): id of the last AI unit that emitted a command this
# turn, 0 at the start of the enemy phase. Part of the AI agents data, private to the AI.
class_name AiCursorSlice
extends SliceBase

const COLUMNS := [[&"_ai_cursor", TYPE_PACKED_INT32_ARRAY]]

var _ai_cursor := PackedInt32Array([0])


func columns() -> Array:
	return COLUMNS


func private_to() -> int:
	return Faction.AI


func length_error(_tiles: int, _factions: int) -> String:
	return _sized_error(&"_ai_cursor", 1)
