# The presentation tree of one match (ADR-0008 §4), built in two phases: instantiated
# without bindings (it lends its adapters: the pacing gate, the runner port), then bound to
# the session once SessionFactory has built it. It carries the AI runner (process priority
# 20, the only Node of the Core), the world, the input surface and the HUD layer; the
# sequencer, the tile renderer and the HUD fill them in later stories.
class_name MatchScreen
extends Node

@onready var ai_runner: AiRunner = $AiRunner
@onready var world: Node2D = $World
@onready var hud_layer: CanvasLayer = $HudLayer
@onready var input_surface: Control = $InputSurface

var session: GameSession
var _runner_port: NodeAiRunnerPort
var _pacing: PacingGate = ImmediatePacingGate.new()


## Phase 1: what the session needs from the presentation.
func ports(event_sink: EventSink) -> SessionPorts:
	return SessionPorts.new(event_sink, _pacing)


func runner_port() -> AiRunnerPort:
	if _runner_port == null:
		_runner_port = NodeAiRunnerPort.new(ai_runner)
	return _runner_port


## Phase 3: the session is built; start the match (new game) or its stored phase (load).
func bind(p_session: GameSession) -> void:
	session = p_session
	ai_runner.process_priority = 20
	session.turns.start()


## The player ends their turn (the end-turn button of the HUD).
func end_turn() -> ValidationResult:
	return session.turns.end_player_turn() if session != null else ValidationResult.refused(Refusal.MATCH_OVER)


## End or abandon, in this order (ADR-0008 §6): cancel the runner, stop the nodes and
## release the gate, break the session's cycles, then free. The session is only dropped by
## the caller once `tree_exited` fires.
func shutdown() -> void:
	if session == null:
		return
	if _runner_port != null:
		_runner_port.cancel()
	set_process(false)
	ai_runner.set_process(false)
	session.gate.clear_player_locks()
	session.shutdown()
	session = null
	_runner_port = null
	queue_free()
