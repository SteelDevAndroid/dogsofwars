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
## What the next tap means (ADR-0010 §5): nothing selected, a unit selected, choosing a target,
## a target chosen and its preview shown.
enum Mode { IDLE, SELECTED, TARGETING, CONFIRMING }
var mode := Mode.IDLE
var target_tiles := PackedInt32Array()
var target_unit := -1
var preview: CombatPreview
var camera: MapCamera

var clock := PresentationClock.new()
var sequencer := PresentationSequencer.new()
var presenter: HudPresenter

var _gestures := GestureInterpreter.new()
var _runner_port: NodeAiRunnerPort
var _pacing: PacingGate
var _queue: EventQueue


func _ready() -> void:
	add_child(clock)  # before everyone (priority -20)
	add_child(sequencer)
	world.add_child(renderer)
	var source := ClockAdapter.new(clock)
	renderer.clock = source
	hud_layer.add_child(hud)
	hud.end_turn_pressed.connect(end_turn)
	hud.pause_pressed.connect(func() -> void: pause_requested.emit())
	hud.speed_pressed.connect(cycle_speed)
	hud.fragment_panel.closed.connect(_on_panel_closed)
	hud.attack_pressed.connect(begin_targeting)
	hud.confirm_pressed.connect(confirm_attack)
	hud.cancel_pressed.connect(cancel_targeting)
	input_surface.pointer.connect(_on_pointer)
	_pacing = SequencerPacingGate.new(sequencer)
	sequencer.clock = source
	sequencer.batch_started.connect(func() -> void: refresh())  # buttons go dead at once
	sequencer.batch_finished.connect(func() -> void: refresh(true))
	sequencer.idle_reached.connect(func() -> void: refresh(true))


func _process(_delta: float) -> void:
	hud.fragment_panel.tick(clock.current())
	if camera != null:
		camera.tick(clock.current())
		if camera.dirty:
			_apply_camera()


## The enemy turn's speed: normal, fast, instant (hud.md section 8).
func cycle_speed() -> void:
	clock.speed = (clock.speed + 1) % PresentationClock.Speed.size()
	hud.speed_button.text = ["Vitesse : normale", "Vitesse : rapide", "Vitesse : instantanée"][clock.speed]


func is_idle() -> bool:
	return sequencer.is_idle()


## Phase 1: what the session needs from the presentation. The queue is the one given, or ours.
func ports(event_sink: EventSink = null) -> SessionPorts:
	_queue = event_sink as EventQueue if event_sink is EventQueue else EventQueue.new()
	sequencer.queue = _queue
	return SessionPorts.new(_queue, _pacing)


func runner_port() -> AiRunnerPort:
	if _runner_port == null:
		_runner_port = NodeAiRunnerPort.new(ai_runner)
	return _runner_port


## Phase 3: the session is built; start the match (new game) or its stored phase (load).
func bind(p_session: GameSession) -> void:
	session = p_session
	ai_runner.process_priority = 20
	sequencer.gate = session.gate
	sequencer.params = session.catalog.presentation
	sequencer.state = session.state
	presenter = HudPresenter.new(hud, session.gate, sequencer, session.catalog.presentation)
	camera = MapCamera.new(session.state.view().width(), session.state.view().height(), HudModel.map_area(_screen_size()))
	_center_on_first_unit()
	get_viewport().size_changed.connect(func() -> void: camera.set_area(HudModel.map_area(_screen_size())))
	sequencer.handlers = [CameraHandler.new(camera, session.catalog.presentation),
			TileRendererHandler.new(renderer, session.catalog.presentation), presenter]
	_apply_camera()
	session.turns.start()
	refresh()


## Redraws the map and the HUD from the state. While a batch is playing the map keeps showing
## the state before it (the effects play over it): the new snapshot comes when the batch ends.
func refresh(show_new_state: bool = false) -> void:
	if session == null or session.state == null:
		return
	if show_new_state or renderer.snapshot == null or sequencer.is_idle():
		renderer.show_state(session.state, session.catalog)
	renderer.set_selection(session.state.view().unit_tile(selected_unit) if selected_unit >= 0 else -1, reachable)
	renderer.set_targets(target_tiles, session.state.view().unit_tile(target_unit) if target_unit >= 0 else -1)
	hud.show_model(HudModel.build(session.state, session.catalog,
			session.gate.is_locked(Faction.PLAYER, Command.EMITTER_PLAYER) or not sequencer.is_idle(), selected_unit, presenter.journal,
			{"can_attack": mode == Mode.SELECTED and not _attack_targets(selected_unit).is_empty(),
			"targeting": mode == Mode.TARGETING, "preview": preview if mode == Mode.CONFIRMING else null}),
			presenter.notice)


