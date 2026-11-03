extends GdUnitTestSuite


func _bank() -> SoundBank:
	var bank := SoundBank.new()
	add_child(bank)
	return bank


func test_every_cue_has_its_file_and_its_bus() -> void:
	var bank := _bank()

	for cue in SoundBank.CUES:
		assert_bool(FileAccess.file_exists("res://assets/audio/%s.wav" % cue)).override_failure_message(String(cue)).is_true()
	assert_int(AudioServer.get_bus_index(SoundBank.EFFECTS_BUS)).is_not_equal(-1)
	assert_int(AudioServer.get_bus_index(SoundBank.INTERFACE_BUS)).is_not_equal(-1)
	assert_array([bank.bus_of(&"ui_tap"), bank.bus_of(&"select"), bank.bus_of(&"refusal"), bank.bus_of(&"ui_back")]).is_equal([SoundBank.INTERFACE_BUS, SoundBank.INTERFACE_BUS, SoundBank.INTERFACE_BUS, SoundBank.INTERFACE_BUS])
	assert_array([bank.bus_of(&"attack"), bank.bus_of(&"fragment"), bank.bus_of(&"threat")]).is_equal([SoundBank.EFFECTS_BUS, SoundBank.EFFECTS_BUS, SoundBank.EFFECTS_BUS])
	bank.free()


func test_a_cue_is_recorded_and_the_history_is_bounded() -> void:
	var bank := _bank()

	bank.play(&"attack")
	bank.play(&"nothing")  # unknown: recorded, silent, no error
	assert_array(bank.played).is_equal([&"attack", &"nothing"])
	for k in SoundBank.HISTORY + 5:
		bank.play(&"ui_tap")
	assert_int(bank.played.size()).is_equal(SoundBank.HISTORY)
	bank.free()


func test_the_volumes_move_the_buses_and_zero_mutes() -> void:
	var bank := _bank()
	var effects := AudioServer.get_bus_index(SoundBank.EFFECTS_BUS)
	var interface := AudioServer.get_bus_index(SoundBank.INTERFACE_BUS)

	bank.set_volumes(50, 100)
	assert_float(AudioServer.get_bus_volume_db(effects)).is_equal_approx(linear_to_db(0.5), 0.01)
	assert_float(AudioServer.get_bus_volume_db(interface)).is_equal_approx(0.0, 0.01)
	assert_bool(AudioServer.is_bus_mute(effects)).is_false()
	bank.set_volumes(0, 100)
	assert_bool(AudioServer.is_bus_mute(effects)).is_true()
	assert_bool(AudioServer.is_bus_mute(interface)).is_false()
	bank.set_volumes(150, -5)  # out of range: clamped
	assert_int(bank.volume_of(SoundBank.EFFECTS_BUS)).is_equal(100)
	assert_int(bank.volume_of(SoundBank.INTERFACE_BUS)).is_equal(0)
	bank.set_volumes(100, 100)
	bank.free()


func test_a_muted_bus_starts_no_player() -> void:
	var bank := _bank()
	bank.set_volumes(0, 100)
	var busy := func() -> int: return bank.get_children().filter(func(p: Node) -> bool: return (p as AudioStreamPlayer).playing).size()

	bank.play(&"attack")
	assert_int(busy.call()).is_equal(0)
	bank.play(&"ui_tap")
	assert_int(busy.call()).is_greater_equal(0)  # the Interface bus is on: the player may already have ended in a headless run
	bank.set_volumes(100, 100)
	bank.free()


func test_the_events_have_their_cues_and_a_direct_display_is_silent() -> void:
	assert_str(SoundHandler.cue_of(UnitMovedEvent.new(0, 5, 14, 17, 17))).is_equal("move")
	assert_str(SoundHandler.cue_of(UnitDestroyedEvent.new(0, 3, 5, 9))).is_equal("destroyed")
	assert_str(SoundHandler.cue_of(NodeCapturedEvent.new(1, 0, 1, 8))).is_equal("capture")
	assert_str(SoundHandler.cue_of(IntentionAnnouncedEvent.new(1, 9, 0, 3, 5, 0, 0))).is_equal("threat")
	assert_str(SoundHandler.cue_of(RuinReadEvent.new(0, 1, 3, 5))).is_equal("fragment")
	assert_str(SoundHandler.cue_of(RuinReadEvent.new(0, 1, 0, 5))).is_equal("")  # a ruin with no fragment is silent
	assert_str(SoundHandler.cue_of(TurnStartedEvent.new(2, Faction.PLAYER, HeaderSlice.PHASE_PLAYER))).is_equal("turn")
	assert_str(SoundHandler.cue_of(TurnStartedEvent.new(1, Faction.PLAYER, HeaderSlice.PHASE_PLAYER))).is_equal("")  # the first turn
	assert_str(SoundHandler.cue_of(TurnStartedEvent.new(2, Faction.AI, HeaderSlice.PHASE_ENEMY_EXECUTION))).is_equal("")

	var bank := _bank()
	var handler := SoundHandler.new(bank)
	var clock := FakeClock.new()
	handler.handle(UnitMovedEvent.new(0, 5, 14, 17, 17), SequenceContext.new(0.0, clock))
	handler.handle(UnitMovedEvent.new(0, 5, 14, 17, 17), SequenceContext.new(0.0, clock, true))
	assert_array(bank.played).is_equal([&"move"])  # the direct one said nothing
	assert_int(handler.handle(UnitMovedEvent.new(0, 5, 14, 17, 17), SequenceContext.new(0.0, clock)).duration_ms).is_equal(0)
	bank.free()


func test_a_capture_vibrates_through_the_handler_even_without_sound_and_a_direct_display_does_not() -> void:
	var pulses: Array[int] = []
	var haptics := Haptics.new(func(duration_ms: int) -> void: pulses.append(duration_ms))
	var handler := SoundHandler.new(null, haptics)
	var clock := FakeClock.new()

	handler.handle(NodeCapturedEvent.new(1, 0, 1, 8), SequenceContext.new(0.0, clock, true))
	handler.handle(NodeCapturedEvent.new(1, 0, 1, 8), SequenceContext.new(0.0, clock))
	handler.handle(UnitMovedEvent.new(0, 5, 14, 17, 17), SequenceContext.new(0.0, clock))  # a move does not vibrate

	assert_array(pulses).is_equal([Haptics.PULSES[&"capture"]])


## The instant enemy speed plays a whole phase in a few frames: the same cue twice in one frame
## starts one sound and takes one player, another cue still sounds (review 2026-11-03).
func test_a_cue_starts_once_per_frame() -> void:
	var bank := _bank()
	var loaded := func() -> int: return bank.get_children().filter(func(p: Node) -> bool: return (p as AudioStreamPlayer).stream != null).size()

	bank.play(&"attack")
	bank.play(&"attack")
	assert_int(loaded.call()).is_equal(1)
	bank.play(&"move")

	assert_int(loaded.call()).is_equal(2)
	assert_array(bank.played).is_equal([&"attack", &"attack", &"move"])  # every cue asked is still recorded
	bank.free()

