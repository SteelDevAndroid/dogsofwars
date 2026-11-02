# Write functions of the AI system (system 9) on its slices.
class_name AiWrites
extends RefCounted


## COMMENCER_LE_TOUR(IA) (ADR-0005 §5): no AI unit has emitted a command yet this turn.
static func reset_cursor(state: GameState) -> void:
	state.ai_cursor._ai_cursor[0] = 0


## ANNONCER_LES_INTENTIONS made this turn: a resumed phase must not announce again.
static func mark_announced(state: GameState) -> void:
	state.ai_cursor._ai_cursor[1] = state.turn()


## GDD 1 formula 4: only the intentions of the current and of the previous turn stay
## (their ids stay consumed).
static func prune_intentions(state: GameState) -> void:
	var keep := PackedInt32Array()
	for row in state.intentions.row_count():
		if state.intentions.announced_turn_of(row) > state.turn() - GameState.INTENT_RETENTION_TURNS:
			keep.append(row)
	if keep.size() != state.intentions.row_count():
		state.intentions.keep_rows(keep)


## Announces an intention: new id, announced this turn, to be executed at the start of
## the next enemy phase, positions of both sides recorded (GDD 1). Returns the id.
static func announce_intention(state: GameState, author_id: int, author_tile: int, target_kind: int,
		target_id: int, target_tile: int, action: int, motive: int) -> int:
	var id := state.allocate_id(HeaderSlice.NEXT_INTENTION_ID)
	var slice := state.intentions
	slice._int_id.append(id)
	slice._int_author.append(author_id)
	slice._int_author_tile.append(author_tile)
	slice._int_target_kind.append(target_kind)
	slice._int_target_id.append(target_id)
	slice._int_target_tile.append(target_tile)
	slice._int_action.append(action)
	slice._int_motive.append(motive)
	slice._int_announced_turn.append(state.turn())
	slice._int_exec_turn.append(state.turn() + 1)
	slice._int_status.append(IntentionsSlice.STATUS_ANNOUNCED)
	slice._int_cancel_reason.append(IntentionsSlice.REASON_NONE)
	return id


## Replaces the tracks (GDD 9 rule 9) by `rows` of [unit, tile, seen_turn, kind], already
## ordered by unit id and capped.
static func set_tracks(state: GameState, rows: Array) -> void:
	var tracks := state.ai_tracks
	tracks._track_unit.clear()
	tracks._track_tile.clear()
	tracks._track_seen_turn.clear()
	tracks._track_kind.clear()
	for row: Array in rows:
		tracks._track_unit.append(row[0])
		tracks._track_tile.append(row[1])
		tracks._track_seen_turn.append(row[2])
		tracks._track_kind.append(row[3])


## Closes an intention: executed, or cancelled with its reason (GDD 9 rule 4).
static func settle_intention(state: GameState, intention_id: int, status: int, reason: int) -> void:
	var row := state.intentions.find_row(intention_id)
	state.intentions._int_status[row] = status
	state.intentions._int_cancel_reason[row] = reason


## Writes the new role data of an AI unit, keeping the rows sorted by unit id.
static func set_agent(state: GameState, unit_id: int, role: int, idle_turns: int, post_tile: int, motive: int) -> void:
	var agents := state.ai_agents
	var row := agents._agent_unit.bsearch(unit_id)
	if row >= agents._agent_unit.size() or agents._agent_unit[row] != unit_id:
		agents._agent_unit.insert(row, unit_id)
		agents._agent_role_state.insert(row, role)
		agents._agent_idle_turns.insert(row, idle_turns)
		agents._agent_post_tile.insert(row, post_tile)
		agents._agent_motive.insert(row, motive)
		return
	agents._agent_role_state[row] = role
	agents._agent_idle_turns[row] = idle_turns
	agents._agent_post_tile[row] = post_tile
	agents._agent_motive[row] = motive


## Siege count of the last node (GDD 9 rule 13): node -1 and count 0 when none.
static func set_siege(state: GameState, node_id: int, count: int) -> void:
	state.siege._siege[SiegeSlice.NODE] = node_id
	state.siege._siege[SiegeSlice.COUNT] = count


## curseur_ia (ADR-0005 §5): id of the last AI unit that emitted an ordinary
## command; called by the command layer after the application, never by a handler.
static func set_cursor(state: GameState, unit_id: int) -> void:
	state.ai_cursor._ai_cursor[0] = unit_id
