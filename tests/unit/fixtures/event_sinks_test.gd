extends GdUnitTestSuite


func test_recording_sink_keeps_batches_in_push_order() -> void:
	var sink := RecordingSink.new()
	var first := EventBatch.new(1)
	var second := EventBatch.new(2)

	sink.push(first)
	sink.push(second)

	assert_array(sink.batches).contains_exactly([first, second])


func test_null_sink_accepts_batches_and_keeps_nothing() -> void:
	var sink := NullSink.new()

	sink.push(EventBatch.new(1))

	assert_object(sink).is_instanceof(EventSink)


func test_event_batch_command_id_is_revision() -> void:
	var batch := EventBatch.new(7)

	assert_int(batch.command_id).is_equal(7)
