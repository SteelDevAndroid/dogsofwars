# AI runner (ADR-0005 §3): a state machine that submits, one command per call and only
# when the pacing gate says ready, what the planner decides: the stored intentions by
# ascending id, the ordinary moves, then the announcement. It never chooses a command
# and never saves (the post-commit port does). Its position is rebuilt from the state
# alone (the announcement of the turn is the last command), so `start_turn` and `resume` are the same: a stop after command k then a
# resume replays the remaining commands of the run without a stop.
# MVP deviation: planning runs on the calling thread, inside the evaluation budget
# (ADR-0005 §7 puts it on a worker thread; to do with the measured budget on a device).
class_name AiRunner
extends Node

enum Step { IDLE, EXECUTING_INTENTIONS, MOVING, ANNOUNCING, DONE }

## Called once the phase is finished (the turn system then begins the player's turn).
var on_turn_finished: Callable

var step := Step.IDLE
var refusals := 0

var _state: GameState
var _pipeline: CommandPipeline
var _pacing: PacingGate
var _catalog: DataCatalog
var _planner := AiPlanner.new()
var _skipped := PackedInt32Array()


func _process(_delta: float) -> void:
	if step != Step.IDLE and _pacing.is_ready():
		advance()


func start_turn(state: GameState, pipeline: CommandPipeline, pacing: PacingGate, catalog: DataCatalog) -> void:
	_state = state
	_pipeline = pipeline
	_pacing = pacing
	_catalog = catalog
	_skipped = PackedInt32Array()
	refusals = 0
	# A resumed phase whose announcement was already made has nothing left to do.
	step = Step.DONE if state.ai_cursor.announced_turn() == state.turn() else Step.EXECUTING_INTENTIONS


## After a load (ADR-0005 §5): the same entry, the position comes from the state.
func resume(state: GameState, pipeline: CommandPipeline, pacing: PacingGate, catalog: DataCatalog) -> void:
	start_turn(state, pipeline, pacing, catalog)


func cancel() -> void:
	step = Step.IDLE


func is_running() -> bool:
	return step != Step.IDLE


## One step: at most one command submitted.
func advance() -> void:
	if _state.header.value(HeaderSlice.PHASE) != HeaderSlice.PHASE_ENEMY_EXECUTION:
		step = Step.IDLE  # the match ended, or the phase is not the AI's
		return
	match step:
		Step.EXECUTING_INTENTIONS:
			var due := _next_due_intention()
			if due < 0:
				step = Step.MOVING
			elif not _pipeline.submit(ExecuteIntentionCommand.new(due)).permitted:
				step = Step.MOVING  # never refused for a cancellation condition; a refusal is a bug
		Step.MOVING:
			var command := _planner.plan_next(_state.filtered_copy(Faction.AI), _catalog,
					AiBudget.new(_catalog.ai.planner("evals_per_call")), _skipped)
			if command == null:
				step = Step.ANNOUNCING
			elif not _pipeline.submit(command).permitted:
				# Deterministic like everything else: the unit is dropped for this phase.
				refusals += 1
				_skipped.append((command as MoveCommand).unit_id if command is MoveCommand else -1)
				if refusals >= _catalog.ai.planner("refusals_max") or command is UpgradeNodeCommand:
					step = Step.ANNOUNCING
		Step.ANNOUNCING:
			var announcement := _planner.plan_announcement(_state.filtered_copy(Faction.AI), _catalog)
			if announcement != null:
				_pipeline.submit(announcement)
			step = Step.DONE
		Step.DONE:
			step = Step.IDLE
			if on_turn_finished.is_valid():
				on_turn_finished.call()


## Lowest id of an intention announced for this turn and not settled, or -1.
func _next_due_intention() -> int:
	var slice := _state.intentions
	var best := -1
	for row in slice.row_count():
		if slice.status_of(row) == IntentionsSlice.STATUS_ANNOUNCED and slice.exec_turn_of(row) == _state.turn() \
				and (best < 0 or slice.id_of(row) < best):
			best = slice.id_of(row)
	return best
