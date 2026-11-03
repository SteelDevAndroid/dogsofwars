extends GdUnitTestSuite

const WIDTH := 16
const CENTER := 6 * WIDTH + 6  # (6,6), index 102


func _params() -> PresentationParams:
	return CatalogFactory.standard().presentation


## The square of the given radius around `source`, clipped by the map.
func _square(source: int, radius: int) -> PackedInt32Array:
	var tiles := PackedInt32Array()
	for y in range(maxi(0, source / WIDTH - radius), mini(WIDTH, source / WIDTH + radius + 1)):
		for x in range(maxi(0, source % WIDTH - radius), mini(WIDTH, source % WIDTH + radius + 1)):
			tiles.append(y * WIDTH + x)
	return tiles


func _starts(plan: WavePlan) -> Array:
	return plan.steps.map(func(step: Array) -> int: return step[0])


func _sizes(plan: WavePlan) -> Array:
	return plan.steps.map(func(step: Array) -> int: return step[1].size())


func test_the_ring_is_the_chebyshev_distance_and_rings_are_ordered_by_tile_index() -> void:
	assert_int(WaveSchedule.ring_of(WIDTH, CENTER, 5 * WIDTH + 8)).is_equal(2)  # (8,5), index 88

	var plan := WaveSchedule.plan(WIDTH, PackedInt32Array([117, 88, 87]), CENTER, _params())

	assert_array(_starts(plan)).is_equal([200, 400])
	assert_array(Array(plan.steps[0][1])).is_equal([87, 117])  # (7,5) before (5,7), both in ring 1
	assert_array(Array(plan.steps[1][1])).is_equal([88])


func test_a_wave_from_a_corner_has_1_3_5_7_tiles_per_ring() -> void:
	var plan := WaveSchedule.plan(WIDTH, _square(0, 3), 0, _params())

	assert_array(_sizes(plan)).is_equal([1, 3, 5, 7])


func test_radius_1_2_3_start_every_200_ms_and_last_600_800_1000_ms() -> void:
	# [radius, starts in ms, tiles per ring, length in ms] (GDD 15 AC-RC9)
	var cases := [[1, [0, 200], [1, 8], 600], [2, [0, 200, 400], [1, 8, 16], 800], [3, [0, 200, 400, 600], [1, 8, 16, 24], 1000]]
	for entry: Array in cases:
		var plan := WaveSchedule.plan(WIDTH, _square(CENTER, entry[0]), CENTER, _params())

		assert_array(_starts(plan)).is_equal(entry[1])
		assert_array(_sizes(plan)).is_equal(entry[2])
		assert_int(plan.duration_ms).is_equal(entry[3])


func test_rings_past_k_max_start_with_ring_k_max_and_the_wave_stays_within_a_second() -> void:
	var plan := WaveSchedule.plan(WIDTH, _square(0, 6), 0, _params())  # a corner source: rings 0 to 6

	assert_array(_starts(plan)).is_equal([0, 200, 400, 600])
	assert_array(_sizes(plan)).is_equal([1, 3, 5, 7 + 9 + 11 + 13])
	assert_int(plan.duration_ms).is_equal(1000)


func test_the_ring_delay_shrinks_so_that_no_wave_outlasts_the_total() -> void:
	var docs := CatalogFactory.documents()
	docs["presentation.json"]["wave_rings_max"] = 4
	var params := CatalogFactory.load_documents(docs).catalog.presentation

	assert_int(WaveSchedule.ring_ms(params)).is_equal(150)  # min(200, (1000 - 400) div 4)
	assert_int(WaveSchedule.plan(WIDTH, _square(0, 6), 0, params).duration_ms).is_equal(1000)
	assert_str(params.ring_trace()).contains("shortened to 150 ms")  # AC-RC10: the loading says so
	assert_str(_params().ring_trace()).is_empty()  # 3 x 200 + 400 = 1000: nothing to shorten


func test_no_source_or_no_tile_means_no_wave() -> void:
	assert_array(WaveSchedule.plan(WIDTH, _square(CENTER, 1), -1, _params()).steps).is_empty()
	assert_int(WaveSchedule.plan(WIDTH, _square(CENTER, 1), -1, _params()).duration_ms).is_equal(0)
	assert_array(WaveSchedule.plan(WIDTH, PackedInt32Array(), CENTER, _params()).steps).is_empty()


func test_the_plan_is_the_same_on_every_run() -> void:
	var tiles := _square(CENTER, 3)
	var first := WaveSchedule.plan(WIDTH, tiles, CENTER, _params())
	for run in 100:
		var again := WaveSchedule.plan(WIDTH, tiles, CENTER, _params())
		assert_array(_starts(again)).is_equal(_starts(first))
		assert_array(again.steps.map(func(step: Array) -> Array: return Array(step[1]))) \
				.is_equal(first.steps.map(func(step: Array) -> Array: return Array(step[1])))
