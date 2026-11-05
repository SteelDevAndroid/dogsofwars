# The presentation tree of one match (ADR-0008 §4), built in two phases: instantiated
# without bindings (it lends its adapters: the event queue, the pacing gate, the runner
# port), then bound to the session once SessionFactory has built it. It carries the AI
# runner (process priority 20, the only Node of the Core), the world with the tile renderer
# (the model of the map; MapView3D shows it in 3D, ADR-0014)
# (priority 10), the input surface and the HUD layer. The sequencer and its animations are a
# later story: until then the screen drains the event queue each frame and redraws at once.
class_name MatchScreen
extends Node

signal pause_requested
## The player cycled the enemy-turn speed with the HUD button (0 normal, 1 fast, 2 instant).
signal speed_changed(speed: int)

@onready var ai_runner: AiRunner = $AiRunner
@onready var world: Node2D = $World
@onready var hud_layer: CanvasLayer = $HudLayer
@onready var input_surface: InputSurface = $InputSurface

var session: GameSession
var renderer := TileRenderer.new()
## The map shown in 3D (ADR-0014): it reads `renderer`, which keeps the snapshot and the effects
## and no longer draws. False shows the 2D drawing (tests of the drawing, a fallback).
var map3d := MapView3D.new()
var use_3d := true
## One line per turn in the log on the device (D2: Pixel 8, Android 15+).
var probe := PerfProbe.new()
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
## What a chosen target will do, in words: the attack preview or the wake price.
var preview_text := ""
## What the targeting is for: "attack" or "wake".
var target_action := &"attack"
## The node selected by a tap on an owned node of the player's (-1 for none).
var selected_node := -1
## A tile tapped with nothing of the player's on it: its sheet shows in the panel (-1 for none).
var inspected_tile := -1
## "Fin du tour" pressed once while units of the player have not played: the next press ends it.
var end_turn_armed := false
var research_open := false
var camera: MapCamera
var layout: HudLayout
## The usable part of the screen: empty (the default) means ask the display, tests set it.
var safe_area_override := Rect2()
## The size of the screen when it is not the window's (tests): empty means the window's.
var screen_size_override := Vector2.ZERO
## Whether the move range of the selected unit is drawn (setting "Portée de déplacement").
var show_range := true
## Landscape with the rail and the context panel swapped (setting "Panneau à gauche").
var mirrored := false
## Whether the short advice of the first turns shows (setting "Conseils des premiers tours").
var hints := true

var clock := PresentationClock.new()
var sequencer := PresentationSequencer.new()
var presenter: HudPresenter

var _gestures := GestureInterpreter.new()
var _needs := Vector2.ZERO
var _runner_port: NodeAiRunnerPort
var _pulsed_unit := -1
## The sound effects, set by the app (null in a bare screen: silent).
var sounds: SoundBank
## The vibrations, set by the app (null in a bare screen: none).
var haptics: Haptics
var _pacing: PacingGate

const SCORE_HELP_SECONDS := 4.0
const END_TURN_ASK_SECONDS := 3.0
var _queue: EventQueue


func _ready() -> void:
	add_child(clock)  # before everyone (priority -20)
	add_child(sequencer)
	world.add_child(renderer)
	var source := ClockAdapter.new(clock)
	renderer.clock = source
	add_child(map3d)
	map3d.renderer = renderer
	set_3d(use_3d)
	hud_layer.add_child(hud)
	hud.end_turn_pressed.connect(request_end_turn)
	hud.pause_pressed.connect(func() -> void: pause_requested.emit())
	hud.speed_pressed.connect(cycle_speed)
	hud.zoom_in_pressed.connect(func() -> void: zoom_by(1.25))
	hud.zoom_out_pressed.connect(func() -> void: zoom_by(0.8))
	hud.recenter_pressed.connect(recenter)
	hud.fragment_panel.closed.connect(_on_panel_closed)
	hud.attack_pressed.connect(begin_targeting)
	hud.confirm_pressed.connect(confirm_attack)
	hud.cancel_pressed.connect(cancel_targeting)
	hud.action_pressed.connect(do_action)
	hud.research_pressed.connect(toggle_research)
	hud.research_closed.connect(toggle_research)
	hud.research_row_pressed.connect(do_action)
	hud.undo_pressed.connect(undo_move)
	hud.chip_pressed.connect(focus_tile)
	hud.toast_pressed.connect(func() -> void: focus_tile(hud.toast_tile()))
	hud.score_pressed.connect(func() -> void: hud.show_toast(HudModel.SCORE_HELP, clock.current(), SCORE_HELP_SECONDS))
	hud.stats_pressed.connect(func() -> void: hud.show_toast(HudModel.STATS_HELP, clock.current(), SCORE_HELP_SECONDS))
	input_surface.pointer.connect(_on_pointer)
	_pacing = SequencerPacingGate.new(sequencer)
	sequencer.clock = source
	sequencer.batch_started.connect(func() -> void: refresh())  # buttons go dead at once
	sequencer.batch_finished.connect(func() -> void: refresh(true))
	sequencer.idle_reached.connect(func() -> void: refresh(true))


