extends GdUnitTestSuite


## A handler that records what it is called with and answers fixed holds.
class Recorder extends PresentationHandler:
	var name := ""
	var log: Array = []
	var holds: Dictionary = {}
	var dispatching: Array[bool] = []
	var gate: CommandGate

	func handle(event: PresentationEvent, _context: SequenceContext) -> PresentationHold:
		log.append(name + ":" + event.get_script().get_global_name())
		dispatching.append(gate.is_dispatching())
		return PresentationHold.new(holds.get(event.get_script().get_global_name(), 0))

	func on_batch_end(_state: GameState) -> void:
		log.append(name + ":batch_end")

	func on_idle(_state: GameState) -> void:
		log.append(name + ":idle")

	func rebuild_from_state(_state: GameState) -> void:
		log.append(name + ":rebuild")


var _clock: FakeClock
var _queue: EventQueue
var _gate: CommandGate


func _sequencer(handlers: Array[PresentationHandler]) -> PresentationSequencer:
	_clock = FakeClock.new()
	_queue = EventQueue.new()
	_gate = CommandGate.new()
	var sequencer := PresentationSequencer.new()
	sequencer.queue = _queue
	sequencer.clock = _clock
	sequencer.gate = _gate
	sequencer.params = CatalogFactory.standard().presentation
	sequencer.handlers = handlers
	sequencer.state = StateFactory.minimal()
	return sequencer


func _recorder(name: String, holds: Dictionary = {}) -> Recorder:
	var recorder := Recorder.new()
	recorder.name = name
	recorder.holds = holds
	recorder.gate = _gate if _gate != null else CommandGate.new()
	return recorder


func test_events_play_one_after_the_other_each_waiting_for_its_hold() -> void:
	var tiles := _recorder("tiles", {"UnitMovedEvent": 300, "UnitHitEvent": 100})
	var hud := _recorder("hud")
	var sequencer := _sequencer([tiles, hud])
	tiles.gate = _gate
	hud.gate = _gate
	_queue.push(EventBatch.new(1, [UnitMovedEvent.new(0, 1, 2, 3, 3), UnitHitEvent.new(0, 1, 2, 3, 3)]))
	var finished := [0]
	sequencer.batch_finished.connect(func() -> void: finished[0] += 1)

	sequencer.advance()
	assert_array(tiles.log).is_equal(["tiles:UnitMovedEvent"])
	assert_array(hud.log).is_equal(["hud:UnitMovedEvent"])  # same event, handlers in order
	assert_bool(sequencer.is_idle()).is_false()
	_clock.advance(0.299)
	sequencer.advance()
	assert_int(tiles.log.size()).is_equal(1)
	_clock.advance(0.002)
	sequencer.advance()
	assert_array(tiles.log).is_equal(["tiles:UnitMovedEvent", "tiles:UnitHitEvent"])
	assert_int(finished[0]).is_equal(0)
	_clock.advance(0.1)
	sequencer.advance()

	assert_int(finished[0]).is_equal(1)
	assert_array(tiles.log.slice(-2)).is_equal(["tiles:batch_end", "tiles:idle"])
	assert_bool(sequencer.is_idle()).is_true()
	sequencer.free()


func test_the_handlers_run_under_the_reentrance_guard_only() -> void:
	var recorder := _recorder("a")
	var sequencer := _sequencer([recorder])
	recorder.gate = _gate
	_queue.push(EventBatch.new(1, [UnitMovedEvent.new(0, 1, 2, 3, 3)]))

	sequencer.advance()

	assert_array(recorder.dispatching).is_equal([true])
	assert_bool(_gate.is_dispatching()).is_false()
	sequencer.free()


func test_an_attack_locks_the_player_for_the_whole_attack_lock() -> void:
	var recorder := _recorder("a", {"AttackResolvedEvent": 250, "UnitHitEvent": 350})
	var sequencer := _sequencer([recorder])
	recorder.gate = _gate
	_queue.push(EventBatch.new(1, [AttackResolvedEvent.new(0, 1, 2, 3, 4), UnitHitEvent.new(1, 2, 3, 4, 4)]))

	sequencer.advance()
	assert_bool(_gate.is_locked(Faction.PLAYER, Command.EMITTER_PLAYER)).is_true()
	assert_bool(_gate.is_locked(Faction.AI, Command.EMITTER_AI)).is_false()
	_clock.advance(0.7)  # both holds are over, 600 ms
	sequencer.advance()
	assert_bool(_gate.is_locked(Faction.PLAYER, Command.EMITTER_PLAYER)).is_true()
	assert_bool(sequencer.is_idle()).is_false()
	_clock.advance(0.89)  # 1.59 s
	sequencer.advance()
	assert_bool(_gate.is_locked(Faction.PLAYER, Command.EMITTER_PLAYER)).is_true()
	_clock.advance(0.02)  # 1.61 s
	sequencer.advance()

	assert_bool(_gate.is_locked(Faction.PLAYER, Command.EMITTER_PLAYER)).is_false()
	assert_bool(sequencer.is_idle()).is_true()
	sequencer.free()


