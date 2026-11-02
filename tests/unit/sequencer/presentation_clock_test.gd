extends GdUnitTestSuite


func test_the_clock_advances_with_its_scale_and_stops_when_paused() -> void:
	var clock := PresentationClock.new()
	assert_int(clock.process_priority).is_equal(-20)

	clock.advance(0.5)
	assert_float(clock.current()).is_equal(0.5)
	clock.speed = PresentationClock.Speed.FAST
	clock.advance(0.5)
	assert_float(clock.current()).is_equal(1.5)
	clock.speed = PresentationClock.Speed.INSTANT
	assert_float(clock.scale()).is_greater(100.0)
	clock.speed = PresentationClock.Speed.NORMAL
	clock.paused = true
	clock.advance(10.0)

	assert_float(clock.current()).is_equal(1.5)
	clock.free()


func test_the_adapter_reads_the_clock_node() -> void:
	var clock := PresentationClock.new()
	var source := ClockAdapter.new(clock)

	clock.advance(2.0)

	assert_float(source.current()).is_equal(2.0)
	clock.free()
