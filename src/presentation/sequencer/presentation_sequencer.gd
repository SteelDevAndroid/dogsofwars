# The presentation sequencer (ADR-0002 §5 to §8): plays the batches of the event queue one
# at a time, an event after the other. Idle, it pops a batch; for each step it calls every
# handler in a fixed order (re-entrance guard up around the calls), waits for the longest
# hold of the step on the presentation clock, and when the batch is over lets the handlers
# draw the new state. A reading of a ruin or an attack raises a player lock for as long as
# it plays (the fragment panel lock is lowered by the HUD). Paused, the clock stops and so
# does everything: no coroutine, no timer, cancelling is going back to IDLE.
class_name PresentationSequencer
extends Node

signal batch_finished
signal idle_reached

const ATTACK_RESOLUTION := &"ATTACK_RESOLUTION"
const FRAGMENT_PANEL := &"FRAGMENT_PANEL"

var queue: EventQueue
var clock: ClockSource
var gate: CommandGate
var params: PresentationParams
## Presenters, called in this order for every event.
var handlers: Array[PresentationHandler] = []
## Reduced animations: waves merge into slots, attack steps keep their order and lengths.
var reduced_motion := false
var state: GameState
## True while the fragment panel is open (a resynchronisation then keeps its lock).
var panel_open := false

var _steps: Array[PresentationEvent] = []
var _step := 0
var _deadline := 0.0
var _playing := false
var _attack_lock_until := -1.0
var _attack_locked := false
var _idle_announced := true


func _init() -> void:
	process_priority = 0


func _process(_delta: float) -> void:
	advance()


func is_idle() -> bool:
	return not _playing and (queue == null or queue.is_empty())


func _exit_tree() -> void:
	if gate != null:
		gate.clear_player_locks()


## One tick: finish the step that is over, then start the next one.
func advance() -> void:
	if queue == null:
		return
	while true:
		var now := clock.current()
		if _playing:
			if now < _deadline:
				return
			_step += 1
			if _step >= _steps.size() and _attack_locked and _attack_lock_until > now:
				# the attack lock lasts ATTACK_LOCK_MS in all: wait out what is left of it
				_steps.append(PresentationPause.new(ceili((_attack_lock_until - now) * 1000.0)))
			if _step < _steps.size():
				_dispatch(_steps[_step], now)
				continue
			_end_batch()
			continue
		var batch := queue.pop()
		if batch == null:
			if not _idle_announced:
				_idle_announced = true
				for handler in handlers:
					handler.on_idle(state)
				idle_reached.emit()
			return
		_idle_announced = false
		if batch.events.size() == 1 and batch.events[0] is ResyncEvent:
			resync()
			continue
		_steps = SequenceOrder.steps(batch, params)
		_step = 0
		_playing = true
		_deadline = now
		if _steps.is_empty():
			_end_batch()
			continue
		_dispatch(_steps[0], now)


## Resynchronisation or load (ADR-0002 §7): empty the queue, cancel, lower the player locks
## except the fragment panel when it is open, show the state directly.
func resync() -> void:
	queue.drain()
	_playing = false
	_steps.clear()
	_attack_locked = false
	gate.clear_player_locks(FRAGMENT_PANEL if panel_open else &"")
	for handler in handlers:
		handler.rebuild_from_state(state)
	_idle_announced = false


func _dispatch(event: PresentationEvent, now: float) -> void:
	var hold_ms := 0
	if event is PresentationPause:
		hold_ms = (event as PresentationPause).duration_ms
	else:
		if event is AttackResolvedEvent:
			gate.lock(ATTACK_RESOLUTION)
			_attack_locked = true
			_attack_lock_until = now + params.value("attack_lock_ms") / 1000.0
		var context := SequenceContext.new(now, clock, false, reduced_motion)
		gate.enter_dispatch()
		for handler in handlers:
			hold_ms = maxi(hold_ms, handler.handle(event, context).duration_ms)
		gate.exit_dispatch()
	_deadline = now + hold_ms / 1000.0


func _end_batch() -> void:
	_playing = false
	_steps.clear()
	_step = 0
	if _attack_locked:
		gate.unlock(ATTACK_RESOLUTION)
		_attack_locked = false
	for handler in handlers:
		handler.on_batch_end(state)
	batch_finished.emit()