func _process(delta: float) -> void:
	hud.fragment_panel.tick(clock.current())
	if session != null and session.state != null:
		var save := session.post_commit as SaveCoordinator
		probe.frame(delta * 1000.0, session.state.turn(), save.last_write_usec if save != null else 0, ai_runner.last_advance_usec)
	if use_3d and session != null:
		map3d.sync(_screen_size())
	hud.tick_toast(clock.current())
	if camera != null:
		if hud.measure() != _needs:  # a container updates its minimum size a frame late
			relayout()
		camera.tick(clock.current())
		if camera.dirty:
			_apply_camera()


## The enemy turn's speed: normal, fast, instant (hud.md section 8).
func cycle_speed() -> void:
	set_speed((clock.speed + 1) % PresentationClock.Speed.size())
	speed_changed.emit(clock.speed)


func set_speed(speed: int) -> void:
	clock.speed = speed
	hud.speed_button.text = ["Vitesse : normale", "Vitesse : rapide", "Vitesse : instantanée"][clock.speed]


## The settings that live in the match (GameSettings keys); the text scale is the window's.
func apply_settings(settings: Dictionary) -> void:
	sequencer.reduced_motion = settings[GameSettings.REDUCED_MOTION] == 1
	set_speed(settings[GameSettings.ENEMY_SPEED])
	renderer.colorblind = settings[GameSettings.COLORBLIND] == 1
	hud.set_colorblind(renderer.colorblind)
	renderer.still = sequencer.reduced_motion
	show_range = settings[GameSettings.SHOW_RANGE] == 1
	mirrored = settings[GameSettings.LEFT_PANEL] == 1
	hints = settings[GameSettings.HINTS] == 1
	relayout()
	refresh()
	renderer.queue_redraw()


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
	presenter = HudPresenter.new(hud, session.gate, sequencer, session.catalog.presentation, session.catalog.fragments)
	var types := {}
	for type in session.catalog.units.count():
		types[type] = [session.catalog.units.key(type), session.catalog.units.side(type) != session.catalog.units.side(0)]
	map3d.set_unit_types(types)
	probe.header(RenderingServer.get_video_adapter_name(), RenderingServer.get_current_rendering_method(), OS.get_model_name())
	camera = MapCamera.new(session.state.view().width(), session.state.view().height(), Rect2(Vector2.ZERO, _screen_size()))
	map3d.map_camera = camera
	camera.depth_scale = MapView3D.depth_scale() if use_3d else 1.0
	relayout()
	get_viewport().size_changed.connect(relayout)
	sequencer.handlers = [CameraHandler.new(camera, session.catalog.presentation),
			TileRendererHandler.new(renderer, session.catalog.presentation), presenter]
	if sounds != null or haptics != null:
		sequencer.handlers.append(SoundHandler.new(sounds, haptics))
	session.turns.start()
	refresh()  # the HUD has its content, so its real heights are known
	_center_on_first_unit()
	_apply_camera()


## Redraws the map and the HUD from the state. While a batch is playing the map keeps showing
## the state before it (the effects play over it): the new snapshot comes when the batch ends.
func refresh(show_new_state: bool = false) -> void:
	if session == null or session.state == null:
		return
	if show_new_state or renderer.snapshot == null or sequencer.is_idle():
		renderer.show_state(session.state, session.catalog)
	renderer.set_selection(session.state.view().unit_tile(selected_unit) if selected_unit >= 0 else inspected_tile, reachable if show_range else PackedInt32Array())
	var advice := HudHint.text(session.state, hints, session.state.header.value(HeaderSlice.PHASE) == HeaderSlice.PHASE_PLAYER \
			and not session.gate.is_locked(Faction.PLAYER, Command.EMITTER_PLAYER) and sequencer.is_idle(), selected_unit, false)
	renderer.hint_tile = _first_unit_tile() if advice != "" and selected_unit < 0 else -1
	renderer.set_targets(target_tiles, session.state.view().unit_tile(target_unit) if target_unit >= 0 else -1)
	hud.show_model(HudModel.build(session.state, session.catalog,
			session.gate.is_locked(Faction.PLAYER, Command.EMITTER_PLAYER) or not sequencer.is_idle(), selected_unit, presenter.journal,
			_hud_actions()), presenter.notice,
			HudHint.text(session.state, hints, session.state.header.value(HeaderSlice.PHASE) == HeaderSlice.PHASE_PLAYER \
					and not session.gate.is_locked(Faction.PLAYER, Command.EMITTER_PLAYER) and sequencer.is_idle(),
					selected_unit, mode == Mode.TARGETING or mode == Mode.CONFIRMING))
	relayout()  # the bars may have grown or shrunk with what they now show


