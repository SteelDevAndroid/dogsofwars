# The real PostCommitPort (ADR-0006 §8): after every command applied by the real pipeline,
# whoever emitted it, the match is saved, synchronously, before the events are pushed.
# A failed write is remembered and retried at the next commit and at `retry` (the app
# going to the background); it never blocks the game.
class_name SaveCoordinator
extends PostCommitPort

var last_error: Error = OK
var writes := 0
## Duration of the last write and of the slowest one, in microseconds: what the device
## spike reads to decide the write thread (ADR-0006 §7, review 2026-11-02, A3).
var last_write_usec := 0
var worst_write_usec := 0
var _store: SaveStore


func _init(store: SaveStore) -> void:
	_store = store


func on_commit(state: GameState, _command: Command, _result: ApplyResult) -> void:
	save(state)


func save(state: GameState) -> void:
	var started := Time.get_ticks_usec()
	last_error = _store.save_match(state)
	last_write_usec = Time.get_ticks_usec() - started
	worst_write_usec = maxi(worst_write_usec, last_write_usec)
	writes += 1


## `on_app_paused` (ADR-0006 §11): retry a write that failed.
func retry(state: GameState) -> void:
	if last_error != OK:
		save(state)
