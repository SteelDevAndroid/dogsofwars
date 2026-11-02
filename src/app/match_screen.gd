# The presentation tree of one match (ADR-0008 §4), built in two phases: instantiated
# without bindings (it lends its adapters: the event queue, the pacing gate, the runner
# port), then bound to the session once SessionFactory has built it. It carries the AI
# runner (process priority 20, the only Node of the Core), the world with the tile renderer
# (priority 10), the input surface and the HUD layer. The sequencer and its animations are a
# later story: until then the screen drains the event queue each frame and redraws at once.
class_name MatchScreen
extends Node

signal pause_requested

@onready var ai_runner: AiRunner = $AiRunner
@onready var world: Node2D = $World
@onready var hud_layer: CanvasLayer = $HudLayer
@onready var input_surface: InputSurface = $InputSurface

var session: GameSession
var renderer := TileRenderer.new()
var hud := Hud.new()
## The unit of the player being looked at, -1 for none.
var selected_unit := -1
var reachable := PackedInt32Array()

var _runner_port: NodeAiRunnerPort
var _pacing: PacingGate = ImmediatePacingGate.new()
var _queue: EventQueue
var _journal: Array[String] = []


func _ready() -> void:
	world.add_child(renderer)
	hud_layer.add_child(hud)
	hud.end_turn_pressed.connect(end_turn)
	hud.pause_pressed.connect(func() -> void: pause_requested.emit())
	input_surface.tapped.connect(on_tap)


func _process(_delta: float) -> void:
	if session == null or session.state == null:
		return
	var changed := false
	if _queue != null:
		for batch in _queue.drain():
			changed = true
			for event in batch.events:
				_note(event)
	if changed:
		refresh()


## Phase 1: what the session needs from the presentation. The queue is the one given, or ours.
func ports(event_sink: EventSink = null) -> SessionPorts:
	_queue = event_sink as EventQueue if event_sink is EventQueue else EventQueue.new()
	return SessionPorts.new(_queue, _pacing)


func runner_port() -> AiRunnerPort:
	if _runner_port == null:
		_runner_port = NodeAiRunnerPort.new(ai_runner)
	return _runner_port


## Phase 3: the session is built; start the match (new game) or its stored phase (load).
func bind(p_session: GameSession) -> void:
	session = p_session
	ai_runner.process_priority = 20
	session.turns.start()
	refresh()


## Redraws the map and the HUD from the state.
func refresh() -> void:
	if session == null or session.state == null:
		return
	renderer.show_state(session.state, session.catalog)
	renderer.fit(HudModel.map_area(_screen_size()))
	renderer.set_selection(session.state.view().unit_tile(selected_unit) if selected_unit >= 0 else -1, reachable)
	hud.show_model(HudModel.build(session.state, session.catalog,
			session.gate.is_locked(Faction.PLAYER, Command.EMITTER_PLAYER), selected_unit, _journal))


## A tap on the map: on a unit of the player, select it; on a tile it can reach, move it.
func on_tap(position: Vector2) -> void:
	on_tap_tile(renderer.layout.tile_at(position))


func on_tap_tile(tile: int) -> void:
	if session == null or session.state == null or tile < 0:
		return
	if selected_unit >= 0 and reachable.has(tile):
		var moved := selected_unit
		session.pipeline.submit(MoveCommand.new(Faction.PLAYER, Command.EMITTER_PLAYER, moved, tile))
		select_unit(-1)
		return
	var view := FactionView.new(session.state, Faction.PLAYER)
	var unit := view.unit_at(tile)
	select_unit(unit if unit >= 0 and view.unit_faction(unit) == Faction.PLAYER else -1)


func select_unit(unit_id: int) -> void:
	selected_unit = unit_id
	reachable = PackedInt32Array()
	if unit_id >= 0 and session.state.header.value(HeaderSlice.PHASE) == HeaderSlice.PHASE_PLAYER:
		reachable = session.pipeline.check_move_range(FactionView.new(session.state, Faction.PLAYER), Faction.PLAYER, unit_id)
	refresh()


## The player ends their turn (the end-turn button of the HUD).
func end_turn() -> ValidationResult:
	if session == null:
		return ValidationResult.refused(Refusal.MATCH_OVER)
	select_unit(-1)
	return session.turns.end_player_turn()


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
	_queue = null
	queue_free()


func _note(event: PresentationEvent) -> void:
	if event is TurnStartedEvent and (event as TurnStartedEvent).turn_faction == Faction.PLAYER:
		_journal.clear()
		return
	var line := HudModel.journal_line(event)
	if line != "":
		_journal.append(line)
		if _journal.size() > HudModel.JOURNAL_LINES:
			_journal.pop_front()


func _screen_size() -> Vector2:
	return get_viewport().get_visible_rect().size if is_inside_tree() else Vector2(390, 844)