## A tap on the map: on a unit of the player, select it; on a tile it can reach, move it;
## while choosing a target, on a unit it can strike, show the preview, then strike.
## During an animation a tap on the map ends it at once (skip_animation), nothing is selected.
func on_tap(position: Vector2) -> void:
	if session != null and not sequencer.is_idle():
		skip_animation()
		return
	on_tap_tile(tile_under(position))


## The 3D map, or the 2D drawing (`on`: false).
func set_3d(on: bool) -> void:
	use_3d = on
	if camera != null:
		camera.depth_scale = MapView3D.depth_scale() if on else 1.0
		camera.set_area(camera.area)  # clamp again with the new depth
	renderer.draw_enabled = not on
	map3d.visible = on
	renderer.queue_redraw()


## The tile under a point of the screen, in the map shown.
func tile_under(position: Vector2) -> int:
	if use_3d and map3d.snapshot != null:
		return map3d.tile_at(position)
	return camera.screen_to_tile(position) if camera != null else renderer.layout.tile_at(position)


## Where a tile shows on the screen, in the map shown (the inverse of tile_under).
func screen_of_tile(tile: int) -> Vector2:
	if use_3d and map3d.snapshot != null:
		return map3d.screen_of(tile)
	return camera.tile_to_screen(tile)


## The batch being shown finishes at once: its effects are dropped and the sequencer plays its
## remaining steps with no wait (PresentationSequencer.finish_batch). The game state is already final.
func skip_animation() -> void:
	renderer.clear_effects()
	sequencer.finish_batch()


## "Annuler le déplacement": the player's last move is taken back, if the pipeline allows it.
func undo_move() -> void:
	if session == null or not sequencer.is_idle() or session.gate.is_locked(Faction.PLAYER, Command.EMITTER_PLAYER):
		return
	select_unit(-1)
	_submit(UndoMoveCommand.new(Faction.PLAYER, Command.EMITTER_PLAYER))


## A chip or the enemy-turn summary was tapped: the camera goes to the tile it speaks of.
func focus_tile(tile: int) -> void:
	if session == null or camera == null or tile < 0:
		return
	camera.start_recenter(tile, clock.current(), 0.0 if sequencer.reduced_motion else session.catalog.presentation.value("recenter_ms") / 1000.0)


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
	end_turn_armed = false
	if selected_unit >= 0 and reachable.has(tile):
		var moved := selected_unit
		_submit(MoveCommand.new(Faction.PLAYER, Command.EMITTER_PLAYER, moved, tile))
		select_unit(-1)
		return
	var view := FactionView.new(session.state, Faction.PLAYER)
	var unit := view.unit_at(tile)
	if unit >= 0 and view.unit_faction(unit) == Faction.PLAYER:
		select_unit(unit)
		return
	var was_inspected := inspected_tile
	select_unit(-1)
	var node := view.node_at(tile)
	if node >= 0 and view.node_owner(node) == Faction.PLAYER:
		selected_node = node
		refresh()
		return
	inspected_tile = tile if tile != was_inspected else -1  # a second tap closes the sheet
	refresh()


func select_unit(unit_id: int) -> void:
	selected_unit = unit_id
	selected_node = -1
	inspected_tile = -1
	end_turn_armed = false
	reachable = PackedInt32Array()
	mode = Mode.SELECTED if unit_id >= 0 else Mode.IDLE
	target_tiles = PackedInt32Array()
	target_unit = -1
	preview = null
	preview_text = ""
	target_action = &"attack"
	if unit_id >= 0 and session.state.header.value(HeaderSlice.PHASE) == HeaderSlice.PHASE_PLAYER:
		reachable = session.pipeline.check_move_range(FactionView.new(session.state, Faction.PLAYER), Faction.PLAYER, unit_id)
		if unit_id != _pulsed_unit:
			_sound(&"select")
		if not sequencer.reduced_motion and unit_id != _pulsed_unit:  # a ring on the tile: "this one"
			var pulse := TileEffect.new(TileEffect.Kind.PULSE, clock.current(), 0.25)
			pulse.tile = session.state.view().unit_tile(unit_id)
			renderer.add_effect(pulse)
	_pulsed_unit = unit_id
	refresh()


