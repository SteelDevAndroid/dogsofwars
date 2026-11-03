# The sound effects of the game (assets/audio, made by tools/audio/make_sounds.py): a pool of
# players, two buses (Effects for what happens on the map, Interface for taps, selection and
# refusals) and their volumes in percent. Every sound has a visual twin elsewhere (a chip, a
# marker, a banner, a panel): none carries information alone (accessibility-requirements).
# `played` keeps the last cues asked, for the tests and for diagnosis.
class_name SoundBank
extends Node

const DIR := "res://assets/audio/"
const EFFECTS_BUS := &"Effects"
const INTERFACE_BUS := &"Interface"
const POOL_SIZE := 8
const HISTORY := 64
## Cues played on the Interface bus; the others are on Effects.
const INTERFACE_CUES := [&"ui_tap", &"ui_back", &"select", &"refusal"]
const CUES := [&"ui_tap", &"ui_back", &"select", &"refusal", &"move", &"attack", &"destroyed", &"threat", &"wake",
		&"capture", &"fragment", &"turn", &"victory", &"defeat"]

var played: Array[StringName] = []

var _streams := {}
var _players: Array[AudioStreamPlayer] = []
var _volume := {EFFECTS_BUS: 100, INTERFACE_BUS: 100}


func _ready() -> void:
	for bus in [EFFECTS_BUS, INTERFACE_BUS]:
		if AudioServer.get_bus_index(bus) < 0:
			AudioServer.add_bus()
			var index := AudioServer.bus_count - 1
			AudioServer.set_bus_name(index, bus)
	for cue in CUES:
		_streams[cue] = load(DIR + String(cue) + ".wav")
	for k in POOL_SIZE:
		var player := AudioStreamPlayer.new()
		add_child(player)
		_players.append(player)
	set_volumes(_volume[EFFECTS_BUS], _volume[INTERFACE_BUS])


## Volumes in percent (0 to 100); 0 mutes the bus.
func set_volumes(effects: int, interface: int) -> void:
	_volume[EFFECTS_BUS] = clampi(effects, 0, 100)
	_volume[INTERFACE_BUS] = clampi(interface, 0, 100)
	for bus: StringName in _volume:
		var index := AudioServer.get_bus_index(bus)
		if index < 0:
			continue
		AudioServer.set_bus_mute(index, _volume[bus] == 0)
		AudioServer.set_bus_volume_db(index, linear_to_db(maxf(_volume[bus] / 100.0, 0.0001)))


func volume_of(bus: StringName) -> int:
	return _volume[bus]


func bus_of(cue: StringName) -> StringName:
	return INTERFACE_BUS if INTERFACE_CUES.has(cue) else EFFECTS_BUS


func play(cue: StringName) -> void:
	played.append(cue)
	if played.size() > HISTORY:
		played.pop_front()
	if not _streams.has(cue) or _volume[bus_of(cue)] == 0 or _players.is_empty():
		return
	var player := _free_player()
	player.bus = bus_of(cue)
	player.stream = _streams[cue]
	player.play()


## An idle player, else the one that has been playing longest (the first of the pool).
func _free_player() -> AudioStreamPlayer:
	for player in _players:
		if not player.playing:
			return player
	return _players[0]
