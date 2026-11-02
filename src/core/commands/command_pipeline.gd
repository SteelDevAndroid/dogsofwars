# The only path that changes the state during a match (ADR-0004, GDD 23).
# submit: refusal prefix (re-entrance, match over, not your turn, player lock),
# validation on the faction's view, application with the real rules, revision + 1,
# undo slot, post-commit (save), profile effects, events filtered by the player's
# fog, one batch pushed, log. Synchronous.
class_name CommandPipeline
extends RefCounted

var _state: GameState
var _rules: RuleTable
var _simulation: RuleTable
## null in replay: no re-entrance from the presentation, no player lock.
var _gate: CommandGate
var _undo: UndoSlot
var _log: CommandLog
var _post_commit: PostCommitPort
var _profile: ProfilePort
var _sink: EventSink
var _submitting := false
var _follow_ups: Array[Command] = []


func _init(state: GameState, rules: RuleTable, gate: CommandGate, undo: UndoSlot, log: CommandLog,
		post_commit: PostCommitPort, profile: ProfilePort, sink: EventSink) -> void:
	_state = state
	_rules = rules
	_simulation = rules.simulation()
	_gate = gate
	_undo = undo
	_log = log
	_post_commit = post_commit
	_profile = profile
	_sink = sink


func submit(command: Command) -> ValidationResult:
	var result := check(command)
	if result.permitted:
		_submitting = true
		_apply(command)
		_submitting = false
		# ADR-0004 §5: once the profile write succeeded, the follow-up command validates the
		# journal entry; a failed write leaves it pending for a retry.
		for follow_up in _follow_ups:
			submit(follow_up)
		_follow_ups.clear()
	return result


## Refusal prefix then validation, without applying (greyed buttons, UNDO_MOVE code).
func check(command: Command) -> ValidationResult:
	var refusal := _prefix(command)
	if refusal != &"":
		return ValidationResult.refused(refusal)
	if command.type() == CommandType.UNDO_MOVE:
		return _validate_undo()
	return _rules.validate(FactionView.new(_state, command.faction), command)


## The command applied on the state seen by its faction (ADR-0004 §6), with the
## simulation rules: no vision recompute, nothing published, nothing written.
func preview(command: Command) -> PreviewResult:
	var preview_result := PreviewResult.new()
	preview_result.base_revision = _state.revision()
	preview_result.validation = check(command)
	if preview_result.validation.permitted and command.type() != CommandType.UNDO_MOVE:
		preview_result.events = _simulation.apply(_state.filtered_copy(command.faction), command).events
	return preview_result


## Chains a command on a copy owned by the caller (AI planning): validation on the
## copy's faction view, simulation rules, the copy's own revision; effects dropped.
func apply_on(copy: GameState, command: Command) -> ValidationResult:
	var result := _simulation.validate(FactionView.new(copy, command.faction), command)
	if result.permitted:
		_simulation.apply(copy, command)
		copy.command_log._cmd_revision[0] += 1
	return result


func check_move_range(view: StateView, faction: int, unit_id: int) -> PackedInt32Array:
	return _rules.check_move_range(view, faction, unit_id)


## After a load (ADR-0004 §8): nothing to undo.
func on_state_loaded() -> void:
	_undo.disarm(Refusal.NOTHING_TO_UNDO)


func _prefix(command: Command) -> StringName:
	if _submitting or (_gate != null and _gate.is_dispatching()):
		return Refusal.COMMANDS_LOCKED
	if _state.header.value(HeaderSlice.PHASE) == HeaderSlice.PHASE_FINISHED:
		return Refusal.MATCH_OVER
	var checks_turn := command.emitter != Command.EMITTER_SYS and command.type() != CommandType.ABANDON
	if checks_turn and not _is_turn_of(command.faction):
		return Refusal.NOT_YOUR_TURN
	if _gate != null and _gate.is_locked(command.faction, command.emitter):
		return Refusal.COMMANDS_LOCKED
	return &""


func _is_turn_of(faction: int) -> bool:
	var phase := HeaderSlice.PHASE_PLAYER if faction == Faction.PLAYER else HeaderSlice.PHASE_ENEMY_EXECUTION
	return _state.header.value(HeaderSlice.ACTIVE_FACTION) == faction and _state.header.value(HeaderSlice.PHASE) == phase


## Any other applied command disarms the slot (AUTRE_ACTION_DEPUIS), so an armed
## slot always holds revision = snapshot + 1 (GDD 23 rule 15).
func _validate_undo() -> ValidationResult:
	if not _undo.is_armed():
		return ValidationResult.refused(_undo.reason)
	return ValidationResult.ok()


func _apply(command: Command) -> void:
	var before := _state.view_cache.duplicate()
	var player_move := command.type() == CommandType.MOVE and command.emitter == Command.EMITTER_PLAYER
	var snapshot := _state.duplicate_state() if player_move else null
	var result := _apply_undo() if command.type() == CommandType.UNDO_MOVE else _rules.apply(_state, command)
	_state.command_log._cmd_revision[0] += 1
	if command.emitter == Command.EMITTER_AI and command is MoveCommand:
		AiWrites.set_cursor(_state, (command as MoveCommand).unit_id)
	if player_move and not (result.revealed or result.ruin_read):
		_undo.arm(snapshot, (command as MoveCommand).unit_id)
	elif player_move:
		_undo.disarm(Refusal.MOVE_REVEALED)
	elif command.type() == CommandType.UNDO_MOVE:
		_undo.disarm(Refusal.NOTHING_TO_UNDO)
	elif command.type() == CommandType.VALIDATE_RUIN_READ:
		pass  # a follow-up of the reading: the move already disarmed the slot with its own reason
	else:
		_undo.disarm(Refusal.OTHER_ACTION_SINCE)
	_post_commit.on_commit(_state, command, result)
	for effect in result.profile_effects:
		if _profile.apply(effect) and effect is RecordFragmentEffect and (effect as RecordFragmentEffect).ruin_id >= 0:
			_follow_ups.append(ValidateRuinReadCommand.new((effect as RecordFragmentEffect).faction, (effect as RecordFragmentEffect).ruin_id))
	_sink.push(EventBatch.new(_state.revision(), _player_events(result.events, before)))
	_log.append(command)


## restore_from keeps the command journal: revision = snapshot + 2 after the +1.
func _apply_undo() -> ApplyResult:
	var result := ApplyResult.new()
	var unit_id := _undo.unit_id
	var from_tile := _state.view().unit_tile(unit_id)
	_state.restore_from(_undo.snapshot)
	result.events.append(MoveUndoneEvent.new(unit_id, from_tile, _state.view().unit_tile(unit_id)))
	return result


## Events the player may see (GDD 5 rule 20), numbered (revision, index).
func _player_events(events: Array[PresentationEvent], before: ViewCache) -> Array[PresentationEvent]:
	var kept: Array[PresentationEvent] = []
	for event in events:
		if VisionService.event_visible(before, _state.view_cache, Faction.PLAYER, event):
			event.event_id = Vector2i(_state.revision(), kept.size())
			kept.append(event)
	return kept
