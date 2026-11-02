# The only constructor of a GameSession (ADR-0008 §3): a new game and a load take the same
# path, only the state and its vision context differ. Assembly order: RuleTable (with the
# VisionContext received: the factory never calls `rebuild`), CommandGate, UndoSlot,
# CommandLog (with the content hash), the SaveCoordinator and the profile port, the
# CommandPipeline, the turn system. The AI runner port arrives with the match screen.
class_name SessionFactory
extends RefCounted


static func build(app: AppContext, state: GameState, vision: VisionContext, ports: SessionPorts, ai: AiRunnerPort) -> GameSession:
	var session := GameSession.new()
	session.state = state
	session.catalog = app.catalog
	session.rules = RuleTable.standard(app.catalog, vision)
	session.gate = CommandGate.new()
	session.undo = UndoSlot.new()
	session.log = CommandLog.new(app.catalog.content_hash)
	session.post_commit = SaveCoordinator.new(app.save_store)
	session.profile = app.profile_port
	session.events = ports.event_sink
	session.pacing = ports.pacing_gate
	session.pipeline = CommandPipeline.new(state, session.rules, session.gate, session.undo, session.log,
			session.post_commit, session.profile, ports.event_sink)
	session.turns = TurnSystem.new(state, session.pipeline, ai, ports.pacing_gate, app.catalog)
	return session


## A new game on a validated map. The chronicle snapshot comes from the profile.
static func new_game(app: AppContext, map: MapDefinition, seed_value: int, ports: SessionPorts, ai: AiRunnerPort,
		ai_passive: bool = false, chronicle: Array = [], match_id: int = 0, profile_epoch: int = 0) -> GameSession:
	var state := GameStateFactory.new_game(app.catalog, map, seed_value, ai_passive, chronicle, match_id, profile_epoch)
	if state == null:
		return null
	app.save_store.delete_match()
	return build(app, state, VisionContext.for_map(app.catalog, state), ports, ai)


## Continue the saved match, or null with the reason in `reason[0]` (a LoadResult code).
static func resume(app: AppContext, ports: SessionPorts, ai: AiRunnerPort, reason: Array) -> GameSession:
	var loaded := app.save_store.load_match(app.profile_port.current_epoch())
	reason[0] = loaded.code
	if loaded.code != LoadResult.OK:
		return null
	var session := build(app, loaded.state, loaded.vision, ports, ai)
	session.pipeline.on_state_loaded()
	return session
