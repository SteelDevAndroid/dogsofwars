# Command gate (ADR-0002 §8): the re-entrance guard armed while the presentation
# dispatches a batch, and the player locks (attack resolution, fragment panel).
# Never saved, never copied; simulations and the replay do not use it.
class_name CommandGate
extends RefCounted

var _dispatching := false
var _player_locks: Dictionary = {}


func enter_dispatch() -> void:
	_dispatching = true


func exit_dispatch() -> void:
	_dispatching = false


func is_dispatching() -> bool:
	return _dispatching


## Player faction only.
func lock(reason: StringName) -> void:
	_player_locks[reason] = true


func unlock(reason: StringName) -> void:
	_player_locks.erase(reason)


## True during a dispatch, or under a player lock for a PLAYER emitter of the
## player's faction: the AI and SYS commands (VALIDER_LA_LECTURE) are never locked.
func is_locked(faction: int, emitter: int) -> bool:
	if _dispatching:
		return true
	return not _player_locks.is_empty() and faction == Faction.PLAYER and emitter == Command.EMITTER_PLAYER


func clear_player_locks(except: StringName = &"") -> void:
	var kept := _player_locks.has(except)
	_player_locks.clear()
	if kept:
		_player_locks[except] = true
