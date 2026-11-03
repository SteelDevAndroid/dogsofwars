# Short vibrations on Android (setting "Vibrations"): a refusal, an attack, a capture. They only
# double a sound or a picture, never carry an information alone (ADR-0013, accessibility). At
# the instant enemy speed a phase plays in a few frames: one pulse per frame at most (the first
# one of the frame), the others are dropped.
class_name Haptics
extends RefCounted

## Cue -> duration in ms (the cues of SoundHandler and of the refusal toast).
const PULSES := {&"refusal": 30, &"attack": 40, &"capture": 60}

var enabled := true
## The pulses started, for the tests (bounded).
var pulsed: Array[StringName] = []

const HISTORY := 32

var _vibrate: Callable
var _last_frame := -1


## `vibrate(duration_ms: int)`: the device call; by default the engine's handheld vibration.
func _init(vibrate: Callable = Callable()) -> void:
	_vibrate = vibrate if vibrate.is_valid() else func(duration_ms: int) -> void: Input.vibrate_handheld(duration_ms)


## Vibrates for `cue` if it has a pulse, the setting is on and no pulse started this frame.
func pulse(cue: StringName, frame: int = -1) -> bool:
	if not enabled or not PULSES.has(cue):
		return false
	var now := frame if frame >= 0 else Engine.get_process_frames()
	if now == _last_frame:
		return false
	_last_frame = now
	pulsed.append(cue)
	if pulsed.size() > HISTORY:
		pulsed.pop_front()
	_vibrate.call(PULSES[cue])
	return true
