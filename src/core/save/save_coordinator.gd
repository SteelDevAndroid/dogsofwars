# The real PostCommitPort (ADR-0006 §8): after every command applied by the real pipeline,
# whoever emitted it, the match is saved, synchronously, before the events are pushed.
# A failed write is remembered and retried at the next commit and at `retry` (the app
# going to the background); it never blocks the game.
class_name SaveCoordinator
extends PostCommitPort

var last_error: Error = OK
var writes := 0
var _store: SaveStore


func _init(store: SaveStore) -> void:
	_store = store


func on_commit(state: GameState, _command: Command, _result: ApplyResult) -> void:
	save(state)


func save(state: GameState) -> void:
	last_error = _store.save_match(state)
	writes += 1


## `on_app_paused` (ADR-0006 §11): retry a write that failed.
func retry(state: GameState) -> void:
	if last_error != OK:
		save(state)