func test_a_ruin_reading_waits_for_the_wave_and_the_delay_before_the_panel() -> void:
	var recorder := _recorder("a", {"TileOwnersChangedEvent": 400})
	var sequencer := _sequencer([recorder])
	recorder.gate = _gate
	_queue.push(EventBatch.new(1, [RuinReadEvent.new(0, 1, 2, 5), TileOwnersChangedEvent.new(PackedInt32Array([1]), Faction.NONE, Faction.PLAYER)]))

	sequencer.advance()
	assert_array(recorder.log).is_equal(["a:PresentationRecenter", "a:TileOwnersChangedEvent"])
	_clock.advance(0.401)
	sequencer.advance()
	assert_int(recorder.log.size()).is_equal(2)  # the delay of the panel
	_clock.advance(0.401)
	sequencer.advance()

	assert_array(recorder.log.slice(0, 3)).is_equal(["a:PresentationRecenter", "a:TileOwnersChangedEvent", "a:RuinReadEvent"])
	sequencer.free()


func test_a_resync_batch_empties_the_queue_and_rebuilds_without_waiting() -> void:
	var recorder := _recorder("a", {"UnitMovedEvent": 300})
	var sequencer := _sequencer([recorder])
	recorder.gate = _gate
	_queue.push(EventBatch.new(1, [UnitMovedEvent.new(0, 1, 2, 3, 3)]))
	_queue.push(EventBatch.new(2, [ResyncEvent.new()]))
	_queue.push(EventBatch.new(3, [UnitMovedEvent.new(0, 1, 2, 3, 3)]))
	_gate.lock(PresentationSequencer.ATTACK_RESOLUTION)
	var idles := [0]
	sequencer.idle_reached.connect(func() -> void: idles[0] += 1)
	sequencer.advance()
	_clock.advance(1.0)

	sequencer.advance()

	assert_bool(recorder.log.has("a:rebuild")).is_true()
	assert_int(idles[0]).is_equal(1)
	assert_bool(_queue.is_empty()).is_true()  # the batch 3 behind the resync is gone too
	assert_bool(_gate.is_locked(Faction.PLAYER, Command.EMITTER_PLAYER)).is_false()
	assert_bool(sequencer.is_idle()).is_true()
	sequencer.free()


func test_a_resync_keeps_the_fragment_panel_lock_when_the_panel_is_open() -> void:
	var sequencer := _sequencer([])
	_gate.lock(PresentationSequencer.FRAGMENT_PANEL)
	_gate.lock(PresentationSequencer.ATTACK_RESOLUTION)
	sequencer.panel_open = true

	sequencer.resync()

	assert_bool(_gate.is_locked(Faction.PLAYER, Command.EMITTER_PLAYER)).is_true()
	_gate.unlock(PresentationSequencer.FRAGMENT_PANEL)
	assert_bool(_gate.is_locked(Faction.PLAYER, Command.EMITTER_PLAYER)).is_false()  # the attack lock went
	sequencer.free()


func test_a_paused_clock_stops_the_sequence() -> void:
	var recorder := _recorder("a", {"UnitMovedEvent": 100})
	var sequencer := _sequencer([recorder])
	recorder.gate = _gate
	var clock := PresentationClock.new()
	sequencer.clock = ClockAdapter.new(clock)
	_queue.push(EventBatch.new(1, [UnitMovedEvent.new(0, 1, 2, 3, 3), UnitHitEvent.new(0, 1, 2, 3, 3)]))
	sequencer.advance()
	clock.paused = true

	clock.advance(5.0)
	sequencer.advance()

	assert_int(recorder.log.size()).is_equal(1)
	clock.paused = false
	clock.advance(0.2)
	sequencer.advance()
	assert_int(recorder.log.size()).is_greater(1)
	sequencer.free()
	clock.free()


func test_the_sequencer_lowers_its_locks_when_it_leaves_the_tree() -> void:
	var sequencer := _sequencer([])
	add_child(sequencer)
	_gate.lock(PresentationSequencer.ATTACK_RESOLUTION)

	sequencer.free()

	assert_bool(_gate.is_locked(Faction.PLAYER, Command.EMITTER_PLAYER)).is_false()


func test_the_pacing_gate_follows_the_sequencer() -> void:
	var sequencer := _sequencer([])
	var gate := SequencerPacingGate.new(sequencer)
	assert_bool(gate.is_ready()).is_true()

	_queue.push(EventBatch.new(1, [UnitMovedEvent.new(0, 1, 2, 3, 3)]))
	assert_bool(gate.is_ready()).is_false()  # a batch is waiting
	sequencer.advance()
	sequencer.free()
