# Write functions of the ruins system (system 13) on the Ruins slice and the ruin
# journal; the chronicle snapshot is written at the match creation only.
class_name RuinWrites
extends RefCounted


## GDD 13 rule 14 b: the ruin is read, from this turn on, by this faction.
static func mark_read(state: GameState, ruin_row: int, reader: int) -> void:
	state.ruins._ruin_read[ruin_row] = 1
	state.ruins._ruin_read_turn[ruin_row] = state.turn()
	state.ruins._ruin_reader[ruin_row] = reader


## GDD 13 rule 14 d: a journal entry, pending while a fragment still has to reach the
## profile, validated at once when the pool was exhausted (fragment 0).
static func journal_add(state: GameState, ruin_id: int, faction: int, fragment_id: int) -> void:
	var journal := state.ruin_journal
	journal._jrn_ruin.append(ruin_id)
	journal._jrn_faction.append(faction)
	journal._jrn_fragment.append(fragment_id)
	journal._jrn_status.append(RuinJournalSlice.PENDING if fragment_id > 0 else RuinJournalSlice.VALIDATED)


## VALIDER_LA_LECTURE: the profile write succeeded.
static func journal_validate(state: GameState, row: int) -> void:
	state.ruin_journal._jrn_status[row] = RuinJournalSlice.VALIDATED
