extends GdUnitTestSuite


func test_a_new_turn_writes_the_line_of_the_last_one() -> void:
	var probe := PerfProbe.new()

	probe.frame(16.0, 1, 0, 0)
	probe.frame(40.0, 1, 3000, 0)
	probe.frame(18.0, 1, 1000, 7500)
	assert_array(probe.lines).is_empty()  # the turn is still under way
	probe.frame(16.0, 2, 0, 0)

	assert_int(probe.lines.size()).is_equal(1)
	assert_str(probe.lines[0]).is_equal("[mesure] tour 1 · 3 images · moyenne 24.7 ms · pire 40.0 ms · > 33 ms : 1 · écriture pire 3.00 ms · IA pire 7.50 ms")
	assert_str(probe.summary()).starts_with("[mesure] tour 2 · 1 images")


func test_switched_off_it_writes_nothing() -> void:
	var probe := PerfProbe.new()
	probe.enabled = false

	probe.header("x", "mobile", "Pixel 8")
	probe.frame(16.0, 1, 0, 0)
	probe.frame(16.0, 2, 0, 0)

	assert_array(probe.lines).is_empty()


func test_the_header_names_the_renderer_and_the_device() -> void:
	var probe := PerfProbe.new()

	probe.header("Mali-G715", "mobile", "Pixel 8")

	assert_str(probe.lines[0]).is_equal("[mesure] rendu mobile (Mali-G715) · appareil Pixel 8")
