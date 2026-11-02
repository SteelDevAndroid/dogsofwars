extends GdUnitTestSuite


func test_a_ruin_reading_plays_the_wave_then_the_delay_then_the_panel() -> void:
	var read := RuinReadEvent.new(0, 1, 2, 5)
	var wave := TileOwnersChangedEvent.new(PackedInt32Array([1, 2]), Faction.NONE, Faction.PLAYER)
	var moved := UnitMovedEvent.new(0, 1, 3, 5, 5)
	var batch := EventBatch.new(4, [read, wave, moved])

	var steps := SequenceOrder.steps(batch, CatalogFactory.standard().presentation)

	assert_int(steps.size()).is_equal(4)
	assert_object(steps[0]).is_same(wave)
	assert_object(steps[1]).is_same(moved)
	assert_object(steps[2]).is_instanceof(PresentationPause)
	assert_int((steps[2] as PresentationPause).duration_ms).is_equal(400)
	assert_object(steps[3]).is_same(read)


func test_other_batches_keep_their_order() -> void:
	var a := UnitMovedEvent.new(0, 1, 3, 5, 5)
	var b := AttackResolvedEvent.new(0, 1, 2, 5, 6)
	var c := UnitHitEvent.new(1, 2, 3, 4, 6)

	var steps := SequenceOrder.steps(EventBatch.new(1, [a, b, c]), CatalogFactory.standard().presentation)

	assert_array(steps).is_equal([a, b, c])
