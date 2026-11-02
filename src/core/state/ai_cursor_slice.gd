# owner: src/core/state/ src/core/ai/
# curseur_ia (ADR-0005 §5): id of the last AI unit that emitted a command this
# turn, 0 at the start of the enemy phase; and the turn whose announcement was made (-1
# before any), so that a resumed phase does not announce twice. Part of the AI agents
# data, private to the AI.
class_name AiCursorSlice
extends SliceBase

const COLUMNS := [[&"_ai_cursor", TYPE_PACKED_INT32_ARRAY]]

## [cursor, turn of the last announcement].
var _ai_cursor := PackedInt32Array([0, -1])


func columns() -> Array:
	return COLUMNS


## Id of the last AI unit that emitted an ordinary command this turn, 0 at the start.
func cursor() -> int:
	return _ai_cursor[0]


func announced_turn() -> int:
	return _ai_cursor[1]


func private_to() -> int:
	return Faction.AI


func length_error(_tiles: int, _factions: int) -> String:
	return _sized_error(&"_ai_cursor", 2)
