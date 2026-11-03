extends GdUnitTestSuite


func _haptics(pulses: Array[int]) -> Haptics:
	return Haptics.new(func(duration_ms: int) -> void: pulses.append(duration_ms))


func test_a_refusal_an_attack_and_a_capture_vibrate_and_nothing_else_does() -> void:
	var pulses: Array[int] = []
	var haptics := _haptics(pulses)

	assert_bool(haptics.pulse(&"refusal", 1)).is_true()
	assert_bool(haptics.pulse(&"attack", 2)).is_true()
	assert_bool(haptics.pulse(&"capture", 3)).is_true()
	assert_bool(haptics.pulse(&"move", 4)).is_false()

	assert_array(pulses).is_equal([30, 40, 60])
	assert_array(haptics.pulsed).is_equal([&"refusal", &"attack", &"capture"])


func test_one_pulse_per_frame_at_most() -> void:
	var pulses: Array[int] = []
	var haptics := _haptics(pulses)

	haptics.pulse(&"attack", 7)
	haptics.pulse(&"capture", 7)
	haptics.pulse(&"capture", 8)

	assert_array(pulses).is_equal([40, 60])


func test_the_setting_off_stops_every_pulse() -> void:
	var pulses: Array[int] = []
	var haptics := _haptics(pulses)
	haptics.enabled = false

	assert_bool(haptics.pulse(&"refusal", 1)).is_false()
	assert_array(pulses).is_empty()