## A tap on the map: on a unit of the player, select it; on a tile it can reach, move it;
## while choosing a target, on a unit it can strike, show the preview, then strike.
func on_tap(position: Vector2) -> void:
	on_tap_tile(camera.screen_to_tile(position) if camera != null else renderer.layout.tile_at(position))


func on_tap_tile(tile: int) -> void:
	if session == null or session.state == null or tile < 0 or not sequencer.is_idle() \
			or session.gate.is_locked(Faction.PLAYER, Command.EMITTER_PLAYER):
		return
	if mode == Mode.TARGETING or mode == Mode.CONFIRMING:
		var target := FactionView.new(session.state, Faction.PLAYER).unit_at(tile)
		if target >= 0 and target_tiles.has(tile):
			if mode == Mode.CONFIRMING and target == target_unit:
				confirm_attack()
			else:
				choose_target(target)
		else:
			cancel_targeting()
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
	mode = Mode.SELECTED if unit_id >= 0 else Mode.IDLE
	target_tiles = PackedInt32Array()
	target_unit = -1
	preview = null
	if unit_id >= 0 and session.state.header.value(HeaderSlice.PHASE) == HeaderSlice.PHASE_PLAYER:
		reachable = session.pipeline.check_move_range(FactionView.new(session.state, Faction.PLAYER), Faction.PLAYER, unit_id)
	refresh()


## "Attaquer": the units the selected one may strike are marked, the map waits for a choice.
func begin_targeting() -> void:
	if session == null or mode != Mode.SELECTED:
		return
	var targets := _attack_targets(selected_unit)
	if targets.is_empty():
		return
	target_tiles = PackedInt32Array()
	var view := FactionView.new(session.state, Faction.PLAYER)
	for id in targets:
		target_tiles.append(view.unit_tile(id))
	reachable = PackedInt32Array()
	mode = Mode.TARGETING
	refresh()


## A target is chosen: the preview of the blow comes from the pipeline, as the real one will.
func choose_target(unit_id: int) -> void:
	target_unit = unit_id
	preview = CombatPreview.of(session.pipeline.preview(AttackCommand.new(Faction.PLAYER, Command.EMITTER_PLAYER, selected_unit, unit_id)),
			selected_unit, unit_id)
	mode = Mode.CONFIRMING
	refresh()


func confirm_attack() -> void:
	if session == null or mode != Mode.CONFIRMING:
		return
	var attacker := selected_unit
	var target := target_unit
	select_unit(-1)
	session.pipeline.submit(AttackCommand.new(Faction.PLAYER, Command.EMITTER_PLAYER, attacker, target))


## Back to the selected unit, nothing struck.
func cancel_targeting() -> void:
	if session == null or (mode != Mode.TARGETING and mode != Mode.CONFIRMING):
		return
	select_unit(selected_unit)


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
	sequencer.set_process(false)
	sequencer.handlers = []
	session.gate.clear_player_locks()
	session.shutdown()
	session = null
	_runner_port = null
	_queue = null
	queue_free()


## The hostile units the player's unit may strike now, the ones the pipeline would accept.
func _attack_targets(unit_id: int) -> Array[int]:
	var targets: Array[int] = []
	if unit_id < 0 or session == null:
		return targets
	var view := FactionView.new(session.state, Faction.PLAYER)
	for id in view.unit_ids():
		if view.unit_faction(id) == Faction.AI \
				and session.pipeline.check(AttackCommand.new(Faction.PLAYER, Command.EMITTER_PLAYER, unit_id, id)).permitted:
			targets.append(id)
	return targets


func _on_pointer(event: PointerEvent) -> void:
	_gestures.tile_size = camera.tile_size if camera != null else 48.0
	for gesture in _gestures.feed(event):
		match gesture.kind:
			Gesture.Kind.TAP:
				on_tap(gesture.position)
			Gesture.Kind.SCROLL:
				camera.scroll(gesture.delta)
			Gesture.Kind.PINCH_UPDATE:
				camera.zoom(gesture.factor, gesture.position)


func _apply_camera() -> void:
	camera.dirty = false
	renderer.layout = camera.layout()
	renderer.set_clip_rect(camera.area)
	renderer.queue_redraw()
	input_surface.position = camera.area.position
	input_surface.size = camera.area.size


## The first look: on the player's unit with the lowest id (ADR-0010 §8).
func _center_on_first_unit() -> void:
	var view := FactionView.new(session.state, Faction.PLAYER)
	for id in view.unit_ids():
		if view.unit_faction(id) == Faction.PLAYER:
			camera.start_recenter(view.unit_tile(id), 0.0, 0.0)
			return


func _on_panel_closed() -> void:
	sequencer.panel_open = false
	session.gate.unlock(PresentationSequencer.FRAGMENT_PANEL)
	refresh()


func _screen_size() -> Vector2:
	return get_viewport().get_visible_rect().size if is_inside_tree() else Vector2(390, 844)
