# The measures on the reference device (D2: Pixel 8, Android 15+), one line per turn in the log
# (`adb logcat -s godot`): frames, mean and worst frame interval, frames over 33 ms, worst save
# write and worst step of the AI runner seen during the turn. It only reads counters and the
# frame interval; it decides nothing (registry: system_clock_in_game_rule, measure exception).
class_name PerfProbe
extends RefCounted

const TAG := "[mesure]"
## Over this a frame is under 30 per second (the floor of ADR-0012 and ADR-0014).
const SLOW_FRAME_MS := 33.4

## The lines written, for the tests (bounded).
var lines: Array[String] = []
var enabled := true

var _turn := -1
var _frames := 0
var _sum_ms := 0.0
var _worst_ms := 0.0
var _slow := 0
var _worst_write_usec := 0
var _worst_ai_usec := 0

const HISTORY := 64


## One frame of the match: its interval, the turn shown, the last save write and the last AI
## step (their last values, in µs). A new turn closes the previous one's line.
func frame(delta_ms: float, turn: int, last_write_usec: int, last_ai_usec: int) -> void:
	if not enabled:
		return
	if turn != _turn:
		if _turn >= 0 and _frames > 0:
			_emit(summary())
		_reset(turn)
	_frames += 1
	_sum_ms += delta_ms
	_worst_ms = maxf(_worst_ms, delta_ms)
	if delta_ms > SLOW_FRAME_MS:
		_slow += 1
	_worst_write_usec = maxi(_worst_write_usec, last_write_usec)
	_worst_ai_usec = maxi(_worst_ai_usec, last_ai_usec)


## The line of the turn under way.
func summary() -> String:
	return "%s tour %d · %d images · moyenne %.1f ms · pire %.1f ms · > 33 ms : %d · écriture pire %.2f ms · IA pire %.2f ms" % [
		TAG, _turn, _frames, _sum_ms / maxf(_frames, 1), _worst_ms, _slow, _worst_write_usec / 1000.0, _worst_ai_usec / 1000.0]


## The renderer and the device, written once at the start of a match.
func header(adapter: String, method: String, model: String) -> void:
	if enabled:
		_emit("%s rendu %s (%s) · appareil %s" % [TAG, method, adapter, model])


func _reset(turn: int) -> void:
	_turn = turn
	_frames = 0
	_sum_ms = 0.0
	_worst_ms = 0.0
	_slow = 0
	_worst_write_usec = 0
	_worst_ai_usec = 0


func _emit(line: String) -> void:
	print(line)
	lines.append(line)
	if lines.size() > HISTORY:
		lines.pop_front()
