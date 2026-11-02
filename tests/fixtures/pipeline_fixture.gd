# A real CommandPipeline over a test state with recording doubles (ADR-0011 §4):
# the pipeline part of what SessionFactory will assemble (ADR-0008 §3).
class_name PipelineFixture
extends RefCounted

var state: GameState
var rules: RuleTable
var gate := CommandGate.new()
var undo := UndoSlot.new()
var log: CommandLog
var sink := RecordingSink.new()
var post_commit: RecordingPostCommitPort
var profile := RecordingProfilePort.new()
var pipeline: CommandPipeline


## `state` put in the player's phase by the setup (no command) unless its phase is
## already set or `created` asks to keep the CRÉÉE state.
func _init(p_state: GameState, created: bool = false) -> void:
	state = p_state
	if not created and state.header.value(HeaderSlice.PHASE) == HeaderSlice.PHASE_CREATED:
		GameStateSetup.set_phase(state, HeaderSlice.PHASE_PLAYER, Faction.PLAYER)
	var catalog := CatalogFactory.standard()
	rules = RuleTable.standard(catalog, VisionContext.for_map(catalog, state))
	log = CommandLog.new(catalog.content_hash)
	post_commit = RecordingPostCommitPort.new(sink)
	pipeline = CommandPipeline.new(state, rules, gate, undo, log, post_commit, profile, sink)


func move(unit_id: int, tile: int, faction: int = Faction.PLAYER) -> ValidationResult:
	var emitter := Command.EMITTER_PLAYER if faction == Faction.PLAYER else Command.EMITTER_AI
	return pipeline.submit(MoveCommand.new(faction, emitter, unit_id, tile))


func research(protocol: int, faction: int = Faction.PLAYER) -> ValidationResult:
	var emitter := Command.EMITTER_PLAYER if faction == Faction.PLAYER else Command.EMITTER_AI
	return pipeline.submit(ResearchCommand.new(faction, emitter, protocol))


func begin_turn(faction: int) -> ValidationResult:
	return pipeline.submit(BeginTurnCommand.new(faction))


func end_turn() -> ValidationResult:
	return pipeline.submit(EndTurnCommand.new())


func attack(attacker_id: int, target_id: int, faction: int = Faction.PLAYER) -> ValidationResult:
	var emitter := Command.EMITTER_PLAYER if faction == Faction.PLAYER else Command.EMITTER_AI
	return pipeline.submit(AttackCommand.new(faction, emitter, attacker_id, target_id))


func upgrade_node(node_id: int, faction: int = Faction.PLAYER) -> ValidationResult:
	var emitter := Command.EMITTER_PLAYER if faction == Faction.PLAYER else Command.EMITTER_AI
	return pipeline.submit(UpgradeNodeCommand.new(faction, emitter, node_id))


func wake(waker_id: int, target_id: int, faction: int = Faction.PLAYER) -> ValidationResult:
	var emitter := Command.EMITTER_PLAYER if faction == Faction.PLAYER else Command.EMITTER_AI
	return pipeline.submit(WakeCommand.new(faction, emitter, waker_id, target_id))


func capture(unit_id: int, faction: int = Faction.PLAYER) -> ValidationResult:
	var emitter := Command.EMITTER_PLAYER if faction == Faction.PLAYER else Command.EMITTER_AI
	return pipeline.submit(CaptureCommand.new(faction, emitter, unit_id))


func abandon() -> ValidationResult:
	return pipeline.submit(AbandonCommand.new())


func undo_move() -> ValidationResult:
	return pipeline.submit(UndoMoveCommand.new())


func last_events() -> Array[PresentationEvent]:
	return sink.batches[-1].events
