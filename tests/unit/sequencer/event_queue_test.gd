extends GdUnitTestSuite


func _batch(revision: int, size: int) -> EventBatch:
	var events: Array[PresentationEvent] = []
	for k in size:
		events.append(PresentationEvent.new())
	return EventBatch.new(revision, events)


func test_batches_come_out_in_the_order_they_went_in() -> void:
	var queue := EventQueue.new()
	queue.push(_batch(1, 2))
	queue.push(_batch(2, 1))

	assert_int(queue.event_count()).is_equal(3)
	assert_int(queue.pop().revision).is_equal(1)
	assert_int(queue.pop().revision).is_equal(2)
	assert_object(queue.pop()).is_null()
	assert_bool(queue.is_empty()).is_true()
	assert_int(queue.event_count()).is_equal(0)


func test_a_batch_that_would_overflow_the_queue_leaves_one_resync() -> void:
	var queue := EventQueue.new(10)
	queue.push(_batch(1, 6))
	queue.push(_batch(2, 4))
	assert_int(queue.resyncs).is_equal(0)

	queue.push(_batch(3, 1))

	assert_int(queue.resyncs).is_equal(1)
	assert_int(queue.size()).is_equal(1)
	var only := queue.pop()
	assert_int(only.revision).is_equal(3)
	assert_bool(only.events[0] is ResyncEvent).is_true()


func test_the_bound_is_inclusive() -> void:
	var queue := EventQueue.new(10)

	queue.push(_batch(1, 10))

	assert_int(queue.resyncs).is_equal(0)
	assert_int(queue.event_count()).is_equal(10)