## A button of the context panel or a row of the research panel (the id says which).
func do_action(id: StringName) -> void:
	if session == null or not sequencer.is_idle() or session.gate.is_locked(Faction.PLAYER, Command.EMITTER_PLAYER):
		return
	var unit := selected_unit
	var node := selected_node
	if id == &"wake":
		begin_targeting(&"wake")
		return
	if id == &"capture" and unit >= 0:
		select_unit(-1)
		_submit(CaptureCommand.new(Faction.PLAYER, Command.EMITTER_PLAYER, unit))
	elif id == &"ability" and unit >= 0:
		_submit(AbilityCommand.new(Faction.PLAYER, Command.EMITTER_PLAYER, unit))
		select_unit(unit)  # the move range may have grown (Sprint)
	elif id == &"upgrade":
		if unit >= 0:
			node = FactionView.new(session.state, Faction.PLAYER).node_at(session.state.view().unit_tile(unit))
		select_unit(-1)
		if node >= 0:
			_submit(UpgradeNodeCommand.new(Faction.PLAYER, Command.EMITTER_PLAYER, node))
	elif String(id).begins_with("research:"):
		research_open = false
		_submit(ResearchCommand.new(Faction.PLAYER, Command.EMITTER_PLAYER, String(id).trim_prefix("research:").to_int()))
		refresh()


## A command of the player: a refusal is told for a moment under the top bar.
func _submit(command: Command) -> ValidationResult:
	return _told(session.pipeline.submit(command))


func _sound(cue: StringName) -> void:
	if sounds != null:
		sounds.play(cue)


func _told(result: ValidationResult) -> ValidationResult:
	if not result.permitted:
		hud.show_toast(RefusalText.of(result), clock.current())
		_sound(&"refusal")
		if haptics != null:
			haptics.pulse(&"refusal")
	return result


func toggle_research() -> void:
	if session == null:
		return
	research_open = not research_open
	refresh()


## "Attaquer" or "Réveiller": the units the selected one may act on are marked, the map waits
## for a choice.
func begin_targeting(action: StringName = &"attack") -> void:
	if session == null or mode != Mode.SELECTED:
		return
	var targets := _attack_targets(selected_unit) if action == &"attack" else ContextActions.wake_targets(session.state, session.pipeline, selected_unit, false)
	if targets.is_empty():
		return
	target_action = action
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
	if target_action == &"attack":
		preview = CombatPreview.of(session.pipeline.preview(AttackCommand.new(Faction.PLAYER, Command.EMITTER_PLAYER, selected_unit, unit_id)),
				selected_unit, unit_id)
		preview_text = preview.text()
	else:
		preview_text = ContextActions.wake_text(session.state, session.catalog, unit_id)
	mode = Mode.CONFIRMING
	refresh()


func confirm_attack() -> void:
	if session == null or mode != Mode.CONFIRMING:
		return
	var actor := selected_unit
	var target := target_unit
	var action := target_action
	select_unit(-1)
	if action == &"attack":
		_submit(AttackCommand.new(Faction.PLAYER, Command.EMITTER_PLAYER, actor, target))
	else:
		_submit(WakeCommand.new(Faction.PLAYER, Command.EMITTER_PLAYER, actor, target))


## Back to the selected unit, nothing struck.
func cancel_targeting() -> void:
	if session == null or (mode != Mode.TARGETING and mode != Mode.CONFIRMING):
		return
	select_unit(selected_unit)


## The end-turn button: with units of the player that have not played, the first press asks
## (a toast and "Confirmer la fin du tour"), the second ends the turn. Any tap on the map in
## between withdraws the question.
func request_end_turn() -> void:
	if session == null or not sequencer.is_idle() or session.gate.is_locked(Faction.PLAYER, Command.EMITTER_PLAYER):
		return
	var idle := HudModel.count_idle_units(FactionView.new(session.state, Faction.PLAYER))
	if idle > 0 and not end_turn_armed and session.state.header.value(HeaderSlice.PHASE) == HeaderSlice.PHASE_PLAYER:
		select_unit(-1)
		end_turn_armed = true
		hud.show_toast(end_turn_question(idle), clock.current(), END_TURN_ASK_SECONDS)
		refresh()
		return
	end_turn()


static func end_turn_question(idle: int) -> String:
	if idle == 1:
		return "1 unité n'a pas joué. Touchez encore pour finir le tour."
	return "%d unités n'ont pas joué. Touchez encore pour finir le tour." % idle


