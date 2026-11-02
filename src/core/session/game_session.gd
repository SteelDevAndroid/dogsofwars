# The objects of one match (ADR-0008 §2): the state, the rules and the pipeline with its
# gate, undo slot, log and ports, and the turn system. Plain objects, no Node. Built by
# SessionFactory only; `shutdown` breaks every reference cycle (ADR-0008 §6).
class_name GameSession
extends RefCounted

var state: GameState
var catalog: DataCatalog
var rules: RuleTable
var gate: CommandGate
var undo: UndoSlot
var log: CommandLog
var pipeline: CommandPipeline
var post_commit: PostCommitPort
var profile: ProfilePort
var events: EventSink
var pacing: PacingGate
var turns: TurnSystem


func is_over() -> bool:
	return state != null and state.header.value(HeaderSlice.PHASE) == HeaderSlice.PHASE_FINISHED


func shutdown() -> void:
	if turns != null:
		turns.shutdown()
	turns = null
	pipeline = null
	post_commit = null
	profile = null
	events = null
	pacing = null
	gate = null
	state = null
