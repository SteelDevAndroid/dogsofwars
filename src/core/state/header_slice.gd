# owner: src/core/state/ src/core/turns/
# Match header (GDD 1): one PackedInt64Array so that 32-bit unsigned values (seed)
# keep their sign (ADR-0003). State fields: ids, epoch, seed, counters (system 1);
# turn, T_MAX, passive AI, phase, active faction, end status (system 3).
class_name HeaderSlice
extends SliceBase

const MATCH_ID := 0
const PROFILE_EPOCH := 1
const SEED := 2
const DRAW_COUNTER := 3
const NEXT_UNIT_ID := 4
const NEXT_NODE_ID := 5
const NEXT_RUIN_ID := 6
const NEXT_INTENTION_ID := 7
const TURN := 8
const T_MAX := 9
const AI_PASSIVE := 10
const PHASE := 11
const ACTIVE_FACTION := 12
const END_STATUS := 13
const WIDTH := 14
const HEIGHT := 15
const FACTION_COUNT := 16
const SIZE := 17

const PHASE_CREATED := 0
const PHASE_PLAYER := 1
const PHASE_ENEMY_EXECUTION := 2
## FIN_DE_TOUR: the player has ended their phase, the enemy phase has not begun.
const PHASE_END_OF_TURN := 3
const PHASE_FINISHED := 4

const COLUMNS := [[&"_header", TYPE_PACKED_INT64_ARRAY]]

var _header := PackedInt64Array()


func _init() -> void:
	_header.resize(SIZE)


func columns() -> Array:
	return COLUMNS


func length_error(_tiles: int, _factions: int) -> String:
	return _sized_error(&"_header", SIZE)


func value(index: int) -> int:
	return _header[index]
