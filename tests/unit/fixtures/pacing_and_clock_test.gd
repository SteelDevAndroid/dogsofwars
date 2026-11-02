extends GdUnitTestSuite


func test_always_ready_pacing_gate_is_ready() -> void:
	assert_bool(AlwaysReadyPacingGate.new().is_ready()).is_true()


func test_fake_clock_starts_at_given_time() -> void:
	assert_float(FakeClock.new(1.5).current()).is_equal(1.5)


func test_fake_clock_advances_by_hand_only() -> void:
	var clock := FakeClock.new()

	clock.advance(0.25)
	clock.advance(0.5)

	assert_float(clock.current()).is_equal(0.75)