## The player ends their turn (the end-turn button of the HUD, after its question).
func end_turn() -> ValidationResult:
	if session == null:
		return ValidationResult.refused(Refusal.MATCH_OVER)
	select_unit(-1)
	return _told(session.turns.end_player_turn())


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


func _hud_actions() -> Dictionary:
	var extras: Array[ContextAction] = []
	var panel := {}
	if mode == Mode.SELECTED or (mode == Mode.IDLE and selected_node >= 0):
		extras = ContextActions.for_selection(session.state, session.catalog, session.pipeline, selected_unit, selected_node)
		panel = ContextActions.node_panel(session.state, session.catalog, selected_node)
	return {
		"can_attack": mode == Mode.SELECTED and not _attack_targets(selected_unit).is_empty(),
		"targeting": mode == Mode.TARGETING, "preview": preview if mode == Mode.CONFIRMING else null,
		"preview_text": preview_text if mode == Mode.CONFIRMING else "", "extras": extras, "panel": panel,
		"research_open": research_open,
		"research": ContextActions.research_rows(session.state, session.catalog, session.pipeline) if research_open else [],
		"undo": session.pipeline.check(UndoMoveCommand.new(Faction.PLAYER, Command.EMITTER_PLAYER)),
		"inspect": inspected_tile if mode == Mode.IDLE and selected_node < 0 else -1,
		"end_turn_armed": end_turn_armed,
	}


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


## Places the HUD zones and the map for the screen, its safe area and what the bars need.
## Fingers down are cancelled: a rotation or a resize must not turn into a tap (ADR-0010 §1).
func relayout() -> void:
	if camera == null:
		return
	var safe := safe_area_override
	if safe.size.x <= 0.0:
		safe = Rect2(Vector2.ZERO, screen_size_override) if screen_size_override.x > 0.0 else SafeArea.of_window(get_window())
	var needs := hud.measure()
	_needs = needs
	var next := HudLayout.compute(_screen_size(), safe, needs.x, needs.y, mirrored)
	var changed := layout == null or next.map_area != layout.map_area or next.landscape != layout.landscape
	layout = next
	hud.apply_layout(layout)
	if changed:
		camera.set_area(layout.map_area)
		_apply_camera()
		if hud.is_inside_tree():
			input_surface.cancel_all()


func zoom_by(factor: float) -> void:
	camera.zoom(factor, camera.area.get_center())
	_apply_camera()


## The recentre button: on the selected unit, else on the first unit of the player.
func recenter() -> void:
	if selected_unit >= 0:
		camera.start_recenter(session.state.view().unit_tile(selected_unit), clock.current(), session.catalog.presentation.value("recenter_ms") / 1000.0)
	else:
		_center_on_first_unit(true)


func _notification(what: int) -> void:
	if what == NOTIFICATION_APPLICATION_FOCUS_OUT or what == NOTIFICATION_APPLICATION_PAUSED:
		if input_surface != null:
			input_surface.cancel_all()


func _apply_camera() -> void:
	camera.dirty = false
	hud.zoom_in_button.disabled = not camera.can_zoom_in()
	hud.zoom_out_button.disabled = not camera.can_zoom_out()
	renderer.layout = camera.layout()
	renderer.set_clip_rect(camera.area)
	renderer.queue_redraw()
	input_surface.position = camera.area.position
	input_surface.size = camera.area.size


## The first look: on the player's unit with the lowest id (ADR-0010 §8).
## The tile of the player's unit with the lowest id, -1 when it has none.
func _first_unit_tile() -> int:
	var view := FactionView.new(session.state, Faction.PLAYER)
	for id in view.unit_ids():
		if view.unit_faction(id) == Faction.PLAYER:
			return view.unit_tile(id)
	return -1


func _center_on_first_unit(animated: bool = false) -> void:
	var view := FactionView.new(session.state, Faction.PLAYER)
	for id in view.unit_ids():
		if view.unit_faction(id) == Faction.PLAYER:
			camera.start_recenter(view.unit_tile(id), clock.current(), session.catalog.presentation.value("recenter_ms") / 1000.0 if animated else 0.0)
			return


func _on_panel_closed() -> void:
	sequencer.panel_open = false
	session.gate.unlock(PresentationSequencer.FRAGMENT_PANEL)
	refresh()


func _screen_size() -> Vector2:
	if screen_size_override.x > 0.0:
		return screen_size_override
	return get_viewport().get_visible_rect().size if is_inside_tree() else Vector2(390, 844)
